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

echo -e "\n### Creating config files (conf/*) from templates (conf-templates/*)"
mkdir conf
for t in $(ls conf-templates/)
do
  f="${t%.*}"
  cp conf/$f conf/$f.bak 2>&1 > /dev/null
  echo -e "\t conf-templates/$t -> conf/$f"
  envsubst < conf-templates/$t > conf/$f
done

echo -e "\n### Init letsencrypt\n"
./init-letsencrypt.sh
