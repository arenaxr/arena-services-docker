#!/bin/bash
# usage: ./dev.sh [docker-compose SUBCOMMAND: up, down, ...]

# copy arena client defaults
cp ./conf/localdev/arena-web-conf/* ./conf/arena-web-conf

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.localdev.yaml $@ # = docker-compose $@
