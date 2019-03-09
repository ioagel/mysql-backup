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
    echo "${CRON_SCHEDULE} /bin/bash /mysql_backup.sh" > /crontab
    crontab /crontab
    exec crond -f
fi

exec /bin/bash /mysql_backup.sh
