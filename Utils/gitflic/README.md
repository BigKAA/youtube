# Gitflic Helm Chart

Создан на основе документации https://docs.gitflic.space/setup/docker_setup. _То, что у них было написано про
kubernetes https://docs.gitflic.space/setup/kuber_setup - не работает из коробки._

## Сборка контейнера

По какой-то причине разработчики не предоставляют готового контейнера приложения. Поэтому вы сами должны его собрать и
куда-то положить.

Скачайте [архив последнего релиза](https://gitflic.ru/project/gitflic/gitflic/release) и распакуейте его.

Перенесите этот [Dockerfile](Dockerfile) в корень проекта.

Запустите сборку контейнера. Имя и тег контейнера задайте согласно вашего хранилища контейнеров.

```shell
docker build -t bigkaa/gitflic:2.16.1 .
docker push bigkaa/gitflic:2.16.1
```

**Внимание!** Контейнер `bigkaa/gitflic:2.16.1` будет удалён после съемки видео.

## Подготовка

### ssh

Для доступа по ssh необходимо включить ssh Service типа NodePort или LoadBalancer.
**Доступ к ssh через Ingress controller не предусмотрен**.

В файле values предусмотрены соответствующие параметры:

```yaml
serviceSSH:
  enable: false
  port: 2222
  # Services type: NodePort or LoadBalancer
  type: NodePort
  # Для сервиса типа NodePort - это обязательный параметр
  nodePort: "31222"
  name: ""
```

Так же, перед установкой helm chart обязательно добавьте Secret, содержащий приватный ssh ключ:

```shell
ssh-keygen -t ed25519 -f key.pem
kubectl -n NAMESPACE create secret generic sshKey --from-file=key.pem --from-file=key.pem.pub 
```

### Непонятное

В документации написано что можно запустить несколько инстансов gitflic. Раздел 
"[Балансировка нагрузки (Кластеризация)](https://docs.gitflic.space/setup/setup_and_start)". Но ничего
не сказано как эти инстансы будут взаимодействовать с томами в файловой системе.

Непонятно. А если непонятно - то будем считать что это монолит. Будем делать только одну реплику и только StatefulSet.

Если в дальнейшем окажется, что инстансы опираются на ону файловую систему - тогда в чарте можно будет перейти
на Deployments и добавить PVC на файловой системе с поддержкой ReadWriteMany.

## Конфигурация

Для работы приложения необходимы два обязательных компонента: redis и postgree. Можно использовать
отдельно установленные приложения. Или поставить приложения при помощи этого чарта.

### Redis

Для подключения стороннего Redis в файле values необходимо определить следующие параметры:

```yaml
redis:
  buildin: false
  externalRedis:
    host: "192.168.0.1"
    port: "6379"
    username: ""
    password: ""
```

Для установки встроенного экземпляра Redis предусмотрена установка helm chart Redis от bitnami.

```yaml
redis:
  buildin: true
  # Параметры встроенного чарта redis
  global:
    storageClass: ""
  auth:
    enabled: false
    password: "PASSWO5RD"
  master:
    count: 1
  replica:
    replicaCount: 1
  metrics:
    enabled: false
  volumePermissions:
    enabled: true
```

### PostgreSQL

Для подключения стороннего Postgresql необходимо определить следующие параметры:

```yaml
# Конфигурация базы данных
db:
  # Host & Port только для внешней базы
  postgresHost: "192.168.0.1"
  postgresPort: "5432"

  postgresDb: "gitflic"
  postgresUser: "gitflic"
  # Secret создаваемый в ручную.
  # ---
  # apiVersion: v1
  # kind: Secret
  # metadata:
  #   name: secretName
  # type: Opaque
  # stringData:
  #   postgres-user-password: password
  # ...
  # Если имя секрета определеноЮ пароль берется из этого сикрета
  secretName: ""
  # Если Secret не определён, и пароль явно не задан в следующем параметре,
  # Secret с паролем генерируется автоматически.
  postgresPassword: ""
  # Первоначальная инициализация базы данных. Только для строенного postgresql!!!
  initJob:
    image: postgres
    tag: 15.5-alpine3.18
    imagePullPolicy: IfNotPresent

# Builtin Postgresql cluster
postgresql:
  buildin: false
```

При использовании сторонней базы данных, база `postgresDb` и пользователь должны быть созданы до
установки gitflic.

_Для корректной работы приложения, требуется расширение pgcrypto для postgresql, для конкретной базы данных 
в СУБД выполняем запрос: CREATE EXTENSION pgcrypto; 
[Из документации по установке](https://docs.gitflic.space/setup/setup_and_start)._

## Default login and password

Стандартные пользователь и пароль для входа:

- adminuser@admin.local
- qwerty123