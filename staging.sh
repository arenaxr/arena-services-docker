#!/bin/bash
# usage: ./staging.sh [docker-compose SUBCOMMAND: up, down, ...]

# make sure arena-web-core/conf folder exists
[ ! -d "arena-web-core/conf" ] && mkdir arena-web-core/conf

# copy arena client defaults
cp ./conf/arena-web-conf/arena-defaults-dev.js ./conf/arena-web-conf/defaults.js
cp ./conf/arena-web-conf/arena-defaults-dev.json ./conf/arena-web-conf/defaults.json

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    #docker volume rm arena-services-docker_arts-static-content
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file VERSION $@
