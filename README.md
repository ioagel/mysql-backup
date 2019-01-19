# HOWTO

Backup mysql and mariadb containers and standalone databases

## TAGS

- latest, 8
- 5, 5.7
- alpine, 5-alpine, 5.7-alpine

**NOTICE**: alpine and 5 images do not support mysql 8

## Environment Variables

- **MYSQL_PASSWD[_FILE]**   ---   REQUIRED
- **BACKUP_ROOTDIR**        ---   default=/backup
- **MYSQL_HOST**            ---   default=localhost
- **MYSQL_PORT**            ---   default=3306
- **MYSQL_PROTO**           ---   default=TCP options=TCP, SOCKET
- **MYSQL_USER**            ---   default=root
- **MYSQL_SINGLE_TX**       ---   default=TRUE options=TRUE, FALSE
- **DATABASES**             ---   default=all eg. 'db1 db2 db3' multiple seaparated by spaces
- **DB_CHARACTER_SET**      ---   default=utf8
- **COMPRESS**              ---   default=YES options=YES, NO
- **CMD_COMPRESS**          ---   default='bzip2 -9' options=bzip2, gzip
- **DELETE_PLAIN_SQL_FILE** ---   default=YES options=YES, NO
- **RUN_FREQ**              ---   default=ONCE options=ONCE, NONSTOP
- **SLEEP**                 ---   default=3600 -> 1 hour , time in seconds

Supports Docker Secrets with *MYSQL_PASSWD_FILE* environment variable!

**IMPORTANT**: Be mindful of clear text passwords

## Examples

    # run once and exit
    $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod floulab/mysql-backup

    # run as a daemon and backup every 1 hour
    $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e RUN_FREQ=NONSTOP -v db_backups:/backup floulab/mysql-backup

    # backup remote docker container or standalone mysql server and exit
    $ docker run --rm -e MYSQL_HOST=mysql.example.org -e MYSQL_PASSWD=password -v db_backups:/backup floulab/mysql-backup

Supports docker swarm services, where you dont need the *--link* option and you can use docker secrets.
