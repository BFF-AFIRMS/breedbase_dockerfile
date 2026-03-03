#!/bin/bash

# allow keycloak to be accessible over localhost for DEVELOPMENT mode
sed -i -E 's|("frontendUrl":).*|\1 "http://localhost:9080/auth",|g' /opt/keycloak/data/import/realm.json
/opt/keycloak/bin/kc.sh start-dev --import-realm
