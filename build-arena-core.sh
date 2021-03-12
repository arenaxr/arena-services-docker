#!/bin/bash

echo -e "\n\e[1m### Building ARENA core js\e[0m\n"
read -p "Continue ? (y/N) " -r

if [[ $REPLY =~ ^[Yy]$ ]]; then
    [ -x "$(command -v git)" ] && cd ARENA-core && git checkout master && git pull && cd ..
    docker run -it -e OWNER=`id -u`:`id -g` --rm -v $PWD/ARENA-core:/ARENA-core -w /ARENA-core conixcenter/arena-services-docker-init-utils npm run build
fi
