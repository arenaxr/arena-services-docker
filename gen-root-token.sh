
#!/bin/bash
# generate a new root token from keys previously created using init.sh 
#
# usage: ./gen-root-token.sh [username]
# where username is the token subject

TOKEN_USERNAME=${1:-cli}

# check if root private key exists
if [ ! -f ./data/keys/jwt.priv.pem ]; then
	echo "A private key needs to exits before creating a new token! Try running init.sh."
	exit 1
fi 
# run in container with all tools/dependencies needed
export $(grep '^ARENA_INIT_UTILS_VERSION=' ./VERSION | xargs)
docker run -it --env-file .env --env-file secret.env -e OWNER=`id -u`:`id -g` -e STORE_TMP_PORT=$STORE_TMP_PORT --rm -v $PWD:/work -w /work arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION sh -c "python /utils/genjwt.py -i $HOSTNAME -k ./data/keys/jwt.priv.pem -j $TOKEN_USERNAME"

