#!/bin/bash
# usage: ./prod.sh [docker-compose SUBCOMMAND: up, down, ...]

# make sure ARENA-core/conf folder exists
[ ! -d "ARENA-core/conf" ] && mkdir ARENA-core/conf

# copy arena client defaults
cp ./conf/arena-web-conf/arena-defaults.js ./conf/arena-web-conf/defaults.js
cp ./conf/arena-web-conf/arena-defaults.json ./conf/arena-web-conf/defaults.json

# create html file describing stack versions (use container so we dont have to install envsubst on host)
docker run --rm -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/arena-web-conf:/conf --env-file VERSION conixcenter/arena-services-docker-init-utils sh -c 'envsubst < /conf-templates/versions.html.tmpl'  > ./conf/arena-web-conf/versions.html  

# force static volumes to be created again on "up"
if [[ "$*" == *up* ]]
then
    #docker volume rm arena-services-docker_arts-static-content
    docker volume rm arena-services-docker_account-static-content
fi

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file VERSION $@

# check if we have our custom website files to write over
[ ! "$(docker ps -a | grep arena-services-docker_arena-web_1)" ] && exit 0 # dont continue if container does not exist
echo "Clone custom website repo into a folder named ARENA-website if you want to override the default website."
if [ -d "ARENA-website" ]
then
    echo "Copying custom website..."
    docker cp ARENA-website arena-services-docker_arena-web_1:/usr/share/nginx/html/
    docker exec arena-services-docker_arena-web_1 sh -c "cp -R /usr/share/nginx/html/ARENA-website/* /usr/share/nginx/html"
fi
