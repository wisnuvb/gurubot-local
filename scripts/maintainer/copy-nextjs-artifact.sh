#!/usr/bin/env bash
# Maintainer: salin standalone build dari gurubot-pwa ke artifacts/nextjs
#
# PENTING — jangan salin isi folder .next langsung ke artifacts/nextjs/
#   SALAH: cp -R gurubot-pwa/.next/* artifacts/nextjs/
#   BENAR: gunakan skrip ini (layout standalone Next.js)
#
# Panduan lengkap: docs/BUILD-ARTIFACT.md
#
# Layout target:
#   artifacts/nextjs/server.js
#   artifacts/nextjs/.next/BUILD_ID
#   artifacts/nextjs/.next/server/
#   artifacts/nextjs/.next/static/
#   artifacts/nextjs/node_modules/   (@prisma/client + prisma lengkap)
#   artifacts/nextjs/prisma/
#   artifacts/nextjs/ml-training/
#   artifacts/nextjs/public/
set -euo pipefail

PWA_ROOT="${1:-../gurubot-pwa}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$DEPLOY_ROOT/artifacts/nextjs"

if [[ "$PWA_ROOT" != /* ]]; then
  if [[ -d "$DEPLOY_ROOT/$PWA_ROOT" ]]; then
    PWA_ROOT="$(cd "$DEPLOY_ROOT/$PWA_ROOT" && pwd)"
  else
    PWA_ROOT="$(cd "$PWA_ROOT" && pwd)"
  fi
fi

if [[ ! -d "$PWA_ROOT/.next/standalone" ]]; then
  echo "ERROR: $PWA_ROOT/.next/standalone tidak ada. Jalankan build dulu."
  echo ""
  echo "  cd $PWA_ROOT"
  echo "  export GURUBOT_BUILD_ENV=local"
  echo "  export NEXTAUTH_URL=https://gurubot.sekolah"
  echo "  export NEXT_PUBLIC_API_URL=https://gurubot.sekolah"
  echo "  export SKIP_SENTRY_WEBPACK=1"
  echo "  export NEXT_BUILD_WEBPACK=1"
  echo "  rm -rf .next && yarn build:next:local"
  echo ""
  echo "Atau satu perintah:"
  echo "  $DEPLOY_ROOT/scripts/maintainer/build-and-copy-nextjs.sh $PWA_ROOT"
  exit 1
fi

echo "Copy artifact dari: $PWA_ROOT"
echo "Target:             $TARGET"
echo ""

rm -rf "$TARGET"
mkdir -p "$TARGET/.next/static"

cp "$PWA_ROOT/.next/standalone/server.js" "$TARGET/server.js"
cp "$PWA_ROOT/.next/standalone/package.json" "$TARGET/package.json"
rsync -a "$PWA_ROOT/.next/standalone/node_modules/" "$TARGET/node_modules/"
cp -R "$PWA_ROOT/.next/standalone/.next/"* "$TARGET/.next/"
cp -R "$PWA_ROOT/.next/static/"* "$TARGET/.next/static/"
cp -R "$PWA_ROOT/public" "$PWA_ROOT/prisma" "$PWA_ROOT/ml-training" "$TARGET/"

# Standalone trace: @prisma/client tidak lengkap + engine hanya platform build.
# Salin paket prisma penuh dari repo PWA (bukan dari standalone trace).
if [[ ! -d "$PWA_ROOT/node_modules/@prisma/client/generator-build" ]]; then
  echo "ERROR: @prisma/client tidak lengkap di $PWA_ROOT — jalankan: cd $PWA_ROOT && yarn install && yarn db:generate"
  exit 1
fi
if [[ ! -d "$PWA_ROOT/node_modules/prisma" ]]; then
  echo "ERROR: node_modules/prisma tidak ada — jalankan: cd $PWA_ROOT && yarn install"
  exit 1
fi

rsync -a "$PWA_ROOT/node_modules/@prisma/client/" "$TARGET/node_modules/@prisma/client/"
rsync -a "$PWA_ROOT/node_modules/.prisma/" "$TARGET/node_modules/.prisma/" 2>/dev/null || true

node "$DEPLOY_ROOT/scripts/maintainer/patch-prisma-schema.js" "$TARGET"

echo "Generating Prisma Client (native + windows + debian-openssl-3.0.x)..."
# Jangan pakai npx di TARGET — node_modules prisma di artifact tidak lengkap
# (@prisma/engines hilang). Generate dari gurubot-pwa yang punya deps penuh.
node "$PWA_ROOT/node_modules/prisma/build/index.js" generate --schema="$TARGET/prisma/schema.prisma"

# Sentry + Turbopack instrumentation sering gagal di deploy lapangan standalone.
cp "$DEPLOY_ROOT/scripts/maintainer/instrumentation.stub.js" "$TARGET/.next/server/instrumentation.js"

# Jangan bawa .env.production dari standalone (bisa berisi secret production).
rm -f "$TARGET/.env.production" "$TARGET/.env"

echo ""
echo "OK: artifact nextjs updated at $TARGET"

"$SCRIPT_DIR/verify-nextjs-artifact.sh" "$TARGET"
