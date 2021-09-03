#!/bin/bash

source .env
set -x

HOSTNAME="arenaxr.org"
cli_token_json=$(cat ./data/keys/cli_token.json)

if [[ ! -z "$SLACK_DEV_CHANNEL_WEBHOOK" ]]; then
    username=$(echo $cli_token_json | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
    cli_token=$(echo $cli_token_json | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")
    alias_name="${HOSTNAME%%.*}"
    curl_data="{\"text\":\"New MQTT token for $HOSTNAME\", \"attachments\": [ {\"text\":\"\`\`\`alias ${alias_name}_pub='mosquitto_pub -h $HOSTNAME -p 8883 -u $username -P $cli_token'\`\`\`\"}, {\"text\":\"\`\`\`alias ${alias_name}_sub='mosquitto_sub -h $HOSTNAME -p 8883 -u $username -P $cli_token'\`\`\`\"} ]}"
    curl -X POST -H 'Content-type: application/json' --data "$curl_data" $SLACK_DEV_CHANNEL_WEBHOOK
fi
