#!/usr/bin/env bash

export DOCKER=YES
CRON_SCHEDULE=${CRON_SCHEDULE:-0}

if [[ ${CRON_SCHEDULE} != '0' ]]; then
    echo "${CRON_SCHEDULE} /bin/bash /mysql_backup.sh" > /crontab
    crontab /crontab
    exec crond -f
fi

exec /bin/bash /mysql_backup.sh
