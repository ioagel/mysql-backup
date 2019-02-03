#!/usr/bin/env bash

export DOCKER=YES
CRON_SCHEDULE=${CRON_SCHEDULE:-0}

# thanks to mysql official image for the following func
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

file_env 'MYSQL_PASSWD'

if [[ ! -z ${MAILTO} ]]; then
    file_env 'SMTP_PASSWD'
    MSMTPRC=${MSMTPRC:-/etc/msmtprc}
    MSMTP_ACCOUNT_NAME=${MSMTP_ACCOUNT_NAME:-sql-dump}
    if [[ -z "${SMTP_HOST}" || -z "${SMTP_PORT}" || -z "${MAILFROM}" || -z "${SMTP_USER}" || -z "${SMTP_PASSWD}" ]]; then
        echo "[ERROR] Mail cannot be sent, ENV variables are missing!"
        exit 255
    fi
    touch /var/log/msmtp.log
    cat <<EOF >"${MSMTPRC}"
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account  ${MSMTP_ACCOUNT_NAME}
host     ${SMTP_HOST}
port     ${SMTP_PORT}
from     ${MAILFROM}
user     ${SMTP_USER}
password ${SMTP_PASSWD}
EOF
fi

if [[ ${CRON_SCHEDULE} != '0' ]]; then
    touch /backup.log
    tail -F /backup.log &
    echo "${CRON_SCHEDULE} BACKUP_ROOTDIR=${BACKUP_ROOTDIR} MYSQL_PORT=${MYSQL_PORT} MYSQL_PROTO=${MYSQL_PROTO} MYSQL_USER=${MYSQL_USER} CMD_COMPRESS='${CMD_COMPRESS}' MYSQL_HOST=${MYSQL_HOST} MYSQL_PASSWD=${MYSQL_PASSWD} MYSQL_OPTIONS='${MYSQL_OPTIONS}' DATABASES='${DATABASES}' COMPRESS=${COMPRESS} ENC=${ENC} CERT_LOC=${CERT_LOC} CRON_SCHEDULE='${CRON_SCHEDULE}' DOCKER=${DOCKER} SWARM_SERVICE=${SWARM_SERVICE} CIPHER=${CIPHER} MAILTO=${MAILTO} MSMTPRC=${MSMTPRC} MSMTP_ACCOUNT_NAME=${MSMTP_ACCOUNT_NAME} /bin/bash /mysql_backup.sh >> /backup.log 2>&1" > /crontab
    crontab /crontab
    exec cron -f -L 8
fi

exec /bin/bash /mysql_backup.sh
