# Keycloak

1. Export

    ```bash
    docker compose exec --user $(id -u):$(id -g) keycloak /opt/keycloak/bin/kc.sh export --realm BFF-AFIRMS --file /data/keycloak/export/export.json --users same_file
    ```
