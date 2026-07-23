# Buat database dari nama di DATABASE_URL (.env.docker) — dipanggil portal operator
param(
  [string]$BundleRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BundleRoot)) {
  $BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-EnvDockerValue {
  param([string]$Key)
  $envFile = Join-Path $BundleRoot ".env.docker"
  if (-not (Test-Path $envFile)) { return "" }
  foreach ($line in Get-Content $envFile -Encoding UTF8) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith("#") -or $line -notmatch "=") { continue }
    $parts = $line -split "=", 2
    if ($parts[0].Trim() -eq $Key) { return $parts[1].Trim() }
  }
  return ""
}

function Parse-MySqlDatabaseUrl {
  param([string]$Url)
  if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
  if ($Url -notmatch '^mysql://') { return $null }
  $rest = $Url.Substring(8)
  $slashIdx = $rest.IndexOf('/')
  if ($slashIdx -lt 0) { return $null }
  $db = [System.Uri]::UnescapeDataString((($rest.Substring($slashIdx + 1)) -split '\?', 2)[0])
  $authority = $rest.Substring(0, $slashIdx)
  $atIdx = $authority.LastIndexOf('@')
  if ($atIdx -lt 0) { return $null }
  $userPart = $authority.Substring(0, $atIdx)
  $hostPort = $authority.Substring($atIdx + 1)
  $colonIdx = $userPart.IndexOf(':')
  if ($colonIdx -ge 0) {
    $user = [System.Uri]::UnescapeDataString($userPart.Substring(0, $colonIdx))
    $pass = [System.Uri]::UnescapeDataString($userPart.Substring($colonIdx + 1))
  } else {
    $user = [System.Uri]::UnescapeDataString($userPart)
    $pass = ""
  }
  $dbHost = $hostPort
  $port = "3306"
  if ($hostPort -match ':') {
    $hp = $hostPort -split ':', 2
    $dbHost = $hp[0]
    $port = $hp[1]
  }
  if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($db)) { return $null }
  return [ordered]@{ user = $user; password = $pass; port = $port; database = $db }
}

function Resolve-MySqlCli {
  $cmd = Get-Command mysql -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
      "C:\xampp\mysql\bin\mysql.exe"
    )) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

$dbUrl = Get-EnvDockerValue "DATABASE_URL"
$parts = Parse-MySqlDatabaseUrl $dbUrl
if (-not $parts) {
  Write-Output "[FAIL] DATABASE_URL tidak valid di .env.docker"
  exit 1
}

$cli = Resolve-MySqlCli
if (-not $cli) {
  Write-Output "[FAIL] mysql.exe tidak ditemukan (MySQL Server / PATH)"
  exit 1
}

$dbName = $parts.database -replace '[^a-zA-Z0-9_]', ''
if ($dbName -ne $parts.database) {
  Write-Output "[FAIL] Nama database tidak aman: $($parts.database)"
  exit 1
}

$sql = "CREATE DATABASE IF NOT EXISTS ``$dbName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
$mysqlCliArgs = @("--host=127.0.0.1", "--port=$($parts.port)", "-u$($parts.user)", "--connect-timeout=10", "-e", $sql)
if ($parts.password) {
  $mysqlCliArgs = @("--host=127.0.0.1", "--port=$($parts.port)", "-u$($parts.user)", "-p$($parts.password)", "--connect-timeout=10", "-e", $sql)
}

$output = & $cli @mysqlCliArgs 2>&1
$code = $LASTEXITCODE
if ($code -ne 0) {
  Write-Output "[FAIL] Gagal membuat database: $output"
  Write-Output "HINT: Cek user/password MySQL di .env.docker"
  exit $code
}

Write-Output "[OK] Database '$dbName' siap (CREATE DATABASE IF NOT EXISTS)"
Write-Output "Langkah berikut: import dump production atau jalankan Tes koneksi DB di portal."
exit 0
