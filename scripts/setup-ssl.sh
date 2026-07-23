#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

CERT_FILE="${CERTS_DIR}/gurubot.sekolah.pem"
KEY_FILE="${CERTS_DIR}/gurubot.sekolah-key.pem"

echo "============================================"
echo " GuruBot - Setup SSL (mkcert, macOS)"
echo "============================================"
echo ""

gurubot_require_cmd mkcert "Instal: brew install mkcert && brew install nss (untuk Firefox)"

mkdir -p "$CERTS_DIR"

echo "[1/3] Install root CA mkcert di Mac server..."
if ! mkcert -install 2>/dev/null; then
  echo "[WARN] mkcert -install gagal — mungkin perlu sudo atau konfirmasi Keychain."
fi

echo ""
echo "[2/3] Deteksi IP LAN..."
LAN_IP=""
if LAN_IP="$(detect_lan_ip 2>/dev/null)"; then
  echo "IP LAN: $LAN_IP"
  MKCERT_ARGS=(gurubot.sekolah localhost 127.0.0.1 "$LAN_IP")
else
  echo "[WARN] IP LAN tidak terdeteksi — sertifikat tanpa IP fallback."
  MKCERT_ARGS=(gurubot.sekolah localhost 127.0.0.1)
fi

echo ""
echo "[3/3] Generate sertifikat ke $CERTS_DIR..."
(
  cd "$CERTS_DIR"
  mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" "${MKCERT_ARGS[@]}"
)

echo ""
echo "[OK] Sertifikat siap:"
echo "  $CERT_FILE"
echo "  $KEY_FILE"
echo ""
echo "Root CA mkcert (bagikan ke HP/tablet):"
echo "  $(mkcert -CAROOT)/rootCA.pem"
echo ""
echo "Langkah berikutnya:"
echo "  1. Trust root CA di HP/tablet (lihat docs/SSL.md)"
echo "  2. cp config/.env.docker.example .env.docker  (jika belum)"
echo "  3. scripts/docker-up.sh"
echo ""
