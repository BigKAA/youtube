# ArgoCD Vault plugin

- [ArgoCD Vault plugin](#argocd-vault-plugin)
  - [Hashicorp vault](#hashicorp-vault)
    - [Установка](#установка)
    - [Добавление данных](#добавление-данных)
  - [Настройка ArgoCD](#настройка-argocd)
    - [Values file](#values-file)
      - [Конфигурация плагинов](#конфигурация-плагинов)
      - [Конфигурация repo server](#конфигурация-repo-server)
      - [Правила RBAC](#правила-rbac)
      - [InitContainer](#initcontainer)
      - [Sidecar containers](#sidecar-containers)
      - [Дополнительные тома](#дополнительные-тома)
  - [Включаем ArgoCD](#включаем-argocd)
  - [Подстановка значений в Secret](#подстановка-значений-в-secret)
    - [Plain text](#plain-text)
    - [Base64](#base64)
  - [ArgoCD application](#argocd-application)

## Hashicorp vault

### Установка

Тем, у кого уже есть живой vault, данный раздел можно пропустить.

```bash
helm install vault hide-charts/vault-helm-0.29.1 -n vault --create-namespace -f my-vault-values.yaml
```

Распечатем хранилище:

```bash
kubectl -n vault exec vault-0 -- vault status
kubectl -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
kubectl -n vault exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
```

### Добавление данных

Получим токен для входа в UI:

```bash
cat cluster-keys.json | jq -r ".root_token"
```

Подготовим "поляну" для работы ArgoCD.

```bash
kubectl -n vault exec -it vault-0 -- /bin/sh
vault login

vault secrets enable -path=test kv-v2

vault auth enable kubernetes
vault auth list

vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    issuer="https://kubernetes.default.svc.cluster.local"
```

Добавим данные секретные данные: пользователь и его пароль в `/test/user`:

```bash
vault kv put -mount=test user password="thepassword" login="user"
vault kv get -mount=test user
```

Создаём политику и связанную с ней роль:

```bash
vault policy write test-policy - <<EOF
path "test/data/user" {
  capabilities = ["read"]
}
EOF

vault policy read test-policy

vault write auth/kubernetes/role/argocd \
    bound_service_account_names=argocd-repo-server \
    bound_service_account_namespaces=argocd \
    policies=test-policy \
    ttl=20m
```

## Настройка ArgoCD

В моем случае ArgoCD уже работает. Он был установлен при помощи Helm chart. Обычно это происходит [как то так](https://github.com/BigKAA/youtube/tree/master/1.31/04-argocd).

Для работы с vault, ArgoCD будет использовать дополнительное приложение: [Argo CD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/).

Задача приложения прочитать данные на входе. Вместо [специальных тегов](https://argocd-vault-plugin.readthedocs.io/en/stable/howitworks/) подставить значения, которые будут получены из vault.

### Values file

Helm chart ArgoCD содержит всё (или почти всё) необходимое для добавления и конфигурации плагина.

#### Конфигурация плагинов

Текущая версия ArgoCD для добавления плагинов рекомендует использовать [Sidecar plugin](https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins).

__Важно!__ Для каждой конфигурации плагина создаётся отдельный sidecar контейнер.

Конфигурация плагина происходит при помощи специального конфигурационного файла. Чей синтаксис напоминает синтаксис манифестов kubernetes.

В values файле добавляем секцию `configs.cmp`. Которая создает config map с именем `argocd-cmp-cm`:

```yaml
configs:
  cmp:
    create: true
    plugins:
      avp-plugin-kustomize:
        allowConcurrency: true
        discover:
          find:
            command:
              - find
              - "."
              - -name
              - kustomization.yaml
        generate:
          command:
            - sh
            - "-c"
            - "kustomize build . | argocd-vault-plugin generate -"
        lockRepo: false

      avp-plugin-helm:
        allowConcurrency: true
        discover:
          find:
            command:
              - sh
              - "-c"
              - "find . -name 'Chart.yaml' && find . -name 'values.yaml'"
        generate:
          # **IMPORTANT**: passing `${ARGOCD_ENV_helm_args}` effectively allows users to run arbitrary code in the Argo CD 
          # repo-server (or, if using a sidecar, in the plugin sidecar). Only use this when the users are completely trusted. If
          # possible, determine which Helm arguments are needed by your users and explicitly pass only those arguments.
          command:
            - sh
            - "-c"
            - |
              helm template $ARGOCD_APP_NAME -n $ARGOCD_APP_NAMESPACE ${ARGOCD_ENV_HELM_ARGS} . |
              argocd-vault-plugin generate --verbose-sensitive-output -
        lockRepo: false

      avp-plugin:
        allowConcurrency: true
        discover:
          find:
            command:
              - sh
              - "-c"
              - "find . -name '*.yaml' | xargs -I {} grep \"<path\\|avp\\.kubernetes\\.io\" {} | grep ."
        generate:
          command:
            - argocd-vault-plugin
            - generate
            - "."
        lockRepo: false
```

В нашем примере в config map будут описаны три файла:

- `avp-plugin-kustomize.yaml` (Как пример. В дальнейшем я его использовать не буду).
- `avp-plugin-helm.yaml`
- `avp-plugin.yaml`

#### Конфигурация repo server

C плагинами работает `argocd-repo-server`. Поэтому дальше колдуем над этим подом.

В файле values добавляем секцию `repoServer`.

В которой:

- Добавим правила RBAC, для доступа к secrets и configMaps.
- Подключим initContainer, загружающий приложение плагина в файловую систему пода.
- Добавим sidecar containers, с отдельными плагинами.
- Определим дополнительные volumes.

#### Правила RBAC

Добавляем возможность получения информации о secrets и configMaps:

```yaml
repoServer:
  rbac:
  - verbs:
      - get
      - list
      - watch
    apiGroups:
      - ''
    resources:
      - secrets
      - configmaps
```

#### InitContainer

Задача initContainer - загрузить плагин в файловую систему пода.

```yaml
repoServer:
  initContainers:
  - name: download-tools
    image: alpine:3.8
    command: [sh, -c]
    env:
      - name: AVP_VERSION
        value: "1.18.1"
    args:
      - >-
        wget -O argocd-vault-plugin
        https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v${AVP_VERSION}/argocd-vault-plugin_${AVP_VERSION}_linux_amd64 &&
        chmod +x argocd-vault-plugin &&
        mv argocd-vault-plugin /custom-tools/
    volumeMounts:
      - mountPath: /custom-tools
        name: custom-tools
```

Определение volume `custom-tools` будет чуть ниже.

#### Sidecar containers

Я предполагаю использовать плагин для обработки простых манифестов и helm charts. Поэтому определю два дополнительных контейнера:

```yaml
repoServer:
  extraContainers:
  - name: avp-helm
    command: [/var/run/argocd/argocd-cmp-server]
    image: quay.io/argoproj/argocd:v2.13.0
    securityContext:
      runAsNonRoot: true
      runAsUser: 999
    env:
      - name: HELM_CACHE_HOME
        value: /helm-working-dir
      - name: HELM_CONFIG_HOME
        value: /helm-working-dir
      - name: HELM_DATA_HOME
        value: /helm-working-dir
    volumeMounts:
      - name: var-files
        mountPath: /var/run/argocd
      - name: plugins
        mountPath: /home/argocd/cmp-server/plugins
      - name: cmp-tmp
        mountPath: /tmp
      
      # Register plugins into sidecar
      - name: cmp-plugin
        mountPath: /home/argocd/cmp-server/config/plugin.yaml
        subPath: avp-plugin-helm.yaml
        
      - name: custom-tools
        subPath: argocd-vault-plugin
        mountPath: /usr/local/bin/argocd-vault-plugin
      - name: helm-temp-dir
        mountPath: /helm-working-dir

  - name: avp-plain
    command: [/var/run/argocd/argocd-cmp-server]
    image: quay.io/argoproj/argocd:v2.13.0
    securityContext:
      runAsNonRoot: true
      runAsUser: 999
    volumeMounts:
      - name: var-files
        mountPath: /var/run/argocd
      - name: plugins
        mountPath: /home/argocd/cmp-server/plugins
      - name: cmp-tmp
        mountPath: /tmp
      
      # Register plugins into sidecar
      - name: cmp-plugin
        mountPath: /home/argocd/cmp-server/config/plugin.yaml
        subPath: avp-plugin.yaml
        
      - name: custom-tools
        subPath: argocd-vault-plugin
        mountPath: /usr/local/bin/argocd-vault-plugin
```

Обязательным условием работы контейнера является наличие конфигурационного файла `/home/argocd/cmp-server/config/plugin.yaml`. Мы получаем его из configMap, который мы определили выше. Соответствующий том (`cmp-plugin`) мы опишем в следующем разделе.

#### Дополнительные тома

```yaml
repoServer:
  # -- Additional volumeMounts to the repo server main container
  volumeMounts:
  - name: custom-tools
    mountPath: /usr/local/bin/argocd-vault-plugin
    subPath: argocd-vault-plugin

  # -- Additional volumes to the repo server pod
  volumes: 
  - name: custom-tools
    emptyDir: {}
  - name: cmp-plugin
    configMap:
      name: argocd-cmp-cm
  - name: cmp-tmp
    emptyDir: {}
  - name: helm-temp-dir
    emptyDir: {}
```

## Включаем ArgoCD

Поскольку у меня ArgoCD уже был запущен, произведу апгрейд чарта:

```shell
helm upgrade argocd argocd/argo-cd -f my-argo-values.yaml -n argocd
```

## Подстановка значений в Secret

Вариантов подстановки много. Подробно как вставлять значения из vault можно почитать в [документации](https://argocd-vault-plugin.readthedocs.io/en/stable/howitworks/).

### Plain text

Пример простейшего secret.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
  annotations:
    avp.kubernetes.io/path: "test/data/user"
type: Opaque
stringData:
  LOGIN: <login>
  PASSWORD: <password>
```

Обратите внимание на аннотацию, в которой указывается путь к хранилищу в vault. "Подсмотреть", какой путь следует использовать, можно в WEB UI vault.
В нашем случае эта аннотация обязательна, поскольку мы используем её при конфигурации плагина. Точнее, мы ищем поле key аннотации:

```yaml
      avp-plugin:
        allowConcurrency: true
        discover:
          find:
            command:
              - sh
              - "-c"
              - "find . -name '*.yaml' | xargs -I {} grep \"<path\\|avp\\.kubernetes\\.io\" {} | grep ."
```

### Base64

Второй пример secret показывает, как подставить данные в формате base64:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: test-secret2
  annotations:
    avp.kubernetes.io/path: "test/data/user"
type: Opaque
data:
  LOGIN: <login | base64encode >
  PASSWORD: <password | base64encode>
```

## ArgoCD application

В манифесте application добавим параметры плагина. В этом примере не указан конкретный плагин. ArgoCD по конфигурации само определит, какой плагин использовать. Но, в принципе, можно указывать какой плагин будет использоваться.

```yaml
spec:
  source:
    plugin:
      env:
        - name: AVP_TYPE
          value: vault
        - name: AVP_AUTH_TYPE
          value: k8s
        - name: AVP_K8S_ROLE
          value: argocd
        - name: VAULT_ADDR
          value: http://vault.vault.svc:8200
```

Создаем тестовый проект:

```shell
kubectl -n argocd apply -f argo-test-app.yaml
```
