# Zalando/Spilo

[Spilo](https://github.com/zalando/spilo): HA PostgreSQL Clusters with Docker.

Видео, рассказывающее о проекте https://www.youtube.com/watch?v=33424uhD1ng
 
Берем [текущий манифест](https://github.com/zalando/spilo/blob/master/kubernetes/spilo_kubernetes.yaml) для kubernetes.
Помещаем в файл `manifests/spilo_kubernetes.yaml`. Начинаем адаптировать его под свой кластер.

## Количество подов.

Spilo умеет играть в кластера, поэтому мы должны указать количество нод в кластере postgree. Один из подов будет 
выполнять функцию master, остальные будут slave.

```yaml
  replicas: 3
```

## podManagementPolicy

Что бы наш кластер, даже во время перезагрузки всегда был в рабочем состоянии. Изменим значение параметра 
`podManagementPolicy` на `Parallel`:

```yaml
spec:
  podManagementPolicy: Parallel
```

## Annotations

Манифест подразумевает запуск кластера в Амазон. Мы же будем пользоваться локальным кластером, поэтому аннотацию в
StatefulSet можно удалить.

## Контейнер

Последний образ контейнера доступный для использования смотрим [тут](https://registry.opensource.zalan.do/ui/).

Изменяем на текущий контейнер.

```yaml
      containers:
      - name: *cluster_name
        image: registry.opensource.zalan.do/acid/spilo-15:3.0-p1  # put the spilo image here
        imagePullPolicy: IfNotPresent
```

Учтите, что это "тяжелый" контейнер - 1.12 GB. Первый раз грузиться будет очень долго. Поэтому 
`imagePullPolicy: IfNotPresent` вполне оправдан.

## Переменная SPILO_CONFIGURATION

Исправим конфигурацию в переменной среды окружения контейнера SPILO_CONFIGURATION.

```yaml
        - name: SPILO_CONFIGURATION
          value: | ## https://github.com/zalando/patroni#yaml-configuration
            bootstrap:
              initdb:
                - auth-host: md5
                - auth-local: md5
```

## Резервное копирование.

Контейнер spilo позволяет осуществлять резервное копирование базы данных. 

Его стоит включить. Это делается в несколько этапов.

### Параметры контейнера

Добавим дополнительные параметры контейнера при помощи переменных среды окружения.

```yaml
            - name: WALG_FILE_PREFIX
              value: "/data/pg_wal"
            - name: CRONTAB
              value: "[\"00 01 * * * envdir /config /scripts/postgres_backup.sh /home/postgres/pgdata/pgroot/data\"]"
```

_[Описание переменных среды окружения](https://github.com/zalando/spilo/blob/master/ENVIRONMENT.rst), используемых для 
конфигурации контейнера._

### Конфигурационные параметры скрипта

Параметры скрипта поместив в отдельный ConfigMap

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-cript
data:
  PGHOST: "/var/run/postgresql"
  PGUSER: "postgres"
  PGROOT: "/home/postgres/pgdata/pgroot"
  PGLOG: "/home/postgres/pgdata/pgroot/pg_log"
  PGDATA: "/home/postgres/pgdata/pgroot/data"
  BACKUP_NUM_TO_RETAIN: "5"
  USE_WALG_BACKUP: "true"
  USE_WALG_RESTORE: "true"
  WALG_ALIVE_CHECK_INTERVAL: "5m"
  WALE_BINARY: "wal-g"
  WALG_FILE_PREFIX: "/data/pg_wal"
  WALE_ENV_DIR: "/config"
```

### Дополнительные диски

Первый - это подключение ConfigMap в файловую систему контейнера.

```yaml
      volumes:
        - configMap:
            name: backup-script
          name: config
```

```yaml
        volumeMounts:
        - mountPath: /config
          name: config
```

Второй - это диск, куда будут помещаться резервные копии. Он будет располагаться в PV.
Поэтому для него необходимо добавить шаблон в `volumeClaimTemplates`.

```yaml
  volumeClaimTemplates:
  - metadata:
      labels:
        application: spilo
        spilo-cluster: *cluster_name
      name: backup
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi # у меня в кластере мало места :)
```

```yaml
        volumeMounts:
        - mountPath: /data/pg_wal
          name: backup
```

## Storage Classes

В моём кластере есть два StorageClasses.

```
$ kubectl get storageclasses
NAME                  PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path            rancher.io/local-path   Delete          WaitForFirstConsumer   false                  6d23h
managed-nfs-storage   kryukov.local/nfs       Delete          Immediate              false                  7d21h
```

Я предполагаю, что файлы базы данных будут храниться на локальных дисках нод
кластера. Поэтому для них будет использоваться StorageClass local-path.
А резервные копии будут помещаться на сетевой (NFS) диск. Для них будем использовать
StorageClass managed-nfs-storage.

Добавим соответствующие параметры в разделе `volumeClaimTemplates`.

```yaml
  volumeClaimTemplates:
  - metadata:
      labels:
        application: spilo
        spilo-cluster: *cluster_name
      name: pgdata
    spec:
      storageClassName: local-path
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi
```

Резервные копии будем сохранять на NFS диске. Один диск для всех подов. Поэтому создадим PVC в режиме `ReadWriteMany`.

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zalandodemo01-backup
spec:
  storageClassName: managed-nfs-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi
```

И подключим его к StatefulSet.

## Пароли

Пароли пользователей находятся в Secret. Для удобства написания паролей я вместо ветки `data` сделал `stringData`.
И добавил их в явном виде без перекодировки в BASE64.

## Affinity

Поскольку кластер postgree будет использовать локальные диски нод kubernetes, необходимо явно указать на каких
нодах будут запускаться поды.

Сначала добавим labels на ноды, где предполагается запускать поды spilo.

```shell
kubectl label nodes ws2.kryukov.local db=spilo
kubectl label nodes ws3.kryukov.local db=spilo
kubectl label nodes ws4.kryukov.local db=spilo
```

Добавим affinity в StatefulSet.

```yaml
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: db
                    operator: In
                    values:
                      - spilo
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: spilo-cluster
                    operator: In
                    values:
                      - *cluster_name
              topologyKey: "kubernetes.io/hostname"
```

Можно "заморочится" еще сильнее. Сделать так, что бы на выбранных нодах кластера запускались только поды spilo.
В этом случае придется ставить tains и использовать toleration. Но у меня кластер маленький, выделять три ноды только
под базу данных у меня не получится.

## Установка

```shell
kubectl create ns spilo
```

```shell
kubectl -n spilo apply -f manifests/spilo_kubernetes.yaml
```

## Доступ к кластеру postgresql

Доступ к postgresql внутри кластера осуществляется при помощи сервиса `zalandodemo01.spilo.svc:5432` 

В качестве примера можно использовать pgadmin.

```shell
kubectl apply -f left-manifests/pgadmin.yaml
```

Для доступа из-за пределов кластера следует добавить сервис типа `nodePort`. Но тут есть нюансы, о которых 
рассказывается в следующем разделе.

## Кто мастер?

Spilo позволяет организовать кластер. Доступ к кластеру осуществляется через один сервис - zalandodemo01.

Мы помним, что сервис типа ClusterIP, при наличии нескольких подов выполняете пересылку запросов к этим подам по
принципу round robbin. Но в нашем случае, почему-то все запросы идут на под мастера базы данных.

Объясняется все просто. В манифесте определен не только сервис, но и Endpoints с именем сервиса.
Причём, в Endpoints не определена секция `subsets`. Spilo выбирает мастера и самостоятельно изменяет эту секцию.
Таким образом, сервис всегда ссылается на под текущего мастера.

Так же, в подах spilo добавляется label с ключём `role`. Значение котрой у мастера равно master, а у 
реплик равно replica.

Этой особенностью можно воспользоваться, например при создании сервиса типа NodePort.

```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: zalandodemo01-nodeport
spec:
  type: NodePort
  ports:
    - port: 5432
      nodePort: 32345
      targetPort: 5432
      name: postgresql
  selector:
    application: spilo
    spilo-cluster: zalandodemo01
    role: master
```

```shell
kubectl -n spilo apply -f manifests/nodePort.yaml
```

## Инструменты

Все инструменты есть в контейнере.

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- psql -U postgres -W -d test
\dp
\q
```

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- patronictl list
```

Набор скриптов.

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- ls /scripts/
```

## Принудительная смена мастера

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- patronictl list
```

```
+ Cluster: zalandodemo01 ----------+---------+---------+----+-----------+
| Member          | Host           | Role    | State   | TL | Lag in MB |
+-----------------+----------------+---------+---------+----+-----------+
| zalandodemo01-0 | 10.233.120.228 | Leader  | running |  4 |           |
| zalandodemo01-1 | 10.233.111.158 | Replica | running |  4 |         0 |
| zalandodemo01-2 | 10.233.82.50   | Replica | running |  4 |         0 |
+-----------------+----------------+---------+---------+----+-----------+
```

Переключим мастера на другой под.

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- patronictl switchover
```

Через некоторое время убедимся, что мастер переключился. 

```shell
kubectl -n spilo exec -it zalandodemo01-0 -- patronictl list
```

```
+ Cluster: zalandodemo01 ----------+---------+---------+----+-----------+
| Member          | Host           | Role    | State   | TL | Lag in MB |
+-----------------+----------------+---------+---------+----+-----------+
| zalandodemo01-0 | 10.233.120.228 | Replica | running |  5 |         0 |
| zalandodemo01-1 | 10.233.111.158 | Replica | running |  5 |         0 |
| zalandodemo01-2 | 10.233.82.50   | Leader  | running |  5 |           |
+-----------------+----------------+---------+---------+----+-----------+
```

Посмотрите labels на подах spilo. Посмотрите, куда указывают Endpoints сервисов.
