#!/bin/bash
# usage: ./dev.sh [docker-compose SUBCOMMAND: up, down, ...]

if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided. Usage:"
    >&2 echo "$0 [docker-compose SUBCOMMAND: up, down, ...]"
    exit 1
fi

if [ ! -d "conf" ] || [ ! -f .env ]; then
    >&2 echo "Config files no found. Did you run ./init.sh ?"
    exit 1
fi 

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.localdev.yaml $@ # = docker-compose $@
