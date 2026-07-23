#!/usr/bin/env bash
# GuruBot common helpers (macOS / Linux)
#
# Usage:
#   source "$(dirname "$0")/lib/common.sh"
#   gurubot_init_paths
#   gurubot_log "pesan"
#   gurubot_fail "pesan error"

gurubot_init_paths() {
  if [[ -z "${BUNDLE_ROOT:-}" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BUNDLE_ROOT="$(cd "$lib_dir/../.." && pwd)"
  fi

  CONFIG_DIR="${BUNDLE_ROOT}/config"
  SCRIPTS_DIR="${BUNDLE_ROOT}/scripts"
  ARTIFACTS_DIR="${BUNDLE_ROOT}/artifacts"
  TOOLS_DIR="${BUNDLE_ROOT}/tools"
  NEXTJS_DIR="${ARTIFACTS_DIR}/nextjs"
  WHISPER_DIR="${ARTIFACTS_DIR}/whisper"
  LLM_DIR="${ARTIFACTS_DIR}/llm"
  CERTS_DIR="${BUNDLE_ROOT}/certs"
  ENV_DOCKER="${BUNDLE_ROOT}/.env.docker"
  ENV_DOCKER_EXAMPLE="${CONFIG_DIR}/.env.docker.example"
}

gurubot_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

gurubot_fail() {
  echo ""
  echo "[ERROR] $*"
  echo ""
  exit 1
}

gurubot_require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$hint" ]]; then
      gurubot_fail "$cmd tidak ditemukan. $hint"
    fi
    gurubot_fail "$cmd tidak ditemukan di PATH."
  fi
}

gurubot_require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    gurubot_fail "File tidak ditemukan: $file"
  fi
}

gurubot_require_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    gurubot_fail "Folder tidak ditemukan: $dir"
  fi
}

gurubot_generate_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

gurubot_require_docker() {
  gurubot_require_cmd docker "Instal Docker Desktop: https://docs.docker.com/desktop/setup/install/mac-install/"
  if ! docker info >/dev/null 2>&1; then
    gurubot_fail "Docker daemon tidak berjalan. Buka Docker Desktop lalu coba lagi."
  fi
}

gurubot_pause() {
  if [[ -t 0 ]]; then
    read -r -p "Tekan Enter untuk melanjutkan..."
  fi
}

gurubot_load_env_docker() {
  local key="$1"
  local file="${2:-$ENV_DOCKER}"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  local line
  line="$(grep -E "^${key}=" "$file" | tail -n 1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  local value="${line#*=}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

gurubot_set_env_docker_value() {
  local key="$1"
  local value="$2"
  local file="${3:-$ENV_DOCKER}"

  gurubot_require_file "$file"

  local tmp
  tmp="$(mktemp)"
  local replaced=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^${key}= ]]; then
      printf '%s=%s\n' "$key" "$value" >>"$tmp"
      replaced=1
    else
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$file"

  if [[ "$replaced" -eq 0 ]]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi

  mv "$tmp" "$file"
}
