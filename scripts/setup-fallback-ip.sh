#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

echo "============================================"
echo " GuruBot - Fallback IP (macOS)"
echo "============================================"
echo ""

LAN_IP=""
if ! LAN_IP="$(detect_lan_ip 2>/dev/null)"; then
  read -r -p "Masukkan IPv4 LAN Mac server: " LAN_IP
fi

if [[ -z "$LAN_IP" ]]; then
  gurubot_fail "IP LAN wajib diisi."
fi

gurubot_require_file "$ENV_DOCKER"

echo ""
echo "PERINGATAN: NEXT_PUBLIC_API_URL disematkan saat build Next.js."
echo "Jika auth/PWA bermasalah setelah ganti IP, rebuild artifact dengan URL baru."
echo ""

BASE_URL="https://${LAN_IP}"
gurubot_set_env_docker_value "NEXTAUTH_URL" "$BASE_URL"
gurubot_set_env_docker_value "NEXT_PUBLIC_API_URL" "$BASE_URL"

echo "[OK] .env.docker diupdate ke $BASE_URL"
echo ""
echo "Regenerate sertifikat agar SAN mencakup IP (jika belum):"
echo "  scripts/setup-ssl.sh"
echo ""
echo "Restart stack:"
echo "  scripts/docker-down.sh && scripts/docker-up.sh"
echo ""
echo "Akses dari HP: $BASE_URL"
echo ""
