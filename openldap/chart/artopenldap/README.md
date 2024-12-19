# Artopenldap

OpenLDAP helm chart

Чарт позволяет запустить OpenLDAP в режиме multimaster от одного пода.

**TODO - добавить ссылку на проект**
Поддерживаются только контейнеры, собранные для этого чарта. Смотрите файлы *.Dockerfile.

Поддерживаются OpenLDAP версии 2.4.х и 2.6.х.

## Конфигурационные параметры

### Версия OpenLDAP

Версия OpenLDAP определяется используемым контейнером.

Параметры:

```yaml
image:
  repository: registry.kryukov.local/library/artopenldap
  tag: "2.6.7"
```

В зависимости от используемого контейнера следует установить параметры `securityContext.runAsUser` и `securityContext.runAsGroup`:

Для версии 2.6:

```yaml
securityContext:
  runAsUser: 100
  runAsGroup: 101
```

Для версии 2.4:

```yaml
securityContext:
  runAsUser: 55
  runAsGroup: 55
```

### Service

`service.type` - для доступа к OpenLDAP можно использовать три типа сервисов:

- `ClusterIP` - доступ только внутри кластера Kubernetes.
- `NodePort` - доступ и внутри и снаружи.
- `LoadBalancer` - доступ и внутри и снаружи. В случае, если кластер
поддерживает сервисы типа `LoadBalancer`.

### Probes

Пробы срабатывают после добавления в LDAP корневого dn, определенного при помощи параметра `ldap.olcRootDN`.

Скрипт проб определен в ConfigMap в шаблоне [cmbin.yaml](templates/cmbin.yaml):

```yaml
probe.sh: |
  #!/bin/sh
  LDAPI_PATH="ldapi://%2Fvar%2Flib%2Fopenldap%2Frun%2Fsldap.sock/"
  ldapsearch -Q -LLL -Y EXTERNAL -H "LDAPI_PATH" -s base -b {{ .Values.ldap.olcSuffix }} 'dn={{ .Values.ldap.olcRootDN }}' cn > /dev/null 2>&1
  exit $?
```

### Диски

Подключаемые volumes для всех контейнеров (masters, slaves) имеют одинаковые значения и определяются при помощи:

```yaml
volumes:
  data:
   storageClassName: ""
   storage: 256Mi
```

### Логи OpenLDAP

Какая информация будет выводиться в логах приложений определяется параметром:

```yaml
debugLevel: '256'
```

