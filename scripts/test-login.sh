#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

echo "============================================"
echo " Test POST /api/auth/login-qr (macOS)"
echo "============================================"
echo ""

PAYLOAD='{"classCode":"1A2B3C","studentCode":"123456"}'

echo "--- Direct :2050 (via docker port mapping internal — biasanya tidak exposed) ---"
curl -s --max-time 10 -X POST "http://127.0.0.1:2050/api/auth/login-qr" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || echo "(tidak dapat diakses — normal jika port 2050 tidak di-map ke host)"
echo ""
echo ""

echo "--- Via nginx gurubot.sekolah (HTTPS) ---"
curl -s --max-time 10 -k -X POST "https://gurubot.sekolah/api/auth/login-qr" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
echo ""
echo ""

echo "--- Via nginx gurubot.sekolah (HTTP redirect) ---"
curl -s --max-time 10 -L -X POST "http://gurubot.sekolah/api/auth/login-qr" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || true
echo ""
echo ""

echo "Harapan: JSON dengan \"success\":true atau \"success\":false"
echo "Jika plain text \"Internal Server Error\" = app crash / belum jalan"
echo ""
echo "Cek data login di DB: scripts/test-db.sh"
echo ""
