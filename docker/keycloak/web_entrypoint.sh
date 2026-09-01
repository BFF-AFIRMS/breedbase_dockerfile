#!/bin/bash

set -e

# Configure custom realms
echo "Initializing BFF-AFIRMS realm"
if [[ $KC_HOSTNAME ]]; then
    sed -E "s|(\"frontendUrl\":).*|\1 \"$KC_HOSTNAME\",|g" /opt/keycloak/data/import/bff-afirms.json > /tmp/bff-afirms.json
else
    cp /opt/keycloak/data/import/bff-afirms.json /tmp/bff-afirms.json
fi
/opt/keycloak/bin/kc.sh import --file=/tmp/bff-afirms.json --override=false --spi-connections-jpa--quarkus--migration-strategy=update

# Start server
/opt/keycloak/bin/kc.sh start
