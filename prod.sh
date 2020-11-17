#!/bin/bash
# usage: ./prod.sh [docker-compose SUBCOMMAND: up, down, ...]

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml $@
