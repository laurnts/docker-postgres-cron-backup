#!/bin/bash
tail -F /postgres_backup.log &

if [ "${INIT_BACKUP}" -gt "0" ]; then
  echo "=> Create a backup on the startup"
  /backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
  echo "=> Restore latest backup"
  until nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"
  do
      echo "waiting database container..."
      sleep 1
  done
  find /backup -maxdepth 1 -name '*.sql.gz' | tail -1 | xargs /restore.sh
fi

echo "${CRON_TIME} /backup.sh >> /postgres_backup.log 2>&1" > /tmp/crontab.conf
crontab /tmp/crontab.conf
echo "=> Running cron task manager in foreground"
exec crond -f -l 8 -L /postgres_backup.log
