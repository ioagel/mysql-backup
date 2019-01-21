# HOWTO

Backup mysql/mariadb databases with optional on the fly *encryption*.

## TAGS

- latest, 8
- 5, 5.7
- alpine

**NOTICE**: tags 5, 5.7, alpine do not support mysql 8 and tags latest, 8 do not support mysql 5 and mariadb.

## Environment Variables

- **MYSQL_HOST**            ---   REQUIRED
- **MYSQL_PASSWD[_FILE]**   ---   REQUIRED
- **MYSQL_PORT**            ---   default=3306
- **MYSQL_PROTO**           ---   default=TCP [options=TCP, SOCKET]
- **MYSQL_USER**            ---   default=root
- **MYSQL_SINGLE_TX**       ---   default=TRUE [options=TRUE, FALSE]
- **DATABASES**             ---   default=all [eg. 'db1 db2 db3' multiple databases separated by spaces]
- **DB_CHARACTER_SET**      ---   default=utf8
- **COMPRESS**              ---   default=YES [options=YES, NO]
- **CMD_COMPRESS**          ---   default='bzip2 -9' [options=bzip2, gzip, xz]
- **DELETE_PLAIN_SQL_FILE** ---   default=YES [options=YES, NO]
- **RUN_FREQ**              ---   default=ONCE [options=ONCE, NONSTOP]
- **SLEEP**                 ---   default=3600 [time in seconds]
- **ENC**                   ---   default=NO [options=YES, NO]
- **CERT_LOC**              ---   default=/run/secrets/mysql_backup_enc_cert

Supports Docker Secrets with *MYSQL_PASSWD_FILE* environment variable!

**IMPORTANT**: Be mindful of clear text passwords

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
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod floulab/mysql-backup

    # run as a daemon and backup every 1 hour(default)
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e RUN_FREQ=NONSTOP -v db_backups:/backup floulab/mysql-backup
    # or backup every 3h
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e RUN_FREQ=NONSTOP -e SLEEP=3h -v db_backups:/backup floulab/mysql-backup

    # Encryption
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e ENC=YES -v $PWD/cert.pem:/run/secrets/mysql_backup_enc_cert -v db_backups:/backup floulab/mysql-backup

    # backup remote docker container or standalone mysql server
    $ docker run --rm -e MYSQL_HOST=mysql.example.org -e MYSQL_PASSWD=password -v db_backups:/backup floulab/mysql-backup

Supports docker swarm services, where you dont need the *--link* option and you can use docker secrets.
