#!/bin/bash

set -e

# Configure custom realms
echo "Initializing custom realm"
if [[ $KC_HOSTNAME ]]; then
    sed -E "s|(\"frontendUrl\":).*|\1 \"$KC_HOSTNAME\",|g" /opt/keycloak/data/import/${REALM_FILE} > /tmp/${REALM_FILE}
else
    cp /opt/keycloak/data/import/${REALM_FILE} /tmp/${REALM_FILE}
fi
/opt/keycloak/bin/kc.sh import --file=/tmp/${REALM_FILE} --override=false

# Start server
/opt/keycloak/bin/kc.sh start
