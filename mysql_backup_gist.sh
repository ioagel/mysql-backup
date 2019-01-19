#!/usr/bin/env bash

# Original Author:   Zhang Huangbin (zhb@iredmail.org)
# Date:              16/09/2007
# Purpose:           Backup specified mysql databases with command 'mysqldump'.
# License:           This shell script is part of iRedMail project, released under
#                    GPL v2.
#
# Modified By:       Ioannis Angelakopoulos <ioagel@gmail.com>
# Date:              18/01/2019

###########################
# REQUIREMENTS
###########################
#
#   * Required commands:
#       + mysqldump
#       + mysql
#       + bzip2 or gzip     # If bzip2 is not available, change 'CMD_COMPRESS'
#                           # to use 'gzip'.
#

###########################
# USAGE
###########################
#   * Set correct values for below variables:
#
#       MYSQL_PASSWD[_FILE]    REQUIRED
#       BACKUP_ROOTDIR         default=/backup
#       MYSQL_HOST             default=localhost
#       MYSQL_PORT             default=3306
#       MYSQL_PROTO            default=TCP
#       MYSQL_USER             default=root
#       MYSQL_SINGLE_TX        default=TRUE
#       DATABASES              default=all
#       DB_CHARACTER_SET       default=utf8
#       COMPRESS               default=YES
#       CMD_COMPRESS           default=bzip2 -9
#       DELETE_PLAIN_SQL_FILE  default=YES
#       RUN_FREQ               default=ONCE
#       SLEEP                  default=3600 -> 1 hour
#
#
# Backup script suitable to run as a command in a mysql docker container
# to backup databases running in production mysql containers or services.
# It is optimized for docker thats why ENV vars are preferred
# instead of commandline args.
#
# Create a dockerfile with a mysql base image and copy this script and use it as the COMMAND, then build and run:
# Better use: floulab/mysql-backup from dockerhub.
#
# run once and exit
# $ docker run --rm --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod floulab/mysql-backup
#
# run as a daemon and backup every 1 hour
# $ docker run -d --link mysql-prod -e MYSQL_PASSWD=password -e MYSQL_HOST=mysql-prod -e RUN_FREQ=NONSTOP -v db_backups:/backup floulab/mysql-backup
#
# SUPPORTS Docker Secrets with MYSQL_PASSWD_FILE environment variable!
#
# run as a standalone script
# $ MYSQL_PASSWD=password MYSQL_HOST=mysql.example.org bash mysql_backup.sh
#
#########################################################
# Modify below variables to fit your need ----
#########################################################
# Where to store backup copies.
BACKUP_ROOTDIR=${BACKUP_ROOTDIR:-/backup} # for docker, mount a volume here

MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_PROTO=${MYSQL_PROTO:-TCP} # either TCP or SOCKET
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_SINGLE_TX=${MYSQL_SINGLE_TX:-TRUE} # either TRUE or FALSE, --single-transaction option

# Databases we should backup.
# Multiple databases MUST be seperated by SPACE.
# Your iRedMail server might have below databases:
# mysql, roundcubemail, policyd (or postfixpolicyd), amavisd, iredadmin
DATABASES=${DATABASES:---all-databases}

# Database character set for ALL databases.
# Note: Currently, it doesn't support to specify character set for each databases.
DB_CHARACTER_SET=${DB_CHARACTER_SET:-utf8}

# Compress plain SQL file: YES, NO.
COMPRESS=${COMPRESS:-YES}

# Compression program: bzip2, gzip
CMD_COMPRESS=${CMD_COMPRESS:-bzip2 -9}

# Delete plain SQL files after compressed. Compressed copy will be remained.
DELETE_PLAIN_SQL_FILE=${DELETE_PLAIN_SQL_FILE:-YES}

# Run once or infinite loop: ONCE, NONSTOP
RUN_FREQ=${RUN_FREQ:-ONCE}

