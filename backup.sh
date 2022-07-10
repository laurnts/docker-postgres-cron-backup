#!/bin/bash

[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
# If provided, take password from file
[ -z "${POSTGRES_PASS_FILE}" ] || { POSTGRES_PASS=$(head -1 "${POSTGRES_PASS_FILE}"); }
# Alternatively, take it from env var
[ -z "${POSTGRES_PASS:=$POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASS cannot be empty" && exit 1; }
[ -z "${GZIP_LEVEL}" ] && { GZIP_LEVEL=6; }

DATE=$(date +%Y%m%d%H%M)
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"

export PGHOST=${POSTGRES_HOST}
export PGPORT=${POSTGRES_PORT}
export PGUSER=${POSTGRES_USER}
export PGPASSWORD=${POSTGRES_PASS}

DATABASES=${POSTGRES_DATABASE:-${POSTGRES_DB:-$(psql $POSTGRES_SSL_OPTS -t -c "SELECT datname FROM pg_database;")}}

for db in ${DATABASES}
do
  if  [[ "$db" != "template1" ]] \
      && [[ "$db" != "template0" ]]
  then
    echo "==> Dumping database: $db"
    FILENAME=/backup/$DATE.$db.sql
    LATEST=/backup/latest.$db.sql
    if pg_dump $POSTGRESDUMP_OPTS $POSTGRES_SSL_OPTS "$db" > "$FILENAME"
    then
      EXT=
      if [ -z "${USE_PLAIN_SQL}" ]
      then
        echo "==> Compressing $db with LEVEL $GZIP_LEVEL"
        gzip "-$GZIP_LEVEL" -f "$FILENAME"
        EXT=.gz
        FILENAME=$FILENAME$EXT
        LATEST=$LATEST$EXT
      fi
      BASENAME=$(basename "$FILENAME")
      echo "==> Creating symlink to latest backup: $BASENAME"
      rm "$LATEST" 2> /dev/null
      cd /backup || exit && ln -s "$BASENAME" "$(basename "$LATEST")"
      if [ -n "$MAX_BACKUPS" ]
      then
        while [ "$(find /backup -maxdepth 1 -name "*.$db.sql$EXT" -type f | wc -l)" -gt "$MAX_BACKUPS" ]
        do
          TARGET=$(find /backup -maxdepth 1 -name "*.$db.sql$EXT" -type f | sort | head -n 1)
          echo "==> Max number of ($MAX_BACKUPS) backups reached. Deleting ${TARGET} ..."
          rm -rf "${TARGET}"
          echo "==> Backup ${TARGET} deleted"
        done
      fi
    else
      rm -rf "$FILENAME"
    fi
  fi
done
echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
