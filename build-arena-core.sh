#!/bin/bash

echo -e "\n\e[1m### Building ARENA core js\e[0m\n"

echo -e "Skipping. For now, you will have to setup a node environment on the host to build ARENA core js.\n"
exit 0

read -p "Build js (production instances - started with ./prod.sh - can skip this step) ? (y/N) " -r

# load ARENA_DOCKER_REPO_FOLDER var
export $(grep "^ARENA_DOCKER_REPO_FOLDER" .env | xargs)

if [[ $REPLY =~ ^[Yy]$ ]]; then
    [ -x "$(command -v git)" ] && cd ${ARENA_DOCKER_REPO_FOLDER}/arena-web-core && git checkout master && git pull
    mkdir -p ${ARENA_DOCKER_REPO_FOLDER}/arena-web-core/dist
    docker run -it --rm -v ${ARENA_DOCKER_REPO_FOLDER}:/arena -w /arena/arena-web-core conixcenter/arena-services-docker-init-utils sh -c "npm install --also=dev && npm run build"
fi