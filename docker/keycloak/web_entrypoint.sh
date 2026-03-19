#!/bin/bash

# # Configure the master realm frontend url
# if [[ $KC_HOSTNAME_ADMIN_URL ]]; then
#     /opt/keycloak/bin/kcadm.sh config credentials --server $KC_HOSTNAME --realm master --user $KC_BOOTSTRAP_ADMIN_USERNAME --password $KC_BOOTSTRAP_ADMIN_PASSWORD
#     /opt/keycloak/bin/kcadm.sh update realms/master --server $KC_HOSTNAME --realm master -s attributes.frontendUrl="${KC_HOSTNAME_ADMIN_URL}"
# fi

# Configure the master realm
if [[ $KC_HOSTNAME_ADMIN_URL ]]; then
    sed -i -E "s|(\"frontendUrl\":).*|\1 \"$KC_FRONTEND_URL\",|g" /opt/keycloak/data/import/master-realm.json
fi
./opt/keycloak/bin/kc.sh import --file=/opt/keycloak/data/import/master-realm.json --override=true

# Configure custom realms
if [[ $KC_FRONTEND_URL ]]; then
    sed -i -E "s|(\"frontendUrl\":).*|\1 \"$KC_FRONTEND_URL\",|g" /opt/keycloak/data/import/breedbase-realm.json
fi
./opt/keycloak/bin/kc.sh import --file=/opt/keycloak/data/import/breedbase-realm.json --override=false


# Start server
/opt/keycloak/bin/kc.sh start-dev
