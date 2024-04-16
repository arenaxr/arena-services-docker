#!/bin/bash
# builds container with packages needed for init scripts and pushes it to dockerhub.
# version is saved into file VERSION
# usage: ./build-push-container.sh
DOCKER_USER=arenaxrorg

# stop on first error
set -e 

export $(grep '^ARENA_INIT_UTILS_VERSION=' ./VERSION | xargs)
echo "Current arena init utils version=$ARENA_INIT_UTILS_VERSION" 
nversion=v$(docker run --rm -it -v $PWD:/app -w /app treeder/bump --input $ARENA_INIT_UTILS_VERSION)
read -p "Enter the arena init utils version [$nversion]: " version
ARENA_INIT_UTILS_VERSION=${version:-$nversion}

echo "Enter dockerhub credentials for '$DOCKER_USER'"
docker login --username $DOCKER_USER

docker buildx rm arena-services-docker-init-utils-builder || true
docker buildx create --name arena-services-docker-init-utils-builder --use --bootstrap
docker buildx build . --attest type=sbom --push --platform linux/amd64,linux/arm64 -t $DOCKER_USER/arena-services-docker-init-utils:latest -t $DOCKER_USER/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION 
