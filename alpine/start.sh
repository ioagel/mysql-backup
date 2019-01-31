#!/usr/bin/env bash

export DOCKER=YES
CRON_SCHEDULE=${CRON_SCHEDULE:-0}

if [[ ${CRON_SCHEDULE} != '0' ]]; then
    if [[ ! -z ${MAILTO} ]]; then
        touch /var/log/msmtp.log
        cat <<EOF >/etc/msmtprc
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account  mysql-dump
host     ${SMTP_HOST}
port     ${SMTP_PORT}
from     ${MAILFROM}
user     ${SMTP_USER}
password ${SMTP_PASSWD}

account default : mysql-dump
EOF
    fi
    echo "${CRON_SCHEDULE} /bin/bash /mysql_backup.sh" > /crontab
    crontab /crontab
    exec crond -f
fi

exec /bin/bash /mysql_backup.sh
