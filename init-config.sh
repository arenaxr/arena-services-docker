#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then echo "Not running as root. Please run init.sh instead." >&2; exit 1; fi

echo -e "\n### Creating data folders\n"
data_folders=( "data/arena-store" "data/grafana"  "data/mongodb"  "data/prometheus" "data/account" "data/keys")
[ ! -d "data" ] && mkdir data
for d in "${data_folders[@]}"
do
  echo $d
  [ ! -d "$d" ] && mkdir $d && chown $OWNER $d
done

[ ! -d "conf/arena-web-conf" ] && mkdir conf/arena-web-conf && chown $OWNER conf/arena-web-conf

touch secret.env

echo -e "\n### Creating secret.env (with secret keys, admin password). This will replace old secret.env (if exists; backup will be in secret.env.bak)."
read -p "Create secret.env ? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  SECRET_KEY=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c40)
  SECRET_KEY_BASE64=$(echo $SECRET_KEY | base64)
  cp secret.env secret.env.bak
  echo "SECRET_KEY=$SECRET_KEY" > secret.env
  echo "SECRET_KEY_BASE64=$SECRET_KEY_BASE64" >> secret.env
  echo "DJANGO_SUPERUSER_PASSWORD=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c15)" >> secret.env
  echo "STORE_ADMIN_PASSWORD=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c15)" >> secret.env
fi

