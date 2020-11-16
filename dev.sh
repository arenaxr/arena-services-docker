#!/bin/bash
# usage: ./dev.sh [up/down; default: up]

if [[ $1 =~ ^down$ ]]; then
  $docker_args="down"
else
  $docker_args="up -d"
fi

docker-compose -f docker-compose.override.yaml $docker_args # = docker-compose $docker_args
