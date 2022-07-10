#!/bin/bash

[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
# If provided, take password from file
[ -z "${POSTGRES_PASS_FILE}" ] || { POSTGRES_PASS=$(head -1 "${POSTGRES_PASS_FILE}"); }
# Alternatively, take it from env var
[ -z "${POSTGRES_PASS}" ] && { echo "=> POSTGRES_PASS cannot be empty" && exit 1; }

if [ "$#" -ne 1 ]
then
    echo "You must pass the path of the backup file to restore"
fi

set -o pipefail

if [ -z "${USE_PLAIN_SQL}" ]
then 
    SQL=$(gunzip -c "$1")
else
    SQL=$(cat "$1")
fi

DB_NAME=${POSTGRES_DATABASE:-${POSTGRES_DB}}
if [ -z "${DB_NAME}" ]
then
    echo "=> Searching database name in $1"
    DB_NAME=$(echo "$SQL" | grep -oE '(Database: (.+))' | cut -d ' ' -f 2)
fi
[ -z "${DB_NAME}" ] && { echo "=> Database name not found" && exit 1; }

echo "=> Restore database $DB_NAME from $1"

export PGHOST=${POSTGRES_HOST}
export PGPORT=${POSTGRES_PORT}
export PGUSER=${POSTGRES_USER}
export PGPASSWORD=${POSTGRES_PASS}

if echo ${SQL} | psql ${POSTGRES_SSL_OPTS} ${DB_NAME}
then
    echo "=> Restore succeeded"
else
    echo "=> Restore failed"
fi
