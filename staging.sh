#!/bin/bash
# usage: ./staging.sh [docker-compose SUBCOMMAND: up, down, ...]

# copy arena client config files
cp ./conf/staging/arena-web-conf/* ./conf/arena-web-conf

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file VERSION $@
