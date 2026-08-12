#!/bin/bash

# Fix Jitsi's acme.sh certificate renewal to use webroot mode instead of standalone.
#
# PROBLEM: The default Jitsi Docker acme.sh setup uses standalone mode, which stops
# nginx during renewal. When ARENA nginx proxies the ACME challenge (port 80 → 8000),
# the renewal can fail, leaving nginx dead and Jitsi unreachable for ~24 hours.
#
# FIX: Switch acme.sh to webroot mode so nginx is never stopped. The ACME challenge
# files are served by nginx from the Jitsi web root, proxied through ARENA nginx.
# A safety net ensures nginx is always restarted after acme.sh runs.
#
# USAGE: Run this after initial Jitsi Docker setup and after running jitsi-add.sh.
#   ./jitsi-fix-acme.sh
#
# PREREQUISITES:
#   - Jitsi Docker stack is running (docker compose up -d)
#   - jitsi-add.sh has been run (ARENA nginx proxies ACME challenges to Jitsi)

set -euo pipefail

# Determine JITSI_HOSTNAME from available .env files
# Supports running from either the ARENA services dir or the Jitsi docker dir
if [[ -f .env ]]; then
    JITSI_HOSTNAME=$(grep -m1 '^JITSI_HOSTNAME=' .env 2>/dev/null | cut -d= -f2 || true)
    if [[ -z "${JITSI_HOSTNAME:-}" ]]; then
        # Jitsi .env uses LETSENCRYPT_DOMAIN instead of JITSI_HOSTNAME
        JITSI_HOSTNAME=$(grep -m1 '^LETSENCRYPT_DOMAIN=' .env 2>/dev/null | cut -d= -f2 || true)
    fi
fi

if [[ -z "${JITSI_HOSTNAME:-}" ]]; then
    echo "ERROR: Could not find JITSI_HOSTNAME or LETSENCRYPT_DOMAIN in .env"
    echo "Run this script from either the arena-services-docker or jitsi-docker directory."
    exit 1
fi

JITSI_HOSTNAME_NOPORT=$(echo "${JITSI_HOSTNAME}" | cut -f1 -d":")
JITSI_CONFIG="${HOME}/.jitsi-meet-cfg"

# Locate the acme.sh domain config (try ECC first, then RSA)
ACME_CONF="${JITSI_CONFIG}/web/acme.sh/${JITSI_HOSTNAME_NOPORT}_ecc/${JITSI_HOSTNAME_NOPORT}.conf"
if [[ ! -f "$ACME_CONF" ]]; then
    ACME_CONF="${JITSI_CONFIG}/web/acme.sh/${JITSI_HOSTNAME_NOPORT}/${JITSI_HOSTNAME_NOPORT}.conf"
fi

if [[ ! -f "$ACME_CONF" ]]; then
    echo "ERROR: Could not find acme.sh config for ${JITSI_HOSTNAME_NOPORT}."
    echo "Looked in: ${JITSI_CONFIG}/web/acme.sh/"
    echo "Make sure the Jitsi Docker stack has been started at least once with ENABLE_LETSENCRYPT=1."
    exit 1
fi

echo "Found acme.sh config: ${ACME_CONF}"

# Check if already using webroot mode
if grep -q "Le_Webroot='/usr/share/jitsi-meet'" "$ACME_CONF"; then
    echo "acme.sh is already configured for webroot mode. No changes needed."
    exit 0
fi

echo ""
echo "Current mode: standalone (stops nginx during renewal)"
echo "Switching to: webroot (nginx stays running)"
echo ""

# 1. Switch from standalone to webroot mode
sed -i "s|Le_Webroot='no'|Le_Webroot='/usr/share/jitsi-meet'|" "$ACME_CONF"

# 2. Remove PreHook that kills nginx
sed -i "s|Le_PreHook='.*'|Le_PreHook=''|" "$ACME_CONF"

# 3. Remove PostHook (no longer needed since nginx stays running)
sed -i "s|Le_PostHook='.*'|Le_PostHook=''|" "$ACME_CONF"

# 4. Add RenewHook to reload nginx after successful cert renewal
sed -i "s|Le_RenewHook=''|Le_RenewHook='nginx -s reload'|" "$ACME_CONF"

echo "Updated acme.sh config:"
grep -E 'Le_Webroot|Le_PreHook|Le_PostHook|Le_RenewHook|Le_ReloadCmd' "$ACME_CONF"
echo ""

# 5. Fix the crontab: add logging and nginx safety net
CRON_FILE="${JITSI_CONFIG}/web/crontabs/root"
if [[ -f "$CRON_FILE" ]]; then
    if grep -q '> /dev/null' "$CRON_FILE"; then
        echo "Updating crontab: adding logging and nginx safety restart..."
        sed -i 's|> /dev/null|>> /config/acme.sh/acme-cron.log 2>\&1; s6-svc -u /var/run/s6/services/nginx 2>/dev/null|' "$CRON_FILE"
        echo "Updated crontab:"
        cat "$CRON_FILE"
        echo ""
    else
        echo "Crontab already modified (no '> /dev/null' found). Skipping."
    fi
else
    echo "WARNING: Could not find crontab at ${CRON_FILE}. Manual crontab update may be needed."
fi

# 6. Verify the ACME challenge proxy works
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
        echo "  Make sure jitsi-add.sh has been run and ARENA nginx is reloaded."
        echo "  Expected 'acme-proxy-test-ok', got: '${RESULT}'"
        exit 1
    fi
else
    echo "WARNING: Could not find Jitsi web container. Skipping proxy verification."
    echo "Make sure the Jitsi Docker stack is running."
fi

echo ""
echo "Done. acme.sh will now use webroot mode for certificate renewal."
echo "Nginx will no longer be stopped during renewal attempts."
echo "Renewal logs will be written to: /config/acme.sh/acme-cron.log"
echo "(accessible on host at: ${JITSI_CONFIG}/web/acme.sh/acme-cron.log)"
