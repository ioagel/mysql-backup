#!/usr/bin/env bash

# Author:   Ioannis Angelakopoulos <ioagel@gmail.com>
# Date:     18/01/2019

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + mysqldump
#       + mysql
#       + bzip2 or gzip or xz  # for compression
#       + openssl # for encryption
#       + msmtp # for mail functionality
#

###########################
# USAGE
###########################
#   * Set correct values for below variables:
#
#       MYSQL_HOST             REQUIRED
#       MYSQL_PASSWD           REQUIRED
#       BACKUP_ROOTDIR         default = /backup (if using the script in a docker container do not change this)
#       MYSQL_PORT             default = 3306
#       MYSQL_PROTO            default = TCP
#       MYSQL_USER             default = root
#       MYSQL_OPTIONS          default = --single-transaction
#       DATABASES              default = all (or 'db1 db2 db3' multiple databases separated by SPACES)
#       COMPRESS               default = YES
#       CMD_COMPRESS           default = bzip2 -9
#
#       SLEEP_SCHEDULE         default = 0 (run once and exit) if you want to use SLEEP, supports docker and as standalone script
#           OR
#       CRON_SCHEDULE          default = 0 (run once and exit) if you want to use CRON in DOCKER image: ioagel/mysql-backup:[alpine|5|8]
#
#       ENC                    default = NO
#       CERT_LOC               default = /run/secrets/mysql_backup_cert
#
#       MAILTO                 REQUIRED for the mail functionality
#       MSMTPRC                default = /etc/msmtprc # where msmtp gets the mail settings
#       MSMTP_ACCOUNT_NAME     default = sql-dump # account identity in msmtprc
#
# Backup script suitable to run as a command in a mysql docker container
# to backup databases running in mysql/mariadb servers, containerized or not.
# It is optimized for docker that's why ENV vars are preferred
# instead of commandline args.
# SUPPORTS Encryption of backups: just use ENV=YES and mount the certificate to default or other dir inside the container
#
# To use it check:
#     - DockerHub https://cloud.docker.com/repository/docker/ioagel/mysql-backup
#     - Github https://github.com/ioagel/mysql-backup
#     - Gist for encryption HOWTO: https://gist.github.com/ioagel/2432fabb8b128f0ea16cb0408310d050

# EXAMPLES:
#
# run once and exit - mysql-prod is the container running the db we want to backup
# $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod ioagel/mysql-backup
#
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
# Use CRON (only with docker image: ioagel/mysql-backup)
# run as a daemon and backup every 1 hour
# $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e CRON_SCHEDULE='0 * * * *' -v db_backups:/backup ioagel/mysql-backup
# or backup once every day at 12:00am
# $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e CRON_SCHEDULE='0 0 * * *' -v db_backups:/backup ioagel/mysql-backup
#
# Encryption
# $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e ENC=YES -v $PWD/cert.pem:/run/secrets/mysql_backup_cert -v db_backups:/backup ioagel/mysql-backup
#
# backup remote docker container or standalone mysql/mariadb server
# $ docker run --rm -e MYSQL_HOST=mysql.example.org -e MYSQL_PASSWD=password -v db_backups:/backup ioagel/mysql-backup
#
# run as a standalone script
# $ MYSQL_PASSWD=password MYSQL_HOST=mysql.example.org bash mysql_backup.sh

#########################################################
# Modify below variables to fit your need ----
#########################################################
[[ -f "/mysql-backup-env" ]] && source /mysql-backup-env

# Where to store backup copies.
BACKUP_ROOTDIR=${BACKUP_ROOTDIR:-/backup} # for docker, mount a volume here

# if you want the name of the service in the name of the BACKUP_DIR
SWARM_SERVICE=${SWARM_SERVICE}

# Required
MYSQL_HOST=${MYSQL_HOST}
MYSQL_PASSWD=${MYSQL_PASSWD}

MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_PROTO=${MYSQL_PROTO:-TCP} # either TCP or SOCKET
MYSQL_USER=${MYSQL_USER:-root}

# You can override it and provide any option you need
MYSQL_OPTIONS=${MYSQL_OPTIONS:---single-transaction}

