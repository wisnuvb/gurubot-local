#!/usr/bin/env bash
# Tampilkan IP LAN, URL akses, dan path file penting untuk deploy sekolah.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

LAN_IP=""
LAN_IP="$(detect_lan_ip 2>/dev/null || true)"

echo "============================================"
echo " GuruBot - Info Server (macOS)"
echo "============================================"
echo ""
if [[ -n "$LAN_IP" ]]; then
  echo "IP LAN Mac server (WiFi/LAN):  $LAN_IP"
else
  echo "IP LAN: tidak terdeteksi — cek koneksi WiFi"
fi
echo ""
echo "URL akses dari HP/tablet di WiFi yang sama:"
echo "  https://gurubot.sekolah/welcome   (butuh dnsmasq + DNS router/HP)"
echo "  https://${LAN_IP:-IP-SERVER}/welcome         (tanpa DNS, pakai QR)"
echo ""
echo "Catatan IP:"
echo "  - IP ini OTOMATIS terdeteksi dari jaringan saat ini"
echo "  - Bisa BERUBAH jika pindah WiFi/router tanpa IP statis"
echo "  - Disarankan: set IP statis di router (DHCP reservation)"
echo ""
echo "File CA untuk Android:"
echo "  ${BUNDLE_ROOT}/certs/mobile/gurubot-mkcert-rootCA.pem"
echo "  (generate: ./scripts/setup-ssl-mobile.sh)"
echo ""
echo "Skrip terkait:"
echo "  ./scripts/setup-ssl.sh           - sertifikat HTTPS"
echo "  ./scripts/setup-ssl-mobile.sh    - export CA ke HP"
echo "  ./scripts/setup-dnsmasq.sh       - DNS LAN (Mac)"
echo "  ./scripts/docker-up.sh           - start stack"
echo ""
