# Spilo helm chart

На основании полученных манифестов создадим helm chart.

```shell
helm create spilo-art
```

## Подготовка шаблона

Удалим не нужные файлы и директории

```shell
rm -rf spilo-art/templates/tests
rm -rf spilo-art/templates/hpa.yaml
rm -rf spilo-art/templates/service.yaml
rm -rf spilo-art/templates/serviceaccount.yaml
rm -rf spilo-art/templates/deployment.yaml
rm -rf spilo-art/templates/ingress.yaml
rm -rf spilo-art/templates/NOTES.txt
```

Создадим файлы шаблонов. Желательно это делать не в виде одного файла, как это сейчас сделано в манифесте.
А по отдельному файлу для каждого kind.

```shell
touch spilo-art/templates/sts.yaml
touch spilo-art/templates/pvc.yaml
touch spilo-art/templates/endpoints.yaml
touch spilo-art/templates/service.yaml
touch spilo-art/templates/servicereplicas.yaml
touch spilo-art/templates/serviceheadless.yaml
touch spilo-art/templates/secret.yaml
touch spilo-art/templates/sa.yaml
touch spilo-art/templates/role.yaml
touch spilo-art/templates/rolebinding.yaml
touch spilo-art/templates/configmap.yaml
```

Скопируем без изменений содержимое каждого kind из общего файла манифеста в файлы шаблонов.

Создадим файл `Chart.yaml`

```shell
cat > spilo-art/Chart.yaml << EOF  
apiVersion: v2
name: spilo-art
description: A Helm chart of spilo
type: application
version: 1.0.1
appVersion: "3.0-p1"
sources:
  - "https://github.com/zalando/spilo/blob/master/kubernetes/spilo_kubernetes.yaml"
maintainers:
  - name: Arthur Kryukov
    url: "https://www.kryukov.biz"
EOF
```

Сделаем копию файла `values.yaml`. И создадим новый, пустой файл.

```shell
mv spilo-art/values.yaml spilo-art/values-old.yaml
cat > spilo-art/values.yaml << EOF
# Configuration parameters
nameOverride: ""
fullnameOverride: ""
EOF
```

## Labeles

