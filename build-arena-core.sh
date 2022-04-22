#!/bin/bash

echo -e "\n\e[1m### Building ARENA core js\e[0m\n"
read -p "Build js (production instances should skip this step) ? (y/N) " -r

if [[ $REPLY =~ ^[Yy]$ ]]; then
    CPWD=${PWD}
    [ -x "$(command -v git)" ] && cd ARENA-core && git checkout master && git pull && mkdir -p dist
    docker run -it --rm -v ${CPWD}/ARENA-core:/ARENA-core -w /ARENA-core conixcenter/arena-services-docker-init-utils sh -c "npm install && npm run build"
fi
