# OpenLDAP как обычное приложение

Установка OpenLDAP в виде обычного приложения на Linux сервере.

На момент записи видео использовался Rocky Linux 9:

```shell
cat /etc/os-release 
NAME="Rocky Linux"
VERSION="9.4 (Blue Onyx)"
ID="rocky"
ID_LIKE="rhel centos fedora"
VERSION_ID="9.4"
PLATFORM_ID="platform:el9"
PRETTY_NAME="Rocky Linux 9.4 (Blue Onyx)"
ANSI_COLOR="0;32"
LOGO="fedora-logo-icon"
CPE_NAME="cpe:/o:rocky:rocky:9::baseos"
HOME_URL="https://rockylinux.org/"
BUG_REPORT_URL="https://bugs.rockylinux.org/"
SUPPORT_END="2032-05-31"
ROCKY_SUPPORT_PRODUCT="Rocky-Linux-9"
ROCKY_SUPPORT_PRODUCT_VERSION="9.4"
REDHAT_SUPPORT_PRODUCT="Rocky Linux"
REDHAT_SUPPORT_PRODUCT_VERSION="9.4"
```

Дистрибутивы, производные от RedHat, начиная с версии 8.5 удалили из своих репозиториев пакеты
`opendldap-server`:

```shell
dnf search openldap
============================================ Name Exactly Matched: openldap 
openldap.x86_64 : LDAP support libraries
openldap.i686 : LDAP support libraries
================================================ Name Matched: openldap 
openldap-clients.x86_64 : LDAP client utilities
openldap-compat.x86_64 : Package providing legacy non-threaded libldap
openldap-compat.i686 : Package providing legacy non-threaded libldap
openldap-devel.x86_64 : LDAP development libraries and header files
openldap-devel.i686 : LDAP development libraries and header files
```

В качестве сервера LDAP рекомендуют использовать 389-ds:

```shell
dnf search 389-ds
================================================= Name Matched: 389-ds 
389-ds-base.x86_64 : 389 Directory Server (base)
389-ds-base-libs.x86_64 : Core libraries for 389 Directory Server
```

Поскольку в нескольких проектах у меня "прибит гвоздями" OpenLDAP и нет возможности перейти на 389-ds. Будем смотреть как установить OpenLDAP на Rocky Linux.

В проектах, которые я обслуживаю используется древняя версия OpenLDAP - 2.4. И к сожалению, нет возможности перейти на более свежие версии 2.5 или 2.6. Там есть серьезное ограничение, связанное с
backend базой данных.

