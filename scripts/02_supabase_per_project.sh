#!/usr/bin/env bash
set -e

echo "=== [02] Supabase setup per project (hard separation) ==="

CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs/supabase-projects.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file $CONFIG_FILE not found."
  echo "Copy configs/supabase-projects.example.json to configs/supabase-projects.json and adjust it."
  exit 1
fi

# Optional argument: project ID to setup only one project
ONLY_PROJECT_ID="$1"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "[*] Installing jq..."
  sudo apt-get update -y
  sudo apt-get install -y jq
fi

# Supabase template repo (cloned once and reused)
BASE_SETUP_DIR="/opt/supabase-template"

if [ ! -d "$BASE_SETUP_DIR" ]; then
  echo "[*] Cloning Supabase repo into $BASE_SETUP_DIR..."
  sudo mkdir -p "$BASE_SETUP_DIR"
  sudo chown "$USER":"$USER" "$BASE_SETUP_DIR"
  cd "$BASE_SETUP_DIR"
  git clone https://github.com/supabase/supabase.git .
else
  echo "[*] Supabase template repo already exists at $BASE_SETUP_DIR."
  echo "[*] You can run 'git pull' in $BASE_SETUP_DIR later to update it."
fi

PROJECT_COUNT=$(jq '.projects | length' "$CONFIG_FILE")
echo "[*] Number of projects in config: $PROJECT_COUNT"

for (( i=0; i<PROJECT_COUNT; i++ )); do
  PROJECT_ID=$(jq -r ".projects[$i].id" "$CONFIG_FILE")

  # If ONLY_PROJECT_ID is set, skip other projects
  if [ -n "$ONLY_PROJECT_ID" ] && [ "$ONLY_PROJECT_ID" != "$PROJECT_ID" ]; then
    continue
  fi

  SUPABASE_DIR=$(jq -r ".projects[$i].supabase_dir" "$CONFIG_FILE")
  STUDIO_DOMAIN=$(jq -r ".projects[$i].studio_domain" "$CONFIG_FILE")
  API_DOMAIN=$(jq -r ".projects[$i].api_domain" "$CONFIG_FILE")
  ADMIN_EMAIL=$(jq -r ".projects[$i].admin_email" "$CONFIG_FILE")

  echo
  echo "=== Project: $PROJECT_ID ==="
  echo "Supabase directory: $SUPABASE_DIR"
  echo "Studio domain     : $STUDIO_DOMAIN"
  echo "API domain        : $API_DOMAIN"
  echo "Admin email       : $ADMIN_EMAIL"

  # Create directory for this project
  sudo mkdir -p "$SUPABASE_DIR"
  sudo chown "$USER":"$USER" "$SUPABASE_DIR"

  # Copy Docker setup from template repo
  if [ ! -d "$SUPABASE_DIR/docker" ]; then
    echo "[*] Copying Docker setup from template..."
    cp -R "$BASE_SETUP_DIR/docker" "$SUPABASE_DIR/"
  else
    echo "[*] Docker setup for $PROJECT_ID already exists – skipping copy."
  fi

  cd "$SUPABASE_DIR/docker"

  # Create .env if not present
  if [ ! -f ".env" ]; then
    echo "[*] Creating .env for project $PROJECT_ID..."

    JWT_SECRET=$(openssl rand -hex 32)
    ANON_KEY=$(openssl rand -hex 32)
    SERVICE_KEY=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)

    cat > .env <<EOF
# Environment variables for Supabase project: $PROJECT_ID

JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_KEY

POSTGRES_PASSWORD=$POSTGRES_PASSWORD

STUDIO_DOMAIN=$STUDIO_DOMAIN
API_DOMAIN=$API_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
EOF

    echo "[*] .env for $PROJECT_ID created – extend with SMTP etc. if needed."
  else
    echo "[*] .env for $PROJECT_ID already exists – not overwriting."
  fi

  # Set Docker Compose project name so container names are unique
  export COMPOSE_PROJECT_NAME="supabase_${PROJECT_ID}"

  echo "[*] Starting Supabase stack for $PROJECT_ID..."
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose up -d
  else
    docker compose up -d
  fi

  echo "[*] Project $PROJECT_ID started."
  echo "[NOTE] You still need to configure Traefik labels & the 'proxy' network in this project's docker-compose to expose Studio/API on the configured domains."
done

echo
echo "=== [02] Supabase project setup finished. ==="
echo "Existing projects were left intact, new ones were created/started."
