#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

CERT_FILE="${CERTS_DIR}/gurubot.sekolah.pem"
KEY_FILE="${CERTS_DIR}/gurubot.sekolah-key.pem"

echo "============================================"
echo " GuruBot - Docker Compose Up (macOS)"
echo "============================================"
echo ""

gurubot_require_docker

if [[ ! -f "$ENV_DOCKER" ]]; then
  if [[ -f "$ENV_DOCKER_EXAMPLE" ]]; then
    echo "[INFO] Membuat .env.docker dari template..."
    cp "$ENV_DOCKER_EXAMPLE" "$ENV_DOCKER"
    echo "[WARN] Edit $ENV_DOCKER — isi DATABASE_URL dan secret sebelum produksi."
  else
    gurubot_fail "Template tidak ditemukan: $ENV_DOCKER_EXAMPLE"
  fi
fi

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  gurubot_fail "Sertifikat belum ada. Jalankan: scripts/setup-ssl.sh"
fi

cd "$BUNDLE_ROOT"

echo "[INFO] Build dan start container..."
docker compose up -d --build

echo ""
echo "[INFO] Menunggu healthcheck (maks ~60 detik)..."
sleep 15

echo ""
docker compose ps
echo ""

set +e
"$SCRIPT_DIR/docker-health-check.sh"
HC=$?
set -e

echo ""
if [[ "$HC" -eq 0 ]]; then
  echo "[OK] GuruBot Docker berjalan — buka https://gurubot.sekolah"
else
  echo "[WARN] Beberapa health check gagal — lihat: docker compose logs"
  echo ""
  echo "--- Log gurubot-app (20 baris terakhir) ---"
  docker compose logs app --tail 20 2>/dev/null || true
fi
echo ""

exit "$HC"
