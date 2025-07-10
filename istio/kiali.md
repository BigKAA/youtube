# Kiali

- [Kiali](#kiali)
  - [Дополнительные приложения.](#дополнительные-приложения)
    - [Сертификат и Gateway](#сертификат-и-gateway)
    - [Prometheus](#prometheus)
    - [Grafana](#grafana)
    - [Авторизация пользователя в kiali](#авторизация-пользователя-в-kiali)
      - [DEX](#dex)
  - [Kiali helm chart](#kiali-helm-chart)


[Kiali](https://kiali.io/).

## Дополнительные приложения.

Для работы kiali необходимо поставить минимум два приложения:

* Сбор и хранение метрик: prometheus или victoriametrics.
* Grafana.

Можно добавить приложение для сбора traces типа jaeger. Но сейчас мы этого делать не будем.

Так же настоятельно рекомендуется добавить авторизацию для ограничение доступа к приложению.

### Сертификат и Gateway

Для упрощения доступа к приложениям мы выпустим сертификат для всех доменных имен вспомогательных служб.

Так же добавим отдельный Gateway, через который мы будем получать доступ к этим службам.

```shell
kubectl apply -f manifests/01-kiali-sup-gateway.yaml
```

### Prometheus

По хорошему, у вас в кластере или рядом с ним должна быть развернута полноценная система мониторинга. Включающая приложение для сбора и хранения метрик.

В нашем случае, мы установим простейший вариант установки prometheus.

```shell
kubectl create ns monitoring
helm install prometheus prometheus-community/prometheus -f values/prometheus-manifest.yaml -n monitoring
```

Создадим HTTPRoute для prometheus.

```shell
kubectl apply -f manifests/02-prometheus-httpr.yaml
```

После этого prometheus доступен снаружи кластера по URL https://prom.kryukov.local/

### Grafana

```shell
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo update
```

В чарте grafana поддерживается HTTPRoute. Поэтому достаточно установить чарт с соответствующим файлом values:

```shell
helm install grafana grafana/grafana -n monitoring -f values/grafana-values.yaml
```

Доступ к Grafana: https://grafana.kryukov.local/. `admin:password`

Необходимые для работы дашборды можно [посмотреть тут](https://istio.io/latest/docs/ops/integrations/grafana/).

### Авторизация пользователя в kiali

Поскольку kiali имеет полный доступ к управлению istio, предоставлять анонимный доступ к такому инструменту равнозначно выстрелу себе в ногу. Поэтому необходимо подключить какой нибудь механизм авторизации.

В нашем случае будем использовать механизм [openid](https://kiali.io/docs/configuration/authentication/openid/). В качестве провайдера установим приложение [Dex](https://dexidp.io/).

#### DEX

Выбираем [самый простой вариант настройки со статическими пользователями](https://dexidp.io/docs/connectors/local/), добавленными прямо в конфигурационном файле dex.

```yaml
    enablePasswordDB: true
    staticPasswords:
        - email: "artur@kryukov.biz"
          # mkpasswd -m bcrypt-a
          hash: "$2a$05$nGTLGROxDIcEsh2ZDP1sDeLVBSP4WyBxZnIkg5U/tWMdlmmxc97j2"
          username: "artur"
          userID: "08a8684b-db89-4b73-91a9-3cd1221f0000"
```

Там же определяем клиента:

```yaml
    staticClients:
      - id: kiali
        redirectURIs:
          - 'https://kiali.kryukov.local/kiali'
        name: 'Kiali'
        secret: ZXvvbX32ZS1hcHAtc2VjcmV1
```

Запускаем dex:

```shell
kubectl create ns dex
kubectl apply -f manifests/03-dex.yaml
```

Получаем информацию от dex:

```shell
curl -k https://dex.kryukov.local/.well-known/openid-configuration | jq
```

## Kiali helm chart

Для установки приложения воспользуемся helm chart:

```shell
helm repo add kiali https://kiali.org/helm-charts
helm repo update
```

В первую очередь мы должны определить [стратегию аутентификации](https://kiali.io/docs/configuration/authentication/).

[Документация по параметрам файла values](https://kiali.io/docs/configuration/kialis.kiali.io/) (*если это конечно можно назвать документацией :)*).

```yaml
auth:
  strategy: "openid"
  openid:
    client_id: kiali
    insecure_skip_verify_tls: true
    issuer_uri: "https://dex.kryukov.local"
    scopes: ["openid", "profile", "email", "groups"]
    disable_rbac: true
    username_claim: "email"
```

Создаем Secret, содержащий пароль oidc client:

```shell
kubectl create secret generic kiali --from-literal="oidc-secret=ZXvvbX32ZS1hcHAtc2VjcmV1" -n istio-system
```

Настраиваем доступы к внешним сервисам (istio, prometheus, grafana):

```yaml
external_services:
  custom_dashboards:
    enabled: true
  grafana:
    auth:
      insecure_skip_verify: true
      password: "password"
      username: "admin"
      type: "basic"
    enabled: true
    internal_url: "http://grafana.monitoring.svc"
    external_url: "https://grafana.kryukov.local"
  istio:
    root_namespace: "istio-system"
  prometheus:
    auth:
      type: "none"
    url: "http://prometheus-server.monitoring.svc"
  tracing:
    enabled: false
```

Определяем параметры сервера:

```yaml
server:
  web_fqdn: "kiali.kryukov.local"
  # Если не указать порт, будет искать заголовок x-forwarded-port
  web_port: "443"
  web_schema: "https"
  observability:
    metrics:
      enabled: true
      port: 9090
```

Устанавливаем приложение

```shell
helm install kiali kiali/kiali-server -n istio-system -f values/kiali-values.yaml
```

Добавим соответствующий HTTPRoute:

```shell
kubectl apply -f manifests/04-kiali-httpr.yaml
```

После запуска всех приложений можно подключаться по https://kiali.kryukov.local.
