#!/bin/bash
# usage: ./demo.sh [docker-compose SUBCOMMAND: up, down, ...]

if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided. Usage:"
    >&2 echo "$0 [docker-compose SUBCOMMAND: up, down, ...]"
    exit 1
fi

# create config if does not exist
if [ ! -f .env ] || [ ! -d "conf" ]
then
    if ! ./init.sh -y; then
        echo "Error creating config."
        exit 1
    fi
fi

# create html file describing stack versions (use container so we dont have to install envsubst on host)
docker run --rm -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/arena-web-conf:/conf --env-file VERSION conixcenter/arena-services-docker-init-utils sh -c 'envsubst < /conf-templates/versions.html.tmpl > /conf/demo/arena-web-conf/versions.html'

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    [ ! -z $(docker volume ls | grep arena-services-docker_account-static-content) ] && docker volume rm arena-services-docker_account-static-content
fi

# pull versions in VERSION
docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION pull

docker-compose -f docker-compose.yaml -f docker-compose.demo.yaml --env-file VERSION $@

./update-custom-website.sh