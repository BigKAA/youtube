# Использование OpenLDAP

Будет рассмотрено два примера использования OpenLDAP:

- Включение SSL в OpenLDAP.
- Отображение пользователей на Linux машину.
- Федерация в Keycloak.

## SSL

### CA и сертификат сервера OpenLDAP

Для работы с сертификатами будем использовать возможности, предоставляемые Cert Manager. Предполагается, что он уже установлен в вашем кластере.

Все действия будем производить в namespace `default`.

Создаем самоподписанный сертификат CA и локальный Issuer:

```shell
kubectl apply -f manifests/01-ldap-issuer.yaml
```

Параметры  Issuer и создаваемого сертификата определяем в файле values.yaml чарта.

### Изменения в чарте OpenLDAP

В версии черта 0.1.1 добавлена секция, посвященная ssl.

```yaml
# Включение TLS  
  ssl:
    enable: true
    # Сертификат можно создать вручную.
    # И поместить его в Secret
    #
    # Пример Secret
    # apiVersion: v1
    # kind: Secret
    # metadata:
    #   name: openldap-cert
    #   namespace: default
    # type: kubernetes.io/tls
    # data:
    #   ca.crt: CA_CRT_DATA
    #   tls.crt: TLS_CRT_DATA
    #   tls.key: TLS_KEY_DATA
    secretName: openldap-cert
    # Или создать при помощи Certmanager, установленного в кластере.
    # Парамeтры Certificate
    certmanager:
      enable: true
      # secretName - из параметра выше
      duration: 9125h # 1y
      renewBefore: 360h # 15d
      subject:
        organizations:
          - "Artur's dev"
        organizationalUnits:
          - "Home lab"
        localities:
          - "Moscow"
        countries:
          - "RU"
      commonName: "Openldap cert"
      # Если известны имена DNS, по которым будут подключаться клиенты,
      # добавьте их в сертификаты:
      dnsNames: []
      # - ldap.exaple.com
      ipAddresses:
        - 192.168.218.189
      # Если известны IP адреса, по которым будут подключаться клиенты,
      # добавьте их в сертификаты:
      #  - 192.168.218.189
      issuerRef:
        name: ldap-issuer
        kind: Issuer
        group: cert-manager.io
```

## Пример отображения пользователей на Linux машину

Для демонстрации используется дистрибутив Rocky Linux 9.4.

Отображения пользователей из LDAP на Linux машину будет происходить при помощи sssd (System Security Services Daemon).

Подробная документация по приложению доступна в его документации.

```shell
man sssd
man sssd.conf
man sssd-ldap
```

### Настройка клиента LDAP

По умолчанию sssd не настроен и не включен. Установим необходимые для работы компоненты:

```shell
dnf install -y oddjob-mkhomedir openldap-clients
```

Добавим в систему сертификат нашего CA. Содержимое сертификата возьмем из созданного ранее secret `openldap-cert`.

```shell
vim /etc/pki/ca-trust/source/anchors/openldap_ca.pem
```

Добавим его в список доверенных сертификатов.

```shell
update-ca-trust
```

Необязательный шаг, но для проверки подключения отредактируем конфигурацию клиента LDAP:

```shell
cat > /etc/openldap/ldap.conf << EOF
URI ldaps://192.168.218.189/ ldap://192.168.218.189/
BASE dc=my-domain,dc=com
# Если в сертификат не добавлен указанный в параметре URI 
# IP адрес или имя машины, добавляем ингнорирование ошибки:
# TLS_REQCERT never
EOF
```

Проверим подключение по ldaps:

```shell
ldapsearch -x -D "cn=Manager,dc=my-domain,dc=com" -W
```

По ldap, но с включением STARTTLS:

```shell
ldapsearch -x -ZZ -H "ldap://192.168.218.189/" -D "cn=Manager,dc=my-domain,dc=com" -W
```

### Настройка sssd

