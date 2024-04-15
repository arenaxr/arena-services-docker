#!/bin/bash

# load env
export $(grep -v '^#' .env | xargs)

# add server block to redirect jitsi requests
if [[ ! -z "$JITSI_HOSTNAME" ]]; then
    echo -e "\n### If you are going to setup a Jitsi server on this machine, you will configure nginx to redirect http requests to a Jitsi virtual host (JITSI_HOSTNAME is an alias to the IP of the machine)."
    read -p "Add server block to redirect requests to Jitsi ? (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        TMPFN=$(tempfile)
        JITSI_HOSTNAME_NOPORT=$(echo $JITSI_HOSTNAME | cut -f1 -d":")
        cat > $TMPFN <<  EOF

server {
    server_name         $JITSI_HOSTNAME_NOPORT;
    listen              80;
    location /.well-known/acme-challenge/ {
        proxy_pass http://$JITSI_HOSTNAME_NOPORT:8000;
    }
    location / {
        return 301 https://$JITSI_HOSTNAME\$request_uri;
    }
}
EOF
        # add server block to production and staging
        cat $TMPFN >> ./conf/prod/arena-web.conf
        cat $TMPFN >> ./conf/staging/arena-web.conf
        rm $TMPFN
    fi
fi