# if NONSTOP use sleep for infinite loop: time in seconds
SLEEP=${SLEEP:-3600}

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
# handle docker stop signal properly
cleanup() {
    echo "Shuting down ..."
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

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

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
CMD_DATE='/bin/date'
CMD_DU='du -sh'
CMD_MYSQLDUMP='mysqldump'
CMD_MYSQL='mysql'

# Verify compress program is either bzip2 or gzip
if [[ ! "$CMD_COMPRESS" =~ ^bzip2.*|^gzip.* ]]; then
    echo "[ERROR] Compression ENV CMD_COMPRESS can either be 'bzip2' or 'gzip'." 1>&2
    exit 255
fi

# Verify MYSQL_HOST is set
if [ -z "$MYSQL_HOST" ]; then
    echo "[ERROR] MySQL Host ENV variable MYSQL_HOST is required." 1>&2

    exit 255
fi

file_env 'MYSQL_PASSWD'
# Verify MYSQL_HOST is set
if [ -z "$MYSQL_PASSWD" ]; then
    echo "[ERROR] MySQL Password ENV variable MYSQL_PASSWD is required." 1>&2

    exit 255
fi

# Verify MySQL connection.
${CMD_MYSQL} -u "$MYSQL_USER" --password="$MYSQL_PASSWD" --host="$MYSQL_HOST" --port="$MYSQL_PORT" --protocol="$MYSQL_PROTO" -e "show databases" &>/dev/null
if [ X"$?" != X"0" ]; then
    echo "[ERROR] MySQL username or password or host or protocol is incorrect in file ${0}." 1>&2
    echo "Please fix them first." 1>&2

    exit 255
fi

backup_db()
{
    # USAGE:
    #  # backup dbname
    db="${1}"

    if [ "$db" = "--all-databases" ]; then
        output_sql="${BACKUP_DIR}/all-${TIMESTAMP}.sql"
    else
        output_sql="${BACKUP_DIR}/${db}-${TIMESTAMP}.sql"
        # Check whether database exists or not
        ${CMD_MYSQL} -u "$MYSQL_USER" --password="$MYSQL_PASSWD" --host="$MYSQL_HOST" --port="$MYSQL_PORT" --protocol="$MYSQL_PROTO" -e "use ${db}" &>/dev/null
    fi

    if [ X"$?" == X'0' ]; then
        # Dump
        ${CMD_MYSQLDUMP} \
            -u "$MYSQL_USER" --password="$MYSQL_PASSWD" --host="$MYSQL_HOST" --port="$MYSQL_PORT" --protocol="$MYSQL_PROTO" \
            --default-character-set="$DB_CHARACTER_SET" \
            --triggers \
            --routines \
            --events \
            --single-transaction="$MYSQL_SINGLE_TX" \
            "$db" > "$output_sql" 2>/dev/null

        # Compress
        if [ X"${COMPRESS}" == X"YES" ]; then
            ${CMD_COMPRESS} "${output_sql}" >> "${LOGFILE}"

            if [ X"$?" == X'0' ] && [ X"${DELETE_PLAIN_SQL_FILE}" == X'YES' ]; then
                rm -f "${output_sql}" >> "${LOGFILE}"
            fi
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

    # Pre-defined backup status
    BACKUP_SUCCESS='YES'

    # Define, check, create directories.
    BACKUP_DIR="${BACKUP_ROOTDIR}/${MYSQL_HOST}/${YEAR}/${MONTH}/${DAY}"

    # Log file
    LOGFILE="${BACKUP_DIR}/${TIMESTAMP}.log"

    # Check and create directories.
    [ ! -d "${BACKUP_DIR}" ] && mkdir -p "${BACKUP_DIR}" 2>/dev/null

    # Initialize log file.
    echo "=============================================================================" > "${LOGFILE}"
    { echo "* Starting backup: ${TIMESTAMP}."; echo "* Backup directory: ${BACKUP_DIR}."; } >> "${LOGFILE}"


    # Backup.
    echo "* Backing up databases ..." >> "${LOGFILE}"
    sed -n 1,4p "${LOGFILE}"
    for db in ${DATABASES}; do
        backup_db "${db}" >> "${LOGFILE}"

        if [ X"$?" == X"0" ]; then
            if [ "$db" = "--all-databases" ]; then
                echo "  - ALL [DONE]" >> "${LOGFILE}"
            else
                echo "  - ${db} [DONE]" >> "${LOGFILE}"
            fi
        else
            [ X"${BACKUP_SUCCESS}" == X"YES" ] && BACKUP_SUCCESS='NO'
        fi
    done

    # Append file size of backup files.
    { echo -e "* File size:\n----"; ${CMD_DU} "${BACKUP_DIR}"/*"${TIMESTAMP}"*sql*; echo "----"; } >> "${LOGFILE}"

    echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >> "${LOGFILE}"

    # if [ X"${BACKUP_SUCCESS}" == X"YES" ]; then
    #     echo "==> Backup completed successfully."
    # else
    #     echo -e "==> Backup completed with !!!ERRORS!!!.\n" 1>&2
    # fi

    sed -n '5,$p' "$LOGFILE"
}

if [ "$RUN_FREQ" = "NONSTOP" ]; then
    while true; do
        execute_backup

        sleep "$SLEEP" &
        wait $!
    done
elif [ "$RUN_FREQ" = "ONCE" ]; then
    execute_backup
else
    echo "[ERROR] RUN_FREQ ENV can either be 'ONCE' or 'NONSTOP'." 1>&2

    exit 255
fi

exit 0
