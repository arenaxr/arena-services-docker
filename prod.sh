#!/bin/bash
# usage: ./prod.sh [docker-compose SUBCOMMAND: up, down, ...]

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
if [ ! -d "arena-web-core/conf" ]; then && mkdir arena-web-core/conf

# get utils version
export $(grep '^ARENA_INIT_UTILS_VERSION=' init-utils/VERSION | xargs)

# create html file describing stack versions (use container so we dont have to install envsubst on host)
docker run --rm -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/arena-web-conf:/conf --env-file VERSION arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION sh -c 'envsubst < /conf-templates/versions.html.tmpl > ./conf/demo/arena-web-conf/versions.html'  > ./conf/arena-web-conf/versions.html  

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    docker volume rm arena-services-docker_account-static-content
fi

# pull versions in VERSION
docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION pull

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION $@
