#!/usr/bin/env bash

export DOCKER=YES
CRON_SCHEDULE=${CRON_SCHEDULE:-0}

if [[ ${CRON_SCHEDULE} != '0' ]]; then
    touch /backup.log
    tail -F /backup.log &
    echo "${CRON_SCHEDULE} BACKUP_ROOTDIR=${BACKUP_ROOTDIR} MYSQL_PORT=${MYSQL_PORT} MYSQL_PROTO=${MYSQL_PROTO} MYSQL_USER=${MYSQL_USER} CMD_COMPRESS='${CMD_COMPRESS}' MYSQL_HOST=${MYSQL_HOST} MYSQL_PASSWD=${MYSQL_PASSWD} MYSQL_OPTIONS='${MYSQL_OPTIONS}' DATABASES='${DATABASES}' COMPRESS=${COMPRESS} ENC=${ENC} CERT_LOC=${CERT_LOC} CRON_SCHEDULE='${CRON_SCHEDULE}' MYSQL_PASSWD_FILE=${MYSQL_PASSWD_FILE} DOCKER=${DOCKER} CIPHER=${CIPHER} /bin/bash /mysql_backup.sh >> /backup.log 2>&1" > /crontab
    crontab /crontab
    exec cron -f -L 8
fi

exec /bin/bash /mysql_backup.sh
