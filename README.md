# HOWTO

Backup mysql/mariadb databases with optional on the fly *encryption*.

## TAGS

- latest, 8
- 5, 5.7
- alpine

**NOTICE**: tags 5, 5.7, alpine do not support mysql 8 and tags latest, 8 do not support mysql 5 and mariadb.

## Environment Variables

Override them according to your requirements.

<pre>
    <b>MYSQL_HOST</b>             # REQUIRED
    <b>MYSQL_PASSWD[_FILE]</b>    # REQUIRED
    <b>MYSQL_PORT</b>             # default = 3306
    <b>MYSQL_PROTO</b>            # default = TCP [options=TCP, SOCKET]
    <b>MYSQL_USER</b>             # default = root
    <b>MYSQL_OPTIONS</b>          # default = '--single-transaction' (override it and provide any option you need)
    <b>DATABASES</b>              # default = all [or 'db1 db2 db3' multiple databases separated by SPACES]
    <b>COMPRESS</b>               # default = YES [options=YES, NO]
    <b>CMD_COMPRESS</b>           # default = 'bzip2 -9' [options=bzip2, gzip, xz]
    <b>DELETE_PLAIN_SQL_FILE</b>  # default = YES [options=YES, NO]
    <b>BACKUP_INTERVAL</b>        # default = 0 [run once and exit]*
    <b>ENC</b>                    # default = NO [options=YES, NO]
    <b>CERT_LOC</b>               # default = /run/secrets/mysql_backup_cert
</pre>

\* *BACKUP_INTERVAL* takes NUMBER for time in seconds and for *Linux ONLY* supports NUMBER[s|m|h|d] for seconds, minutes, hours and days respecitvely.

## Required Commands

- *mysqldump*
- *mysql*
- *bzip2* or *gzip* or *xz* if COMPRESS=YES and/or ENC=YES
- *openssl* if ENC=YES

## Encryption

Encrypt your backups on the fly using openssl.

You need a self-signed certificate to encrypt the backup and your private key to decrypt it.

You can find a tutorial in this [gist](https://gist.github.com/ioagel/2432fabb8b128f0ea16cb0408310d050).

## Examples

    # run once and exit - mysql-prod is the container running the db we want to backup
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod ioagel/mysql-backup

    # run as a daemon and backup every 1 hour
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e BACKUP_INTERVAL=3600 -v db_backups:/backup ioagel/mysql-backup
    # or backup every 3h (10800 seconds)
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e BACKUP_INTERVAL=10800 -v db_backups:/backup ioagel/mysql-backup
    # or backup every 3h (only supported in LINUX)
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e BACKUP_INTERVAL=3h -v db_backups:/backup ioagel/mysql-backup

    # Encryption
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e ENC=YES -v $PWD/cert.pem:/run/secrets/mysql_backup_cert -v db_backups:/backup ioagel/mysql-backup

    # backup remote docker container or standalone mysql server
    $ docker run --rm -e MYSQL_HOST=mysql.example.org -e MYSQL_PASSWD=password -v db_backups:/backup ioagel/mysql-backup
