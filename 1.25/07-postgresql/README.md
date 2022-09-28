# Crunchy PostgreSQL Operator

[Документация](https://access.crunchydata.com/documentation/postgres-operator/v5/installation/helm/)

## Установка оператора.

```shell
git clone --depth 1 "https://github.com/CrunchyData/postgres-operator-examples.git"
```

В файле [postgres-operator-examples/helm/install/values.yaml](postgres-operator-examples/helm/install/values.yaml) поменяем singleNamespace на true, поскольку в дальнейшем потребуется только один кластер и жить он будет в одном неймспейсе.

```shell
kubectl apply -f 00-pgo-ns.yaml

```

## Оператор

[Документация](https://github.com/zalando/postgres-operator)

```shell
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo update
helm search repo postgres-operator-charts
helm install postgres-operator postgres-operator-charts/postgres-operator -n pgo --create-namespace
```

[Пример конфигурации кластера](https://github.com/zalando/postgres-operator/blob/master/manifests/complete-postgres-manifest.yaml).

Поставим метку на ноду на которой будет жить кластер:

```shell
kubectl label nodes db1.kryukov.local pgo=enabled
kubectl label nodes worker1.kryukov.local pgo=enabled
```

Добавим кластер

```shell
kubectl apply -f 01-cluster.yaml
```

Пароль пользователей postgres и artur находятся в соответствующих сикретах.

```shell
kubectl -n pgo get secret postgres.acid-artur.credentials.postgresql.acid.zalan.do \
-o 'jsonpath={.data.password}' | base64 -d
```

## Pgadmin

Установка pgadmin.

Добавьте [project](../argo-sys-project.yaml) в ArgoCD. И запустите [argo приложение](pgadmin/argo/argo-app.yaml).

Или вручную:

 ```shell
 kubectl -n pgo apply -f pgadmin/manifestst
 ```



