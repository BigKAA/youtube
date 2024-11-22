#! /bin/bash

# Usage: init.sh init|master|slave

export LDAPI_PATH="ldapi://%2Fvar%2Flib%2Fopenldap%2Frun%2Fsldap.sock/"
init_master() {
    echo "init master"

    echo "init data_data.ldif"
    cat > /var/lib/openldap/init_data.ldif << EOF
# Корень дерева
dn: dc=my-domain,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: Тестовая организация
dc: my-domain

# Админ. Что бы был. Пароль не нужен
dn: cn=Manager,dc=my-domain,dc=com
objectClass: organizationalRole
cn: Manager
description: OpenLDAP Manager

# Пользователь для доступа к мониторингу
dn: cn=Monitoring,dc=my-domain,dc=com
objectClass: inetOrgPerson
cn: Monitoring
sn: Monitoring
# slappasswd пароль: password
userPassword: {SSHA}nwXoxv3hFEbtZmQctIH57vFik1mb1380

# OU для хранения учетных записей
dn: ou=Users,dc=my-domain,dc=com
objectClass: organizationalUnit
ou: Users

# OU для хранения групп
dn: ou=Groups,dc=my-domain,dc=com
objectClass: organizationalUnit
ou: Groups

# Группа мониторинг для демонстрации memberOf
dn: cn=monitoring,ou=Groups,dc=my-domain,dc=com
objectclass: groupOfNames
cn: monitoring
member: cn=Monitoring,dc=my-domain,dc=com

# Posix группа для отображения на Linux
dn: cn=users,ou=Groups,dc=my-domain,dc=com
objectClass: posixGroup
cn: users
gidNumber: 20000
memberUid: Monitoring

# Пользователь Linux
dn: uid=petrov_vs,ou=Users,dc=my-domain,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Петров
sn: Василий
displayName: Петров Василий Сергеевич
# slappasswd пароль: password
userPassword: {SSHA}nwXoxv3hFEbtZmQctIH57vFik1mb1380
loginShell: /bin/bash
uid: petrov_vs
uidNumber: 30000
gidNumber: 20000
homeDirectory: /home/petrov_vs
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0

dn: cn=repluser,dc=my-domain,dc=com
objectClass: inetOrgPerson
cn: repluser
sn: repluser
description: Application account for LDAP replication
# password: password
userPassword: {SSHA}Cl6ONU2E26tVc4CziboiSrkh3FP76MTC
EOF

    echo "ldapadd -Y EXTERNAL -H $LDAPI_PATH -f /var/lib/openldap/init_data.ldif"
    ldapadd -Y EXTERNAL -H $LDAPI_PATH -f /var/lib/openldap/init_data.ldif

    echo "init master.ldif"
    cat > /var/lib/openldap/master.ldif << EOF
dn: cn=config
changetype: modify
replace: olcServerID
olcServerID: 101

dn: olcDatabase={1}hdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://rocky2.kryukov.local:10389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=on
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
EOF

    echo "ldapmodify -Y EXTERNAL -H $LDAPI_PATH -f /var/lib/openldap/master.ldif"
    ldapmodify -Y EXTERNAL -H $LDAPI_PATH -f /var/lib/openldap/master.ldif
}

init_slave() {
    echo "init slave"

    cat > /var/lib/openldap/slave.ldif << EOF
dn: cn=config
changetype: modify
replace: olcServerID
olcServerID: 102

dn: olcDatabase={1}hdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://rocky1.kryukov.local:10389/
  bindmethod=simple
  binddn="cn=repluser,dc=my-domain,dc=com"
  credentials=password
  searchbase="dc=my-domain,dc=com"
  scope=sub
  schemachecking=on
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
EOF

    ldapmodify -Y EXTERNAL -H $LDAPI_PATH -f /var/lib/openldap/slave.ldif
}


init(){
cat > /var/lib/openldap/data/DB_CONFIG << EOF
# one 0.25 GB cache
set_cachesize 0 268435456 1

# Data Directory
#set_data_dir db

# Transaction Log settings
set_lg_regionmax 262144
set_lg_bsize 2097152
#set_lg_dir logs

set_flags DB_LOG_AUTOREMOVE
EOF

cat > /var/lib/openldap/slapd.ldif << EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcArgsFile: /var/lib/openldap/run/slapd.args
olcPidFile: /var/lib/openldap/run/slapd.pid

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath:  /usr/lib64/openldap/
olcModuleload:  back_mdb.so
olcModuleload:  memberof.so
olcModuleload:  syncprov.so
olcModuleload:  refint.so

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

include: file:///etc/openldap/schema/core.ldif
include: file:///etc/openldap/schema/cosine.ldif
include: file:///etc/openldap/schema/inetorgperson.ldif
include: file:///etc/openldap/schema/nis.ldif

dn: olcDatabase=frontend,cn=config
objectClass: olcDatabaseConfig
objectClass: olcFrontendConfig
olcDatabase: frontend

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to *
  by dn.exact=gidNumber=55+uidNumber=55,cn=peercred,cn=external,cn=auth manage
  by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage
  by dn.exact="cn=Manager,dc=ecp,dc=local" manage
  by group.exact="cn=Administrators,dc=my-domain,dc=com" manage
  by * none

#######################################################################
# LMDB database definitions
#######################################################################
#
dn: olcDatabase=hdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcHdbConfig
olcDatabase: hdb
olcSuffix: dc=my-domain,dc=com
olcRootDN: cn=Manager,dc=my-domain,dc=com
olcRootPW: {SSHA}Cl6ONU2E26tVc4CziboiSrkh3FP76MTC
olcDbDirectory: /var/lib/openldap/data
olcDbIndex: objectClass eq
olcDbIndex: ou,cn,mail,surname,givenname,uid eq,pres,sub
olcAccess: to dn.subtree="dc=my-domain,dc=com" 
  by dn.exact="cn=repluser,dc=my-domain,dc=com" read
  by * break
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

dn: olcOverlay={0}memberof,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: {0}memberof
olcMemberOfRefint: TRUE

dn: olcOverlay={1}refint,olcDatabase={1}hdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: {1}refint
olcRefintAttribute: memberof member manager owner

dn: olcOverlay={2}syncprov,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
# Количество ожидаемых записей в базе LDAP с запасом.
olcSpSessionLog: 100

dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcRootDN: cn=config
olcMonitoring: TRUE
olcAccess: to *
  by dn=cn=Manager,dc=my-domain,dc=com read
  by dn=cn=Monitoring,dc=my-domain,dc=com read
  by group.exact="cn=Administrators,dc=my-domain,dc=com" read
  by dn.base=gidNumber=55+uidNumber=55,cn=peercred,cn=external,cn=auth read
  by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth read
  by * none
EOF

slapadd -b cn=config -l /var/lib/openldap/slapd.ldif -F /etc/openldap/slapd.d/

slapd -4 -F /etc/openldap/slapd.d -u ldap -g ldap \
      -h "ldap://0.0.0.0:10389/ $LDAPI_PATH" -d "-1" \
      > /dev/null 2>&1 &
    
while ! ldapsearch -LLL -Y EXTERNAL -H "$LDAPI_PATH" -b 'cn=Monitor' '(cn=Monitor)' dn > /dev/null 2>&1 ; do
    sleep 2
done
}

case $1 in 
  master)
    echo "Init master"
    init_master
    ;;
  slave)
    echo "Init slave"
    init_slave
    ;;
   init)
    echo "Init"
    init
    ;;
   *)
    echo "Usage: init.sh init|master|slave"
    ;;
esac