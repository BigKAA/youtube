# Zalando postgres-operator

* https://opensource.zalando.com/postgres-operator/
* https://postgres-operator.readthedocs.io/en/latest/
* https://github.com/zalando/postgres-operator

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

configKubernetes:
  # toggles pod anti affinity on the Postgres pods
  enable_pod_antiaffinity: true
  # toogles readiness probe for database pods
  enable_readiness_probe: true
  # operator watches for postgres objects in the given namespace
  watched_namespace: "*"  # listen to all namespaces

configLoadBalancer:
  # DNS zone for cluster DNS name when load balancer is configured for cluster
  db_hosted_zone: kryukov.local
```

Пользователи. Мы не будем включать `PostgresTeam CR`.

```yaml
# automate creation of human users with teams API service
configTeamsApi:
  # team_admin_role will have the rights to grant roles coming from PG manifests
  enable_admin_role_for_users: true
  # operator watches for PostgresTeam CRs to assign additional teams and members to clusters
  enable_postgres_team_crd: false
```

Планируем только один оператор в кластере.

```yaml
controllerID:
  # Specifies whether a controller ID should be defined for the operator
  # Note, all postgres manifest must then contain the following annotation to be found by this operator
  # "acid.zalan.do/controller": <controller-ID-of-the-operator>
  create: false
  # The name of the controller ID to use.
  # If not set and create is true, a name is generated using the fullname template
  name:
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

## Тестовый кластер

Попытаемся запустить кластер, аналогичный тому, что мы делали при помощи манифестов.

```shell
kubectl -n postgres-operator apply -f operator/01-config-map.yaml \
-f operator/02-pvc.yaml -f operator/03-test1-db.yaml
```