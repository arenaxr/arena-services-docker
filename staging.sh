#!/bin/bash
# usage: ./staging.sh [docker-compose SUBCOMMAND: up, down, ...]

# make sure arena-web-core/conf folder exists
[ ! -d "arena-web-core/conf" ] && mkdir arena-web-core/conf

# copy arena client config files
cp ./conf/staging/arena-web-conf-files/defaults.js ./conf/arena-web-conf-files/defaults.js
cp ./conf/staging/arena-web-conf-files/defaults.json ./conf/arena-web-conf-files/defaults.json

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    #docker volume rm arena-services-docker_arts-static-content
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file VERSION $@
