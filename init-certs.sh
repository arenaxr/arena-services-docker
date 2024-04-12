#!/bin/bash
# init certificates; create a self-signed cert for local (localhost, *.local, and *.arena hostname) setups; 
# uses letsencrypt for other setups, assuming hostname can reply to letsencrypt requests
#
# NOTE: usually, this script should not be called directly; it is instead called from init.sh
#
# uses variables in .env and the following:
#   ALWAYS_YES="true" indicates that we answer yes to all questions: create new secrets, tokens, regenerate config files
#   SELF_SIGNED="true" forces to create a self-signed certificate, independent of hostname assigned
#   STAGING="true" passes --staging to letsencrypt to avoit hitting request limits

# load utils
source init-utils/bash-common-utils.sh 

# generated a self-signed cert
gen_self_signed_and_exit() { 
  echocolor ${BOLD} "Creating self-signed certificate for $HOSTNAME"
  if [ ! -z "${ADDITIONAL_HOSTNAMES}" ]; then
    echocolor ${WARNING} "Additional hostnames not supported. Self-signed certificate will not contain: $ADDITIONAL_HOSTNAMES."
  fi
  path=$(echo "/etc/letsencrypt/live/$HOSTNAME" | sed 's/ *$//')
  mkdir -p $path
  openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE\
      -keyout "$path/privkey.pem" \
      -out "$path/cert.pem" \
      -subj "/CN=$HOSTNAME"
  cp -f "$path/cert.pem" "$path/chain.pem"
  cp -f "$path/cert.pem" "$path/fullchain.pem"
  exit 0
}

if [ "$(id -u)" -ne 0 ]; then echoerr "Not running as root. Please run from init.sh instead.\n"; exit 1; fi

RSA_KEY_SIZE=4096

if [ -d "/etc/letsencrypt/live" ]; then
  readprompt "Existing data found. Continue and replace existing certificate files (beware of letsencrypt retry limits, if using it)? (y/N) "
  if [ "$REPLY" != "Y" ] && [ "$REPLY" != "y" ]; then
    exit
  fi
  rm -fr /etc/letsencrypt/*
fi

echo -e "Downloading recommended TLS parameters ...\n"
mkdir -p "/etc/letsencrypt"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "/etc/letsencrypt/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "/etc/letsencrypt/ssl-dhparams.pem"

local="${HOSTNAME##*.}"
# if setting up a "localhost", ".local", or ".arena" domain, just create a self-signed certificate
# note: no support for ADDITIONAL_HOSTNAMES
if [ $HOSTNAME = "localhost" ] || [ $local = "local" ] || [ $local = "arena" ] || [ "$SELF_SIGNED" = "true" ]; then
  gen_self_signed_and_exit
fi

if [[ ! -z "$ADDITIONAL_HOSTNAMES" ]]; then
  domains="$HOSTNAME $ADDITIONAL_HOSTNAMES" # space-separated list of domains
else
  domains="$HOSTNAME" 
fi
email=$EMAIL # Adding a valid address is strongly recommended
staging_arg=""
if [ ! "$STAGING" == "true" ]; then
  staging_arg="--staging"
fi

echocolor {BOLD} "Requesting Let's Encrypt certificate for $domains ..."
# Join $domains to -d args
domain_args=""
for domain in ${domains}; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

certbot certonly --standalone -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $RSA_KEY_SIZE \
    --agree-tos

if [ $? -ne 0 ]
then
  echoerr "\n\n### !!! Could not create certificate. Certbot failed (see errors above) !!! ###\n"
  gen_self_signed_and_exit
fi
echo "\n"
