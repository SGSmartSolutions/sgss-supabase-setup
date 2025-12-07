#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SGSS Supabase Setup – Full Run ==="

echo
echo "[1/3] 00_base_setup.sh"
bash "$SCRIPT_DIR/00_base_setup.sh"

echo
echo "[2/3] 01_traefik_setup.sh"
bash "$SCRIPT_DIR/01_traefik_setup.sh"

echo
echo "[3/3] 02_supabase_per_project.sh"
bash "$SCRIPT_DIR/02_supabase_per_project.sh"

echo
echo "=== Alle Schritte ausgeführt. ==="
echo "Jetzt kannst du die DNS-Einträge für deine Domains setzen und (falls gewünscht) deinen Traefik-Reverse-Proxy auf die Supabase-Container zeigen lassen."
