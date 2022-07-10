# postgres-cron-backup

Run pg_dump to backup your databases periodically using the cron task manager in the container. Your backups are saved in `/backup`. You can mount any directory of your host or a docker volumes in /backup. Othwerwise, a docker volume is created in the default location.

## Usage:

```bash
docker container run -d \
       --env POSTGRES_USER=root \
       --env POSTGRES_PASS=my_password \
       --link postgres
       --volume /path/to/my/backup/folder:/backup
       ghcr.io/mentos1386/postgres-cron-backup
```

## Variables

- `POSTGRES_HOST`: The host/ip of your postgres database.
- `POSTGRES_PORT`: The port number of your postgres database.
- `POSTGRES_USER`: The username of your postgres database.
- `POSTGRES_PASS`: The password of your postgres database.
- `POSTGRES_PASS_FILE`: The file in container where to find the password of your postgres database (cf. docker secrets). You should use either POSTGRES_PASS_FILE or POSTGRES_PASS (see examples below).
- `POSTGRES_DATABASE`: The database name to dump. Default: `--all-databases`.
- `POSTGRESDUMP_OPTS`: Command line arguments to pass to pg_dump (see [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html)).
- `CRON_TIME`: The interval of cron job to run pg_dump. `0 3 * * sun` by default, which is every Sunday at 03:00. It uses UTC timezone.
- `MAX_BACKUPS`: The number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default.
- `INIT_BACKUP`: If set, create a backup when the container starts.
- `INIT_RESTORE_LATEST`: If set, restores latest backup.
- `TIMEOUT`: Wait a given number of seconds for the database to be ready and make the first backup, `10s` by default. After that time, the initial attempt for backup gives up and only the Cron job will try to make a backup.
- `GZIP_LEVEL`: Specify the level of gzip compression from 1 (quickest, least compressed) to 9 (slowest, most compressed), default is 6.
- `USE_PLAIN_SQL`: If set, back up and restore plain SQL files without gzip.
- `TZ`: Specify TIMEZONE in Container. E.g. "Europe/Berlin". Default is UTC.

If you want to make this image the perfect companion of your Postgres container, use [docker-compose](https://docs.docker.com/compose/). You can add more services that will be able to connect to the Postgres image using the name `my_postgres`, note that you only expose the port `5432` internally to the servers and not to the host:

### Docker-compose with POSTGRES_PASS env var:

```yaml
version: "2"
services:
  postgres:
    image: postgres
    container_name: my_postgres
    expose:
      - 5432
    volumes:
      - data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DATABASE=${DATABASE_NAME}
    restart: unless-stopped

  postgres-cron-backup:
    image: ghcr.io/mentos1386/postgres-cron-backup
    depends_on:
      - postgres
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - POSTGRES_HOST=my_postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASS=${POSTGRES_PASSWORD}
      - MAX_BACKUPS=15
      - INIT_BACKUP=0
      # Every day at 03:00
      - CRON_TIME=0 3 * * *
      # Make it small
      - GZIP_LEVEL=9
    restart: unless-stopped

volumes:
  data:
```

### Docker-compose using docker secrets:

The database root password passed to docker container by using [docker secrets](https://docs.docker.com/engine/swarm/).

In example below, docker is in classic 'docker engine mode' (iow. not swarm mode) and secret source is a local file on host filesystem.

Alternatively, secret can be stored in docker secrets engine (iow. not in host filesystem).

```yaml
version: "3.7"

secrets:
  postgres_password:
    # Place your secret file somewhere on your host filesystem, with your password inside
    file: ./secrets/postgres_password

services:
  postgres:
    image: postgres
    container_name: my_postgres
    expose:
      - 3306
    volumes:
      - data:/var/lib/postgres/data
    environment:
      - POSTGRES_DATABASE=${DATABASE_NAME}
      - POSTGRES_PASS_FILE=/run/secrets/postgres_password
    secrets:
      - postgres_password
    restart: unless-stopped

  backup:
    build: .
    image: ghcr.io/mentos1386/postgres-cron-backup
    depends_on:
      - postgres
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - POSTGRES_HOST=my_postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASS_FILE=/run/secrets/postgres_password
      - MAX_BACKUPS=10
      - INIT_BACKUP=1
      - CRON_TIME=0 0 * * *
    secrets:
      - postgres_password
    restart: unless-stopped

volumes:
  data:

```

## Restore from a backup

### List all available backups :

See the list of backups in your running docker container, just write in your favorite terminal:

```bash
docker container exec <your_postgres_backup_container_name> ls /backup
```

### Restore using a compose file

To restore a database from a certain backup you may have to specify the database name in the variable POSTGRES_DATABASE:

```YAML
postgres-cron-backup:
    image: ghcr.io/mentos1386/postgres-cron-backup
    command: "/restore.sh /backup/201708060500.${DATABASE_NAME}.sql.gz"
    depends_on:
      - postgres
    volumes:
      - ${VOLUME_PATH}/backup:/backup
    environment:
      - POSTGRES_HOST=my_postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASS=${POSTGRES_PASSWORD}
      - POSTGRES_DATABASE=${DATABASE_NAME}
```
### Restore using a docker command

```bash
docker container exec <your_postgres_backup_container_name> /restore.sh /backup/<your_sql_backup_gz_file>
```

if no database name is specified, `restore.sh` will try to find the database name from the backup file.