В работе кластера spilo важнейшую роль играют labels, которые будут установлены на различные компоненты. В
[документации по переменным среды окружения](https://github.com/zalando/spilo/blob/master/ENVIRONMENT.rst) следует
обратить внимание на переменные:

* **KUBERNETES_ROLE_LABEL**: имя метки, содержащей роль Postgres при запуске в Kubernetens. Значение по умолчанию - 
  `spilo-role`.
* **KUBERNETES_SCOPE_LABEL**: имя метки, содержащей название кластера. Значение по умолчанию - `version`.
* **KUBERNETES_LABELS**: JSON список, содержащий имена и значения других меток, используемых Patroni в Kubernetes для 
  поиска своих метаданных. Значение по умолчанию равно `{"application": "spilo"}`

Добавим определение значения этих переменных в файл `values.yaml`

```yaml
spilo:
  env:
    kubernetesRoleLabel: role
    kubernetesScopeLabel: spilo-cluster
    kubernetesLabels:
      application: spilo
```

Внесём изменения в шаблоны генерации labels в файле `_helpers.tpl`.

```yaml
{{/*
Common labels - Включает в себя все возможные labels
*/}}
{{- define "spilo-art.labels" -}}
{{ include "spilo-art.headerLabels" . }}
{{ include "spilo-art.selectorLabels" . }}
{{- end }}

{{/*
Base labels - Заголовочные labels.
*/}}
{{- define "spilo-art.headerLabels" -}}
helm.sh/chart: {{ include "spilo-art.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels - базовые labels, используемые для секции selectors. Включая специфические для 
контейнеров spilo.
*/}}
{{- define "spilo-art.selectorLabels" -}}
{{ include "spilo-art.baseSelectorLabels" . }}
{{- with .Values.spilo.env.kubernetesLabels }}
{{ toYaml . }}
{{- end }}
{{ .Values.spilo.env.kubernetesScopeLabel }}: {{ include "spilo-art.fullname" . }}
{{- end }}

{{/*
Base Selector labels - базовые labels, используемые для секции selectors.
*/}}
{{- define "spilo-art.baseSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spilo-art.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### StatefulSet

Добавим конфигурационные параметры в переменные среды окружения StatefulSet.

```yaml
        - name: KUBERNETES_SCOPE_LABEL
          value: {{ .Values.spilo.env.kubernetesScopeLabel }}
        - name: KUBERNETES_ROLE_LABEL
          value: {{ .Values.spilo.env.kubernetesRoleLabel }}
        - name: KUBERNETES_LABELS
          value: '{{ toJson .Values.spilo.env.kubernetesLabels }}'
```

Так же необходимо подставить определение labels.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: &cluster_name {{ include "spilo-art.fullname" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "spilo-art.selectorLabels" . | nindent 6 }}
  replicas: 3
  serviceName: *cluster_name
  podManagementPolicy: Parallel
  template:
    metadata:
      labels:
        {{- include "spilo-art.selectorLabels" . | nindent 8 }}
```

```yaml
  volumeClaimTemplates:
  - metadata:
      labels:
        {{- include "spilo-art.selectorLabels" . | nindent 8 }}
      name: pgdata
```

И еще одно место:

```yaml
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: {{ .Values.spilo.env.kubernetesScopeLabel }}
                    operator: In
                    values:
                      - *cluster_name
              topologyKey: "kubernetes.io/hostname"
```

Проверим правильность генерации шаблона.

```shell
helm template test spilo-art > app.yaml
```

## ServiceAccount, Role, RoleBinding

Для работы spilo нам потребуется создать ServiceAccount, Role, RoleBinding.

### ServiceAccount

Для того, что бы была возможность явно определять имя ServiceAccount, в файле `values.yaml` добавим следующие строки:

```yaml
serviceAccount:
  name: ""
```

Поскольку Создание ServiceAccount обязательно, из файла `_helpers.tpl` в определении имени нужно удалить оператор if.
В результате шаблон будет выглядеть следующим образом:

```gotemplate
{{- define "spilo-art.serviceAccountName" -}}
{{- default (include "spilo-art.fullname" .) .Values.serviceAccount.name }}
{{- end }}
```

Шаблон ServiceAccount:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "spilo-art.serviceAccountName" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
```

Имя для ServiceAccount формируется в `_helpers.tpl`. Поэтому мы можем использовать `include`.
Секция `labels` не обязательна, но лучше её определить.

### Role

В шаблоне роли необходимо определить только имя роли. И, если хотите, секцию `labels`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "spilo-art.serviceAccountName" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
```

### RoleBinding

В шаблоне RoleBinding, по аналогии с Role, определяем имя. Добавляем имена Role и ServiceAccount

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "spilo-art.serviceAccountName" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "spilo-art.serviceAccountName" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "spilo-art.serviceAccountName" . }}
```

### StatefullSet

В StatefullSet мы используем ServiceAccount. Добавляем генерацию его имени.

```yaml
    spec:
      serviceAccountName: {{ include "spilo-art.serviceAccountName" . }}
```

Попробуем сгенерировть шаблон.

```shell
helm template test spilo-art > app.yaml
```

## Раздел для резервного копирования.

Мы должны иметь возможность:

* Включать/выключать резервное копирование.
* Определять параметры PVC.

В `values.yaml` добавим секцию `backup` и параметры PVC по умолчанию.

```yaml
backup:
  enable: true
  # Если используется готовый PVC, укажите его имя.
  externalPvcName: ""
  # Не удалять PVC после удаления чарта.
  dontDeletePvc: false
  PVC:
    # storageClassName: "managed-nfs-storage"
    accessModes:
    - ReadWriteMany
    resources:
      requests:
        storage: 2Gi
```

_В дальнейшем мы еще раз пройдёмся по файлу и установим нормальные значения по умолчанию._

Так же нам следует пройтись по шаблонам, где происходит определение параметров, связанных с
резервным копированием.

### PVC

Шаблон PVC

```yaml
{{- if and .Values.backup.enable (empty .Values.backup.externalPvcName) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "spilo-art.fullname" . }}-backup
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
  {{- if .Values.backup.dontDeletePvc }}
  annotations:
    "helm.sh/resource-policy": keep  
  {{- end }}
