#!/bin/bash
# usage: ./prod.sh [docker-compose SUBCOMMAND: up, down, ...]

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

# make sure arena-web-core/conf folder exists
[ ! -d "arena-web-core/conf" ] && mkdir arena-web-core/conf

# get utils version
export $(grep '^ARENA_INIT_UTILS_VERSION=' init-utils/VERSION | xargs)

# create files describing stack versions (use container so we dont have to install envsubst on host)
docker run --rm \
    -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/prod/arena-web-conf:/arena-web-conf \
    --env-file VERSION arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION sh \
    -c 'envsubst < /conf-templates/versions.html.tmpl > /arena-web-conf/versions.html; envsubst < /conf-templates/versions.spdx.json.tmpl > /arena-web-conf/versions.spdx.json'  

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    docker volume rm arena-services-docker_account-static-content
fi

# pull versions in VERSION
$DOCKER_COMPOSE -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION pull -q

$DOCKER_COMPOSE -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION $@

if [[ "$*" == *up* ]]
then
    ./update-custom-website.sh
fi
