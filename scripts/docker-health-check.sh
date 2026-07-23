#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
gurubot_init_paths

FAIL=0

echo "============================================"
echo " GuruBot Docker Health Check (macOS)"
echo "============================================"
echo ""

check_url() {
  local name="$1"
  local url="$2"
  shift 2
  if curl -sf --max-time 10 "$@" "$url" >/dev/null 2>&1; then
    echo "[ OK ] $name - $url"
  else
    echo "[FAIL] $name - $url"
    FAIL=1
  fi
}

check_docker() {
  local name="$1"
  local container="$2"
  local url="$3"
  if docker exec "$container" curl -sf --max-time 10 "$url" >/dev/null 2>&1; then
    echo "[ OK ] $name - $container"
  else
    echo "[FAIL] $name - $container $url"
    FAIL=1
  fi
}

check_dns() {
  local name="$1"
  local host="$2"
  local expect="$3"
  if [[ -z "$expect" ]]; then
    echo "[WARN] $name - IP LAN tidak terdeteksi, lewati verifikasi"
    return 0
  fi
  local out
  out="$(dig +short @127.0.0.1 "$host" 2>/dev/null || true)"
  if [[ "$out" == *"$expect"* ]]; then
    echo "[ OK ] $name -> $expect"
  else
    echo "[FAIL] $name - tidak resolve ke $expect. Output: $out"
    FAIL=1
  fi
}

check_url "nginx HTTPS" "https://gurubot.sekolah/api/health" -k
check_url "Ollama Qwen (host)" "http://127.0.0.1:11434/api/tags"

# shellcheck source=lib/detect-lan-ip.sh
source "$SCRIPT_DIR/lib/detect-lan-ip.sh"
LAN_IP="$(detect_lan_ip 2>/dev/null || true)"
check_dns "DNS gurubot.sekolah (Technitium)" "gurubot.sekolah" "$LAN_IP"

cd "$BUNDLE_ROOT"
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || true
echo ""

check_docker "OCR internal" "gurubot-ocr" "http://127.0.0.1:2059/docs"
check_docker "Whisper /health" "gurubot-whisper" "http://127.0.0.1:2063/health"
check_docker "Whisper /ready" "gurubot-whisper" "http://127.0.0.1:2063/ready"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "[OK] Semua check lulus."
else
  echo "[FAIL] Ada service yang belum siap."
fi

exit "$FAIL"
