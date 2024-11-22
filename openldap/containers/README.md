# Набор контейнеров для OpenLDAP

Набор контейнеров включает в себя два контейнера с OpenLDAP версий 2.4 и 2.6. И контейнер с
LDAP exporter.

Контейнеры OpenLDAP не содержат никаких стартовых скриптов для запуска и|или инициализации приложения. Вы должны самостоятельно позаботиться о первоначальной инициализации и запуске
OpenLDAP.

В контейнерах OpenLDAP, на всякий случай дополнительно установлены: curl, wget и git. На случай
если вы захотите настроить резервное копирование на внешние устройства. Никто не мешает
самостоятельно добавить в контейнер необходимые для дальнейшей работы пакеты.

Приложения во всех контейнерах работают с правами обычных пользователей.

## Контейнер OpenLDAP v2.6

Контейнер построен на базе дистрибутива Alpine Linux. Дистрибутив содержит пакеты OpenLDAP
последней версии.

Пользователь `ldap:100:101` создается автоматически, при установке пакета. Подключаемые тома должны быть переданы пользователю и группе `ldap`.

[Dockerfile контейнера](openldap.Dockerfile).

## Контейнер OpenLDAP v2.4

Контейнер построен на базе дистрибутива Rocky Linux. С использованием дополнительного репозитория [https://repo.symas.com/configs/SOFL/rhel8/sofl.repo](https://repo.symas.com/configs/SOFL/rhel8/sofl.repo).

Пользователь `ldap:55:55` создается автоматически, при установке пакета.

[Dockerfile контейнера](openldap-2.4.Dockerfile).

## Контейнер OpenLDAP exporter

Контейнер создан [на базе проекта](https://github.com/tomcz/openldap_exporter/releases/tag/v2.2.2).

*Разработчик проекта перестал его сопровождать и перенес в архив. Возможно с последними версиями
OpenLDAP он может работать не корректно.*

Экспортер собирается из исходных кодов. Для сборки контейнера можно использовать
[mulistage Dockerfile](exporter_broken.Dockerfile), удалив из него строку
`COPY --from=build /ca.crt /ca.crt`. В случае среды разработки, которую использую я, с
собственным CA. (*Смотрите видео на моих каналах про среду разработки на базе k3s*).
Приходится колдовать с сертификатом собственного CA. Что не есть хорошо. Поэтому процедура
CI разделена на два stage: build и push. На первом этапе создается артефакт. На втором собирается контейнер, содержащий этот артефакт.

Контейнер конфигурируется при помощи переменных среды окружения:

- `LDAP_USER` - dn пользователя, с правами которого приложение обращается к `cn=Monitor` OpenLDAP.
- `LDAP_PASS` - пароль этого пользователя.
- `INTERVAL` - интервал сбора метрик, по умолчанию `30s`.

Пользователь, справами которого запускается экспортер: `exporter:5001:5001`.

## Запуск контейнеров

В качестве примера установим OpenLDAP версии 2.4 на дистрибутиве Rocky Linux 9. Напомню, что в 9-й версии нет поддержки OpenLDAP 2.4.
Для обхода этого ограничения воспользуемся подготовленным контейнером.

Добавим в файл `/etc/hosts` машину с Harbor моего dev стенда. *Смотрите цикл видео про среду разработки на базе k3s.*

```txt
192.168.218.189 registry.kryukov.local
```

На всякий случай. Если вдруг осталась старая конфигурация:

```shell
rm -rf /etc/openldap/slapd.d/*
```

### containerd

Для запуска контейнеров будем использовать containerd. Почему не podman, стандартно поставляемый с этим дистрибутивом?

Две причины:

1. В качестве движка контейнеризации в k8s я предпочитаю использовать containerd.
2. Не зависимо от темы данного видео, мне надо провести несколько экспериментов с containerd.

Добавим репозиторий докера:

```shell
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf makecache
```

Установим приложение:

```shell
dnf install -y containerd.io
```

Я планирую использовать свое собственное хранилище контейнеров.
Harbor использует сертификат подписанный моим СА. Для того что бы containerd мог без проблем общаться с моим Harbor, надо добавить сертификат CA в список доверенных сертификатов.

Сертификат берем из secret `dev-ca` в namespace `cert-manager`. И помещаем в файл `/etc/pki/ca-trust/source/anchors/dev-ca.pem`.

Добавим сертификат к списку доверенных:

```shell
update-ca-trust extract
```

Проверим, добавился ли сертификат в список доверенных.

```shell
curl -I https://registry.kryukov.local
```

Поправим конфигурацию containerd:

```shell
mv /etc/containerd/config.toml /etc/containerd/config.toml.orig
containerd config default > /etc/containerd/config.toml
```

На всякий пожарный, добавим работу с docker hub через зеркало. *Уже были прецеденты, закрытия прямого доступа к docker hub.*
Для этого поработаем с конфигурационным файлом containerd.

```shell
vim /etc/containerd/config.toml
```

```toml
[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
```

```shell
mkdir -p /etc/containerd/certs.d/docker.io
vim /etc/containerd/certs.d/docker.io/hosts.toml
```

Документация по настройке mirror [тут](https://github.com/containerd/containerd/blob/main/docs/hosts.md#setup-a-local-mirror-for-docker).

```toml
server = "https://registry-1.docker.io"

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
[host."https://mirror.gcr.io"]
  capabilities = ["pull", "resolve"]
```

Включим использование SystemdCgroup.

```shell
vim /etc/containerd/config.toml
```

```toml
[plugins."io.containerd.grpc.v1.cri".containerd]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
```

Запустим containerd:

```shell
systemctl enable --now containerd.service
systemctl status containerd.service
```

### nerdctl

Для управления контейнерами с containerd поставляется утилита `ctr`. Но она жутко неудобная в использовании.
Поэтому поставим дополнительный инструмент - [nerdctl](https://github.com/containerd/nerdctl). *Это мой выбор. Вы можете использовать любое приложение для управления контейнерами*.

Параметры nerdctl похожи на параметры docker. Плюс дополнительный плюшки для работы с k8s.

```shell
cd
wget https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz
tar -xzf nerdctl-1.7.6-linux-amd64.tar.gz
cp nerdctl /usr/local/bin/nerdctl
nerdctl --help
```

Попробуем загрузить контейнер:

```shell
nerdctl pull registry.kryukov.local/library/artopenldap:2.4.59
nerdctl pull nginx:latest
```

Посмотрим список загруженных контейнеров:

```shell
nerdctl images
```

### Подготовка конфигурационных файлов и директорий

#### На master сервере

Для работы OpenLDAP создадим директорию, в которой будет находится база данных OpenLDAP:

```shell
mkdir -p /var/lib/openldap/data /var/lib/openldap/run
```

Создадим файл `/var/lib/openldap/data/DB_CONFIG`:

```txt
# one 0.25 GB cache
set_cachesize 0 268435456 1

# Data Directory
#set_data_dir db

# Transaction Log settings
set_lg_regionmax 262144
set_lg_bsize 2097152
#set_lg_dir logs

set_flags DB_LOG_AUTOREMOVE
```

Создадим конфигурационный файл `/var/lib/openldap/slapd.ldif`. Содержание файлам можно посмотреть [тут](conf/slapd.ldif).

Мы собираемся запускать контейнер с OpenLDAP версии 2.4. Внутри которого уже есть пользователь и группа ldap с UID и GID 55.
Передадим директории, которые мы будем подключать к контейнеру этому пользователю и группе:

```shell
chown -R 55:55 /etc/openldap /var/lib/openldap
```

Запустим контейнер:

```shell
nerdctl run --network host -d \
   --mount type=bind,src=/etc/openldap/slapd.d,dst=/etc/openldap/slapd.d \
   --mount type=bind,src=/var/lib/openldap,dst=/var/lib/openldap \
   --ulimit nofile=1024:1024 \
   --name openldap \
   registry.kryukov.local/library/artopenldap:2.4.59
```

Проверим наличие работающего контейнера:

```shell
nerdctl ps
```

Зайдем в контейнер:

```shell
nerdctl exec -it openldap bash
```

Начнем заниматься конфигурацией OpenLDAP.

```shell
slapadd -b cn=config -l /var/lib/openldap/slapd.ldif -F /etc/openldap/slapd.d/
```

Запускаем сервер OpenLDAP

```shell
slapd -4 -F /etc/openldap/slapd.d -u ldap -g ldap \
      -h "ldap://0.0.0.0:10389/ ldapi://%2Fvar%2Flib%2Fopenldap%2Frun%2Fsldap.sock/" -d "256" \
      > /dev/null 2>&1 &
```

Проверяем подключение к slapd:

```shell
export LDAP_URL="ldapi://%2Fvar%2Flib%2Fopenldap%2Frun%2Fsldap.sock/"
ldapsearch -Q -LLL -Y EXTERNAL -H $LDAP_URL -b 'cn=Monitor' '(cn=Monitor)'
```

Файл [/var/lib/openldap/init_data.ldif](conf/init_data.ldif).

```bash
ldapadd -Y EXTERNAL -H $LDAP_URL -f /var/lib/openldap/init_data.ldif
```

Файл [/var/lib/openldap/add_users.ldif](conf/add_users.ldif).

```bash
ldapadd -Y EXTERNAL -H $LDAP_URL -f /var/lib/openldap/add_users.ldif
```

Посмотрим содержимое нашего "дерева" `dc=my-domain,dc=com`:

```shell
ldapsearch -Q -LLL -Y EXTERNAL -H $LDAP_URL -b 'dc=my-domain,dc=com'
```

Добавляем в конфигурацию настройку репликации. Файл [/var/lib/openldap/master.ldif](conf/master.ldif).

```shell
ldapadd -Y EXTERNAL -H $LDAP_URL -f /var/lib/openldap/master.ldif
```

Корректно останавливаем slapd:

```shell
kill PID_SLAPD
```

Выходим из контейнера и останавливаем его.

```shell
nerdctl stop openldap
nerdctl rm openldap
```

#### На slave сервере

```shell
mkdir -p /var/lib/openldap/data /var/lib/openldap/run
chown -R 55:55 /var/lib/openldap/
```

Для ускорения процесса конфигурации я написал небольшой скрипт. Создадим файл `/var/lib/openldap/init.sh`. Содержимое скрипта можно посмотреть [тут](conf/init.sh).

Запустим контейнер:

```shell
nerdctl run --network host -d \
   --mount type=bind,src=/etc/openldap/slapd.d,dst=/etc/openldap/slapd.d \
   --mount type=bind,src=/var/lib/openldap,dst=/var/lib/openldap \
   --ulimit nofile=1024:1024\
   --name openldap \
   registry.kryukov.local/library/artopenldap:2.4.59
```

Проверим наличие работающего контейнера:

```shell
nerdctl ps
```

Зайдем в контейнер:

```shell
nerdctl exec -it openldap bash
```

Запустим скрипт внутри контейнера:

```shell
/var/lib/openldap/init.sh init
/var/lib/openldap/init.sh slave
```

Корректно останавливаем slapd:

```shell
kill PID_SLAPD
```

Выходим из контейнера и останавливаем его.

```shell
nerdctl stop openldap
nerdctl rm openldap
```

#### Unit file

После конфигурации, нам необходимо запустить OpenLDAP в рабочем режиме. Для этого создадим файл юнита для systemd - [/etc/systemd/system/artopenldap.service](conf/artopenldap.service):

```toml
[Unit]
Description=OpenLDAP Service
After=containerd.service
Requires=containerd.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/local/bin/nerdctl stop %n
ExecStartPre=-/usr/local/bin/nerdctl rm %n
ExecStartPre=/usr/local/bin/nerdctl image pull registry.kryukov.local/library/artopenldap:2.4.59
ExecStart=/usr/local/bin/nerdctl run --network host \
   --mount type=bind,src=/etc/openldap/slapd.d,dst=/etc/openldap/slapd.d \
   --mount type=bind,src=/var/lib/openldap,dst=/var/lib/openldap \
   --name %n \
   --ulimit nofile=1024:1024\
   --entrypoint /usr/sbin/slapd \
   registry.kryukov.local/library/artopenldap:2.4.59  \
      -4 -F /etc/openldap/slapd.d -u ldap -g ldap \
      -h "ldap://0.0.0.0:10389/ ldapi://%%2Fvar%%2Flib%%2Fopenldap%%2Frun%%2Fsldap.sock/" \
      -d "256"

[Install]
WantedBy=multi-user.target
```

```shell
systemctl daemon-reload
systemctl start artopenldap
systemctl status artopenldap
```

Смотрим логи:

```shell
journalctl -f -u artopenldap
```
