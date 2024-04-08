#!/bin/bash
# execute init-config.sh and init-letsencrypt.sh inside container with all utils needed
# usage ./init.sh [-y|--yes] [-c|--config_only] [-n|--nocerts]
# where -y or --yes indicates that we answer yes to all questions
# where -c or --config_only indicates that we skip everything expect config files creation from templates
# where -n or --nocerts indicates that we skip certificate creation

# load utils
source init-utils/bash-common-utils.sh 

cleanup_and_exit () {
    if [[ $1 == 1 ]]; then
        echoerr "Stopping here."
    fi
    if [ ! -z "$CONFIG_FILES_ONLY" ]; then
        exit $1
    fi 
    echocolor ${HIGHLIGHT} "### Cleanup..."
    # stop temp filebrowser container before exiting
    docker stop storetmp
    # sync filestore password
    export $(grep '^STORE_ADMIN_PASSWORD' secret.env | xargs)
    [[ ! -z "${STORE_ADMIN_PASSWORD}" ]] && docker run -it \
            -v ${PWD}/init-utils/store-config-for-init.json:/.filebrowser.json \
            -v ${PWD}/data/arena-store:/arena-store/data:rw \
            filebrowser/filebrowser users update admin -p $STORE_ADMIN_PASSWORD
    # start compose filebrowser, if we stopped it
    [[ ! -z "${START_COMPOSE_FILESTORE}" ]] && docker-compose up -d store
    exit $1
}

# parse args
while true; do
    case "$1" in
        -y|--yes)
            ALWAYS_YES="true"
            shift
            ;;
        -c|--config_only)
            CONFIG_FILES_ONLY="true"
            shift
            ;;
        -n|--nocerts)
            NO_CERTS="true"
            shift
            ;;
        --)
            shift
            break
            ;;
        * ) break ;;            
    esac
done

# create .env from init.env on first execution
if [ ! -f .env ]
then
  cp init.env .env
else 
  echo "Previous .env found. Loading config from .env (instead of init.env)."    
fi

# create conf/
[ ! -d conf ] && mkdir conf

# make sure arena-web-core/conf folder exists
[ ! -d "arena-web-core/conf" ] && mkdir arena-web-core/conf

# load versions and pull init utils container
export $(grep -v '^#' VERSION | xargs)
docker pull arenaxrorg/arena-services-docker-init-utils:${ARENA_INIT_UTILS:-latest}

# TMP: create arena-web-core/user/static
[ ! -d "arena-web-core/user/static" ] && mkdir -p arena-web-core/user/static

if [ -z "$CONFIG_FILES_ONLY" ]; then 

    # build arena-core js
    export ARENA_DOCKER_REPO_FOLDER=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    ./build-arena-core.sh

    START_COMPOSE_FILESTORE=""
    # stop filestore if up
    if docker ps | grep -q "arena-services-docker_store_1"; then
        docker-compose stop store
        export START_COMPOSE_FILESTORE="YES"
    fi

    echo "Starting temp filestore instance..."
    export STORE_TMP_PORT=8111
    # bring up a temp instance of filebrowser (used in init config; note: using store config in init-utils folder)
    docker run --rm \
        --name storetmp \
        -v ${PWD}/init-utils/store-config-for-init.json:/.filebrowser.json \
        -v ${PWD}/store-branding:/arena-store/frontend/arena-branding \
        -v ${PWD}/store:/srv-files \
        -v ${PWD}/data/arena-store:/arena-store/data:rw \
        -p $STORE_TMP_PORT:8080 \
        filebrowser/filebrowser:${ARENA_FILESTORE:-latest} &

    # check if filestore is up
    timeout 10 bash -c 'until printf "" 2>>/dev/null >>/dev/tcp/$0/$1; do sleep 1; done' localhost $STORE_TMP_PORT
    if [ $? -ne 0 ]; then
        echo "Filestore timed-out. WARNING: filestore share and hash will not be created correctly."
        export STORE_TMP_PORT="none"
    else
        echo "Filestore instance ready."
    fi

fi # CONFIG_FILES_ONLY

touch secret.env &>/dev/null
echocolor ${HIGHLIGHT} "### Init config files (create secrets.env, ./conf/* files, and ./data/* folders)"
docker run --add-host host.docker.internal:host-gateway -it --env-file .env --env-file secret.env --env-file VERSION -e OWNER=`id -u`:`id -g` -e STORE_TMP_PORT=$STORE_TMP_PORT -e ALWAYS_YES=$ALWAYS_YES -e CONFIG_FILES_ONLY=$CONFIG_FILES_ONLY --rm -v $PWD:/work -w /work arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION /work/init-config.sh

if [ $? -ne 0 ]
then
    echoerr "Init config failed. See previous errors."
    cleanup_and_exit 1
fi

if [ -z "$CONFIG_FILES_ONLY" ]; then 

    if [ -z "$NOCERTS" ]; then 
        echocolor ${HIGHLIGHT} "### Create/renew certificates"
        docker run -it --env-file .env --env-file secret.env -e OWNER=`id -u`:`id -g` -e ALWAYS_YES=$ALWAYS_YES --rm -v $PWD:/work -v $PWD/data/certbot/conf:/etc/letsencrypt -v $PWD/data/certbot/www:/var/www/certbot -w /work -p 80:80 arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION /work/init-certs.sh
        if [ $? -ne 0 ]
        then
            echoerr "### Certificate creation failed."
            cleanup_and_exit 1
        fi
    fi

fi # CONFIG_FILES_ONLY

echo 
echocolor ${BOLD} "Init Done. If you are going to setup a Jitsi server on this machine, run jitsi-add.sh next."
echo

cleanup_and_exit 0


