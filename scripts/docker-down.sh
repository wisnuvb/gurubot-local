#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

echo "============================================"
echo " GuruBot - Docker Compose Down (macOS)"
echo "============================================"
echo ""

gurubot_require_docker

cd "$BUNDLE_ROOT"
docker compose down

echo ""
echo "[OK] Semua container GuruBot dihentikan."
echo ""
