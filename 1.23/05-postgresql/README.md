# Crunchy PostgreSQL Operator

[Документация](https://access.crunchydata.com/documentation/postgres-operator/v5/installation/helm/)

**В 5-й версии ребята порядком извратились с установкой... Ставить придется путём клонирования их git репозитория...**

## Установка оператора.

Создатели оператора рекомендуют сначала форкнуть к себе их репозиторий:
https://github.com/CrunchyData/postgres-operator-examples/fork

Затем, локально клонировать его часть:

    git clone --depth 1 "https://github.com/BigKAA/postgres-operator-examples.git"
    cd postgres-operator-examples

И уже тут начинать менять парамеры. Я удалю не используемые файлы и директории.

Устанавливать будем при помощи helm.

В файле helm/install/values.yaml поменяем singleNamespace на true, поскольку в дальнейшем потребуется только один 
кластер и не более.

```yaml
---
## Provide image repository and tag
image:
  image: registry.developers.crunchydata.com/crunchydata/postgres-operator:ubi8-5.0.4-0

relatedImages:
  postgres_14:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:centos8-14.1-0
  postgres_14_gis_3.1:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:centos8-14.1-3.1-0
  postgres_13:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:centos8-13.5-0
  postgres_13_gis_3.1:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-gis:centos8-13.5-3.1-0
  pgbackrest:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:centos8-2.36-0
  pgbouncer:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbouncer:centos8-1.16-0
  pgexporter:
    image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.0.4-0

# singleNamespace determines how to install PGO to watch namesapces. If set to
# false, PGO will watch for Postgres clusters in all namesapces Setting to
# "true" will instruct PGO to only watch for Postgres clusters in the namespace
# that it is installed in. Defaults to the value below.
singleNamespace: true

# debug allows you to enable or disable the "debug" level of logging.
# Defaults to the value below.
debug: true
```

    kubectl create namespace pgo
    helm install pgo -n pgo helm/install

## Запуск экземпляра базы данных

Вешаем заразы и метки на ноды кластера. Для того, что бы приземлить базу данных на нужный сервер и запретить
деплоить на него остальные приложения.

    kubectl taint nodes db1.kryukov.local db=pgsql:NoSchedule
    kubectl label nodes db1.kryukov.local db=pgsql-main

Для определения БД можно воспользоваться helm или kustomize. Но мы будем пользоваться последним, поскольку он лучше
документирован и helm chart очень, очень, очень сырой.

Отредактируем файл установки: postgres-operator-examples/kustomize/postgres/postgres.yaml . 

```yaml
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: pg
spec:
  users:
    - name: postgres
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:centos8-13.5-0
  postgresVersion: 13
  instances:
    - name: one
      replicas: 1
      dataVolumeClaimSpec:
        storageClassName: "managed-nfs-storage"
        accessModes:
        - "ReadWriteOnce"
        resources:
          requests:
            storage: 8Gi
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: db
                operator: In
                values:
                - pgsql-main
      tolerations:
      - key: "db"
        operator: "Equal"
        value: "pgsql"
        effect: "NoSchedule"
  backups:
    pgbackrest:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:centos8-2.36-0
      repos:
      - name: repo1
        volume:
          volumeClaimSpec:
            storageClassName: "managed-nfs-storage"
            accessModes:
            - "ReadWriteOnce"
            resources:
              requests:
                storage: 10Gi
```

И применим его.

Я так и не понял, зачем надо было это делать через kustomize. Ведь в файле kustomization.yaml мы определяем только
namespace.

Запустим базу данных.

    kubectl.exe apply -k kustomize/postgres

Параметры доступа к кластеру появятся в Secret pg-pguser-pg. Там определены все параметры, которые потребуются
для доступа к базе данных.
* dbname
* host
* jdbc-uri
* password
* port
* uri
* user
* verifier

## Pgadmin

Установка pgadmin простая как электровеник.

Добавьте [project](../argo-sys-project.yaml) в ArgoCD. И запустите [argo приложение](pgadmin/argo/argo-app.yaml).