Про допустимые значения можно прочитать в документации к демону slapd. [Смотрите описание параметра `-d`](https://www.openldap.org/doc/admin26/runningslapd.html#Command-Line%20Options).

### Backend

Используемый backend определяется в зависимости от версии OpenLDAP.

Выбор версии OpenLDAP осуществляется путём выбора используемого контейнера в ветке `image` в файле values.

- Версия 2.6: `ldap.dbBackend` может иметь значение только `mdb`.
- Версия 2.4: `ldap.dbBackend` может быть установлен в `mdb` или `hdb`.

Параметр `ldap.olcDbMaxSize` обязателен только для backend `mdb`.

### Base DN

Base DN Задаётся параметром:

```yaml
ldap:
  olcSuffix: 'dc=my-domain,dc=com'
```

### Административный пользователь

DN администратора:

```yaml
ldap:
  olcRootDN: 'cn=Manager,dc=my-domain,dc=com'
```

Пароль можно указать в открытом виде (*не желательно*):

```yaml
ldap:
  adminPassword: password
```

Или **в заренее созданном Secret**. Пример Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: adminpw
stringData:
  ADMIN_PASSWORD: password
```

Указав имя Secret в качестве параметра:

```yaml
ldap:
  adminPasswodSecret: "adminpw"
```

### olcSizeLimit

`ldap.olcSizeLimit` - Очень важный параметр, определяющий максимальное количество записей возвращаемых сервером в ответе на запрос поиска. **Если количество записей в базе данных больше чем этот параметр - синхронизация между нодами не будет работать**.

Если его явно не определять, значение по умолчанию будет равно 500. [См. документацию, раздел 5.2.5.6. olcSizeLimit](https://www.openldap.org/doc/admin26/guide.html#Database-specific%20Directives).

### Overlays

В данной версии добавлена конфигурация только двух overlay: memberOf и refint.

Overlay syncprov включен по умолчанию.

```yaml
ldap:
  overlaysEnabled:
    memberOf: true
    refint: true
```

*Конфигурация прописана в стартовых скриптах. Если вам понадобятся другие overlays - придется редактировать чарт.*

### Schemas

**Порядок загрузки схем имеет значение!**

Подключение необходимых для работы схем конфигурируется путем добавления их в соответствующий массив:

```yaml
ldap:
  schemas:
    files:
    - core.ldif
    - cosine.ldif
    - inetorgperson.ldif
    - nis.ldif
```

Полный список файлов схем, поставляемый с OpenLDAP, можно прочитать в документации к демону slapd или посмотреть в файловой системе контейнера.

При определении кастомных схем, их НЕ нужно добавлять выше в 'schemas.files'. Предполагается, что кастомные схемы будут подгружаться при старте контейнера из внешних источников. В данный момент поддерживается только S3 хранилище.

Custom схемы в конфигурационном файле располагаются после схем из 'schemas.files'.

```yaml
ldap:
  schemas:
    customSchemas:
      enable: false
      # Тип хранилища, откуда будут загружаться файлы схем
      # На данный момент, поддерживается только S3.
      type: s3
      s3:
        url: "minio.minio.svc:9000"
        user: openldap
        password: password
        bucket: openldap
      files:
      - my_core.ldif
      - my_cosine.ldif
      - my_inetorgperson.ldif
```

### Индексы

Бакенды, используемые OpenLDAP поддерживают индексацию.

Параметры индексации настраиваются при помощи массива:

```yaml
ldap:
  olcDbIndexes:
  - "objectClass eq"
  - "entryUUID,entryCSN eq"
  - "ou,cn,mail,surname,givenname,uid eq,pres,sub"
```

Подробнее про индексацию смотрите в документации к бакендам OpenLDAP `5.2.7.4. olcDbIndex`.

### olcAccess

**Права доступа определяются только один раз, при первом запуске чарта**.

olcAccess предусмотрены для четырех записей в конфигурационном файле slapd.ldif.

```yaml
ldap:
  olcAccess:
    dbFrontend:
    dbConfig:
    mdbOrHdbConfig:
    dbMonitor:
```

### dbConfig24

`dbConfig24` используется только в бакенде `hdb`.

Содержит конфигурационный файл `DB_CONFIG`.

```yaml
ldap:
  dbConfig24: |
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

Обязательно указывайте параметр `set_flags DB_LOG_AUTOREMOVE` в конфигурационном файле, что бы файловая система базы данных не забивалась бинарными логами.

### multimaster

`replicas` - определяет количество реплик сервера OpenLDAP.

Количество реплик желательно делать 2 и более. При восстановлении из бекапа базы данных OpenLDAP. Количество реплик необходимо уменьшить до 1. После восстановления данных, увеличить до 2-х и более.

Остальные значения определяют параметры репликации модуля Syncrepl.

### Экспортер

Экспортер добавляется в виде отдельного контейнера в под с OpenLDAP.

Пользователь, с правами которого экспортер обращается к `cn=Monitor` соответствует административному пользователю.

Параметры доступа к метрикам экспортера задается при помощи аннотации пода экспортера. Это следует учитывать при конфигурации scrapper Prometheus.

Показанные ниже параметры определяют имена ключей в аннотации пода:

```yaml
exporter:
  annotationKeys:
   path: "prometheus.io/path"
   port: "prometheus.io/port"
   scrape: "prometheus.io/scrape"
```

Значения полей аннотации изменить нельзя. Они имеют следующие значения по умолчанию:

- `prometheus.io/path: "/metrics"`
- `prometheus.io/port: "9330"`
- `prometheus.io/scrape: "true"`

### Backup

*Процедура резервного копирования не проработана от слова - совсем. Представляет из себя деревянный костыль.*

Восстановление из бекапа и создание бекапа поддерживает только S3 хранилища. Параметры S3 хранилища одинаковы и для создания файла бекпа и для восстановления из бекпа.

```yaml
backup:
  type: s3
  s3:
    url: "minio.minio.svc:9000"
    user: openldap
    # TODO: add secret
    password: password
    bucket: openldap
```

#### Восстановление из бекапа

```yaml
backup:
  restore:
    # Важно! После восстановления из backup переключаем в -> enable: false
    # И дальше используем helm upgrade для чарта.
    # Что бы в дальнейшем при рестарте контейнера не качались данные из backup.
    # Это ускорит время старта приложения.
    enable: false
    # Файл бекапа должен быть сжат при помощи gzip
    file: backup/backup.ldif.gz
```

#### Создание бекапа

Для регулярного создания бекапа используется cronJob. Параметры которого описаны ниже.

```yaml
backup:
  save:
    enable: false
    image:
      repository: registry.kryukov.local/library/artopenldap
      pullPolicy: IfNotPresent
      tag: "2.4.59"
      # tag: "2.6.7"
    #      ┌─ minute (0 - 59)
    #      │ ┌ hour (0 - 23)
    #      │ │ ┌─ day of the month (1 - 31)
    #      │ │ │ ┌─ month (1 - 12)
    #      │ │ │ │ ┌─ day of the week (0 - 6) (Sunday to Saturday) 
    #      │ │ │ │ │  OR sun, mon, tue, wed, thu, fri, sat
    #      │ │ │ │ │ 
    #      │ │ │ │ │
    #      │ │ │ │ │
    cron: "* 1 * * *"
    failedJobHistoryLimit: 3
    successfulJobsHistoryLimit: 5
    backoffLimit: 3
    file:
      path: backup
      fileNameStartAt: ldap-data
```

Если необходимо создавать бекап вручную, то вы можете подключиться любым инструментом к LDAP серверу и сделать бекап. Например:

```shell
export LDAP_BIND_DN="cn=admin,dc=my-domain,dc=com"
export LDAP_BIND_PASSWORD="password"
export LDAP_URL="openldap.openldap.svc:389"
export LDAP_SUFFIX="dc=my-domain,dc=com"
ldapsearch -x -D $LDAP_BIND_DN \
      -w $LDAP_BIND_PASSWORD \
      -H ldap://$LDAP_URL \
      -b $LDAP_SUFFIX + > backup/ldap-data-$(date +%Y-%m-%d).ldif
```

Обратите внимание на символ `+` в конце ldapsearch. Он заставляет сохранять в резервной копии служебные параметры записей. Типа `memberOf`, `entryUUID`, `entryCSN` и т.п.

## Состояние сервера после установки

После первого запуска сервера создаются:

- База с использованием backend mdb или hdb.
- Административный пользователь для организации синхронизации.
- Записи в базе.

`dn` зависит от параметра `ldap.olcSuffix`. Например, если `ldap.olcSuffix: 'dc=my-domain,dc=com'`,
то в дерево будет добавлена следующая структура:

```ldif
dn: dc=my-domain,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: Организация из параметра ldap.organization
dc: dc=my-domain,dc=com

dn: cn=repluser,dc=my-domain,dc=com
objectClass: inetOrgPerson
cn: repluser
sn: repluser
description: Account for LDAP replication
userPassword: Хеш пароля пользователя repluser
```

**Никогда не удаляйте пользователя `repluser`!**
