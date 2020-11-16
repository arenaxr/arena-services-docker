#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

echo -e "\n### Creating SECRET_KEY to environment.env (old file in environment.bak). This will replace secret key (if exists)."
read -p "Continue? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  SECRET_KEY=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c40)
  SECRET_KEY_BASE64=$(echo $SECRET_KEY | base64)
  cp environment-secret.env environment-secret.bak
  echo "SECRET_KEY="$SECRET_KEY > environment-secret.env
  echo "SECRET_KEY_BASE64="$SECRET_KEY_BASE64 >> environment-secret.env
fi

echo -e "\n### Contents of environment.env:\n"
cat environment.env
echo

echo -e "Please edit environment.env (shown above) to reflect your setup (hostname, email, ...). \n(this will generate certificates, nginx config, ...)."
read -p "Continue? (y/N)" -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Stopped."
    exit 1
fi

echo -e "\n### Creating data folders\n"
data_folders=( "data/arena-store" "data/grafana"  "data/mongodb"  "data/prometheus")
mkdir data
for d in "${data_folders[@]}"
do
  echo $d
  [ ! -d "$d" ] && mkdir $d
done

# load environment
export $(grep -v '^#' environment.env | xargs)
export $(grep -v '^#' environment-secret.env | xargs)
export ESC="$"

echo -e "\n### Creating conf/nginx-conf.d/arena-web.conf from template (conf/templates/arena-web.tmpl)\n"
mkdir conf/nginx-conf.d 2> /dev/null
envsubst < conf/templates/arena-web.tmpl > conf/nginx-conf.d/arena-web.conf

echo -e "\n### Creating conf/arena-web-dev.conf from template (conf/templates/arena-web-dev.tmpl)\n"
mkdir conf/nginx-conf.d 2> /dev/null
envsubst < conf/templates/arena-web-dev.tmpl > conf/arena-web-dev.conf

echo -e "\n### Creating conf/mosquitto.conf from template (conf/templates/mosquitto.tmpl)\n"
envsubst < conf/templates/mosquitto.tmpl > conf/mosquitto.conf

echo -e "\n### Creating conf/mosquitto-br-conn.conf from template (conf/templates/mosquitto-br-conn.tmpl)\n"
envsubst < conf/templates/mosquitto-br-conn.tmpl > conf/mosquitto-br-conn.conf

echo -e "\n### Creating conf/arena-runtime-simulated.conf from template (conf/templates/arena-runtime-simulated.tmpl)\n"
envsubst < conf/templates/arena-runtime-simulated.tmpl > conf/arena-runtime-simulated.conf

echo -e "\n### Creating conf/arts-settings.py from template (conf/templates/arts-settings.tmpl)\n"
envsubst < conf/templates/arts-settings.tmpl > conf/arts-settings.py

echo -e "\n### Creating conf/arena-defaults.js from template (conf/templates/arena-defaults.tmpl)\n"
envsubst < conf/templates/arena-defaults.tmpl > conf/arena-defaults.js

echo -e "\n### Creating conf/auth-config.json from template (conf/templates/auth-config.tmpl)\n"
envsubst < conf/templates/auth-config.tmpl > conf/auth-config.json

echo -e "\n### Init letsencrypt\n"
./init-letsencrypt.sh
