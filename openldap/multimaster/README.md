# OpenLDAP multimaster

Для демонстрации будут использоваться два сервера:

- `rocky1.kryukov.local`
- `rocky2.kryukov.local`
  
На первом сервере в предыдущем видео уже установлен OpenLDAP. Мы только установим пароль администратора
`cn=Administrators,dc=my-domain,dc=com` в `password`:

```shell
ldapmodify -Q -Y EXTERNAL -f admin_password.ldif
```

## Установка второго сервера OpenLdap

На машине `rocky2.kryukov.local` следует установить сервер OpenLDAP, так же, как и в предыдущем видео. Единственно, что не надо делать - добавлять информацию в дерево LDAP. Оно в дальнейшем автоматически будет скопировано с первого мастера.

```shell
wget -q https://repo.symas.com/configs/SOLDAP/rhel9/release26.repo -O /etc/yum.repos.d/soldap-release26.repo
dnf update -y
dnf install -y symas-openldap-clients symas-openldap-servers
exit
```

Выходим для того, что бы применились изменения в среде окружения пользователя.

Подготовим файл `slapd.ldif`. Содержимое файла аналогично файлу с первого сервера OpenLDAP:

```shell
vim ~/slapd.ldif
```

Конфигурацию юнита:

```shell
cat > /etc/default/symas-openldap << EOF
SLAPD_URLS="ldap:/// ldapi://%2Fvar%2Fsymas%2Frun%2Fsldap.sock/"
SLAPD_OPTIONS="-4 -F /etc/openldap/slapd.d -u ldap -g ldap"
EOF
```

Создадим конфигурационный файл клиентских приложений.

```shell
cd /opt/symas/etc/openldap
cat > ldap.conf << EOF
BASE   dc=my-domain,dc=com
URI    ldapi://%2Fvar%2Fsymas%2Frun%2Fsldap.sock/ ldap://127.0.0.1:389
SASL_NOCANON    on
EOF
rm -f /etc/openldap/ldap.conf
ln -s /opt/symas/etc/openldap/ldap.conf /etc/openldap/ldap.conf
```

Создание директорий и установка прав доступа:

```shell
rm -rf /etc/openldap/slapd.d
mkdir -p /etc/openldap/slapd.d
```

Создание конфигурации:

```shell
slapadd -b cn=config -l ~/slapd.ldif -F /etc/openldap/slapd.d/
chown -R ldap:ldap /var/symas/openldap-data /var/symas/run /etc/openldap/slapd.d
```

Запуск сервера:

```shell
systemctl start slapd
systemctl status slapd
systemctl enable slapd
```

Заполнять базу данных основными записями не станем. Они будут скопированы с мастер сервера, после настройки репликации.

## Master slave

**Перед началом работы обязательно удалите** `dn: cn=monitoring,ou=Groups,dc=my-domain,dc=com` на мастер сервере!
И, если они есть, другие записи с `objectclass: groupOfNames`. При первоначальной синхронизации, первыми в списке у нас идет группа monitoring. Она так же первой создаётся на слейв сервере. У этой группы есть обязательное поле `member`, в котором должен указываться dn уже существующей записи пользователя. Но на slave сервере такого пользователя еще нет, его dn идет дальше в списке. Поэтому при создании группы возникает ошибка и процесс синхронизации встает колом. *В дальнейшем мы обнаружим ещё много "чудесатого" у OpenLDAP*.

В качестве slave сервера будем использовать OpenLDAP на машине `rocky2.kryukov.local`.

Для включения механизма синхронизации нам необходимо включить и настроить модуль syncprov.