# Databases we should backup.
# Multiple databases MUST be separated by SPACE.
# eg. 'db1 db2 db3'
DATABASES=${DATABASES:---all-databases}

# Compress plain SQL file: YES, NO.
# If Encryption is chosen then this var is not considered, the file will be compressed and encrypted!
COMPRESS=${COMPRESS:-YES}

# Compression program: bzip2, gzip, xz
CMD_COMPRESS=${CMD_COMPRESS:-bzip2 -9}

# Encryption: YES or NO
ENC=${ENC:-NO}
# x509 certificate file in pem format
# Mount in container or use secrets with swarm.
# Secrets are mounted by default under: /run/secrets dir.
CERT_LOC=${CERT_LOC:-/run/secrets/mysql_backup_cert}
# Cipher
CIPHER=${CIPHER:--aes-256-cbc}

# Takes a NUMBER for time in seconds or
# for LINUX ONLY: NUMBER[s|m|h|d] for seconds, minutes, hours and days respectively.
# Default value is 0 which means run once and exit.
SLEEP_SCHEDULE=${SLEEP_SCHEDULE:-0}
# OR
# Use Cron schedule like: '0 0 * * *' backup every day at 12am
CRON_SCHEDULE=${CRON_SCHEDULE:-0}

# MAIL Settings
MAILTO=${MAILTO}
MSMTPRC=${MSMTPRC:-/etc/msmtprc}
MSMTP_ACCOUNT_NAME=${MSMTP_ACCOUNT_NAME:-sql-dump}
####### example of msmtprc ########
#   defaults
#   auth           on
#   tls            on
#   tls_starttls   on
#   tls_trust_file /etc/ssl/certs/ca-certificates.crt
#   logfile        /var/log/msmtp.log
#
#   account  sql-dump [$MSMTP_ACCOUNT_NAME]
#   host     smtp.example.org
#   port     587
#   from     admin@example.org
#   user     admin@example.org
#   password my_secure_password


#########################################################
# You do *NOT* need to modify below lines.
#########################################################
PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
CMD_DATE='/bin/date'
CMD_DU='du -sh'
CMD_MYSQLDUMP='mysqldump'
CMD_MYSQL='mysql'
CMD_MAIL='msmtp'

# if we run inside docker
DOCKER=${DOCKER:-NO}

if [[ ${DATABASES} == 'all' ]]; then
    DATABASES='--all-databases'
fi

# declare some vars we will use later
LOGFILE=
TIMESTAMP=
BACKUP_DIR=

