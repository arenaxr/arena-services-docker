#!/bin/bash
# usage: ./prod.sh [docker-compose SUBCOMMAND: up, down, ...]

# make sure ARENA-core/conf folder exists
[ ! -d "ARENA-core/conf" ] && mkdir ARENA-core/conf

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml $@