echo -e "\n### Creating RSA key pair for JWT (conf/keys/jwt.priv.pem). This will replace old keys (if exist; backup will be in data/keys/jwt.priv.pem.bak)."
read -p "Create RSA key pair ? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  [ -f ./data/keys/jwt.priv.pem ] && cp ./data/keys/jwt.priv.pem data/keys/jwt.priv.pem.bak
  rm ./data/keys/*
  openssl genrsa -out ./data/keys/jwt.priv.pem 4096
  openssl rsa -in ./data/keys/jwt.priv.pem -pubout -outform PEM -out ./data/keys/jwt.public.pem
  openssl rsa -in ./data/keys/jwt.priv.pem -RSAPublicKey_out -outform DER -out ./data/keys/jwt.public.der # mqtt auth plugin requires RSAPublicKey format
fi

# reset ownership of public keys
[ -f ./data/keys/jwt.public.pem ] && chown $OWNER ./data/keys/jwt.public.pem
[ -f ./data/keys/jwt.public.der ] && chown $OWNER ./data/keys/jwt.public.der

rm ./conf/arena-web-conf/*.pem 2>/dev/null
# copy public key to /conf/sha256(hostname).pem to be used for Atlassian Service Authentication Protocol (ASAP)
HOSTSHA256=$(echo -n $HOSTNAME | shasum -a 256)
cat ./data/keys/jwt.public.pem > ./conf/arena-web-conf/${HOSTSHA256%???}.pem

echo -e "\n### Creating Service Tokens. This will replace service tokens in secret.env (if exists; backup will be in secret.env.bak)."
read -p "Create Service Tokens ? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  grep -v '^SERVICE_' secret.env > secret.tmp # remove all service tokens
  cp secret.env secret.env.bak
  cp secret.tmp secret.env
  services=("arena_persist" "arena_arts" "py_runtime" "mqttbr")
  for s in "${services[@]}"
  do
    tn="SERVICE_${s^^}_JWT"
    echo "$tn=$(python /utils/genjwt.py -i $HOSTNAME -k ./data/keys/jwt.priv.pem $s)" >> secret.env
  done
  # generate a token for cli tools (for developers) and announce it in slack
  cli_token_json=$(python /utils/genjwt.py -i $HOSTNAME -k ./data/keys/jwt.priv.pem -j cli)
  echo $cli_token_json > ./data/keys/cli_token.json
  if [[ ! -z "$SLACK_DEV_CHANNEL_WEBHOOK" ]]; then
    username=$(echo $cli_token_json | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
    cli_token=$(echo $cli_token_json | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")
    alias_name="${HOSTNAME%%.*}"
    curl_data="{\"text\":\"New MQTT token for $HOSTNAME\", \"attachments\": [ {\"text\":\"\`\`\`alias ${alias_name}_pub='mosquitto_pub -h $HOSTNAME -p 8883 -u $username -P $cli_token'\`\`\`\"}, {\"text\":\"\`\`\`alias ${alias_name}_sub='mosquitto_sub -h $HOSTNAME -p 8883 -u $username -P $cli_token'\`\`\`\"} ]}"
    curl -X POST -H 'Content-type: application/json' --data "$curl_data" $SLACK_DEV_CHANNEL_WEBHOOK
  fi
  echo -e "\n Service tokens created. !NOTE!: For new service tokens to be used, you need to (re)create config files (answer Y to question about creating config files)."
fi

# load secrets
export $(grep -v '^#' secret.env | xargs)

echo "STORE_TMP_PORT = $STORE_TMP_PORT"
if [ "$STORE_TMP_PORT" == "none" ]
then
    echo -e "\n### Skipping filestore share and hash setup (instance failed to start)."
else
    echo -e "\n### Generating filestore public share and inline js hash."
    read -p "Create a public share on filebrowser ? (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        [ ! -d "store/public" ] && mkdir store/public
        fsauth_data='{"username": "'"$STORE_ADMIN_USERNAME"'", "password": "'"$STORE_ADMIN_PASSWORD"'"}'
        fsauth_token=$(curl -X POST -d "$fsauth_data" -H "Content-Type: application/json" "http://host.docker.internal:$STORE_TMP_PORT/api/login")

        # get share
        export FS_SHARE_HASH=$(curl -X GET -d "{}" -H "Content-Type: application/json" -H "X-Auth: $fsauth_token" "http://localhost:$STORE_TMP_PORT/api/share/public/" )
        if [ "$FS_SHARE_HASH" == "[]" ]
        then
            # create share
            export FS_SHARE_HASH=$(curl -X POST -d "{}" -H "Content-Type: application/json" -H "X-Auth: $fsauth_token" "http://localhost:$STORE_TMP_PORT/api/share/public/" | \
                python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])")
            echo "Share created: $FS_SHARE_HASH"
        else
                echo "Share already exists: $FS_SHARE_HASH"
        fi
    fi

    # gen hash of filebrowser javascript launch script for CSP
    export FS_LAUNCH_JS_HASH=$(node ./init-utils/filebrowserScriptToHash.js http://host.docker.internal:$STORE_TMP_PORT)
    echo "New FS_LAUNCH_JS_HASH=$FS_LAUNCH_JS_HASH"
fi

echo -e "\n### Creating config files (conf/*) from templates (conf-templates/*) and .env"
echo -e "\n\nContents of .env:\n"
cat .env
echo

echo -e "Please edit the file .env (shown above) to reflect your setup (hostname, email, ...). \n"
read -p "Continue and (re)create config files (backups will be created in conf/)? (y/N)" -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopped."
    exit 0
fi

# setup escape var for envsubst templates
export ESC="$"

# create a list of hostnames for python config files
HOSTNAMES_LIST=""
for host in $(echo "$HOSTNAME $ADDITIONAL_HOSTNAMES"|tr ' ' '\n'); do
  HOSTNAMES_LIST="$HOSTNAMES_LIST '$host',"
done
export HOSTNAMES_LIST=${HOSTNAMES_LIST::-1} # remove last comma

# gen orchestrator secret key
export ORCH_SECRET_KEY=$(openssl rand -base64 32)

for t in $(find conf-templates/ -type f)
do
  t="${t:15}" # remove "conf-templates/"
  f="${t%.*}" # remove trailing ".tmpl"
  d="$(dirname $f)" # get folder inside conf-templates
  if [[ ! $d = "." ]]; then
    [ ! -d "conf/$d" ] && mkdir "conf/$d" && chown $OWNER "conf/$d" # create destinatinon folder if needed
  fi
  cp conf/$f conf/$f.bak >/dev/null 2>&1
  echo -e "\t conf-templates/$t -> conf/$f"
  envsubst < conf-templates/$t > conf/$f
  chown $OWNER conf/$f
done

for t in $(find conf/*js -type f)
do
    f="${t%.*}" # remove trailing ".js"
    node /utils/jsDefaultsToJson.js "$PWD/$t" > $f.json
    chown $OWNER $f.json
done

# TODO: Re-enable additions hostnames - They are not allowing certbot to renew certificates
# add server block to redirect additional hostnames
# if [[ ! -z "$ADDITIONAL_HOSTNAMES" ]]; then
#         TMPFN=/tmp/nginx_tmpcfg
#         cat > $TMPFN <<  EOF

# server {
#     server_name         $ADDITIONAL_HOSTNAMES;
#     server_tokens off;
#     client_max_body_size 1000M;

#     listen              443 ssl;
#     ssl_certificate     /etc/letsencrypt/live/arenaxr.org/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/arenaxr.org/privkey.pem;
#     include             /etc/letsencrypt/options-ssl-nginx.conf;
#     ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

#     location ^~ /user/ {
#         add_header 'Access-Control-Allow-Origin' "\$http_origin";
#         add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, DELETE, PUT';
#         add_header 'Access-Control-Allow-Credentials' 'true';
#         add_header 'Access-Control-Allow-Headers' 'User-Agent,Keep-Alive,Content-Type';
#         proxy_pass http://arena-account:8000;
#         proxy_http_version 1.1;
#         proxy_set_header Host $host;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection "Upgrade";
#         proxy_read_timeout 86400;
#     }

#     location / {
#         return 301 https://$HOSTNAME\$request_uri;
#     }
# }
# EOF
#         # add server block to production and staging
#         cat $TMPFN >> ./conf/arena-web.conf
#         cat $TMPFN >> ./conf/arena-web-staging.conf
#         rm $TMPFN
# fi

echo -e "\n### If you are going to setup a Jitsi server on this machine, run init-jitsi.sh next."

