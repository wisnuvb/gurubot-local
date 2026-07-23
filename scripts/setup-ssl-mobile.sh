#!/usr/bin/env bash
# Siapkan root CA mkcert untuk di-install di HP/tablet (fix "koneksi tidak aman").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

gurubot_require_cmd mkcert

CA_DIR="$(mkcert -CAROOT)"
CA_FILE="${CA_DIR}/rootCA.pem"
OUT_DIR="${BUNDLE_ROOT}/certs/mobile"
OUT_FILE="${OUT_DIR}/gurubot-mkcert-rootCA.pem"

if [[ ! -f "$CA_FILE" ]]; then
  echo "Root CA belum ada. Jalankan dulu: ./scripts/setup-ssl.sh"
  exit 1
fi

mkdir -p "$OUT_DIR"
cp "$CA_FILE" "$OUT_FILE"

echo "============================================"
echo " GuruBot - Trust SSL di HP/Tablet"
echo "============================================"
echo ""
echo "File CA untuk perangkat lain:"
echo "  $OUT_FILE"
echo ""
echo "--- Android ---"
echo "1. Kirim file ke HP (AirDrop/email/USB)"
echo "2. Settings → Security → Encryption & credentials"
echo "3. Install a certificate → CA certificate"
echo "4. Pilih gurubot-mkcert-rootCA.pem"
echo ""
echo "--- iPhone / iPad ---"
echo "1. AirDrop atau email file ke perangkat"
echo "2. Buka file → Install Profile"
echo "3. Settings → General → About → Certificate Trust Settings"
echo "4. Aktifkan trust untuk mkcert root CA"
echo ""
echo "--- Verifikasi di HP ---"
LAN_IP=""
if LAN_IP="$(detect_lan_ip 2>/dev/null)"; then
  echo "Buka https://${LAN_IP}/welcome — tanpa peringatan SSL"
else
  echo "Buka https://<IP-SERVER>/welcome — tanpa peringatan SSL"
fi
echo ""
echo "Buka folder certs/mobile:"
open "$OUT_DIR" 2>/dev/null || true
