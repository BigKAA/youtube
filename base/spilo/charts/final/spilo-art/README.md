# Spilo art

Helm chart для деплоя кластера PostgreSQL с использованием контейнера от проекта 
[Zalando/Spilo](https://github.com/zalando/spilo).

Предназначен для демонстрации создания helm chart в серии видео на каналах:

* Youtube: https://www.youtube.com/channel/UCU55LZT7oRxhX4GTvb5H4HA
* VK: https://vk.com/video/@bigkaa
* Telegramm: https://t.me/arturkryukov
* Rutube: https://rutube.ru/channel/23474256/

[Исходные коды чарта](https://github.com/BigKAA/youtube/tree/master/base/spilo/charts/spilo-art).

**Важно понимать**, что это demo chart. Он может содержать/содержит различные обидные ошибки. Применение его в продакшн 
среде только на свой страх и риск. Автор никакой ответственности за использование этого чарта не несёт. 

## Конфигурация

* **nameOverride**
  * Переопределение имени чарта.
  * _Значение по умолчанию_: `""`
* **fullnameOverride**
  * Переопределение имени чарта.
  * _Значение по умолчанию_: `""`
* **spilo.env.kubernetesRoleLabel**
  * Имя метки, содержащей роль Postgres при запуске в Kubernetens..
  * _Значение по умолчанию_: `role`
* **spilo.env.kubernetesScopeLabel**
  * Имя метки, содержащей название кластера.
  * _Значение по умолчанию_: `spilo-cluster`
* **spilo.env.kubernetesLabels**
  * Список содержащий имена и значения меток, используемых Patroni в Kubernetes для поиска своих метаданных.
  * _Значение по умолчанию_: `application: spilo`
* **spilo.env.configuration**
  * _YAML_. Конфигурация
  * _Значение по умолчанию_: 

```
bootstrap:
  initdb:
  - auth-host: md5
  - auth-local: md5
```
          
* **serviceAccount.name**
  * Имя ServiceAccount. Если не определено, автоматически присваивается `spilo-art.serviceAccountName`
  * _Значение по умолчанию_: не определено
* **image.name**
  * Контейнер spilo. 
  * _Значение по умолчанию_: `registry.opensource.zalan.do/acid/spilo-15`
* **image.tag**
  * Tag контейнера.
  * _Значение по умолчанию_: `3.0-p1`
* **image.imagePullSecrets**
  * 
  * _Значение по умолчанию_: IfNotPresent
* **podManagementPolicy**
  * 
  * _Значение по умолчанию_: `Parallel`
* **replicas**
  * Количество подов
  * _Значение по умолчанию_: `2`
* **annotations:**
  * _Словарь_. Аннотации StatefulSet
  * _Значение по умолчанию_: `{}`
* **podAnnotations**
  * _Словарь_. Аннотации пода StatefulSet
  * _Значение по умолчанию_: `{}`
* **probes**
  * Секция probes контейнера spilo в YAML формате. 
  * _Значение по умолчанию_: `{}`
* **resources**
  * Секция resources  контейнера spilo в YAML формате.
  * _Значение по умолчанию_: `{}`
* **data.storageClassName**
  * storageClassName volumeClaimTemplates контейнера spilo. Предназначенного для хранения файлов баз данных. Если 
    не определено, используется storageClass по умолчанию. 
  * _Значение по умолчанию_: `""`
* **data.storage**
  * Размер запрашиваемого PVC в volumeClaimTemplates контейнера spilo. Предназначенного для хранения файлов баз данных.
  * _Значение по умолчанию_: `2Gi`
* **backup.enable**
  * Включение/выключение механизма автоматического резервного копирования базы данных по расписанию.
  * _Значение по умолчанию_: `false`
* **backup.crontabTime**
  * Время выполнения скрипта резервного копирования в формате crontab
  * _Значение по умолчанию_: `00 01 * * *`
* **backup.externalPvcName**
  * Если используется готовый PVC, укажите его имя.
  * _Значение по умолчанию_: `""`
* **backup.PVC**
  * Параметры PVC для разделов резервного копирования в YAML. Выделяется один PVC для всех контейнеров.
  * _Значение по умолчанию_:

```yaml
# storageClassName: ""
accessModes:
- ReadWriteMany
resources:
  requests:
    storage: 2Gi
```

* **service.type**
  * Тип сервиса для доступа к мастеру кластера PostgreSQL. Возможные варианты: ClusterIP, NodePort или LoadBalancer.
    * _Значение по умолчанию_: `ClusterIP`
* **service.name**
  * Имя сервиса.
  * _Значение по умолчанию_: `postgresql`
* **service.port**
  * Порт сервиса.
  * _Значение по умолчанию_: `5432`
* **service.NodePort**
  * В случае сервиса типа NodePort. Если значение пустое, номер NodePort выбирается автоматически. Если значение 
    установлено, NodePort присваивается указанное значение. 
  * _Значение по умолчанию_: `""`
* **service.annotations**
  * Дополнительные аннотации сервиса. _Поле .spec.loadBalancerIP для Service типа LoadBalancer устарело в Kubernetes версии v1.24.
    Рекомендуется обратиться к документации поставщика услуг, для уточнения как использовать аннотации
    для конфигурации сервиса типа LoadBalancer. Например: `metallb.universe.tf/loadBalancerIPs: 192.168.1.100`._  
  * _Значение по умолчанию_: `{}`
* **servicereplica.enable**
  * Включает генерацию сервиса для доступа к replica базы данных.
  * _Значение по умолчанию_: `false`
* **servicereplica.type**
  * Тип сервиса для доступа к мастеру кластера PostgreSQL. Возможные варианты: ClusterIP, NodePort или LoadBalancer.
  * _Значение по умолчанию_: `ClusterIP`
* **servicereplica.name**
  * Имя сервиса.
  * _Значение по умолчанию_: `postgresql`
* **servicereplica.port**
  * Порт сервиса.
  * _Значение по умолчанию_: `5432`
* **servicereplica.NodePort**
  * В случае сервиса типа NodePort. Если значение пустое, номер NodePort выбирается автоматически. Если значение 
    установлено, NodePort присваивается указанное значение. 
  * _Значение по умолчанию_: `""`
* **servicereplica.annotations**
  * Дополнительные аннотации сервиса. _Поле .spec.loadBalancerIP для Service типа LoadBalancer устарело в Kubernetes версии v1.24.
    Рекомендуется обратиться к документации поставщика услуг, для уточнения как использовать аннотации
    для конфигурации сервиса типа LoadBalancer. Например: `metallb.universe.tf/loadBalancerIPs: 192.168.1.100`._  
  * _Значение по умолчанию_: `{}`
* **secret.externalSecretName**
  * Имя заранее созданного secret, содержащего пароли, используемые в приложении. Если это поле содержит имя, остальные 
    поля секции secret игнорируются. 
  * _Значение по умолчанию_: `""`

Пример secret:

```yaml
 apiVersion: v1
 kind: Secret
 metadata:
   name: password-secret
 type: Opaque
 stringData:
   admin-password: password
   replication-password: password
   superuser-password: password
```

* **secret.defaultPasswords**
  * Список паролей. Если поле пустое - пароли генерируется автоматически. Их значение можно посмотреть в соответствующем 
    secret, созданном при установке приложения.
  * _Значение по умолчанию_: `{}`

Пример определения паролей в файле values.yaml:

```yaml
secret:
  defaultPasswords:
    superuser: password
    replication: password
    admin: password
```

* **nodeAffinity**
  * Определение `affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms`. Если значение
    не определено - affinity в итоговом манифесте приложения не добавляется. Иначе, необходимо определить значение в 
    YAML формате. Применяется для указания нод кластера kubernetes, на которых будут запущены поды приложения. По одному
    полу на каждой ноде кластера. Если нод кластера больше, чем значение `replicas` - размещение подов происходит 
    случайным образом на нодах, подходящих под условие выбора.
  * _Значение по умолчанию_: `{}`
  
Пример определения:

```yaml
nodeAffinity:
  nodeSelectorTerms:
    - matchExpressions:
      - key: db
        operator: In
        values:
          - spilo
```

* **tolerations**
  * Определение tolerations приложения.
  * _Значение по умолчанию_: `[]`

Пример определения:

```yaml
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
```

## Использование чарта

Скопируйте файл values.yaml в файл с новым именем, например `new-values.yaml`. Отредактируйте полученный файл.

```shell
helm install testcluster ./spilo-art -f new-values.yaml -n testcluster
helm list -n testcluster
```

Удаление приложения.

```shell
helm uninstall testcluster -n testcluster
```
