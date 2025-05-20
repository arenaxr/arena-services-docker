#!/bin/bash
# usage: ./staging.sh [docker-compose SUBCOMMAND: up, down, ...]

# prefer newer docker compose; fall back to older docker-compose
[[ $(docker compose --help 2>&1) ]] && DOCKER_COMPOSE="docker compose" || DOCKER_COMPOSE="docker-compose"
[[ $($DOCKER_COMPOSE --help 2>&1) ]] && echo "Docker compose not found. Please install."

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

# pull versions in VERSION
# $DOCKER_COMPOSE -f docker-compose.yaml -f docker-compose.staging.yaml --env-file VERSION pull -q

$DOCKER_COMPOSE -f docker-compose.yaml -f docker-compose.staging.yaml --env-file VERSION $@

if [[ "$*" == *up* ]]
then
    ./update-custom-website.sh
fi
