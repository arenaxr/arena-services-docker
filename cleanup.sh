#!/bin/bash
# cleanup previous config created with init.sh; run with sudo

[ -d conf ] && ( rm -fr conf_bak; mv conf conf_bak && echo "Backup conf in conf_bak" ) || echo "No conf folder found"
[ -d data ] && ( rm -fr data_bak; mv data data_bak && echo "Backup data in data_bak") || echo "No conf folder found"
[ -f .env ] && ( rm -fr .env_bak; mv .env .env_bak && echo "Backup .env in .env_bak") || echo "No .env found"

if [ -d "./data/certbot/conf/live" ]; then
  echo "Existing certificate/letsencrypt data found (deleting and retrying to create certificates might bump into letsencrypt retry limits)."
  read -p "Continue and remove certificate/letsencrypt files ? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
  rm -fr ./data/certbot/conf/*
else
  echo "No certificate/letsencrypt data found."
fi