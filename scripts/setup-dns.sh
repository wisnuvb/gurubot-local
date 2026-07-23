#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

echo "============================================"
echo " GuruBot - Setup DNS (macOS)"
echo "============================================"
echo ""

LAN_IP=""
if ! LAN_IP="$(detect_lan_ip 2>/dev/null)"; then
  read -r -p "Masukkan IPv4 LAN Mac server: " LAN_IP
fi

if [[ -z "$LAN_IP" ]]; then
  gurubot_fail "IP LAN wajib diisi."
fi

echo "IP LAN server: $LAN_IP"
echo ""

# --- /etc/hosts di Mac server ---
echo "[1/2] /etc/hosts di Mac server..."
if grep -qE '[[:space:]]gurubot\.sekolah([[:space:]]|$)' /etc/hosts 2>/dev/null; then
  echo "[INFO] Entry gurubot.sekolah sudah ada di /etc/hosts"
else
  echo "Perlu sudo untuk menulis /etc/hosts"
  sudo sh -c "echo '127.0.0.1   gurubot.sekolah' >> /etc/hosts"
  echo "[OK] Ditambahkan: 127.0.0.1 gurubot.sekolah"
fi

sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

# --- Petunjuk dnsmasq ---
echo ""
echo "[2/2] DNS LAN untuk perangkat WiFi (dnsmasq)"
echo ""
echo "Untuk menggantikan Acrylic DNS di Windows, instal dnsmasq:"
echo "  brew install dnsmasq"
echo ""
echo "Buat file /opt/homebrew/etc/dnsmasq.d/gurubot.conf (Apple Silicon)"
echo "atau /usr/local/etc/dnsmasq.d/gurubot.conf (Intel):"
echo ""
echo "  address=/gurubot.sekolah/${LAN_IP}"
echo "  listen-address=${LAN_IP},127.0.0.1"
echo ""
echo "Start service:"
echo "  sudo brew services start dnsmasq"
echo ""
echo "Atur router DHCP DNS ke: ${LAN_IP}"
echo "Atur DNS adapter WiFi Mac server: 127.0.0.1 (primer), 8.8.8.8 (sekunder)"
echo ""
echo "Verifikasi:"
echo "  nslookup gurubot.sekolah"
echo "  curl -k https://gurubot.sekolah/api/health"
echo ""
echo "Alternatif tanpa dnsmasq: tambahkan di setiap HP/tablet (/etc/hosts atau app hosts):"
echo "  ${LAN_IP}   gurubot.sekolah"
echo ""
echo "Catatan: docker-compose.yml sudah menyertakan Technitium DNS (container) —"
echo "jalur di atas (dnsmasq) hanya perlu jika memilih tidak memakai Technitium."
echo "Lihat docs/DNS-LAN.md untuk detail router dan troubleshooting."
echo ""
