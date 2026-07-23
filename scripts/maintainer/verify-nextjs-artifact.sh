#!/usr/bin/env bash
# Verifikasi artifact nextjs siap deploy cross-platform.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="${1:-$DEPLOY_ROOT/artifacts/nextjs}"

FAIL=0

check() {
  if eval "$2"; then
    echo "[ OK ] $1"
  else
    echo "[FAIL] $1"
    FAIL=1
  fi
}

echo "============================================"
echo " Verifikasi artifact: $TARGET"
echo "============================================"
echo ""

check "server.js" "test -f '$TARGET/server.js'"
check "package.json" "test -f '$TARGET/package.json'"
check "node_modules/next" "test -f '$TARGET/node_modules/next/package.json'"
check ".next/BUILD_ID" "test -f '$TARGET/.next/BUILD_ID'"
check ".next/server/" "test -d '$TARGET/.next/server'"
check ".next/static/" "test -d '$TARGET/.next/static'"
check "prisma/schema.prisma" "test -f '$TARGET/prisma/schema.prisma'"
check "ml-training/ocr_server.py" "test -f '$TARGET/ml-training/ocr_server.py'"
check "public/" "test -d '$TARGET/public'"
check "@prisma/client generator-build" "test -f '$TARGET/node_modules/@prisma/client/generator-build/index.js'"
check "instrumentation stub" "test -f '$TARGET/.next/server/instrumentation.js'"

if grep -q 'debian-openssl-3.0.x' "$TARGET/prisma/schema.prisma" 2>/dev/null; then
  echo "[ OK ] binaryTargets debian-openssl-3.0.x"
else
  echo "[FAIL] binaryTargets debian-openssl-3.0.x — jalankan copy-nextjs-artifact.sh"
  FAIL=1
fi

ENGINE_COUNT="$(find "$TARGET/node_modules/.prisma/client" \( -name 'libquery_engine-*' -o -name 'query_engine-windows.dll.node' \) 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${ENGINE_COUNT:-0}" -ge 3 ]]; then
  echo "[ OK ] Prisma query engine: $ENGINE_COUNT platform (darwin + windows + linux)"
elif [[ "${ENGINE_COUNT:-0}" -ge 1 ]]; then
  echo "[WARN] Prisma query engine hanya $ENGINE_COUNT — generate gagal/sebagian; Docker akan regenerate"
  FAIL=1
else
  echo "[FAIL] Tidak ada query engine — jalankan ulang copy-nextjs-artifact.sh"
  FAIL=1
fi

if grep -rq 'app\.gurubot\.io' "$TARGET/.next/static" 2>/dev/null; then
  echo "[WARN] Bundle masih mengandung app.gurubot.io — rebuild dengan profil sekolah:"
  echo "       ./scripts/maintainer/build-and-copy-nextjs.sh  (GURUBOT_BUILD_ENV=local / .env.school)"
  FAIL=1
fi

if grep -rq 'gurubot\.sekolah' "$TARGET/.next/static" 2>/dev/null; then
  echo "[ OK ] Bundle mengandung gurubot.sekolah"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "[OK] Artifact siap deploy."
else
  echo "[FAIL] Perbaiki artifact sebelum distribusi."
fi

exit "$FAIL"
