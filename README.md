# HOWTO

Backup mysql/mariadb databases with optional on the fly *encryption*.

## TAGS

- latest, 8
- 5, 5.7
- alpine

**NOTICE**: tags 5, 5.7, alpine do not support mysql 8 and tags latest, 8 do not support mysql 5 and mariadb.

## Environment Variables

Override them according to your requirements.

```
    BACKUP_ROOTDIR         # default = /backup
    MYSQL_HOST             # REQUIRED
    MYSQL_PASSWD[_FILE]    # REQUIRED
    MYSQL_PORT             # default = 3306
    MYSQL_PROTO            # default = TCP [options=TCP, SOCKET]
    MYSQL_USER             # default = root
    MYSQL_OPTIONS          # default = '--single-transaction' (override it and provide any option you need)
    DATABASES              # default = all [or 'db1 db2 db3' multiple databases separated by SPACES]
    COMPRESS               # default = YES [options=YES, NO]
    CMD_COMPRESS           # default = 'bzip2 -9' [options=bzip2, gzip, xz]

    SLEEP_SCHEDULE         # default = 0 [run once and exit] if you want to use SLEEP
          or
    CRON_SCHEDULE          # default = 0 [run once and exit]* if you want to use CRON

    ENC                    # default = NO [options=YES, NO]
    CERT_LOC               # default = /run/secrets/mysql_backup_cert
```

\* For *CRON_SCHEDULE* use proper cron format like: '0 0 * * *' every day at 12:00am

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

```
    # run once and exit - mysql-prod is the container running the db we want to backup
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod ioagel/mysql-backup

    # Use SLEEP
    # run as a daemon and backup every 1 hour
    # $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e SLEEP_SCHEDULE=3600 -v db_backups:/backup ioagel/mysql-backup
    # or backup every 3h (10800 seconds)
    # $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e SLEEP_SCHEDULE=10800 -v db_backups:/backup ioagel/mysql-backup
    # or backup every 3h (only supported in LINUX)
    # $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e SLEEP_SCHEDULE=3h -v db_backups:/backup ioagel/mysql-backup
    #
    # OR
    #
    # Use CRON
    # run as a daemon and backup every 1 hour
    # $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e CRON_SCHEDULE='0 * * * *' -v db_backups:/backup ioagel/mysql-backup
    # or backup once every day at 12:00am
    # $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e CRON_SCHEDULE='0 0 * * *' -v db_backups:/backup ioagel/mysql-backup

    # Encryption
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e ENC=YES -v $PWD/cert.pem:/run/secrets/mysql_backup_cert -v db_backups:/backup ioagel/mysql-backup

    # backup remote docker container or standalone mysql server
    $ docker run --rm -e MYSQL_HOST=mysql.example.org -e MYSQL_PASSWD=password -v db_backups:/backup ioagel/mysql-backup
```