Сначала внимательно читаем [документацию по syncrepl](https://www.openldap.org/doc/admin26/guide.html#syncrepl) и по [настройке различных типов репликации](https://www.openldap.org/doc/admin26/guide.html#Configuring%20the%20different%20replication%20types).

Модуль syncprov мы уже загружали в файле `slapd.ldif`. Теперь подключим его к базе данных `mdb`.

Файл `syncprov_enable.ldif`:

```ldif
dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpSessionLog: 100
```

`olcSpSessionlog` Указывает, что на сервере-поставщике должен вестись журнал, в который записывается информация об операциях записи, производимых в базе данных. Аргумент определяет количество операций, которое можно поместить в данный журнал. Туда помещается информация о всех операциях записи (за исключением операций добавления add). Если такой журнал сессии используется, целесообразно назначить индекс eq на атрибут entryUUID в соответствующей базе данных поставщика.

Данный журнал сессии может использоваться при репликации во время операций синхронизации, чтобы минимизировать обновления потребителя, в первую очередь в режиме refreshOnly. Поскольку на поставщике не настраивается количество потребителей репликации, которое будет запрашивать синхронизацию, для наибольшей эффективности значение аргумента, задаваемого в данной директиве, должно позволять сохранять в журнале предполагаемый максимум числа изменений, которые могут произойти в промежутке между синхронизациями потребителя с самым длинным интервалом пересинхронизации (устанавливается параметром interval директивы syncrepl). Если в журнале сессии недостаточно информации, поставщик вынужден будет выполнять полную последовательность ресинхронизации, начиная с последней известной точки.

На обеих серверах вносим изменения в конфигурацию.

```shell
ldapadd -Y EXTERNAL -f syncprov_enable.ldif
```

Добавляем ID сервера. **ID должен быть уникальным у каждого сервера OpenLDAP**.

На сервере `rocky1.kryukov.local`:

Файл `01ldapId.ldif`:

```ldif
dn: cn=config
changetype: modify
replace: olcServerID
olcServerID: 101
```

```shell
ldapmodify -Y EXTERNAL -f 01ldapId.ldif
```

На сервере `rocky2.kryukov.local`:

Файл `02ldapId.ldif`:

```ldif
dn: cn=config
changetype: modify
replace: olcServerID
olcServerID: 102
```

```shell
ldapmodify -Y EXTERNAL -f 02ldapId.ldif
```

На мастер сервере добавим пользователя, которого будем использовать для репликации данных.

Файл `repluser.ldif`:

```ldif
dn: cn=repluser,dc=my-domain,dc=com
objectClass: inetOrgPerson
cn: repluser
sn: repluser
description: Application account for LDAP replication
# password: password
userPassword: {SSHA}Cl6ONU2E26tVc4CziboiSrkh3FP76MTC
```

```shell
ldapadd -Y EXTERNAL -f repluser.ldif
```

Добавим права на чтение этому пользователю.

Файл `repluserrights.ldif`:

```ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to dn.subtree="dc=my-domain,dc=com" by dn.exact="cn=repluser,dc=my-domain,dc=com" read by * break
```

```shell
ldapmodify -Q -Y EXTERNAL -f repluserrights.ldif
```

На slave сервере `rocky2.kryukov.local` добавим конфигурацию модуля syncprov.

Файл `02ldapslave.ldif`:

```ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://rocky1.kryukov.local:389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=off
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
```

Где:

- `olcSyncRepl`
  - `schemachecking` - `on` каждая реплицируемая запись будет проверяться на соответствие ее схеме, на сервере-получателе. Если параметр отключен, записи будут сохранены без проверки соответствия схемы. Значение по умолчанию отключено.
  - `type` - определяет, какой режим будет использовать клиент при подключении к провайдеру. Существует два режима:
    - `refreshOnly` - следующая операция поиска синхронизации периодически переносится через определенный промежуток времени после завершения каждой операции синхронизации. Интервал определяется параметром `interval`.
    - `refreshAndPersist` - операция поиска является постоянной.
  - `retry` - Если во время репликации возникает ошибка, пользователь попытается повторно подключиться в соответствии с параметром `retry`, который представляет собой список пар <интервал повторных попыток> и <количество повторных попыток>. Например, параметр retry="30 5 300 3" позволяет пользователю повторять попытку каждые 30 секунд в течение первых 5 раз, а затем каждые 300 секунд в течение следующих трех раз, прежде чем прекратить повторные попытки. + в <числе повторных попыток> означает неопределенное количество попыток до достижения успеха.
- `olcMirrorMode` - первоначально OpenLDAP поддерживал очень ограниченную 2-х узловую систему синхронизации. `TRUE` включает полноценный зеркальный режим.

```shell
ldapmodify -Y EXTERNAL -f 02ldapslave.ldif
```

Подключаемся к slave LDAP серверу и наблюдаем записи с основного мастера.

Если записей нет, значит вы где то ошиблись. Смотрите логи slave и мастер серверов.

```shell
journalctl -u symas-openldap-servers --no-pager
```

## Multimaster

Режим multimaster подразумевает, что (в нашем случае) оба два серевра OpenLDAP могут работать в режиме rw. И в случае изменения данных на любом из серверов, на другой сервер будут реплицированы изменения с сервера на котором произошли изменения.

В нашем случае достаточно на сервере `rocky1.kryukov.local` настроить репликацию данных с сервера `rocky2.kryukov.local`.

Файл `01ldapslave.ldif`:

```ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://rocky2.kryukov.local:389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=off
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
```

```shell
ldapmodify -Y EXTERNAL -f 01ldapslave.ldif
```

## Multimaster + slave

В случае необходимости, к multimaster серверам можно добавлять дополнительные slave сервера. В конфигурации репликации следует указывать репликацию с обеих мастер серверов.

Пример настройки репликации на slave серевре:

```ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://rocky1.kryukov.local:389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=off
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
olcSyncRepl: rid=002
  provider=ldap://rocky2.kryukov.local:389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=off
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
```
