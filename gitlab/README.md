# Gitlab

https://docs.gitlab.com/charts/installation/

Для создания PV в моём кластере используется NFS диск и соответствующий ему StorageClass - managed-nfs-storage.

## Prerequisites

Для деплоя приложений я использую ArgoCD. Вы можете использовать манифесты или helm charts. Что и где находится
можно посмотреть в соответствующих yaml файлов в директории argocd. 

### Postgresql

Поставим один под postgresql. Простейшая установка. Для прод необходимо ставить полнофункциональный кластер.

```shell
kubectl apply -f argocd/postgre-app.yaml
```

### Redis

```shell
kubectl apply -f argocd/redis-app.yaml
```

### minio

```shell
kubectl apply -f argocd/minio-app.yaml
kubectl apply -f argocd/minio-console-app.yaml
```

### mail-relay

```shell
kubectl apply -f argocd/mail-relay-app.yaml
```

## Установка чарта

```shell
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm search repo gitlab/gitlab
```

```shell
helm show values gitlab/gitlab > gitlab-values.yaml
```

### Параметры чарта

Создадим values файл `gl-values.yaml`

#### Выключаем не нужное.

Чарт gitlab универсальный и содержит в себе помимо gitlab еще много дополнительных приложений.
У меня в кластере и за его пределами уже установлены:

* PostgreSQL
* Minio
* Redis
* Prometheus
* Ingress controller
* Cert-manager

Поэтому устанавливать рядом дубли этих приложений не имеет смысла. Поэтому мы выключим
их установку.

Так же мы не будем ставить gitlab runner. Мы добавим его позднее, учитывая наши
пожелания к нему. 

Gitlab registry пока тоже оставим за бортом. Для его работы потребуются валидные сертификаты
или много телодвижений на серверах кубера.

```yaml
certmanager:
  install: false

postgresql:
  install: false

redis:
  install: false

prometheus:
  install: false

nginx-ingress:
  enabled: false

registry:
  enabled: false

gitlab-runner:
  install: false

global:
  minio:
    enabled: false
```

#### Вариант GitLab

Будем устанавливать Git lab Community Edition. Это нужно указать явным образом. 
В секции `global` добавим параметр:

```yaml
global:
  edition: ce
```

#### Пароль администратора

Пароль пользователя root - администратора GitLab, генерируется автоматически и помещается
в соответствущий Secret. Но его можно указать явным образом.

Следующий Secret, содержит пароль пользователя `root`. В дельнейшем его
можно изменить непосредственно в самом приложении. Пароль должен быть сложным и кроме букв
содержать специальные символы и цифры. _Если пароль будет "слабым"
при установке чарта, пользователь root создаваться не будет и вы
не сможете войти в систему._

```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: initial-admin-password
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  password: "password-password-33"
EOF
```

В файле `gl-values.yaml`, в секции `global` добавим следующие строки:

```yaml
global:
    initialRootPassword:
    key: password
    secret: initial-admin-password
```

Тут мы определили имя Secret, содержащего пароль и имя ключа, в котором
этот пароль находится.

#### Gitaly PVC

