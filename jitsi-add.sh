#!/bin/bash

# Jitsi setup for co-located ARENA + Jitsi deployments.
#
# This script handles two things:
#   1. Adds an nginx server block to redirect Jitsi requests and proxy ACME challenges
#   2. Fixes Jitsi's acme.sh certificate renewal to use webroot mode instead of standalone
#
# The acme.sh fix is critical: by default, Jitsi's acme.sh uses standalone mode, which
# stops nginx during renewal. When ARENA nginx proxies the ACME challenge (port 80 → 8000),
# the renewal can fail, leaving nginx dead and Jitsi unreachable for ~24 hours every ~60 days.
#
# USAGE:
#   Run after init.sh to add the nginx server block:
#     ./jitsi-add.sh
#   Run again (with sudo) after the Jitsi Docker stack has started to fix acme.sh:
#     sudo ./jitsi-add.sh

# load env
export $(grep -v '^#' .env | xargs)

# --- Part 1: Add server block to redirect Jitsi requests ---

if [[ ! -z "$JITSI_HOSTNAME" ]]; then
    JITSI_HOSTNAME_NOPORT=$(echo $JITSI_HOSTNAME | cut -f1 -d":")

    echo -e "\n### If you are going to setup a Jitsi server on this machine, you will configure nginx to redirect http requests to a Jitsi virtual host (JITSI_HOSTNAME is an alias to the IP of the machine)."
    read -p "Add server block to redirect requests to Jitsi ? (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        TMPFN=$(tempfile)
        cat > $TMPFN <<  EOF

server {
    server_name         $JITSI_HOSTNAME_NOPORT;
    listen              80;
    location /.well-known/acme-challenge/ {
        proxy_pass http://$JITSI_HOSTNAME_NOPORT:8000/.well-known/acme-challenge/;
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

    # --- Part 2: Fix Jitsi acme.sh to use webroot mode instead of standalone ---

    echo ""
    JITSI_CONFIG="${HOME}/.jitsi-meet-cfg"

    # Locate the acme.sh domain config (try ECC first, then RSA)
    ACME_CONF="${JITSI_CONFIG}/web/acme.sh/${JITSI_HOSTNAME_NOPORT}_ecc/${JITSI_HOSTNAME_NOPORT}.conf"
    if [[ ! -f "$ACME_CONF" ]]; then
        ACME_CONF="${JITSI_CONFIG}/web/acme.sh/${JITSI_HOSTNAME_NOPORT}/${JITSI_HOSTNAME_NOPORT}.conf"
    fi

    if [[ ! -f "$ACME_CONF" ]]; then
        echo "NOTE: Jitsi acme.sh config not found at ${JITSI_CONFIG}/web/acme.sh/"
        echo "This is normal if the Jitsi Docker stack hasn't been started yet."
        echo "After starting Jitsi for the first time, re-run this script (with sudo) to fix certificate renewal."
    else
        echo "Found acme.sh config: ${ACME_CONF}"

        # Check if already using webroot mode
        if grep -q "Le_Webroot='/usr/share/jitsi-meet'" "$ACME_CONF"; then
            echo "acme.sh is already configured for webroot mode. No changes needed."
        else
            echo ""
            echo "Current mode: standalone (stops nginx during renewal)"
            echo "Switching to: webroot (nginx stays running)"
            echo ""

            # Switch from standalone to webroot mode
            sed -i "s|Le_Webroot='no'|Le_Webroot='/usr/share/jitsi-meet'|" "$ACME_CONF"

            # Remove PreHook that kills nginx
            sed -i "s|Le_PreHook='.*'|Le_PreHook=''|" "$ACME_CONF"

            # Remove PostHook (no longer needed since nginx stays running)
            sed -i "s|Le_PostHook='.*'|Le_PostHook=''|" "$ACME_CONF"

            # Add RenewHook to reload nginx after successful cert renewal
            sed -i "s|Le_RenewHook=''|Le_RenewHook='nginx -s reload'|" "$ACME_CONF"

            echo "Updated acme.sh config:"
            grep -E 'Le_Webroot|Le_PreHook|Le_PostHook|Le_RenewHook|Le_ReloadCmd' "$ACME_CONF"
            echo ""
        fi

        # Fix the crontab: add logging and nginx safety net
        CRON_FILE="${JITSI_CONFIG}/web/crontabs/root"
        if [[ -f "$CRON_FILE" ]]; then
            if grep -q '> /dev/null' "$CRON_FILE"; then
                echo "Updating crontab: adding logging and nginx safety restart..."
                sed -i 's|> /dev/null|>> /config/acme.sh/acme-cron.log 2>\&1; s6-svc -u /var/run/s6/services/nginx 2>/dev/null|' "$CRON_FILE"
                echo "Updated crontab:"
                cat "$CRON_FILE"
                echo ""
            fi
        fi

        # Verify the ACME challenge proxy works
        echo ""
        echo "Verifying ACME challenge proxy..."
        JITSI_WEB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -m1 'jitsi.*web' || true)
        if [[ -n "$JITSI_WEB_CONTAINER" ]]; then
            docker exec "$JITSI_WEB_CONTAINER" mkdir -p /usr/share/jitsi-meet/.well-known/acme-challenge
            docker exec "$JITSI_WEB_CONTAINER" sh -c 'echo "acme-proxy-test-ok" > /usr/share/jitsi-meet/.well-known/acme-challenge/proxy-test'

            RESULT=$(curl -sf "http://${JITSI_HOSTNAME_NOPORT}/.well-known/acme-challenge/proxy-test" 2>/dev/null || true)
            docker exec "$JITSI_WEB_CONTAINER" rm -f /usr/share/jitsi-meet/.well-known/acme-challenge/proxy-test

            if [[ "$RESULT" == "acme-proxy-test-ok" ]]; then
                echo "✓ ACME challenge proxy is working correctly."
            else
                echo "✗ WARNING: ACME challenge proxy test failed."
                echo "  Make sure ARENA nginx has been restarted after adding the Jitsi server block."
                echo "  Expected 'acme-proxy-test-ok', got: '${RESULT}'"
            fi
        else
            echo "NOTE: Jitsi web container not running. Skipping proxy verification."
        fi

        echo ""
        echo "Done. acme.sh will use webroot mode for certificate renewal."
        echo "Nginx will no longer be stopped during renewal attempts."
        echo "Renewal logs: ${JITSI_CONFIG}/web/acme.sh/acme-cron.log"
    fi
fi
