#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SGSS Supabase multi-project full setup ==="

bash "$SCRIPT_DIR/00_base_setup.sh"
bash "$SCRIPT_DIR/01_traefik_setup.sh"
bash "$SCRIPT_DIR/02_supabase_per_project.sh"

echo
echo "=== All setup steps finished. ==="
echo "Next steps:"
echo "- Create DNS A records for all domains defined in configs/supabase-projects.json."
echo "- Add Traefik labels and the 'proxy' network to the relevant Supabase services"
echo "  in each project's docker-compose file so Studio/API are reachable via their domains."