Чарт GitLab сожержит в себе несколько сабчартов. Один из них устанавливает 
[gitaly](https://gitlab.com/gitlab-org/gitaly/?_gl=1%2a16ox1i6%2a_ga%2aOTUyMDU0MzQ0LjE2ODYyMTA2NzY.%2a_ga_ENFH3X7M5Y%2aMTY4Njg5NTA5OS4xMC4xLjE2ODY4OTYyODQuMC4wLjA.).

Для работы приложения потребуется выделить дисковое пространство.
Соответствующие параметры можно указать в разделе `gitlab.gitaly`.
В нашем случае важно правильно определить `storageClass` и размер PV.

```yaml
gitlab:
  gitaly:
    persistence:
      size: 50Gi
      storageClass: "managed-nfs-storage"
```

#### Redis

Мы будем пользоваться уже установленным Redis. Так получилось, что в моём случае 
Redis установлен в том же кластере kubernetes, в том же namespace, где будет
располагаться gitlab.

Пароль доступа храниться в Secret `gitlab-redis` в поле `redis-password`.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-redis
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  redis-password: 'qUwTt8g9it'
EOF
```

Доступ к Redis будем осуществлять при помощи Service `gitlab-redis-master`.

Соответствущие параметры будем определять в разделе `global.redis`:

```yaml
global:
  redis:
    auth:
      enabled: true
      secret: gitlab-redis
      key: redis-password
    host: gitlab-redis-master
    port: 6379
```

#### PostgreSQL

База данных установлена на том же кластере kubernetes, в том же namespace, 
где будет располагаться gitlab.

Основные параметры для подключения понятны из их названий. Пароль пользователя
хранится в Secret `postgres-secret`.

```yaml
global:
  psql:
    host: postgres-np
    port: 5432
    database: gitlab
    username: artur
    password:
      useSecret: true
      secret: postgres-secret
      key: POSTGRES_PASSWORD
```

#### Ingress

В кластере уже установлен Ingress controller. Его class: `system-ingress`.

```yaml
global:
  ingress:
    configureCertmanager: false
    class: system-ingress
    provider: nginx
    tls:
      enabled: false
```

Хочу обратить внимание на то, что мой ingress controller не поддерживает проброс
22-го порта на GitLab. Т.е. доступ по ssh не предусмотрен. Если вы хотите разрешить
22-й порт, смотрите [эту документацию](https://docs.gitlab.com/charts/advanced/external-nginx/).

#### DNS имена

Все сервисы, предоставляемы GitLab будут в домене `kryukov.local`. Для того, что бы
GitLab работал нормально, вы должны предусмотреть преобразование имён для машин:

* gitlab.kryukov.local
* kas.kryukov.local

И других сервисов, если вы их собираетесь включить.

```yaml
global:
  hosts:
    domain: kryukov.local
    https: false
    externalIP: 192.168.218.180
```

#### Внешнее хранилище объектов

GitLab сохраняет различные объекты в S3 хранилище. Мы будем использовать отдельно
установленный Minio. В моём случае Minio установлен в том же кластере kubernetes, 
в том же namespace, где будет располагаться gitlab.

Создаём два secrets, содержащих файлы с параметрами подключения к Minio.

```shell
cat << EOF | kubectl apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  connection: |
    provider: AWS
    region: us-east-1
    host: minio.kryukov.local
    endpoint: http://gitlab-minio:9000
    path_style: true
    aws_access_key_id: admin 
    aws_secret_access_key: password
EOF
```

```shell
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: s3-credentials
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  config: |
    s3:
      bucket: gitlab-registry-storage
      accesskey: admin
      secretkey: password
      region: us-east-1
      regionendpoint: "http://gitlab-minio:9000"
      v4auth: true
EOF
```

Приложения, использующие хранилище объектов:

```yaml
global:
  appConfig:
    lfs:
      bucket: gitlab-lfs-storage
      connection: # https://gitlab.com/gitlab-org/charts/gitlab/blob/master/doc/charts/globals.md#connection
        secret: minio-credentials
        key: connection
    artifacts:
      bucket: gitlab-artifacts-storage
      connection:
        secret: minio-credentials
        key: connection
    uploads:
      bucket: gitlab-uploads-storage
      connection:
        secret: minio-credentials
        key: connection
    packages:
      bucket: gitlab-packages-storage
      connection:
        secret: minio-credentials
        key: connection

    backups:
      bucket: gitlab-backup-storage
      tmpBucket: gitlab-tmp-storage

gitlab:
  toolbox:
    backups:
      objectStorage:
        config:
          secret: s3-credentials
          key: config
```

#### Почта

Для пересылки почты пришлось устанавливать отдельный mail relay.
Он не требует авторизации и в Gitlab её нужно отключить. Для отключения достаточно было бы в values добавить всего один 
параметр `global.smtp.authentication: "none"`. Но в чарте криво определили условия проверки 
необходимости аутентификации в сабчартах.  

Есть два пути решения:

1. Править кучу сабчартов gitlab.
2. Забить и создать левый Secret с фейковым паролем почтового пользователя.

Мы пойдем вторым путём.

```shell
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: fake-mail-password
  namespace: gitlab
  labels:
    manual: "yes"
type: Opaque
stringData:
  password: "gitlab-helm-writers"
EOF
```

```yaml
global:
  smtp:
    enabled: true
    tls: false
    starttls_auto: false
    openssl_verify_mode: 'none'
    domain: "git.kryukov.local"
    address: mail-relay
    port: 25
    # Говорим, что аутентификация не нужна. Главное, что чарт sidekiq написан правильно. Он поймет, что мы хотим.
    authentication: "none"
    # Для остальных кривых чартов из gitlab добавляем Secret с фейковым паролем.
    password:
      secret: 'fake-mail-password'
      key: 'password'
  email:
    from: "noreply@gitlab.kryukov.local"
    display_name: "GitLab kryukov.local"
```

## После установки

Не забудьте создать все buckets в minio. 

## Run

```shell
helm template gitlab gitlab/gitlab -n gitlab -f gl-values.yaml > gt2.yaml
```

```shell
helm install gitlab gitlab/gitlab -n gitlab -f gl-values.yaml 
```

```shell
helm uninstall gitlab -n gitlab 
```

## После создания видео

После создания видео обнаружил, что GitLab не может удалить проекты.
Почему-то для удаления ему требуется наличие сервиса registry.

Поэтому в файле values закоментируйте 

```yaml
#registry:
#  enabled: false
```

И обновите чарт.

```shell
helm upgrade gitlab gitlab/gitlab -n gitlab -f gl-values.yaml
```

Добавится сервис registry и проекты, стоящие в очереди на удаление будут удалены.

## Видео

* [VK](https://vk.com/video7111833_456239246)
* [Telegramm](https://t.me/arturkryukov/279)
* [Rutube](https://rutube.ru/video/c1c366f5bf2430541041838f009f0594/)
* [Zen](https://dzen.ru/video/watch/64be1959dff44977f6bf675e)
* [Youtube](https://youtu.be/mQAdGy9YOBg)