from config.settings.common_settings import DATABASES, OIDC_CONFIG
import os
# Require SSL for database connections
DATABASES["default"]["OPTIONS"]["sslmode"] = "require"

for i, provider in enumerate(OIDC_CONFIG):
    if provider["provider_id"] == "keycloak":
        OIDC_CONFIG[i]["settings"]["oauth_pkce_enabled"] = True

# Network
prefix              = "mathesar"

# Will be served by caddy
MEDIA_URL           = f"/{prefix}/media/"
STATIC_URL          = f"/{prefix}/static/"
LOGIN_URL           = "/auth/login/"
LOGIN_REDIRECT_URL  = "/"

if os.getenv("DJANGO_LOGOUT_REDIRECT_URL"):
    LOGOUT_REDIRECT_URL = os.getenv("DJANGO_LOGOUT_REDIRECT_URL")
