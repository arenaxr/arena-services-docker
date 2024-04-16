#!/bin/bash
# execute init-config.sh and init-certs.sh inside container with all utils needed
# usage: ./init.sh [-yntsclbh] (see below)

# load utils
source init-utils/bash-common-utils.sh 

usage () {
printf "\nInit ARENA stack config \n \
\n \
./init.sh [-yntsclb], \n \
\n \
where: \n \
 -y indicates that we answer yes to all questions \n \
 -t passes the 'staging' flag to letsencrypt to avoid request limits \n \
 -s forces the creation of a self-signed certificate \n \
 -n skip certificate creation \n \
 -c create config files ONLY (skip everything else) \n \
 -r create certificates ONLY (skip everything else) \n \
 -b build arena-web-core js ONLY (skip everything else) \n \
 -h print help \n\n"
}

cleanup_and_exit () {
    if [[ $1 == 0 ]]; then
        echo "" && echocolor ${BOLD} "Init Done. If you are going to setup a Jitsi server on this machine, run jitsi-add.sh next." && echo ""       
    else
        echo "" && echoerr "Stopping here."
    fi
    if [ ! -z "$CONFIG_FILES_ONLY" ]; then
        exit $1
    fi 
    echocolor ${HIGHLIGHT} "### Cleanup..."
    # stop temp filebrowser container before exiting
    [[ $(docker ps | grep storetmp) ]] && docker stop storetmp
    # stop temp nginx container before exiting
    [[ $(docker ps | grep nginxtmp) ]] && docker stop nginxtmp
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

build_arena_js() {
    # build arena-core js
    export ARENA_DOCKER_REPO_FOLDER=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    ./build-arena-core.sh
}

setup_filestore() {
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
}

init_config() {
    touch secret.env &>/dev/null
    docker run --add-host host.docker.internal:host-gateway -it --rm \
        --env-file .env --env-file secret.env --env-file VERSION -e OWNER=`id -u`:`id -g` -e STORE_TMP_PORT=$STORE_TMP_PORT -e ALWAYS_YES=$ALWAYS_YES -e CONFIG_FILES_ONLY=$CONFIG_FILES_ONLY \
        -v $PWD:/work -w /work \
        arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION \
        /work/init-config.sh

    if [ $? -ne 0 ]
    then
        echoerr "Init config failed. See previous errors."
        cleanup_and_exit 1
    fi
}

create_certs() {
    if [ -z "$NOCERTS" ]; then 
        echocolor ${HIGHLIGHT} "### Create/renew certificates"

        # bring up a temp instance of nginx
        docker run -it --rm \
            --name nginxtmp \
            -v ${PWD}/data/certbot/conf:/etc/letsencrypt:rw \
            -v ${PWD}/data/certbot/www:/var/www/certbot:rw \
            -v ${PWD}/conf/letsencrypt-web.conf:/etc/nginx/conf.d/default.conf:ro \
            -p 80:80 \
            nginx &

        # run cert creation script in container
        docker run -it --rm \
            --env-file .env --env-file secret.env -e OWNER=`id -u`:`id -g` -e ALWAYS_YES=$ALWAYS_YES -e STAGING=$STAGING_LE -e SELF_SIGNED=$SELF_SIGNED \
            -v $PWD:/work -v $PWD/data/certbot/conf:/etc/letsencrypt -v $PWD/data/certbot/www:/var/www/certbot \
            -w /work \
            arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION \
            /work/init-certs.sh

        if [ $? -ne 0 ]
        then
            echoerr "### Certificate creation failed."
            cleanup_and_exit 1
        fi
    fi # NOCERTS
}

# handle args
args=`getopt yntscrbh $*`
[[ ! $? == 0 ]] && usage
eval set -- "$args"

# parse options
while true; do
    case "$1" in
        -y)
            ALWAYS_YES="true"
            shift
            ;;
        -n)
            NO_CERTS="true"
            shift
            ;;
        -t)
            STAGING_LE="true"
            shift
            ;;
        -s)
            SELF_SIGNED="true"
            shift
            ;;
        -h)
            usage
            exit
            ;;
        --)
            shift
            break
            ;;
        * ) break ;;            
    esac
done

echocolor ${HIGHLIGHT} "### Setting up folders and dependencies ..."

# create .env from init.env on first execution
if [ ! -f .env ]
then
    if [ -f init.env ]; then
        grep -v -e '^#\|^$' init.env > .env
    else
        echoerr "No init.env file found! This is needed for a correct init. Running from arena-services-docker repository root ?"
        exit 1
    fi
else 
  echocolor ${WARNING} "NOTE: A .env file was found (init.sh was executed before?). Loading config from .env instead of init.env."
  echo -e "You can use cleanup.sh to clear a previous init.sh.\n"
fi

# create conf/
[ ! -d conf ] && mkdir conf

# make sure arena-web-core/conf folder exists
[ ! -d "arena-web-core/conf" ] && mkdir arena-web-core/conf

# load versions and pull init utils container
export $(grep -v '^#' VERSION | xargs)
docker pull arenaxrorg/arena-services-docker-init-utils:${ARENA_INIT_UTILS_VERSION}

# TMP: create arena-web-core/user/static
[ ! -d "arena-web-core/user/static" ] && mkdir -p arena-web-core/user/static

# handle remaining options; execute something and exit
while true; do
    case "$1" in
        -c)
            CONFIG_FILES_ONLY="true"
            init_config
            cleanup_and_exit $?
            ;;
        -r)
            create_certs
            cleanup_and_exit $?
            ;;
        -b)
            build_arena_js
            cleanup_and_exit $?
            ;;
        --)
            shift
            break
            ;;
        * ) break ;;            
    esac
done

# run everything
build_arena_js
setup_filestore
init_config
create_certs
cleanup_and_exit 0

