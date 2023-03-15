# Сбор логов в Rancher

## Установка системы сбора логов

Заходим в Rancher как пользователь  `admin`.

Выбираем кластер, в котором будут собраться логи.

Создаём проект `Logging`

`Cluster Tools` -> `Logging` -> `Install`

Check `Customize Helm options befor install`

Press `Next`

Необходимо определить параметр `systemd Log Path`, для того чтобы система корректно работала с systemd.

Зайдите на любую ноду кластера. Нам необходимо узнать в какой директории будут находиться журналы.

```shell
ls -l /var/log/journal
ls -l /run/log/journal
```

В поле `systemd Log Path` укажите путь, который используется у вас на серверах.

Посмотрите какие `Taints` установлены на мастер нодах вашего кластера и добавьте их в `tolerations` файла values.

Перейдите в редактирование файла values -> `Edit YAML`

Ищем ветки `tolerations` и добавляем в них (в случае моего кластера):

```yaml
    - key: node-role.kubernetes.io/master
      effect: NoSchedule
      operator: Exists
```

Press `Next`

Press `Install`

## Хранилище логов

В качестве хранилища логов буду использовать opensearch. Установка opensearch неоднократно была показана на моём канале,
например [тут](../../opensearch).

Для удобства дальнейшей работы, неймспейс, в котором находится opensearch можно добавить в project Logging. 

## Сбор логов - администратор

Для сбора логов в Rancher используется [Logging operator](https://kube-logging.github.io/docs/). Который, в свою
очередь умеет устанавливать и "на лету" настраивать [Fluentbit](https://docs.fluentbit.io/manual) и 
[Fluentd](https://docs.fluentd.org/).

У меня на канале был подробный разбор сбора логов в kubernetes. 
Его можно посмотреть [тут](../../k8s-step-by-step/06-logs).

Для конфигурации системы сбора логов мы будем пользоваться kind, которые нам предоставляет оператор.

* Flows и ClusterFlows
* Outputs и ClusterOutputs

В качестве примера настроим сбор логов приложений control plane из namespace kube-system.

В Rancher мы можем создавать kind при помощи WEB интерфейса.

### ClusterOutputs

Создадим output доступный дял работы только администратору Rancher.

Поскольку мы планируем подключаться к кластеру opensearch, необходимо создать secret содержащий пароль этого 
пользователя.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: opensearch-user
  namespace: cattle-logging-system
type: Opaque
stringData:
  PASSWORD: 'password'
```

Перейдём в `Logging` -> `ClusterOutputs`

Нажмём кнопку `Create`

* `Name` -> `opensearch-control-plane`
* `Description` -> `Opensearch global control plane output`
* `Output`
  * `Output` -> `Elasticsearch`
  * `Sheme` -> `https`
  * `Host` -> `opensearch-cluster-master.es.svc`
  * `Port` -> `9200`
  * `Index Name` -> `control-plane.%Y%m%d`
  * `User` -> `admin`
  * `Password from secret` -> `opensearch-user`
  * `Key` -> `PASSWORD`
  * uncheck `Verify SSL`
  * push button `Create`

В yaml добавляем `suppress_type_name: true`

```yaml
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterOutput
metadata:
  annotations:
    field.cattle.io/description: Opensearch global control plane output
  name: opensearch-control-plane
  namespace: cattle-logging-system
spec:
  opensearch:
    buffer:
      timekey: 1m
      timekey_wait: 30s
    host: opensearch-cluster-master.es.svc
    index_name: control-plane.${tag}.%Y-%m-%d
    password:
      valueFrom:
        secretKeyRef:
          key: PASSWORD
          name: opensearch-user
    port: 9200
    scheme: https
    ssl_verify: false
    suppress_type_name: true
    user: admin
```

### Flow

Перейдём в `Logging` -> `Flows`

Нажмём кнопку `Create`

* `Namespace` -> `kube-system` 
* `Name` -> `kube-system`
* `Description` -> `Control plane logs`
* `Matches` -> оставляем все поля пустыми.
* `Outputs` -> выбираем Cluster Outputs `opensearch-system`
* `Filters` -> 

```yaml
- tag_normaliser:
    format: ${namespace_name}.${pod_name}.${container_name}
- kube_events_timestamp:
    mapped_time_key: mtime
    timestamp_fields:
    - event.eventTime
    - event.lastTimestamp
    - event.firstTimestamp
```

_Про доступные фильтры можно почитать [тут](https://kube-logging.github.io/docs/configuration/plugins/filters/)._

Нажмём кнопку `Create`

## Сбор логов - пользователь

[Настроить сбор логов в проекте может только 
 **Project Owner**](https://ranchermanager.docs.rancher.com/v2.6/integrations-in-rancher/logging/rbac-for-logging). 
На этом Rancher можно закапывать.