Для автоматического создания домашних директорий пользователя.

```shell
authselect select sssd with-mkhomedir --force
systemctl enable --now oddjobd.service
systemctl status oddjobd.service
```

Настройка демона sssd:

```shell
cat > /etc/sssd/sssd.conf << EOF
[sssd]
config_file_version = 2
services = nss, pam
domains = LDAP

[nss]
filter_users = root,named,avahi,haldaemon,dbus,radiusd,news,nscd
homedir_substring = /home

[pam]
offline_credentials_expiration = 0
offline_failed_login_attempts = 0
reconnection_retries = 3
offline_failed_login_delay = 5

[domain/LDAP]
#debug_level= 9
id_provider = ldap
autofs_provider = ldap
auth_provider = ldap
chpass_provider = ldap

ldap_default_authtok_type = password
ldap_default_bind_dn = cn=Manager,dc=my-domain,dc=com
ldap_default_authtok = password
ldap_uri = ldaps://192.168.218.189/
# ldap_tls_reqcert = never
# ldap_tls_cacert = /etc/pki/ca-trust/source/anchors/openldap_ca.pem
ldap_schema = rfc2307
ldap_search_base = dc=my-domain,dc=com?subtree?
ldap_user_search_base = ou=users,dc=my-domain,dc=com?subtree?(objectClass=posixAccount)
ldap_group_search_base = ou=groups,dc=my-domain,dc=com?subtree?(objectClass=posixGroup)
enumerate = true
cache_credentials = true
#ldap_tls_reqcert = never
#ldap_tls_cacertdir = /etc/openldap/cacerts
EOF
```

- `ldap_schema`:
  - `rfc2307` - в группе пользователи указываются при помощи аттрибута `memberUid`.
  - `rfc2307bis` и `IPA` - в группе пользователи указываются при помощи аттрибута `member`.
  - `AD` - если используется LDAP Active Directory.

```shell
chmod 0600 /etc/sssd/sssd.conf
systemctl start sssd
systemctl enable sssd
```

Проверяем наличие пользователя и группы:

```shell
getent passwd
getent group
```

Попробуем зайти через ssh:

```shell
ssh user1@127.0.0.1
```

Проверяем:

```shell
id
pwd
passwd
```

## Keycloak

Предварительно создадим базу keycloak в Postgres.

Для запуска с Keycloak воспользуемся чартом Bitnami. Простейшая установка, для демонстрации настройки федерации.

```shell
helm install keycloak bitnami/keycloak -n keycloak --create-namespace -f chart/keycloak-values.yaml
```

- Connection and authentication settings
  - `connection URL`: `ldap://test-artopenldap.default.svc`.
  - `bind DN`: `cn=Manager,dc=my-domain,dc=com`.
  - `bind password`: `password`.

Проверяем подключение.

- LDAP searching and updating
  - `Edit mode`: `READ_ONLY`.
  - `Users DN`: `ou=users,dc=my-domain,dc=com`.
  - `Username LDAP attribute`: `uid`.
  - `RDN LDAP attribute`: `uid`.
  - `UUID LDAP attribute`: `entryUUID`.
  - `User object classes`: `person`, `organizationalPerson`, `inetOrgPerson`.
  - `User LDAP filter`: `(mail=*)`.
  - `Search scope`: `Subtree`.

- Synchronization settings
  - `Import users`: On
  - `Sync Registrations`: On
  - `Periodic full sync`: On
    - `Full sync period`: `20`. _Для тестов сделаем период обновления 20 секунд_.

Там же, смотрим раздел Mappers.

## Видео

- [VK](https://vkvideo.ru/video7111833_456239297)
- [Telegram](https://t.me/arturkryukov/722)
- [Rutube](https://rutube.ru/video/1b7abaeb8b31d3ae8cf789b45d0767e7/)
- [Youtube](https://youtu.be/RFLmLwyoNxo)
