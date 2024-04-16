#!/bin/bash

cleanup_and_exit () {
    echo -e "\n\e[1m### Stopping here. Doing Cleanup...\e[0m\n"
    # stop temp filebrowser container before exiting
    docker stop storetmp
    # sync filestore password
    export $(grep '^STORE_ADMIN_PASSWORD' secret.env | xargs)
    [[ ! -z "${STORE_ADMIN_PASSWORD}" ]] && docker run -it \
        -v ${PWD}/conf/arena-store-config.json:/.filebrowser.json \
        -v ${PWD}/data/arena-store:/arena-store/data:rw \
        filebrowser/filebrowser users update admin -p $STORE_ADMIN_PASSWORD
    # start compose filebrowser, if we stopped it
    [[ ! -z "${START_COMPOSE_FILESTORE}" ]] && docker-compose up -d store
    echo -e "\n\e[1m### Cleanup done.\e[0m\n"
    exit $1
}

if [ ! -f .env ]
then
  cp init.env .env
else 
  echo "Previous .env found. Loading config from .env (instead of init.env)."    
fi

# create conf/
[ ! -d conf ] && mkdir conf

# load versions and pull init utils container
export $(grep -v '^#' VERSION | xargs)
docker pull arenaxrorg/arena-services-docker-init-utils:${ARENA_INIT_UTILS:-latest}

# TMP: create arena-web-core/user/static
[ ! -d "arena-web-core/user/static" ] && mkdir -p arena-web-core/user/static

# build arena-core js
./build-arena-core.sh

START_COMPOSE_FILESTORE=""
# stop filestore if up
if docker ps | grep -q "arena-services-docker_store_1"; then
    docker-compose stop store
    export START_COMPOSE_FILESTORE="YES"
fi

echo "Starting temp filestore instance..."
# create arena store config file (TODO: this assumes arena-store-config.json template has no variables; do substitutions if needed)
[ ! -f "${PWD}/conf/arena-store-config.json" ] && cp ${PWD}/conf-templates/arena-store-config.json.tmpl ${PWD}/conf/arena-store-config.json
export STORE_TMP_PORT=8111
# bring up a temp instance of filebrowser (used in init config)
docker run --rm \
    --name storetmp \
    -v ${PWD}/conf/arena-store-config.json:/.filebrowser.json \
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

touch secret.env &>/dev/null
echo -e "\n\e[1m### Init config files (create secrets.env, ./conf/* files, and ./data/* folders)\e[0m\n"
docker run --add-host host.docker.internal:host-gateway -it --env-file .env --env-file secret.env -e OWNER=`id -u`:`id -g` -e STORE_TMP_PORT=$STORE_TMP_PORT --rm -v $PWD:/work -w /work conixcenter/arena-services-docker-init-utils /work/init-config.sh

if [ $? -ne 0 ]
then
    echo -e "\n\e[1m### Init config failed.\e[0m\n"
    cleanup_and_exit 1
fi

echo -e "\n\e[1m### Init letsencrypt (create/renew certificates)\e[0m\n"
docker run -it --env-file .env --env-file secret.env -e OWNER=`id -u`:`id -g` --rm -v $PWD:/work -v $PWD/data/certbot/conf:/etc/letsencrypt -v $PWD/data/certbot/www:/var/www/certbot -w /work -p 80:80 conixcenter/arena-services-docker-init-utils /work/init-letsencrypt.sh
if [ $? -ne 0 ]
then
    echo -e "\n\e[1m### Init letsencrypt failed. Did you stop services on port 80 ? To stop all services: [./dev.sh | ./prod.sh ./staging.sh] down).\e[0m\n"
    cleanup_and_exit 1
fi

cleanup_and_exit 0