# handle docker stop signal properly
cleanup() {
    echo "Shutting down ..."
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

# Verify MYSQL_HOST is set
if [[ -z "$MYSQL_HOST" ]]; then
    echo "[ERROR] Environment variable MYSQL_HOST is required." 1>&2
    exit 255
fi

# Verify MYSQL_PASSWD is set
if [[ -z "$MYSQL_PASSWD" ]]; then
    echo "[ERROR] Environment variable MYSQL_PASSWD is required." 1>&2
    exit 255
fi

# Verify compress program is either bzip2 or gzip or xz
if [[ ! "$CMD_COMPRESS" =~ ^bzip2.*|^gzip.*|^xz.* ]]; then
    echo "[ERROR] Environment variable CMD_COMPRESS can either be 'bzip2', 'gzip' or 'xz' with/without options like 'bzip2 -9'." 1>&2
    exit 255
fi

# VERIFY ENC is either YES or NO
if [[ ! "$ENC" =~ ^YES$|^NO$ ]]; then
    echo "[ERROR] Environment variable ENC can be either YES or NO." 1>&2
    exit 255
fi

# Verify openssl program is available if we are encrypting
if [[ "$ENC" == "YES" ]]; then
    if [[ ! "$(openssl version 2>/dev/null)" ]]; then
        echo "[ERROR] For Encryption 'openssl' program is required." 1>&2
        exit 255
    fi
    if [[ ! -f "$CERT_LOC" ]]; then
        echo "[ERROR] For encryption you need to mount the certificate in: $CERT_LOC" 1>&2
        echo "[ERROR] or your own location using the Environment variable CERT_LOC." 1>&2
        exit 255
    fi
fi

# Use this var to filter this warning from the logs.
SUPPRESS_MYSQL_ERROR="Using a password on the command line interface can be insecure."

CON_SETTINGS="-u $MYSQL_USER --password=$MYSQL_PASSWD --host=$MYSQL_HOST --port=$MYSQL_PORT --protocol=$MYSQL_PROTO"

# Verify MySQL connection.
${CMD_MYSQL} ${CON_SETTINGS} -e "show databases" >/dev/null 2>&1
if [[ "$?" != '0' ]]; then
    echo "[ERROR] MySQL username or password or host or protocol is incorrect in file ${0}." 1>&2
    echo "Please fix them first." 1>&2
    exit 255
fi

BACKUP_SUCCESS='YES'
sleep_linux_regex='^[0-9]+[s|m|h|d]{0,1}$'
sleep_unix_regex='^[0-9]+$'

backup_db()
{
    db="${1}"

    if [[ "$db" == '--all-databases' ]]; then
        output_sql="${BACKUP_DIR}/all-${TIMESTAMP}.sql"
    else
        output_sql="${BACKUP_DIR}/${db}-${TIMESTAMP}.sql"
        # Check whether database exists or not
        ${CMD_MYSQL} ${CON_SETTINGS} -e "use ${db}" 2>&1 | grep -v "${SUPPRESS_MYSQL_ERROR}" >> ${LOGFILE}
        [[ "${PIPESTATUS[0]}" != '0' ]] && return 1
    fi

    if [[ "$ENC" == 'NO' ]]; then
        ${CMD_MYSQLDUMP} \
            ${CON_SETTINGS} \
            ${MYSQL_OPTIONS} \
            "$db" > "$output_sql" 2>&1 | grep -v "${SUPPRESS_MYSQL_ERROR}" >> ${LOGFILE}

        if [[ "${PIPESTATUS[0]}" != '0' ]]; then
            echo "[ERROR] MYSQL_OPTIONS environment variable value: '${MYSQL_OPTIONS}' is INVALID!"
            rm -f "$output_sql"
            return 1
        fi

        # Compress
        if [[ "${COMPRESS}" == 'YES' ]]; then
            ${CMD_COMPRESS} "${output_sql}" >> ${LOGFILE}
        fi
    else # we are encrypting
        if [[ "$CMD_COMPRESS" =~ ^bzip2.* ]]; then
            suffix='bz2'
        elif [[ "$CMD_COMPRESS" =~ ^gzip.* ]]; then
            suffix='gz'
        else
            suffix='xz'
        fi

        ${CMD_MYSQLDUMP} \
            ${CON_SETTINGS} \
            ${MYSQL_OPTIONS} \
            "$db" 2>&1 | grep -v "${SUPPRESS_MYSQL_ERROR}" | ${CMD_COMPRESS} | \
            openssl smime -encrypt -binary ${CIPHER} -out "$output_sql"."$suffix".enc -outform DER "$CERT_LOC" >> ${LOGFILE}

        if [[ "${PIPESTATUS[0]}" != '0' ]]; then
            echo "[ERROR] MYSQL_OPTIONS environment variable value: '${MYSQL_OPTIONS}' is INVALID!"
            rm -f "$output_sql"."$suffix".enc
            return 1
        fi
    fi
}

execute_backup() {
    # Date.
    YEAR="$(${CMD_DATE} +%Y)"
    MONTH="$(${CMD_DATE} +%m)"
    DAY="$(${CMD_DATE} +%d)"
    TIME="$(${CMD_DATE} +%H.%M.%S)"
    TIMESTAMP="${YEAR}.${MONTH}.${DAY}.${TIME}"

    # Define, check, create directories.
    if [[ -z ${SWARM_SERVICE} ]]; then
        BACKUP_DIR="${BACKUP_ROOTDIR}/${MYSQL_HOST}/${YEAR}/${MONTH}/${DAY}"
    else
        BACKUP_DIR="${BACKUP_ROOTDIR}/${SWARM_SERVICE}_${MYSQL_HOST}/${YEAR}/${MONTH}/${DAY}"
    fi

    # Log file
    LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

    # Check and create directories.
    [[ ! -d "${BACKUP_DIR}" ]] && mkdir -p "${BACKUP_DIR}" 2>/dev/null

    # Initialize log file.
    echo "==========================================================" > "${LOGFILE}"
    { echo "* Starting backup: ${TIMESTAMP}"; echo "* Backup directory: ${BACKUP_DIR}"; } >> "${LOGFILE}"


    # Backup.
    echo "* Backing up databases ..." >> "${LOGFILE}"
    sed -n 1,4p "${LOGFILE}"
    for db in ${DATABASES}; do
        backup_db "${db}" >> "${LOGFILE}"

        if [[ "$?" == '0' ]]; then
            if [[ "$db" == '--all-databases' ]]; then
                echo "  - ALL [DONE]" >> "${LOGFILE}"
            else
                echo "  - ${db} [DONE]" >> "${LOGFILE}"
            fi
        else
            BACKUP_SUCCESS='NO'
        fi
    done

    # Append file size of backup files.
    { echo -e "* File size:\n----"; ${CMD_DU} "${BACKUP_DIR}"/*"${TIMESTAMP}"*sql*; echo "----"; } >> "${LOGFILE}"

    echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >> "${LOGFILE}"
}

backup_interval_format_error() {
    echo "[ERROR] SLEEP_SCHEDULE supports 0 for running the script once and exit (the default value)" 1>&2
    echo "[ERROR] or a NUMBER for time in seconds or for LINUX ONLY: NUMBER[s|m|h|d] for seconds, minutes, hours and days respectively." 1>&2
    exit 255
}

send_mail() {
    cp ${LOGFILE} /tmp/mail_file
    MAIL_FILE=/tmp/mail_file
    sed -i '1d;$d' ${MAIL_FILE}
    sed -i "1s/^/To: ${MAILTO}\n/" ${MAIL_FILE}
    if [[ -z ${SWARM_SERVICE} ]]; then
        sed -i "2s/^/Subject: SQL Dump - HOST: ${MYSQL_HOST}\n/" ${MAIL_FILE}
    else
        sed -i "2s/^/Subject: SQL Dump - HOST: ${MYSQL_HOST} - SERVICE: ${SWARM_SERVICE}\n/" ${MAIL_FILE}
    fi
    sed -i "3s/^/*** Backup completed (Success? ${BACKUP_SUCCESS})\n/" ${MAIL_FILE}
    sed -i "4s/^/***\n/" ${MAIL_FILE}
    sed -i "5s/^/-----------DETAILED REPORT-----------\n/" ${MAIL_FILE}

    cat ${MAIL_FILE} | ${CMD_MAIL} -C ${MSMTPRC} -a ${MSMTP_ACCOUNT_NAME} "${MAILTO}"
    rm -f ${MAIL_FILE}
}

if [[ ${CRON_SCHEDULE} != '0' ]]; then
    if [[ "${DOCKER}" == 'NO' ]]; then
        echo "[ERROR] CRON scheduling can be used only with the docker image: ioagel/mysql-backup"
        exit 255
    fi
    execute_backup
    sed -n '5,$p' "$LOGFILE"
    if [[ ! -z "${MAILTO}" && -f "${MSMTPRC}" ]]; then
        send_mail
    fi
    exit 0
fi

if [[ "$SLEEP_SCHEDULE" == '0' ]]; then
    execute_backup

    if [[ "${DOCKER}" == 'YES' ]]; then
        echo "Override SLEEP_SCHEDULE environment variable if you want to run non-stop as a daemon" >> ${LOGFILE}
    fi
    sed -n '5,$p' "$LOGFILE"
elif [[ "$SLEEP_SCHEDULE" =~ $sleep_linux_regex ]]; then
    [[ $(uname -s) != 'Linux' ]] && [[ ! "$SLEEP_SCHEDULE" =~ $sleep_unix_regex ]] && backup_interval_format_error
    while true; do
        execute_backup
        sed -n '5,$p' "$LOGFILE"
        if [[ ! -z "${MAILTO}" && -f "${MSMTPRC}" ]]; then
            send_mail
        fi
        sleep "$SLEEP_SCHEDULE" &
        wait $!
    done
else
    backup_interval_format_error
fi

exit 0
