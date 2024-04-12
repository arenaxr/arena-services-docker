#!/bin/bash
# build arena-web-core javascript
# ALWAYS_YES="true" indicates that we answer yes to all questions: create new secrets, tokens, regenerate config files

# load utils
source init-utils/bash-common-utils.sh 

echocolor ${HIGHLIGHT} "### Building ARENA core js."

printf "Skipping. For now, you will have to setup a node environment on the host to build ARENA core js.\n"
exit 0


# try to load ARENA_DOCKER_REPO_FOLDER var
export $(grep "^ARENA_DOCKER_REPO_FOLDER" .env | xargs)

if [ -z ${ARENA_DOCKER_REPO_FOLDER+x} ]; then 
  ARENA_DOCKER_REPO_FOLDER=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )    
  printf "ARENA_DOCKER_REPO_FOLDER not set. Using inferred folder from script path: $ARENA_DOCKER_REPO_FOLDER\n".
  printf "Add ARENA_DOCKER_REPO_FOLDER to .env if this is incorrect\n".
fi

readprompt "Build js (production instances - started with ./prod.sh - can skip this step) ? (y/N) "
if [[ $REPLY =~ ^[Yy]$ ]]; then
    [ -x "$(command -v git)" ] && cd ${ARENA_DOCKER_REPO_FOLDER}/arena-web-core && git checkout master && git pull
    mkdir -p ${ARENA_DOCKER_REPO_FOLDER}/arena-web-core/dist
    docker run -it --rm -v ${ARENA_DOCKER_REPO_FOLDER}:/arena -w /arena/arena-web-core arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION sh -c "npm install --also=dev && npm run build"
fi