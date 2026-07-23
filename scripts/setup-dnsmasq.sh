#!/usr/bin/env bash
# Setup dnsmasq di Mac agar perangkat WiFi bisa resolve gurubot.sekolah → IP Mac server.
#
# Usage: ./scripts/setup-dnsmasq.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

echo "============================================"
echo " GuruBot - Setup dnsmasq (DNS LAN, macOS)"
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

if ! command -v brew >/dev/null 2>&1; then
  gurubot_fail "Homebrew tidak ditemukan. Instal dari https://brew.sh"
fi

if ! command -v dnsmasq >/dev/null 2>&1; then
  echo "[1/4] Instal dnsmasq..."
  brew install dnsmasq
else
  echo "[1/4] dnsmasq sudah terinstal."
fi

# Homebrew prefix (Apple Silicon vs Intel)
BREW_PREFIX="$(brew --prefix)"
DNSMASQ_CONF_DIR="${BREW_PREFIX}/etc/dnsmasq.d"
DNSMASQ_CONF="${DNSMASQ_CONF_DIR}/gurubot.conf"
DNSMASQ_MAIN="${BREW_PREFIX}/etc/dnsmasq.conf"

mkdir -p "$DNSMASQ_CONF_DIR"

echo "[2/4] Tulis config $DNSMASQ_CONF ..."
cat >"$DNSMASQ_CONF" <<EOF
# GuruBot local deploy — resolve gurubot.sekolah untuk perangkat LAN
address=/gurubot.sekolah/${LAN_IP}

# Dengarkan di loopback + IP LAN WiFi (jangan 0.0.0.0 — hindari konflik)
listen-address=127.0.0.1,${LAN_IP}

# Forward DNS lain ke resolver publik
server=8.8.8.8
server=1.1.1.1

# Jangan baca /etc/hosts Mac (hindari 127.0.0.1 gurubot.sekolah bocor ke LAN)
no-hosts

# Log query (opsional, comment jika terlalu verbose)
# log-queries
EOF

# Pastikan dnsmasq.conf utama include folder .d
if [[ -f "$DNSMASQ_MAIN" ]] && ! grep -q '^conf-dir=.*/dnsmasq.d' "$DNSMASQ_MAIN" 2>/dev/null; then
  echo "conf-dir=${DNSMASQ_CONF_DIR},*.conf" >>"$DNSMASQ_MAIN"
  echo "[INFO] Menambahkan conf-dir ke $DNSMASQ_MAIN"
fi

echo "[3/4] Start dnsmasq (butuh sudo untuk port 53)..."
sudo brew services restart dnsmasq 2>/dev/null || sudo brew services start dnsmasq

sleep 2

echo "[4/4] Verifikasi..."
if dig +short @"${LAN_IP}" gurubot.sekolah 2>/dev/null | grep -q "^${LAN_IP}$"; then
  echo "[ OK ] dig @${LAN_IP} gurubot.sekolah → ${LAN_IP}"
else
  echo "[WARN] dig gagal — cek: sudo brew services list | grep dnsmasq"
  echo "       Port 53 mungkin dipakai macOS. Coba: sudo lsof -i :53"
fi

echo ""
echo "============================================"
echo " Langkah di PERANGKAT LAIN (HP/tablet)"
echo "============================================"
echo ""
echo "Atur DNS WiFi manual ke IP Mac server:"
echo "  DNS 1: ${LAN_IP}"
echo "  DNS 2: 8.8.8.8 (opsional fallback)"
echo ""
echo "  iPhone/iPad: Settings → Wi-Fi → (i) jaringan → Configure DNS → Manual"
echo "  Android:     Wi-Fi → Modify → Advanced → DNS → ${LAN_IP}"
echo ""
echo "Atau set router DHCP DNS ke: ${LAN_IP} (semua perangkat otomatis)"
echo ""
echo "Lalu buka: https://gurubot.sekolah/welcome"
echo ""
echo "SSL di HP: install root CA mkcert — jalankan: ./scripts/setup-ssl-mobile.sh"
echo ""
