#!/bin/bash
# check if we have our custom website files to write over

[ ! "$(docker ps -a | grep arena-services-docker_arena-web.*)" ] && exit 0 # dont continue if container does not exist

echo "Clone custom website repo into a folder named custom-website if you want to override the default website."
if [ -d "custom-website" ]
then
    echo "Updating custom website..."
    docker cp custom-website arena-services-docker_arena-web_1:/usr/share/nginx/html/
    docker exec arena-services-docker_arena-web_1 sh -c "cp -R /usr/share/nginx/html/custom-website/* /usr/share/nginx/html"
fi
