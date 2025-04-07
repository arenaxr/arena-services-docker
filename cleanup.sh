#!/bin/bash
# cleanup previous config created with init.sh; **run with sudo**

# load utils
source init-utils/bash-common-utils.sh 

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
        -h)
            echo "$0 [-y]"
            exit
            ;;
        * ) break ;;            
    esac
done

[ -d conf ] && ( rm -fr conf_bak 2>&1; mv conf conf_bak && echo "Backup conf in conf_bak" ) || echo "No conf folder found"
[ -d data ] && ( rm -fr data_bak 2>&1; mv data data_bak && echo "Backup data in data_bak") || echo "No conf folder found"
[ -f .env ] && ( rm -fr .env_bak 2>&1; mv .env .env_bak && echo "Backup .env in .env_bak") || echo "No .env found"

if [ -d "./data/certbot/conf/live" ]; then
  echo "Existing certificate/letsencrypt data found (deleting and retrying to create certificates might bump into letsencrypt retry limits)."
  readprompt "Continue and remove certificate/letsencrypt files ? (y/N) "
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then  
    rm -fr ./data/certbot/conf/*
  fi
else
  echo "No certificate/letsencrypt data found."
fi