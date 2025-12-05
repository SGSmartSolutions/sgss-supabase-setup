#!/usr/bin/env bash
set -e

echo "=== [01] Traefik reverse proxy setup ==="

CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs/supabase-projects.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file $CONFIG_FILE not found."
  echo "Copy configs/supabase-projects.example.json to configs/supabase-projects.json and adjust it."
  exit 1
fi

TRAEFIK_DASHBOARD_DOMAIN=$(jq -r '.base.traefik_dashboard_domain' "$CONFIG_FILE")
LETSENCRYPT_EMAIL=$(jq -r '.base.letsencrypt_email' "$CONFIG_FILE")

TRAEFIK_DIR="/opt/traefik"

###################################
# 1. Docker network 'proxy'
###################################
echo "[*] Creating Docker network 'proxy' (if not existing)..."

if ! docker network ls | grep -q "proxy"; then
  docker network create proxy
else
  echo "[*] Docker network 'proxy' already exists."
fi

###################################
# 2. Directory structure
###################################
echo "[*] Preparing Traefik directory at $TRAEFIK_DIR..."

sudo mkdir -p "$TRAEFIK_DIR"
sudo chown "$USER":"$USER" "$TRAEFIK_DIR"

cd "$TRAEFIK_DIR"

###################################
# 3. traefik.yml (static configuration)
###################################
cat > traefik.yml <<EOF
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false

api:
  dashboard: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: "${LETSENCRYPT_EMAIL}"
      storage: /acme.json
      httpChallenge:
        entryPoint: web
EOF

###################################
# 4. acme.json
###################################
if [ ! -f acme.json ]; then
  touch acme.json
  chmod 600 acme.json
fi

###################################
# 5. docker-compose.yml for Traefik
###################################
cat > docker-compose.yml <<EOF
version: "3.9"

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/acme.json"
      - "--api.dashboard=true"
    ports:
      - "80:80"
      - "443:443"
    networks:
      - proxy
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./traefik.yml:/etc/traefik/traefik.yml:ro"
      - "./acme.json:/acme.json"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`${TRAEFIK_DASHBOARD_DOMAIN}\`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"

networks:
  proxy:
    external: true
EOF

###################################
# 6. Start Traefik
###################################
echo "[*] Starting Traefik..."
if command -v docker-compose >/dev/null 2>&1; then
  docker-compose up -d
else
  docker compose up -d
fi

echo
echo "=== [01] Traefik setup finished. ==="
echo "DNS reminder:"
echo "- Create an A record for ${TRAEFIK_DASHBOARD_DOMAIN} pointing to this server's IP."
echo "Then you can access the Traefik dashboard at: https://${TRAEFIK_DASHBOARD_DOMAIN}"
