FROM golang:1.15.8-alpine3.12 AS binary
RUN apk -U add openssl git

ARG DOCKERIZE_VERSION=v0.6.1
WORKDIR /go/src/github.com/jwilder
RUN git clone https://github.com/jwilder/dockerize.git && \
    cd dockerize && \
    git checkout ${DOCKERIZE_VERSION}

WORKDIR /go/src/github.com/jwilder/dockerize
RUN go get github.com/robfig/glock
RUN glock sync -n < GLOCKFILE
RUN go install

FROM alpine:3.16.0
LABEL maintainer "mentos1386 <mentos1386@tjo.space>"
LABEL org.opencontainers.image.source=https://github.com/mentos1386/docker-postgres-cron-backup
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.description="Docker image to backup all your databases periodically"

RUN apk add --update \
        tzdata \
        bash \
        postgresql-client \
        gzip \
        openssl && \
    rm -rf /var/cache/apk/*

COPY --from=binary /go/bin/dockerize /usr/local/bin

ENV CRON_TIME="0 3 * * sun" \
    POSTGRES_HOST="postgres" \
    POSTGRES_PORT="5432" \
    TIMEOUT="10s" \
    POSTGRESDUMP_OPTS=""

COPY ["run.sh", "backup.sh", "restore.sh", "/"]
RUN mkdir /backup && \
    chmod 777 /backup && \ 
    chmod 755 /run.sh /backup.sh /restore.sh && \
    touch /postgres_backup.log && \
    chmod 666 /postgres_backup.log

VOLUME ["/backup"]

CMD dockerize -wait tcp://${POSTGRES_HOST}:${POSTGRES_PORT} -timeout ${TIMEOUT} /run.sh
