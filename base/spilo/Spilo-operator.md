# Zalando postgres-operator

https://opensource.zalando.com/postgres-operator/

```shell
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
```

```shell
helm search repo postgres
```

## Operator

```shell
helm show values postgres-operator-charts/postgres-operator > operator/postgres-operator-values.yaml
```

Правим файл values.

Ищем последнюю версию оператора на сайте производителя:  
https://registry.opensource.zalan.do/ui/#/Pier_One_API

В моем случае последняя обнаруженная версия - v1.10.0. Подставляю ее в поле tag:

```yaml
image:
  tag: v1.10.0
```

Аналогичным образом ищем версию контейнера spilo. И определяем его в values:

```yaml
# general configuration parameters
configGeneral:
  # Spilo docker image
  docker_image: registry.opensource.zalan.do/acid/spilo-15:3.0-p1
```

Установим оператор

```shell
helm install postgres-operator postgres-operator-charts/postgres-operator -f operator/postgres-operator-values.yaml \
-n postgres-operator --create-namespace
```

## Operator UI

```shell
helm show values postgres-operator-ui-charts/postgres-operator-ui > operator/postgres-operator-ui-values.yaml
```

Определяем последнюю версию контейнера и подставляем её 

```yaml
# configure ui image
image:
  tag: v1.9.0
  #tag: v1.10.0
```

```yaml
# configure UI ENVs
envs:
  # IMPORTANT: While operator chart and UI chart are independent, this is the interface between
  # UI and operator API. Insert the service name of the operator API here!
  operatorApiUrl: "http://postgres-operator:8080"
  operatorClusterNameLabel: "cluster-name"
  resourcesVisible: "False"
  targetNamespace: "postgres-operator"
  teams:
    - "acid"
```

Конфигурация ingress:

```yaml
# configure UI ingress. If needed: "enabled: true"
ingress:
  enabled: true
  annotations:
    {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  ingressClassName: "system-ingress"
  hosts:
    - host: operator.kryukov.local
      paths: [""]
```

Установим UI.

```shell
helm install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui \
-f operator/postgres-operator-ui-values.yaml \
-n postgres-operator
```