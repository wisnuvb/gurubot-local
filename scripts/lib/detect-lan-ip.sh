#!/usr/bin/env bash
# Deteksi IPv4 LAN utama (macOS).
# Output: satu baris IP, atau exit 1 jika tidak ditemukan.

set -euo pipefail

detect_lan_ip() {
  local iface ip

  iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
  if [[ -n "$iface" ]]; then
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  fi

  for iface in en0 en1 en2 en3; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  done

  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if ! detect_lan_ip; then
    echo "[WARN] Tidak menemukan IPv4 LAN. Set LAN_IP manual di environment." >&2
    exit 1
  fi
fi
