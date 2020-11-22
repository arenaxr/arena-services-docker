#!/usr/bin/env bash
docker login --username conixcenter
docker build . -t conixcenter/arena-services-docker-init-utils
docker push conixcenter/arena-services-docker-init-utils

