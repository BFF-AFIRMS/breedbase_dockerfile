#!/bin/bash

set -e

# Configure custom realms
echo "Initializing Breedbase realm"
if [[ $KC_HOSTNAME ]]; then
    sed -i -E "s|(\"frontendUrl\":).*|\1 \"$KC_HOSTNAME\",|g" /opt/keycloak/data/import/breedbase-realm.json
fi
/opt/keycloak/bin/kc.sh import --file=/opt/keycloak/data/import/breedbase-realm.json --override=false


# Start server
/opt/keycloak/bin/kc.sh start-dev
