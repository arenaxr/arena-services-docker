#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

echo -e "\n### Contents of environment.env:\n"
cat environment.env
echo

data_folders=( "data/arena-store" "data/certbot"  "data/grafana"  "data/mongodb"  "data/prometheus")
mkdir data
for d in "${data_folders[@]}"
do
  echo $d
  [ ! -d "$d" ] && mkdir $d
done

echo -e "Please edit environment.env (shown above) to reflect your setup (hostname, email, ...). \n(this will generate certificates, nginx config and a new SECRET_KEY in environment.env)."
read -p "Continue? " -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Stopped."
    exit 1
fi

echo -e "\n### Writing SECRET_KEY to environment.env (old file in environment.bak)\n"
SECRET_KEY=$(LC_ALL=C tr -dc '[:alnum:]' < /dev/urandom | head -c40)
grep -v '^SECRET_KEY' environment.env > environment.tmp
echo "SECRET_KEY="$SECRET_KEY >> environment.tmp
cp environment.env environment.bak
mv environment.tmp environment.env

# load environment
export $(grep -v '^#' environment.env | xargs)
export ESC="$"

echo -e "\n### Creating conf/nginx-conf.d/arena-web.conf from template (conf/templates/arena-web.tmpl)\n"
mkdir conf/nginx-conf.d 2> /dev/null
envsubst < conf/templates/arena-web.tmpl > conf/nginx-conf.d/arena-web.conf

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