Посмотрев различные варианты установки OpenLDAP на клоны RedHat Linux, сделал вывод, что можно использовать готовые пакеты из проекта [https://repo.symas.com](https://repo.symas.com/).

Но! Как всегда есть одно большое  **НО**! Версию OpenLDAP 2.4 из пакетов получится поставить только на Rocky Linux 8. На 9-ю поставить не получится.

Как вариант, приложение можно собрать приложение из исходных кодов. Но, в следующих видео этого цикла, вы поймете, что контейнеризация рулит! Поэтому, в качестве компромисса, мы поставим версию
2.6. На этом примере разберемся, как настраивать, запускать и управлять сервером OpenLDAP. А в дельнейших видео, при помощи контейнеров установим OpenLDAP версии 2.4.

## Установка OpenLDAP

Установка приложения простая как электровеник. [Инструкция по установке](https://repo.symas.com/sofl/rhel9/) находится на сейте проекта.

Из этой инструкции выполним только три пункта, связанные с установкой приложения:

```shell
wget -q https://repo.symas.com/configs/SOLDAP/rhel9/release26.repo -O /etc/yum.repos.d/soldap-release26.repo
dnf update
```

Посмотрим, какие пакеты с OpenLDAP добавлены в список.

```shell
dnf search symas-openldap
```

Появился пакет `symas-openldap-servers`.

Установим приложения:

```shell
dnf install -y symas-openldap-clients symas-openldap-servers
```

## Конфигурация сервера

После установки пакетов, обязательно смотрите какие файлы были установлены. В нашем случае
будет использоваться директория `/opt`.

```shell
rpm -ql symas-openldap-servers | less
rpm -ql symas-openldap-clients | less
```

Для конфигурации сервера OpenLDAP есть два пути:

- классический - файл `slapd.conf`.
- новый - директория `slapd.d`.

Я выбираю конфигурацию при помощи директории `slapd.d`. Это более сложный вариант конфигурации
сервера. Но у него есть один жирный плюс - конфигурацию можно делать "на лету", без рестарта
OpenLDAP.

Как всегда, перед использование приложения **внимательно** читаем [документацию](https://www.openldap.org/doc/admin26/guide.html#Configuring%20slapd).

Перед запуском сервера, нам необходимо:

- создать ldif файл с первоначальной конфигурацией.
- при помощи специального инструмента импортировать это файл в директорию slapd.d.
- запустить сервер OpenLDAP.

### Файл slapd.ldif

За основу возьмем файл `/opt/symas/etc/openldap/slapd.ldif.default`:

```shell
cd /opt/symas/etc/openldap
cp slapd.ldif.default slapd.ldif
```

Перед нами типичный файл в формате ldif, в котором описаны записи дерева `cn=config`.

#### cn=config

Корнем дерева конфигурации является `dn: cn=config`.

[https://www.openldap.org/doc/admin26/guide.html#cn=config](https://www.openldap.org/doc/admin26/guide.html#cn=config)

В полях этой записи определяются глобальные параметры сервера OpenLDAP:

- `olcLogLevel` - уровень отладочной информации. *Мы будем использовать другой вариант включения отладки в контейнерах*.
- `olcIdleTimeout` - определяет количество секунд ожидания перед принудительным закрытием незанятого клиентского соединения. По умолчанию отключено.
- `olcPidFile` - определяет файл, в котором после запуска сервера будет помещен PID процесса.

В файле в комментариях вы можете увидеть другие `olc*` аттрибуты. Подробно о них написано в `man 5 slapd-config`.

#### cn=module,cn=config

Следующая запись: `dn: cn=module,cn=config`, позволяет указать какие модули необходимо запускать при старте OpenLDAP.

[https://www.openldap.org/doc/admin26/guide.html#cn=module](https://www.openldap.org/doc/admin26/guide.html#cn=module)

Модулей у OpenLDAP много.

Аттрибут `olcModulepath` определяет директорию, в которой находятся библиотеки с модулями.

При помощи `olcModuleload` перечисляем, какие модули будем использовать в нашей инсталляции сервера.

Кроме модуля бакенда базы данных `back_mdb` я планирую использовать еще два модуля:

- [memberof.so](https://www.openldap.org/doc/admin26/guide.html#Reverse%20Group%20Membership%20Maintenance) - поддержание обратного членства в группе
- [syncprov.so](https://www.openldap.org/doc/admin26/guide.html#Sync%20Provider) - поддержка синхронизации содержимого по протоколу LDAP.

```ldif
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath:  /opt/symas/lib/openldap
olcModuleload:  back_mdb.so
olcModuleload:  memberof.so
olcModuleload:  syncprov.so
olcModuleload:  refint.so
```

#### cn=schema,cn=config

`dn: cn=schema,cn=config` определяет, какие схемы можно использовать в записях сервера.

Файлы схем находятся в директории `/opt/symas/etc/openldap/schema`.

Я буду использовать:

- core.ldif
- cosine.ldif
- inetorgperson.ldif
- nis.ldif

```ldif
cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

include: file:///opt/symas/etc/openldap/schema/core.ldif
include: file:///opt/symas/etc/openldap/schema/cosine.ldif
include: file:///opt/symas/etc/openldap/schema/inetorgperson.ldif
include: file:///opt/symas/etc/openldap/schema/nis.ldif
```

#### olcDatabase=frontend,cn=config

`dn: olcDatabase=frontend,cn=config`

В man slapd-config есть упоминание, что эта база данных должна всегда иметь номер {-1}. Что параметры базы frontend наследуются в других базах данных, если они явно не определяются в этих базах.

Т.е. frontend это как бы базовый шаблон для всех остальных записей `objectClass: olcDatabaseConfig`.

Например, если вы используете несколько баз данных, обслуживающие различные деревья LDAP, но имеющие одинаковые параметры, типа `olcAccess` и подобных. Имеет смысл определить их во frontend и эти параметры будут унаследованы в этих базах.

```ldif
dn: olcDatabase=frontend,cn=config
objectClass: olcDatabaseConfig
objectClass: olcFrontendConfig
olcDatabase: frontend
```

#### olcDatabase=config,cn=config

Эта база создаётся автоматически. Я решил ее добавить сразу, что бы прописать необходимые ACL. (*Об ACL поговорим чуть позже.*)

```ldif
dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by * none
```

#### olcDatabase=mdb,cn=config

Собственно описание базы данных, в которой будет храниться дерево LDAP.

`objectClass: olcMdbConfig` говорит нам о том, что в качестве бакенда будет использоваться [LMDB](https://www.openldap.org/doc/admin26/guide.html#LMDB).

Внимательно читаем [документацию](https://www.openldap.org/doc/admin26/guide.html#MDB%20Database%20Directives) по параметрам базы данных mdb.

- `olcDbMaxSize` - при инициализации mdb обязательно требуется указывать размер базы данных.
- `olcSuffix` - "корень" дерева LDAP.
- `olcRootDN` - dn администратора базы данных. По умолчанию администратор в этой базе может всё.
- `olcRootPW` - пароль в открытом виде или hash пароля админа.

Получить хеш пароля можно при помощи утилиты `slappasswd`

- `olcDbDirectory` - директория, где будут храниться файлы базы данных.
- `olcDbIndex` - индексы базы данных.

На промежуточном этапе запись будет выглядеть следующим образом:

```ldif
dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcDbMaxSize: 1073741824
olcSuffix: dc=my-domain,dc=com
olcRootDN: cn=Manager,dc=my-domain,dc=com
olcRootPW: {SSHA}Cl6ONU2E26tVc4CziboiSrkh3FP76MTC
olcDbDirectory: /var/symas/openldap-data
olcDbIndex: objectClass eq
olcDbIndex: ou,cn,mail,uid eq,pres,sub
```

#### olcDatabase=monitor,cn=config

Самой последней записью в файле должна быть `dn: olcDatabase=monitor,cn=config`.

В дальнейшем я планирую подключить openldap exporter, при помощи которого буду собирать метрики OpenLDAP в систему мониторинга. Для того, что бы экспортер мог собирать данные о работе сервера, необходимо определить эту запись в конфигурации приложения.

```ldif
dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcRootDN: cn=config
olcMonitoring: TRUE
```

### ACL

Теперь займемся доступами пользователей к базам данных.

На данный момент, полный доступ к базам имеет пользователь `cn=Manager,dc=my-domain,dc=com`.

Нам необходимо разрешить кое какие действия обычным пользователям. Например, менять свой пароль. И добавить несколько сервисных пользователей, которые будут иметь доступ только на чтение к базам данных.

Ну и особый "гость" - системный пользователь `root` (*или любой другой локальный пользователь сервера Linux*). Доступ для таких пользователей предоставлять не обязательно. Но пример, как это можно сделать, мы тоже рассмотрим.

Подробно про ACL написано в [документации к OpenLDAP](https://www.openldap.org/doc/admin26/guide.html#Access%20Control).

#### Простые смертные и их пароли

Поскольку информация о пользователях будет храниться в базе данных `dn: olcDatabase=mdb,cn=config`. Соответствующий olcAccess будем добавлять в этом dn.

Для нормальной работы пользователей мы должны дать д доступ к аттрибутам `userPassword` и `shadowLastChange`.

- Для анонимных (еще не прошедших аутентификацию) пользователей - auth (возможность проверить правильность введенного пароля).
- Для пользователя, которому принадлежит эта запись - write (возможность перезаписи пароля).
- Для админа - write.
- Для членов группы `cn=Administrators,dc=my-domain,dc=com` - write. (*Группу добавим позднее.*)
- Всем остальным пользователям - запретить доступ к этим аттрибутам.

```ldif
olcAccess: to attrs=userPassword,shadowLastChange 
  by dn="cn=Manager,dc=my-domain,dc=com" write
  by group.exact="cn=Administrators,dc=my-domain,dc=com" write
  by anonymous auth
  by self write
  by * none
```

Обратите внимание на формат ldif файлов, касательно переноса строк. Продолжить писать значение параметра можно на следующей строке. Но новая строка должна начинаться с двух и более пробелов.

Если в начале строки поставить один пробел. это будет считаться не как пробел, а как признак жесткой склейки.

Пример:

```ldif
olcAccess: to attrs=userPassword,shadowLastChange by dn="cn=Manager,dc=my-domain,dc=com" write
 by anonymous auth
```

Будет интерпретирована как: `olcAccess: to attrs=userPassword,shadowLastChange by dn="cn=Manager,dc=my-domain,dc=com" writeby anonymous auth`. В результате вы получите сообщение об ошибке.

#### Доступ к дереву

Если вам потребуется ограничивать доступы к другим аттрибутам, записям или веткам "дерева". Добавляйте ACL, определяющие соответствующие ограничения.

К остальным записям в дереве, всем другим пользователям предоставляется доступ только на чтение. По сути, информация, хранящаяся в LDAP - это публичная информация.

Поэтому добавим еще одно поле в запись базы данных. Предоставляющую соответствующий доступ всем остальным пользователям.

```ldif
olcAccess: to *
  by dn=cn=Manager,dc=my-domain,dc=com write
  by group.exact="cn=Administrators,dc=my-domain,dc=com" write
  by * read
```

#### Overlay memberof

Сразу добавим [overlay memberof](https://www.openldap.org/software/man.cgi?query=slapo-memberof&apropos=0&sektion=5&manpath=OpenLDAP+2.6-Release&arch=default&format=html).

```ldif
dn: olcOverlay={0}memberof,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfRefint: TRUE
```

#### Overlay Refint

И еще один [overlay](https://www.openldap.org/software/man.cgi?query=slapo-refint&apropos=0&sektion=5&manpath=OpenLDAP+2.6-Release&arch=default&format=html), позволяющий держать в порядке ссылки на атрибуты.

```ldif
dn: olcOverlay={1}refint,olcDatabase={1}mdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: {1}refint
olcRefintAttribute: memberof member manager owner
```

#### Доступ к мониторингу

И отдельно добавим доступ к базе данных мониторинга специальному пользователю: `cn=Monitoring,dc=my-domain,dc=com`.

```ldif
dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcRootDN: cn=config
olcMonitoring: TRUE
olcAccess: to *
  by dn=cn=Manager,dc=my-domain,dc=com read
  by dn=cn=Monitoring,dc=my-domain,dc=com read
  by group.exact="cn=Administrators,dc=my-domain,dc=com" read
  by * none
```

самого пользователя Monitoring мы добавим позднее.

#### Приглашенные звёзды

Сервер slapd позволяет управлять им с правами пользователей Linux. Т.е. достаточно зайти в систему пользователем root или любым другим. И не зная пароль администратора `cn=Manager,dc=my-domain,dc=com` выполнять административные функции.

Эта возможность по умолчанию не включена.

Что бы разрешить таким пользователям работать с базами OpenLDAP потребуется их добавить в соответствующие ACL.

Пользователь root в ACL будет выглядеть так: `dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth`

```shell
id ldap
uid=55(ldap) gid=55(ldap) groups=55(ldap)
```

А пользователь ldap: `dn.exact=gidNumber=55+uidNumber=55,cn=peercred,cn=external,cn=auth`

Таким образом группа ACL базы данных mdb будет выглядеть следующим образом:

```ldif
olcAccess: to attrs=userPassword,shadowLastChange 
  by dn="cn=Manager,dc=my-domain,dc=com" write
  by group.exact="cn=Administrators,dc=my-domain,dc=com" write
  by dn.base=gidNumber=55+uidNumber=55,cn=peercred,cn=external,cn=auth write
  by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write
  by anonymous auth
  by self write
  by * none
olcAccess: to *
  by dn=cn=Manager,dc=my-domain,dc=com write
  by group.exact="cn=Administrators,dc=my-domain,dc=com" write
  by dn.base=gidNumber=55+uidNumber=55,cn=peercred,cn=external,cn=auth write
  by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write
  by * read
```

### Подготовительные действия

#### Конфигурационный файл юнита systemd

Для того что бы не копаться в юните systemd, создадим конфигурационный файл, содержащий две переменные:

- `SLAPD_URLS` - определяет список URL, где будет слушать запросы сервер OpenLDAP.
- `SLAPD_OPTIONS` - параметры запуска демона slapd.

```shell
cat > /etc/default/symas-openldap << EOF
SLAPD_URLS="ldap:/// ldapi://%2Fvar%2Fsymas%2Frun%2Fsldap.sock/"
SLAPD_OPTIONS="-4 -F /etc/openldap/slapd.d -u ldap -g ldap"
EOF
```

#### Создание директорий

Создаём директорию, где будет находиться конфигурация сервера.

Передаем эту директорию и директории, где будут располагаться файлы базы данных и soacket файл пользователю и группе ldap.

```shell
mkdir -p /etc/openldap/slapd.d
chown ldap:ldap /var/symas/openldap-data /var/symas/run /etc/openldap/slapd.d
```

#### Создание конфигурационной директории

На данный момент у нас есть первоначальный конфигурационный файл `slapd.ldif`. На основании этого файла мы создадим конфигурационную директорию `slapd.d`.

```shell
slapadd -b cn=config -l ~/slapd.ldif -F /etc/openldap/slapd.d/
```

Передадим созданные файлы конфигурации пользователю и группе ldap:

```shell
chown -R ldap:ldap /etc/openldap/slapd.d/
```

Исследуем содержимое директории `/etc/openldap/slapd.d`.

**Внимание!** Не редактируйте файлы в директории `/etc/openldap/slapd.d`! Изменение конфигурации должно происходить только при помощи специальных утилит.

## Запуск сервера

```shell
systemctl start slapd
systemctl status slapd
systemctl enable slapd
```

Проверяем наличие socket файла и открытого порта 389:

```shell
ls -l /var/symas/run/
ss -nltp | grep 389
```

Директория с данными:

```shell
ls -l /var/symas/openldap-data
```

## Клиенты

### Утилиты командной строки

Создадим конфигурационный файл клиентских приложений.

```shell
cd /opt/symas/etc/openldap
cat > ldap.conf << EOF
BASE   dc=my-domain,dc=com
URI    ldapi://%2Fvar%2Fsymas%2Frun%2Fsldap.sock/ ldap://127.0.0.1:389

EOF
```

Делаем красиво:

```shell
ln -s /opt/symas/etc/openldap/ldap.conf /etc/openldap/ldap.conf
```

На данный момент у нас в LDAP в базе mdb нет никакой информации. Поэтому запросим данные из системы мониторинга.

Пытаемся подключиться с правами системного пользователя `root` через ldapi (socket файл).

```shell
ldapsearch -Q -LLL -Y EXTERNAL -b 'cn=Monitor' '(cn=Monitor)'
```

В ответ должны получить:

```txt
dn: cn=Monitor
objectClass: monitorServer
cn: Monitor
description: This subtree contains monitoring/managing objects.
description: This object contains information about this server.
description: Most of the information is held in operational attributes, which 
 must be explicitly requested.
```

Аналогичный запрос, но уже с правами администратора:

```shell
ldapsearch -LLL -x -D cn=Manager,dc=my-domain,dc=com -W -b 'cn=Monitor' '(cn=Monitor)'
```

- `-x` включает base auth.
- `-W` приложение попросит вас ввести пароль администратора.

Аналогичным образом можно посмотреть, например конфигурацию сервера:

```shell
ldapsearch -Q -LLL -Y EXTERNAL -b 'cn=config' | less
```

### Добавление информации в дерево LDAP

Для добавления данных необходимо создать ldif файл, содержащие данные.

В файле `init_data.ldif` находится базовая структура дерева и служебные пользователи.

```bash
ldapadd -Y EXTERNAL -f init_data.ldif
```

Договоримся (проведем приказом по отделу), что пользователи, которые будут отображаться на машины Linux, будут иметь RDN uid. И находится в определенном OU.

Добавим пользователя, который будет отображаться в Linux машины:

```bash
ldapadd -Y EXTERNAL -f add_user.ldif
```

Посмотрим содержимое дерева:

```shell
ldapsearch -Q -LLL -Y EXTERNAL 
```

Выведем список пользователей, отображаемых на Linux машины:

```shell
ldapsearch -Q -LLL -Y EXTERNAL -b 'ou=Users,dc=my-domain,dc=com' 'uid=*' dn displayName uid
```

```ldif
dn: uid=petrov_vs,ou=Users,dc=my-domain,dc=com
displayName:: 0J/QtdGC0YDQvtCyINCS0LDRgdC40LvQuNC5INCh0LXRgNCz0LXQtdCy0LjRhw==
uid: petrov_vs
```

### Модификация данных

#### Изменение пароля пользователя

Для изменения пароля пользователя petrov_vs создадим ldif файл `petrov_password.ldif`.

Хеш пароля получим при помощи приложения `slappasswd`.

```ldif
dn: uid=petrov_vs,ou=Users,dc=my-domain,dc=com
changetype: modify
userPassword: olcRootPW
# password: password2
olcRootPW: {SSHA}2o0EN89kKcR/T4z2EAI1nFI/oG1mFX9T
```

```shell
ldapmodify -Q -Y EXTERNAL -f petrov_password.ldif
```

Проверяем:

```shell
ldapsearch -LLL -x -D uid=petrov_vs,ou=Users,dc=my-domain,dc=com -W "uid=*" dn uid userPassword
```

```ldif
dn: uid=petrov_vs,ou=Users,dc=my-domain,dc=com
uid: petrov_vs
userPassword:: e1NTSEF9Mm8wRU44OWtLY1IvVDR6MkVBSTFuRkkvb0cxbUZYOVQ=
```

#### Изменение пароля админа

Изменение пароля администратора происходит аналогичным образом. Но нужно учитывать в каком дереве находится информация об этом пользователе и его пароле.

Создадим файл `admin_password.ldif`.

```ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
# password: password2
olcRootPW: {SSHA}2o0EN89kKcR/T4z2EAI1nFI/oG1mFX9T
```

Применяем изменения:

```shell
ldapmodify -Q -Y EXTERNAL -f admin_password.ldif
```

Проверяем:

```bash
ldapsearch -LLL -x -D cn=Manager,dc=my-domain,dc=com -W dn
```