spec:
  {{- toYaml .Values.backup.PVC | nindent 2 }}
{{- end }}
```

### ConfigMap

Данный ConfigMap необходим только для скрипта резервного копирования. Поэтому поместим весь шаблон во внутрь
оператора if

```yaml
{{- if .Values.backup.enable }}

{{- end }}
```

Определим имя ConfigMap.

```yaml
metadata:
  name: {{ include "spilo-art.fullname" . }}-backup
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
```

### StatefullSet

В StatefullSet мы подключаем PVC.

```yaml
        volumeMounts:
        {{- if .Values.backup.enable }}
        - mountPath: /data/pg_wal
          name: backup
        - mountPath: /config
          name: config
        {{- end }}
        - mountPath: /home/postgres/pgdata
          name: pgdata
```

Переменные среды окружения.

Определение времени выполнения скрипта вынесу в файл `values.yaml`.

```yaml
backup:
  # Время выполнения скрипта резервного копирования в формате crontab
  crontabTime: "00 01 * * *"
```

```yaml
        {{- if .Values.backup.enable }}
        - name: WALG_FILE_PREFIX
          value: "/data/pg_wal"
        - name: CRONTAB
          value: "[\"{{ .Values.backup.crontabTime }} envdir /config /scripts/postgres_backup.sh /home/postgres/pgdata/pgroot/data\"]"
        {{- end }}
```

Подключение томов в контейнере. Заодно определим корректные имена ConfigMap и PVC. 

```yaml
      {{- if .Values.backup.enable }}
      volumes:
        - configMap:
            name: {{ include "spilo-art.fullname" . }}-backup
          name: config
        - persistentVolumeClaim:
            {{- if empty .Values.backup.externalPvcName }}
            claimName: {{ include "spilo-art.fullname" . }}-backup
            {{- else }}
            claimName: {{ .Values.backup.externalPvcName }}
            {{- end }}
          name: backup
      {{- end }}
```

Проверим правильность генерации шаблона. Сначала в файле `values.yaml` выключим бекап:

```yaml
backup:
  enable: false
```

```shell
helm template test spilo-art > app.yaml
```

Посмотрим, что получилось в app.yaml. 

Теперь включим backup.

```yaml
backup:
  enable: true
```

```shell
helm template test spilo-art > app.yaml
```

Посмотрим, что получилось в app.yaml.

При генерации шаблона не должно быть сообщений об ошибках.

## Сервисы

### Headless service

Тут все просто. Добавляем имя и labels. Единственный момент - имя сервиса должно заканчиваться
на `-config`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spilo-art.fullname" . }}-config
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
spec:
  clusterIP: None
```

### Service

При определении этого сервиса мы должны решить, как мы будем получать доступ к кластеру базы данных.
Доступ будет только внутри кластера kubernetes или мы должны предоставить возможность обращаться из-за пределов кластера.

В первом случае будем использовать сервис типа `ClusterIP`, во втором - `NodePort`.

Добавим в файл `values.yaml` раздел описания сервиса.

```yaml
service:
  # ClusterIP, NodePort или LoadBalancer
  type: ClusterIP
  name: postgresql
  port: 5432
  nodePort: 32345
  # Поле .spec.loadBalancerIP для Service типа LoadBalancer устарело в Kubernetes версии v1.24.
  # Рекомендуется обратиться к документации поставщика услуг, для уточнения как использовать аннотации
  # для конфигурации сервиса типа LoadBalancer. 
  annotations: {}
  #  metallb.universe.tf/loadBalancerIPs: 192.168.1.100
```

Подставим в шаблон сервиса соответствующие переменные.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spilo-art.fullname" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
  {{- if .Values.service.annotations }}
  annotations:
    {{- toYaml .Values.service.annotations | nindent 4 }}
  {{- end}}
