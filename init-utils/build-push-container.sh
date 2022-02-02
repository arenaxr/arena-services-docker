#!/bin/bash
# builds container with packages needed for init scripts and pushes it to dockerhub.
# version is saved into file VERSION
# usage: ./build-push-container.sh
DOCKER_USER=conixcenter

# stop on first error
set -e 

export $(grep '^ARENA_INIT_UTILS=' ./VERSION | xargs)
echo "Current arena init utils version=$ARENA_INIT_UTILS" 
nversion=$(docker run --rm -it -v $PWD:/app -w /app treeder/bump --input $ARENA_INIT_UTILS)
read -p "Enter the arena init utils version [$nversion]: " version
ARENA_INIT_UTILS_VERSION=${version:-$nversion}

docker build . -t $DOCKER_USER/arena-services-docker-init-utils
docker tag $DOCKER_USER/arena-services-docker-init-utils:latest $DOCKER_USER/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION 

echo -e "\n### Push the container to dockerhub (needs dockerhub credentials for user '$DOCKER_USER'."
read -p "Continue? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Enter dockerhub credentials for '$DOCKER_USER'"
    docker login --username $DOCKER_USER
    docker push $DOCKER_USER/arena-services-docker-init-utils
    docker push $DOCKER_USER/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION
    sed -i "s/ARENA_INIT_UTILS=.*/ARENA_INIT_UTILS=$ARENA_INIT_UTILS_VERSION/" ./VERSION
fi
