#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
gurubot_init_paths

OLLAMA_MODEL="qwen3:1.7b"

echo "============================================"
echo " GuruBot Local Deploy - Setup (macOS)"
echo " Bundle: $BUNDLE_ROOT"
echo "============================================"
echo ""

preflight() {
  gurubot_log "Preflight checks..."

  gurubot_require_docker
  gurubot_require_dir "$NEXTJS_DIR"
  gurubot_require_dir "${WHISPER_DIR}/app"

  if command -v mysql >/dev/null 2>&1; then
    gurubot_log "MySQL CLI ditemukan: $(command -v mysql)"
  else
    echo "[WARN] mysql CLI tidak ditemukan. Instal: brew install mysql"
    echo "       Pastikan MySQL 8.0 berjalan sebelum docker compose up."
  fi

  if brew services list 2>/dev/null | grep -q "mysql.*started"; then
    gurubot_log "MySQL service (brew) aktif"
  elif pgrep -x mysqld >/dev/null 2>&1; then
    gurubot_log "MySQL daemon terdeteksi"
  else
    echo "[WARN] MySQL belum terdeteksi berjalan."
    echo "       Start: brew services start mysql"
  fi

  gurubot_log "Preflight OK"
}

setup_ollama() {
  gurubot_log "Cek Ollama + model Qwen..."

  if ! command -v ollama >/dev/null 2>&1; then
    echo "[WARN] Ollama tidak ditemukan di PATH."
    echo "       Instal dari https://ollama.com/download/mac"
    echo "       Lalu: ollama pull $OLLAMA_MODEL"
    return 0
  fi

  if ! curl -sf --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "[WARN] Ollama belum merespons di port 11434."
    echo "       Buka aplikasi Ollama, lalu jalankan setup ulang."
    return 0
  fi

  if ollama list 2>/dev/null | grep -qi "$OLLAMA_MODEL"; then
    gurubot_log "Model $OLLAMA_MODEL sudah terinstal"
  else
    gurubot_log "Model $OLLAMA_MODEL belum ada — menjalankan ollama pull..."
    if ollama pull "$OLLAMA_MODEL"; then
      gurubot_log "Model $OLLAMA_MODEL siap"
    else
      echo "[WARN] ollama pull gagal — jalankan manual: ollama pull $OLLAMA_MODEL"
    fi
  fi
}

setup_env_docker() {
  gurubot_log "Menyiapkan .env.docker..."

  if [[ -f "$ENV_DOCKER" ]]; then
    gurubot_log ".env.docker sudah ada — lewati generate secret"
    return 0
  fi

  gurubot_require_file "$ENV_DOCKER_EXAMPLE"
  cp "$ENV_DOCKER_EXAMPLE" "$ENV_DOCKER"

  local nextauth_secret jwt_secret
  nextauth_secret="$(gurubot_generate_secret)"
  jwt_secret="$(gurubot_generate_secret)"

  echo ""
  echo "=== Konfigurasi MySQL untuk DATABASE_URL ==="
  echo "User MySQL = akun database di server MySQL, BUKAN user macOS."
  echo "Jika pakai dump production, isi sesuai DB yang sudah ada."
  echo ""

  local db_user db_pass db_name db_url
  read -r -p "MySQL user [default: root]: " db_user
  db_user="${db_user:-root}"
  read -r -s -p "MySQL password: " db_pass
  echo ""
  read -r -p "Nama database [default: gurubot_db]: " db_name
  db_name="${db_name:-gurubot_db}"

  if [[ -n "$db_pass" ]]; then
    db_url="mysql://${db_user}:${db_pass}@host.docker.internal:3306/${db_name}"
  else
    db_url="mysql://${db_user}@host.docker.internal:3306/${db_name}"
  fi

  gurubot_set_env_docker_value "DATABASE_URL" "$db_url"
  gurubot_set_env_docker_value "NEXTAUTH_SECRET" "$nextauth_secret"
  gurubot_set_env_docker_value "JWT_SECRET" "$jwt_secret"

  gurubot_log ".env.docker dibuat di $ENV_DOCKER"
}

verify_nextjs_build() {
  gurubot_log "Verifikasi artifact Next.js..."

  if [[ ! -f "${NEXTJS_DIR}/server.js" ]]; then
    gurubot_fail "server.js tidak ada di artifacts/nextjs — bundle tidak lengkap."
  fi
  if [[ ! -f "${NEXTJS_DIR}/.next/BUILD_ID" ]]; then
    gurubot_fail "BUILD_ID tidak ada — jalankan copy-nextjs-artifact.sh dari repo gurubot-pwa."
  fi

  gurubot_log "Artifact Next.js OK"
}

setup_dns_hosts() {
  gurubot_log "Menambah hosts entry gurubot.sekolah..."

  if grep -qE '[[:space:]]gurubot\.sekolah([[:space:]]|$)' /etc/hosts 2>/dev/null; then
    gurubot_log "hosts entry sudah ada"
    return 0
  fi

  echo "Perlu sudo untuk menulis /etc/hosts"
  if sudo sh -c 'grep -qE "[[:space:]]gurubot\.sekolah([[:space:]]|$)" /etc/hosts 2>/dev/null || echo "127.0.0.1   gurubot.sekolah" >> /etc/hosts'; then
    gurubot_log "hosts: 127.0.0.1 gurubot.sekolah"
  else
    echo "[WARN] Gagal menulis /etc/hosts — tambahkan manual:"
    echo "       127.0.0.1   gurubot.sekolah"
  fi

  sudo dscacheutil -flushcache 2>/dev/null || true
  sudo killall -HUP mDNSResponder 2>/dev/null || true
}

print_dns_lan_hint() {
  local lan_ip=""
  lan_ip="$(detect_lan_ip 2>/dev/null || true)"

  echo ""
  echo "=== DNS LAN (HP/tablet di WiFi) ==="
  echo "docker-compose.yml sudah menyertakan Technitium DNS (container) — jalan otomatis"
  echo "bareng 'docker compose up' di semua OS, termasuk macOS."
  echo "Pilihan lain jika perlu:"
  echo "  A) Router DHCP DNS → IP Mac server${lan_ip:+ ($lan_ip)} (Technitium jawab query DNS)"
  echo "  B) dnsmasq manual (legacy, lihat scripts/setup-dns.sh) — tidak perlu jika pakai Technitium"
  echo "  C) Fallback IP: scripts/setup-fallback-ip.sh"
  echo "  D) /etc/hosts manual di setiap perangkat"
}

preflight
setup_ollama
setup_env_docker
verify_nextjs_build
setup_dns_hosts
print_dns_lan_hint

echo ""
echo "[OK] Setup selesai."
echo ""
echo "Langkah berikutnya:"
echo "  1. Import dump MySQL ke database lokal"
echo "  2. scripts/setup-ssl.sh"
echo "  3. scripts/docker-up.sh"
echo ""