spec:
  type: {{ .Values.service.type }}
  ports:
  - name: {{ .Values.service.name }}
    port: {{ .Values.service.port}}
    targetPort: 5432
    {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
    nodePort: {{ .Values.service.nodePort}}
    {{- end }}
```

### Service replica

Сервис для доступа к репликам.

Добавим в файл `values.yaml` раздел описания сервиса.

```yaml
servicereplica:
  enable: true
  # ClusterIP, NodePort или LoadBalancer
  type: ClusterIP
  name: postgresql
  port: 5432
  nodePort: 32345
  # Поле .spec.loadBalancerIP для Service типа LoadBalancer устарело в Kubernetes версии v1.24.
  # Рекомендуется обратиться к документации поставщика услуг, для уточнения как использовать аннотации
  # для конфигурации сервиса типа LoadBalancer. 
  annotations: {}
  #  metallb.universe.tf/loadBalancerIPs: 192.168.1.100
```

Подставим в шаблон сервиса соответствующие переменные.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spilo-art.fullname" . }}-replica
  labels:
    {{- include "spilo-art.headerLabels" . | nindent 4 }}
    {{- include "spilo-art.baseSelectorLabels" . | nindent 4 }}
  {{- if .Values.servicereplica.annotations }}
  annotations:
    {{- toYaml .Values.servicereplica.annotations | nindent 4 }}
  {{- end}}
spec:
  type: {{ .Values.servicereplica.type }}
  ports:
  - name: {{ .Values.servicereplica.name }}
    port: {{ .Values.servicereplica.port}}
    targetPort: 5432
    {{- if and (eq .Values.servicereplica.type "NodePort") .Values.servicereplica.nodePort }}
    nodePort: {{ .Values.servicereplica.nodePort}}
    {{- end }}
  selector:
    {{- include "spilo-art.selectorLabels" . | nindent 4 }}
    role: replica
```

Для включения/выключения генерации сервиса будем использовать два условия:

1. `servicereplica.enable: true`
2. Если количество реплик > 1.

В `values.yaml` добавим:

```yaml
replicas: 2
```

В шаблоне StatefulSet:

```yaml
spec:
  replicas: {{ .Values.replicas }}
```

В шаблоне сервиса добавим соответствующие условия.

```yaml
{{- if and .Values.servicereplica.enable ( gt .Values.replicas 1.0 ) }}

{{- end }}
```

### Endpoints

Определяем имя (оно должно совпадать с именем сервиса) и labels.

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: {{ include "spilo-art.fullname" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
subsets: []
```

Проверим правильность генерации шаблона.

```shell
helm template test spilo-art > app.yaml
```

## Secrets

Secret используется для хранения паролей. В самом простом случае мы создаём раздел `secret` в файле `valuses.yaml`.

```yaml
secret:
  defaultPasswords:
    superuser: password
    replication: password
    admin: password
```

Тогда шаблон secret будет выглядеть вот так:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "spilo-art.fullname" . }}
  labels:
    {{- include "spilo-art.labels" . | nindent 4 }}
type: Opaque
data:
  superuser-password: {{ .Values.secret.defaultPasswords.superuser | b64enc | quote }}
  replication-password: {{ .Values.secret.defaultPasswords.replication | b64enc | quote }}
  admin-password: {{ .Values.secret.defaultPasswords.admin | b64enc | quote }}
```

Но хранить пароли в `valuse.yaml`, мягко говоря, не очень правильно. Поэтому мы должны предусмотреть несколько вариантов
генерации сикрета.

1. Secret создаётся в ручную и мы должны указать его имя для дальнейшего использования.
2. Пароли в secret генерируются автоматически.

### Подстановка внешнего secret.

В `values.yaml` предусматриваем переменную для указания имени secret.

```yaml
secret:
  # Secret создаваемый в ручную.
  # ---
  # apiVersion: v1
  # kind: Secret
  # metadata:
  #   name: test-spilo-art
  # type: Opaque
  # stringData:
  #   admin-password: password
  #   replication-password: password
  #   superuser-password: password
  # ...
  # Если определен параметр externalSecretName, остальные переменные из раздела secret не используются.  
  externalSecretName: ""
```

В шаблоне secret в начале добавим глобальный оператор if.

```
{{- if empty .Values.secret.externalSecretName }}
тут тело шаблона.
{{- end }}
```

В шаблоне StatefulSet добавим выбор имени secret.

```yaml
        - name: PGPASSWORD_SUPERUSER
          valueFrom:
            secretKeyRef:
              name: {{ default "*cluster_name" .Values.secret.externalSecretName }}
              key: superuser-password
        - name: PGPASSWORD_ADMIN
          valueFrom:
            secretKeyRef:
              name: {{ default "*cluster_name" .Values.secret.externalSecretName }}
              key: admin-password
        - name: PGPASSWORD_STANDBY
          valueFrom:
            secretKeyRef:
              name: {{ default "*cluster_name" .Values.secret.externalSecretName }}
              key: replication-password
```

### Автоматическая генерация паролей

Автоматически сгенерировать пароли несложно:

```
randAlphaNum 16 | nospace | b64enc | quote
```

Но мы должны учитывать, что пароли необходимо генерировать только один раз - при первой установке чарта. Поэтому скрипт 
будет "немного" сложнее.

_[Документация по lookup](https://helm.sh/docs/chart_template_guide/functions_and_pipelines/#using-the-lookup-function)._

```yaml
  {{- if .Release.IsInstall }}
  superuser-password: {{ default (randAlphaNum 19 | nospace) .Values.secret.defaultPasswords.superuser | b64enc | quote }}
  replication-password: {{ default (randAlphaNum 19 | nospace) .Values.secret.defaultPasswords.replication | b64enc | quote }}
  admin-password: {{ default (randAlphaNum 19 | nospace) .Values.secret.defaultPasswords.admin | b64enc | quote }}
  {{ else }}
  superuser-password: {{ index (lookup "v1" "Secret" .Release.Namespace (include "spilo-art.fullname" .)).data "superuser-password" }}
  replication-password: {{ index (lookup "v1" "Secret" .Release.Namespace (include "spilo-art.fullname" .)).data "replication-password" }}
  admin-password: {{ index (lookup "v1" "Secret" .Release.Namespace (include "spilo-art.fullname" .)).data "admin-password" }}
  {{ end }}
```

Итого, что бы пароли генерировались автоматически, секция `secret` в файле `values.yaml` должна выглядеть следующим
образом:

```yaml
secret:
  externalSecretName: ""
  defaultPasswords: {}
```

Проверим правильность генерации шаблона.

```shell
helm template test spilo-art > app.yaml
```

## StatefulSet

Осталось окончательно "причесать" StatefulSet.

### Контейнер

В файле `values.yaml` добавим переменные определяющие image контейнера.

```yaml
image:
  name: registry.opensource.zalan.do/acid/spilo-15
  tag: 3.0-p1
  imagePullSecrets: IfNotPresent

podManagementPolicy: Parallel
```

Соответственно внесём изменения в шаблон StatefulSet.

```yaml
spec:
  podManagementPolicy: {{ .Values.podManagementPolicy }}
```

```yaml
      containers:
      - name: {{ .Chart.Name }}
        image: {{ .Values.image.name }}:{{ .Values.image.tag }}  # put the spilo image here
        imagePullPolicy: {{ .Values.image.imagePullSecrets }}
```

### Пробы и ресурсы

В базовом манифесте я забыл добавить пробы и ресурсы. Исправим это в шаблоне чарта.

В файле `values.yaml` добавим секцию `probes`.

```yaml
probes: {}
#  livenessProbe:
#    # postgres check
#    exec:
#      command: [ "psql", "-U", "postgres", "-c", "SELECT 1" ]
#    initialDelaySeconds: 60
#    periodSeconds: 10
#  readinessProbe:
#    # patroni check
#    tcpSocket:
#      port: 8008
#    initialDelaySeconds: 20
#    periodSeconds: 20
```

В шаблоне в определении контейнера добавим.

```yaml
        {{- if .Values.probes }}
        {{- toYaml .Values.probes | nindent 8 }}
        {{- end }}
```

Аналогичным образом поступим и с ресурсами.

values.yaml

```yaml
resources: {}
#  limits:
#    cpu: 100m
#    memory: 128Mi
#  requests:
#    cpu: 100m
#    memory: 128Mi
```

шаблон StatefulSet

```yaml
        {{- if .Values.resources }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- end }}
```

### Affinity и tolerations

#### Affinity

Определение affinity в манифесте в нашем случае обязательно. Поэтому будем выносить в конфигурацию чарта только
конфигурацию `nodeAffinity`. В части указания label устанавливаемой на нодах кластера rubernetes.

values.yaml

```yaml
nodeAffinity: {}
#  nodeSelectorTerms:
#    - matchExpressions:
#      - key: db
#        operator: In
#        values:
#          - spilo
```

Шаблон.

```yaml
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              {{- toYaml .Values.nodeAffinity.nodeSelectorTerms | nindent 14 }}
```

Так же поместим все определения affinity в оператор if:

```yaml
{{- if .Values.nodeAffinity }}

{{- end }}
```

#### Tolerations

values.yaml

```yaml
tolerations: []
#- key: "key1"
#  operator: "Equal"
#  value: "value1"
#  effect: "NoSchedule"
```

В шаблоне добавляем секцию.

```yaml
      {{- if .Values.tolerations }}
      tolerations:
        {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
```

### Annotations

На всякий случай позаботимся о возможности добавления аннотаций и меток. Для StatefulSet и шаблона контейнера
будем делать отдельные определения.

values.yaml

```yaml
annotations: {}
#  annotation1: value
#  annotation2: value
  
podAnnotations: {}
#  podAnnotation1: value
#  podAnnotation2: value
```

Шаблон.

```yaml
kind: StatefulSet
metadata:
  {{- if .Values.annotations }}
  annotations:
    {{- toYaml .Values.annotations | nindent 4 }}
  {{- end }}
```

```yaml
spec:
  template:
    metadata:
      {{- if .Values.podAnnotations }}
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
      {{- end }}
```

### volumeClaimTemplates

Параметры связанные с volumeClaimTemplates. В чарте предусмотрен только один PV для хранения данных.

values.yaml

```yaml
# Параметры PVC для хранения файлов базы данных.
data:
  storageClassName: ""
  storage: 2Gi
```

Шаблон.

```yaml
volumeClaimTemplates:
  - metadata:
      labels:
        {{- include "spilo-art.selectorLabels" . | nindent 8 }}
      name: pgdata
    spec:
      {{- if .Values.data.storageClassName }}
      storageClassName: {{ .Values.data.storageClassName }}
      {{- end }}
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: {{ .Values.data.storage }}
```

### Прочее

Переменную среды окружения SPILO_CONFIGURATION тоже не мешало бы вынести в values.yaml.

```yaml
spilo:
  env:
    ## https://github.com/zalando/patroni#yaml-configuration
    configuration: |
      bootstrap:
        initdb:
          - auth-host: md5
          - auth-local: md5
```

В шаблоне.

```yaml
        - name: SPILO_CONFIGURATION
          value: |
            {{- .Values.spilo.env.configuration | nindent 12 }}
```

## Документация

Файл `NOTES.txt`. Содержимое файла выводится после установки чарта и должно содержать сообщение
облегчающее дальнейшую эксплуатацию.

Файл `README.md`. Основная документация по чарту.

## Проверка установки чарта

```shell
rm -f spilo-art/values-old.yaml
cp spilo-art/values.yaml valuest-art.yaml
```

```shell
helm install base spilo-art -n spilo -f valuest-art.yaml --create-namespace 
```

Подключитесь к базе с помощью текущих паролей из secret. Запомните текущий пароль в secret.

Внесите изменение в файл `valuest-art.yaml`. Например, отключите пробы.

```shell
helm upgrade base spilo-art -n spilo -f valuest-art.yaml
```

Проверьте, изменились ли пароли в secret.

Удалите приложение.

```shell
helm uninstall base spilo-art -n spilo
```

Протестируйте корректность работы других параметров.

Если всё работает, пора переходить к самой сложной части создания чарта - написанию документации.
