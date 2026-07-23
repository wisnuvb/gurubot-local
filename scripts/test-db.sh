#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

echo "============================================"
echo " Test koneksi MySQL (Prisma, macOS)"
echo "============================================"
echo ""

gurubot_require_cmd node
gurubot_require_file "$ENV_DOCKER"

if [[ ! -f "${NEXTJS_DIR}/node_modules/@prisma/client/package.json" ]]; then
  gurubot_fail "@prisma/client belum ada di artifacts/nextjs/node_modules. Build Docker akan menjalankan prisma generate."
fi

DATABASE_URL="$(gurubot_load_env_docker DATABASE_URL || true)"
if [[ -z "$DATABASE_URL" ]]; then
  gurubot_fail "DATABASE_URL kosong di .env.docker"
fi

# test-db.js membaca artifacts/nextjs/.env — buat sementara dari .env.docker
TMP_ENV=""
BACKUP_ENV=""
cleanup() {
  if [[ -n "$BACKUP_ENV" && -f "$BACKUP_ENV" ]]; then
    mv -f "$BACKUP_ENV" "${NEXTJS_DIR}/.env"
  elif [[ -n "$TMP_ENV" && -f "$TMP_ENV" ]]; then
    rm -f "$TMP_ENV"
    [[ -f "${NEXTJS_DIR}/.env" ]] && rm -f "${NEXTJS_DIR}/.env"
  fi
}
trap cleanup EXIT

if [[ -f "${NEXTJS_DIR}/.env" ]]; then
  BACKUP_ENV="$(mktemp)"
  cp "${NEXTJS_DIR}/.env" "$BACKUP_ENV"
fi

printf 'DATABASE_URL=%s\n' "$DATABASE_URL" >"${NEXTJS_DIR}/.env"
TMP_ENV="${NEXTJS_DIR}/.env"

pushd "$NEXTJS_DIR" >/dev/null
set +e
node "$SCRIPTS_DIR/maintainer/test-db.js" "$NEXTJS_DIR"
EXIT_CODE=$?
set -e
popd >/dev/null

echo ""
if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "Perbaiki .env.docker lalu jalankan ulang."
  echo "Pastikan MySQL listen di host (bukan hanya socket) dan host.docker.internal dapat diakses dari container."
else
  echo "Jika login masih 500, cek: docker compose logs app"
fi
echo ""

exit "$EXIT_CODE"
