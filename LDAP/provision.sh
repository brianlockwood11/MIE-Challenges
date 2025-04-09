#!/usr/bin/env bash

dnf install -y epel-release 

dnf update -y

dnf install -y openldap-servers openldap-clients #postgresql-server postgresql-contrib

systemctl enable slapd
systemctl start slapd
#postgresql-setup --initdb
#systemctl enable postgresql
#systemctl start postgresql

PASSWORD="Secret1"
LDAP_ADMIN_HASH=$(slappasswd -s "$PASSWORD") 

#sudo -u postgres psql <<EOF
#CREATE DATABASE ldapdb;
#CREATE USER ldapuser WITH PASSWORD '$PASSWORD';
#GRANT ALL PRIVILEGES ON DATABASE ldapdb TO ldapuser;
#EOF
#
#echo "host    ldapdb    ldapuser    127.0.0.1/32    md5" >> /var/lib/pgsql/data/pg_hba.conf
#echo "host    ldapdb    ldapuser    ::1/128         md5" >> /var/lib/pgsql/data/pg_hba.conf
#systemctl restart postgresql
#
#cd /tmp
#sudo -u postgres psql ldapdb <<EOF
#CREATE TABLE ldap_entries (
#    id SERIAL PRIMARY KEY,
#    dn VARCHAR(255) NOT NULL,
#    parent INT,
#    oc_map_id INT,
#    keyval INT
#);
#
#CREATE TABLE ldap_oc_mappings (
#    id SERIAL PRIMARY KEY,
#    name VARCHAR(255) NOT NULL
#);
#
#CREATE TABLE ldap_attr_mappings (
#    id SERIAL PRIMARY KEY,
#    oc_map_id INT NOT NULL,
#    name VARCHAR(255) NOT NULL,
#    sel_expr TEXT,
#    from_tbls TEXT,
#);
#
#CREATE TABLE ldap_entry_objclasses (
#    entry_id INT NOT NULL,
#    oc_name VARCHAR(255) NOT NULL
#);
#EOF
#



mkdir /ldap
mkdir -p /var/lib/ldap
mkdir -p /etc/openldap/slapd.d
chown -R ldap:ldap /var/lib/ldap
chown -R ldap:ldap /etc/openldap/slapd.d

#cat <<EOF > /ldap/sql-backend.ldif
#dn: cn=module{0},cn=config
#changetype: modify
#add: olcModuleLoad
#olcModuleLoad: back_sql
#
#dn: olcDatabase=sql,cn=config
#objectClass: olcDatabaseConfig
#objectClass: olcSqlConfig
#olcDatabase: sql
#olcDbSqlUser: ldapuser
#olcDbSqlPasswd: ldap_password
#olcDbSqlDbname: ldapdb
#olcDbSqlHost: 127.0.0.1
#olcDbSqlPort: 5432
#olcSuffix: dc=mie,dc=com
#olcRootDN: cn=Manager,dc=mie,dc=com
#olcRootPW: $LDAP_ADMIN_HASH
#EOF

cat <<EOF > /ldap/DB_CONFIG 
# Set database flags
set_flags DB_LOG_AUTOREMOVE

# Set the size of the database cache
set_cachesize 0 10485760 0

# Set the size of the database log files
set_lg_regionmax 262144
set_lg_bsize 2097152

# Set the maximum number of locks
set_lk_max_locks 1000
set_lk_max_objects 1000
set_lk_max_lockers 1000
EOF
cat <<EOF > /ldap/ldaproot.ldif 
dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=mie,dc=com

dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,dc=mie,dc=com

dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $LDAP_ADMIN_HASH
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f /ldap/ldaproot.ldif
#ldapadd -Y EXTERNAL -H ldapi:/// -f /ldap/sql-backend.ldif

ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/nis.ldif

cat <<EOF > /ldap/base.ldif
dn: dc=mie,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: Medical Informatics Engineering
dc: mie

dn: ou=People,dc=mie,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=mie,dc=com
objectClass: organizationalUnit
ou: Groups

dn: cn=users,ou=Groups,dc=mie,dc=com
objectClass: top
objectClass: posixGroup
cn: users
gidNumber: 1001
memberUid: mie1
memberUid: mie2
memberUid: mie3
EOF

ldapadd -x -D "cn=Manager,dc=mie,dc=com" -w "$PASSWORD" -f /ldap/base.ldif


cat <<EOF > /ldap/users.ldif
dn: uid=mie1,ou=People,dc=mie,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: MIE1
sn: MIE1
uid: mie1
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/mie1
loginShell: /bin/bash
userPassword: $LDAP_ADMIN_HASH

dn: uid=mie2,ou=People,dc=mie,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: MIE2
sn: MIE2
uid: mie2
uidNumber: 1002
gidNumber: 1001
homeDirectory: /home/mie2
loginShell: /bin/bash
userPassword: $LDAP_ADMIN_HASH

dn: uid=mie3,ou=People,dc=mie,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: MIE3
sn: MIE3
uid: mie3
uidNumber: 1003
gidNumber: 1001
homeDirectory: /home/mie3
loginShell: /bin/bash
userPassword: $LDAP_ADMIN_HASH
EOF

ldapadd -x -D "cn=Manager,dc=mie,dc=com" -w "$PASSWORD" -f /ldap/users.ldif
