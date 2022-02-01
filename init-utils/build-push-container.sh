#!/bin/bash
# usage: ./build-push-container.sh <tag>; e.g. ./build-push-container.sh v1.0.0
DOCKER_USER=conixcenter
docker build . -t conixcenter/arena-services-docker-init-utils:${1:-latest}

echo -e "\n### Push the container to dockerhub (needs dockerhub credentials for user '$DOCKER_USER'."
read -p "Continue? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Enter dockerhub credentials for '$DOCKER_USER'"
    docker login --username $DOCKER_USER
    docker push conixcenter/arena-services-docker-init-utils:${1:-latest}
fi
