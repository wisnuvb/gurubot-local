# GuruBot - Set/replace KEY=VALUE di file .env, tanpa mengubah baris lain.
# Dipanggil oleh scripts\lib\common.bat (set_env_value).

param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Key,
  [Parameter(Mandatory = $true)][string]$Value
)

if (-not (Test-Path $Path)) {
  Write-Host "[ERROR] File tidak ditemukan: $Path"
  exit 1
}

$lines = Get-Content -Path $Path
$pattern = "^$([regex]::Escape($Key))="
$found = $false

$out = foreach ($line in $lines) {
  if ($line -match $pattern) {
    $found = $true
    "$Key=$Value"
  } else {
    $line
  }
}

if (-not $found) {
  $out += "$Key=$Value"
}

Set-Content -Path $Path -Value $out -Encoding UTF8
exit 0
