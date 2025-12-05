#!/usr/bin/env bash
set -e

echo "=== [00] Base setup (Ubuntu + Docker + UFW) ==="

# Path to config file
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs/supabase-projects.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file $CONFIG_FILE not found."
  echo "Copy configs/supabase-projects.example.json to configs/supabase-projects.json and adjust it."
  exit 1
fi

# Ensure jq is installed (for reading JSON config)
if ! command -v jq >/dev/null 2>&1; then
  echo "[*] Installing jq..."
  sudo apt-get update -y
  sudo apt-get install -y jq
fi

SSH_PORT=$(jq -r '.base.ssh_port' "$CONFIG_FILE")

###################################
# 1. System update
###################################
echo "[*] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

###################################
# 2. Useful tools
###################################
echo "[*] Installing basic tools..."
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  ufw

###################################
# 3. Install Docker (official repo)
###################################
if ! command -v docker >/dev/null 2>&1; then
  echo "[*] Installing Docker..."

  sudo mkdir -p /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  fi

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo usermod -aG docker "$USER"
else
  echo "[*] Docker already installed."
fi

###################################
# 4. docker-compose binary (optional convenience)
###################################
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "[*] Installing docker-compose binary..."
  sudo curl -L "https://github.com/docker/compose/releases/download/2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
else
  echo "[*] docker-compose already present."
fi

###################################
# 5. UFW firewall
###################################
echo "[*] Configuring UFW firewall..."

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow "${SSH_PORT}"/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

sudo ufw --force enable

echo
echo "=== [00] Base setup finished. ==="
echo "If this is the first time Docker was installed, you may need to log out and log back in so the docker group takes effect."
