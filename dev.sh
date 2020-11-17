#!/bin/bash
# usage: ./dev.sh [docker-compose SUBCOMMAND: up, down, ...]

docker-compose -f docker-compose.override.yaml $@ # = docker-compose $@
