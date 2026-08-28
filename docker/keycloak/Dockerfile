# -----------------------------------------------------------------------------
# Build Layer

FROM keycloak/keycloak:26.7.2 AS builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

# Themes
ADD --chown=keycloak:keycloak themes/bff-afirms-theme /opt/keycloak/themes/bff-afirms-theme

# Build
WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

# -----------------------------------------------------------------------------
# Final Layer

FROM keycloak/keycloak:26.7.2
COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY web_entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
HEALTHCHECK --interval=10s --timeout=5s --retries=30 --start-period=5s \
  CMD bash -c ":> /dev/tcp/localhost/$KC_HTTP_PORT"
