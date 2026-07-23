#!/usr/bin/env bash
# Build gurubot-pwa (profil sekolah) + copy artifact ke gurubot-local-deploy.
#
# Default: GURUBOT_BUILD_ENV=local → yarn memakai .env.school
# (bukan .env.production / app.gurubot.io).
#
# Usage:
#   ./scripts/maintainer/build-and-copy-nextjs.sh [path/to/gurubot-pwa]
#
# Override URL deploy lokal:
#   NEXTAUTH_URL=https://192.168.1.50 NEXT_PUBLIC_API_URL=https://192.168.1.50 \
#     ./scripts/maintainer/build-and-copy-nextjs.sh
#
# Override profil (jarang):
#   GURUBOT_BUILD_ENV=production ./scripts/maintainer/build-and-copy-nextjs.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PWA_ROOT="${1:-../gurubot-pwa}"

if [[ "$PWA_ROOT" != /* ]]; then
  if [[ -d "$DEPLOY_ROOT/$PWA_ROOT" ]]; then
    PWA_ROOT="$(cd "$DEPLOY_ROOT/$PWA_ROOT" && pwd)"
  else
    PWA_ROOT="$(cd "$PWA_ROOT" && pwd)"
  fi
fi

if [[ ! -f "$PWA_ROOT/package.json" ]]; then
  echo "ERROR: gurubot-pwa tidak ditemukan di: $PWA_ROOT"
  echo "Usage: $0 /path/to/gurubot-pwa"
  exit 1
fi

# Profil sekolah = default. Override hanya jika maintainer set eksplisit.
export GURUBOT_BUILD_ENV="${GURUBOT_BUILD_ENV:-local}"
export NEXTAUTH_URL="${NEXTAUTH_URL:-https://gurubot.sekolah}"
export NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-https://gurubot.sekolah}"
export SKIP_SENTRY_WEBPACK="${SKIP_SENTRY_WEBPACK:-1}"
export NEXT_BUILD_WEBPACK="${NEXT_BUILD_WEBPACK:-1}"
export NEXT_TELEMETRY_DISABLED=1
# PM2 deploy (prod/beta) sengaja tanpa standalone; bundle sekolah butuh .next/standalone/.
export NEXT_OUTPUT_STANDALONE="${NEXT_OUTPUT_STANDALONE:-1}"

ENV_FILE_HINT=".env.school"
case "$GURUBOT_BUILD_ENV" in
  local | school) ENV_FILE_HINT=".env.school" ;;
  beta) ENV_FILE_HINT=".env.beta" ;;
  production | prod) ENV_FILE_HINT=".env.production" ;;
  dev | development) ENV_FILE_HINT=".env" ;;
esac

echo "============================================"
echo " GuruBot — Build & Copy Next.js Artifact"
echo "============================================"
echo "PWA:        $PWA_ROOT"
echo "Deploy:     $DEPLOY_ROOT"
echo "Profil:     $GURUBOT_BUILD_ENV → $ENV_FILE_HINT"
echo "NEXTAUTH:   $NEXTAUTH_URL"
echo "PUBLIC API: $NEXT_PUBLIC_API_URL"
echo "============================================"
echo ""

if [[ ! -f "$PWA_ROOT/$ENV_FILE_HINT" ]]; then
  echo "ERROR: $PWA_ROOT/$ENV_FILE_HINT tidak ada."
  echo "       Profil $GURUBOT_BUILD_ENV membutuhkan file itu."
  if [[ "$ENV_FILE_HINT" == ".env.school" ]]; then
    echo "       Buat: cp $PWA_ROOT/.env.school.example $PWA_ROOT/.env.school"
    echo "       Lalu sesuaikan URL/secret untuk deploy sekolah."
  fi
  exit 1
fi

cd "$PWA_ROOT"

echo "[1/4] yarn install..."
yarn install

echo ""
echo "[2/4] Clean .next..."
rm -rf .next

echo ""
echo "[3/4] yarn build:next (GURUBOT_BUILD_ENV=$GURUBOT_BUILD_ENV)..."
# yarn build:next menghormati GURUBOT_BUILD_ENV yang sudah di-export
# (default di PWA adalah production; di sini kita set local).
yarn build:next

if [[ ! -d ".next/standalone" ]]; then
  echo "ERROR: .next/standalone tidak ada setelah build."
  echo "Pastikan next.config.ts memiliki output: \"standalone\""
  exit 1
fi

echo ""
echo "[4/4] Copy artifact..."
"$SCRIPT_DIR/copy-nextjs-artifact.sh" "$PWA_ROOT"

echo ""
echo "[OK] Selesai. Langkah deploy:"
echo "  cd $DEPLOY_ROOT"
echo "  ./scripts/docker-up.sh"
echo ""
