#!/bin/bash
# usage: ./prod.sh [up/down; default: up]

if [[ $1 =~ ^down$ ]]; then
  docker_args="down"
else
  docker_args="up -d"
fi

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml $docker_args
