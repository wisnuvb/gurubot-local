# GuruBot - health checks as JSON (used by setup-agent and optionally docker-health-check.bat)
param(
  [string]$BundleRoot = "",
  [string]$Domain = "gurubot.sekolah"
)

$ErrorActionPreference = "SilentlyContinue"

if ([string]::IsNullOrWhiteSpace($BundleRoot)) {
  $BundleRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$scriptsDir = Join-Path $BundleRoot "scripts"
$fail = 0
$warn = 0
$checks = @()
$warnings = @()

function Add-Check {
  param([string]$Id, [string]$Name, [string]$Status, [string]$Detail = "")
  $script:checks += [ordered]@{
    id     = $Id
    name   = $Name
    status = $Status
    detail = $Detail
  }
  if ($Status -eq "fail") { $script:fail = 1 }
  if ($Status -eq "warn") { $script:warn = 1 }
}

function Test-CurlOk {
  param([string]$Url, [hashtable]$Headers = @{})
  try {
    $h = @{}
    foreach ($k in $Headers.Keys) { $h[$k] = $Headers[$k] }
    Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -Headers $h | Out-Null
    return $true
  } catch { return $false }
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
  $dbPath = $rest.Substring($slashIdx + 1)
  $db = [System.Uri]::UnescapeDataString(($dbPath -split '\?', 2)[0])
  $authority = $rest.Substring(0, $slashIdx)

  $user = ""
  $pass = ""
  $hostPort = $authority
  $atIdx = $authority.LastIndexOf('@')
  if ($atIdx -ge 0) {
    $userPart = $authority.Substring(0, $atIdx)
    $hostPort = $authority.Substring($atIdx + 1)
    $colonIdx = $userPart.IndexOf(':')
    if ($colonIdx -ge 0) {
      $user = [System.Uri]::UnescapeDataString($userPart.Substring(0, $colonIdx))
      $pass = [System.Uri]::UnescapeDataString($userPart.Substring($colonIdx + 1))
    } else {
      $user = [System.Uri]::UnescapeDataString($userPart)
    }
  } else {
    return $null
  }

  $dbHost = $hostPort
  $port = "3306"
  if ($hostPort -match ':') {
    $hp = $hostPort -split ':', 2
    $dbHost = $hp[0]
    $port = $hp[1]
  }

  if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($dbHost) -or [string]::IsNullOrWhiteSpace($db)) {
    return $null
  }

  return [ordered]@{
    user     = $user
    password = $pass
    host     = $dbHost
    port     = $port
    database = $db
  }
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

function Test-MySqlDbConnection {
  param($Parts)
  if (-not $Parts) {
    return [ordered]@{
      status  = "skipped"
      message = "DATABASE_URL belum valid"
      hints   = @("Edit .env.docker di root bundle: DATABASE_URL=mysql://USER:SANDI@host.docker.internal:3306/NAMA_DB")
      method  = "none"
    }
  }

  $cli = Resolve-MySqlCli
  if (-not $cli) {
    return [ordered]@{
      status  = "unknown"
      message = "mysql.exe tidak ditemukan (simulasi CLI dilewati)"
      hints   = @("Gunakan tombol Tes koneksi (Prisma) di portal", "Pastikan MySQL Server 8 terinstal")
      method  = "none"
    }
  }

  $mysqlCliArgs = @(
    "--host=127.0.0.1",
    "--port=$($Parts.port)",
    "-u$($Parts.user)",
    "--connect-timeout=5",
    "-e", "SELECT 1 AS ok",
    $Parts.database
  )
  if ($Parts.password) {
    $mysqlCliArgs = @(
      "--host=127.0.0.1",
      "--port=$($Parts.port)",
      "-u$($Parts.user)",
      "-p$($Parts.password)",
      "--connect-timeout=5",
      "-e", "SELECT 1 AS ok",
      $Parts.database
    )
  }

  $output = (& $cli @mysqlCliArgs 2>&1 | Out-String).Trim()
  $exitCode = $LASTEXITCODE
  if ($null -eq $exitCode -or $exitCode -eq -1) {
    if ($output -match "ERROR") { $exitCode = 1 } else { $exitCode = 0 }
  }
  if ($exitCode -eq 0 -and $output -match "ok") {
    return [ordered]@{
      status  = "ok"
      message = "Koneksi ke database '$($Parts.database)' berhasil (127.0.0.1:$($Parts.port))"
      hints   = @()
      method  = "mysql_cli"
    }
  }

  $hints = @("Isi user dan sandi MySQL di form Simpan ke .env.docker di bawah, lalu Periksa ulang")
  $msg = if ($output) { ($output -split "`n" | Where-Object { $_ -match "ERROR" } | Select-Object -First 1) } else { $null }
  if (-not $msg) {
    $msg = if ($output) { ($output -split "`n" | Select-Object -First 2) -join " " } else { "mysql exit code $exitCode" }
  }

  if ($output -match "Unknown database") {
    $hints = @(
      "Database '$($Parts.database)' belum ada - klik Buat database di portal",
      "Atau import dump: mysql -u $($Parts.user) -p $($Parts.database) < backup.sql"
    )
  } elseif ($output -match "Access denied") {
    $hints = @(
      "MySQL tidak bisa memberitahu sandi yang benar - hanya Anda atau admin IT yang tahu saat instal MySQL"
      ,"Isi sandi root/user di form portal lalu klik Simpan ke .env.docker"
      ,"Contoh URL: mysql://root:SANDI@host.docker.internal:3306/$($Parts.database)"
    )
    if (-not $Parts.password) {
      $hints = @(
        "DATABASE_URL saat ini tanpa sandi, tapi MySQL menolak - isi sandi root di form bawah"
        ,"MySQL tidak menyimpan sandi yang bisa dibaca ulang dari server"
      )
    }
  } elseif ($output -match "Can't connect|connect to MySQL|2003|10061") {
    $hints = @(
      "Pastikan service MySQL80 RUNNING (Services.msc)",
      "Port $($Parts.port) harus listen di 127.0.0.1"
    )
  }

  return [ordered]@{
    status  = "fail"
    message = $msg
    hints   = $hints
    method  = "mysql_cli"
  }
}

# LAN IP (utamakan 192.168.x; lewati Docker/WSL virtual)
$lanIp = ""
try {
  $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notmatch '^127\.' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } |
    Sort-Object -Property @{
      Expression = {
        if ($_.IPAddress -match '^192\.168\.') { 0 }
        elseif ($_.InterfaceAlias -match 'Wi-Fi|Ethernet|LAN') { 1 }
        elseif ($_.IPAddress -match '^172\.(1[6-9]|2[0-9]|3[01])\.') { 9 }
        else { 5 }
      }
    }
  if ($candidates) { $lanIp = ($candidates | Select-Object -First 1).IPAddress }
} catch {}
if (-not $lanIp) {
  $detectBat = Join-Path $scriptsDir "lib\detect-lan-ip.bat"
  if (Test-Path $detectBat) {
    $lanIp = (& cmd /c "`"$detectBat`"" 2>$null | Select-Object -First 1).Trim()
  }
}

# nginx HTTPS
$nginxOk = $false
if (Test-CurlOk "https://$Domain/api/health") { $nginxOk = $true }
elseif (Test-CurlOk "https://127.0.0.1/api/health" @{ Host = $Domain }) { $nginxOk = $true }
if ($nginxOk) {
  Add-Check "nginx_https" "nginx HTTPS" "ok" "https://$Domain/api/health"
} else {
  Add-Check "nginx_https" "nginx HTTPS" "fail" "Cek gurubot-nginx dan certs"
}

# Port 80 - nginx Windows vs Docker (http://IP/ sering 502 jika bentrok)
$hostNginx = Get-Process -Name nginx -ErrorAction SilentlyContinue
if ($hostNginx) {
  Add-Check "port80_host_nginx" "Port 80 - nginx di Windows" "warn" "nginx.exe host bentrok dengan gurubot-nginx Docker"
  $warnings += "http://$lanIp/ bisa 502 - stop nginx Windows (XAMPP/legacy PM2): taskkill /IM nginx.exe /F; pakai https://$Domain atau https://$lanIp/welcome"
} elseif ($lanIp) {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1/" -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5
    if ($r.StatusCode -ge 500) {
      Add-Check "port80_http" "HTTP :80 redirect" "warn" "Respon HTTP aneh - cek siapa listen port 80"
    }
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 301) {
      Add-Check "port80_http" "HTTP :80 ke HTTPS" "ok" "Redirect 301 ke HTTPS"
    }
  }
}

# Ollama
if (Test-CurlOk "http://127.0.0.1:11434/api/tags") {
  Add-Check "ollama" "Ollama Qwen (host)" "ok" "http://127.0.0.1:11434"
} else {
  Add-Check "ollama" "Ollama Qwen (host)" "fail" "Jalankan Ollama di host"
}

# DNS Technitium
$dnsTechnitiumRunning = $false
$dnsResolvedOk = $false
$dnsContainer = docker ps --filter "name=gurubot-dns" --filter "status=running" -q 2>$null
if (-not $dnsContainer) {
  Add-Check "dns_technitium" "DNS Technitium" "warn" "Container gurubot-dns tidak running"
  $warnings += "Jalankan: docker compose up -d dns"
} else {
  $dnsTechnitiumRunning = $true
  Add-Check "dns_technitium" "DNS Technitium" "ok" "Container gurubot-dns"
  if (-not $lanIp) {
    Add-Check "dns_resolve" "DNS $Domain" "warn" "IP LAN tidak terdeteksi"
  } else {
    $resolved = $false
    $dout = ""
    try {
      $ns = nslookup $Domain 127.0.0.1 2>&1 | Out-String
      $dout = ($ns -split "`n" | Where-Object { $_ -match "Address" }) -join " "
      if ($dout -match [regex]::Escape($lanIp)) { $resolved = $true }
    } catch {}
    if ($resolved) {
      $dnsResolvedOk = $true
      Add-Check "dns_resolve" "DNS $Domain" "ok" "$Domain -> $lanIp"
    } else {
      Add-Check "dns_resolve" "DNS $Domain" "fail" "Expected $lanIp; got: $dout"
      $warnings += "Jalankan scripts\setup-dns.bat (Administrator)"
    }
  }
}

# Docker containers
function Test-DockerExec {
  param([string]$Container, [string]$Url)
  $running = docker ps --filter "name=$Container" --filter "status=running" -q 2>$null
  if (-not $running) { return "not_running" }
  docker exec $Container curl -sf --max-time 10 $Url 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { return "unhealthy" }
  return "ok"
}

$ocrSt = Test-DockerExec "gurubot-ocr" "http://127.0.0.1:2059/docs"
switch ($ocrSt) {
  "ok" { Add-Check "ocr" "OCR internal" "ok" "gurubot-ocr" }
  "not_running" { Add-Check "ocr" "OCR internal" "fail" "Container tidak running" }
  default { Add-Check "ocr" "OCR internal" "fail" "Health check gagal" }
}

$whSt = Test-DockerExec "gurubot-whisper" "http://127.0.0.1:2063/health"
switch ($whSt) {
  "ok" { Add-Check "whisper_health" "Whisper /health" "ok" "gurubot-whisper" }
  "not_running" { Add-Check "whisper_health" "Whisper /health" "fail" "Container tidak running" }
  default { Add-Check "whisper_health" "Whisper /health" "fail" "Health check gagal" }
}

$whReady = Test-DockerExec "gurubot-whisper" "http://127.0.0.1:2063/ready"
switch ($whReady) {
  "ok" { Add-Check "whisper_ready" "Whisper /ready" "ok" "" }
  "not_running" { Add-Check "whisper_ready" "Whisper /ready" "fail" "" }
  default { Add-Check "whisper_ready" "Whisper /ready" "warn" "Model mungkin masih unduh" }
}

# MySQL - service, port, dan kredensial dari .env.docker
$mysqlUp = $false
$mysqlSvcName = ""
foreach ($svc in @("MySQL80", "MySQL")) {
  $q = sc.exe query $svc 2>$null | Out-String
  if ($q -match "RUNNING") { $mysqlUp = $true; $mysqlSvcName = $svc; break }
}
$mysqlPortOpen = $false
try {
  $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
  $mysqlPortOpen = [bool]$tcp.TcpTestSucceeded
} catch {}

$dbUrl = Get-EnvDockerValue "DATABASE_URL"
$mysqlParts = Parse-MySqlDatabaseUrl $dbUrl
$mysqlConn = Test-MySqlDbConnection $mysqlParts
$mysqlInfo = [ordered]@{
  configured = ($null -ne $mysqlParts)
  serviceRunning = $mysqlUp
  serviceName = $mysqlSvcName
  portOpen = $mysqlPortOpen
  connection = $mysqlConn
  passwordNote = "Sandi MySQL tidak bisa dibaca dari server Windows/MySQL - hanya tersimpan di .env.docker. Operator harus memasukkan sandi saat instal MySQL atau dari admin IT."
  canRecoverPassword = $false
  note = "Aplikasi Docker memakai host dari DATABASE_URL (biasanya host.docker.internal). MySQL Workbench / CLI di PC server: 127.0.0.1:3306"
}
if ($mysqlParts) {
  $mysqlInfo.host = $mysqlParts.host
  $mysqlInfo.port = $mysqlParts.port
  $mysqlInfo.database = $mysqlParts.database
  $mysqlInfo.user = $mysqlParts.user
  $mysqlInfo.password = $mysqlParts.password
  $mysqlInfo.hostLocal = "127.0.0.1"
  $detail = "$($mysqlParts.database) @ 127.0.0.1:$($mysqlParts.port) user $($mysqlParts.user)"
  if (-not $mysqlUp) {
    Add-Check "mysql" "MySQL (Windows service)" "warn" "$detail - service belum RUNNING"
  } elseif (-not $mysqlPortOpen) {
    Add-Check "mysql" "MySQL (Windows service)" "warn" "$detail - port 3306 tidak merespons"
  } else {
    Add-Check "mysql" "MySQL (Windows service)" "ok" $detail
  }
  switch ($mysqlConn.status) {
    "ok" { Add-Check "mysql_connection" "MySQL koneksi DB" "ok" $mysqlConn.message }
    "fail" { Add-Check "mysql_connection" "MySQL koneksi DB" "fail" $mysqlConn.message }
    default { Add-Check "mysql_connection" "MySQL koneksi DB" "warn" $mysqlConn.message }
  }
} else {
  $mysqlInfo.connection = $mysqlConn
  if ($mysqlUp) {
    Add-Check "mysql" "MySQL (Windows service)" "warn" "Service RUNNING - isi DATABASE_URL di .env.docker"
  } else {
    Add-Check "mysql" "MySQL (Windows service)" "warn" "Service belum RUNNING; DATABASE_URL belum valid"
  }
}

# Docker daemon
docker info 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Add-Check "docker" "Docker daemon" "ok" "" }
else { Add-Check "docker" "Docker daemon" "fail" "Buka Docker Desktop" }

# mkcert
$mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
if ($mkcert) { Add-Check "mkcert" "mkcert" "ok" "" }
else { Add-Check "mkcert" "mkcert" "warn" "choco install mkcert" }

# Firewall rules (Windows)
function Test-FwRule {
  param([string]$Name)
  $out = netsh advfirewall firewall show rule name="$Name" 2>$null | Out-String
  return ($out -match "Enabled:\s+Yes")
}
$fw443 = Test-FwRule "GuruBot HTTPS 443"
$fw53u = Test-FwRule "GuruBot DNS 53 UDP"
if ($fw443) { Add-Check "firewall_443" "Firewall TCP 443" "ok" "" }
else {
  Add-Check "firewall_443" "Firewall TCP 443" "warn" "HP di WiFi perlu akses HTTPS"
  $warnings += "Jalankan scripts\setup-lan-firewall.bat sebagai Administrator"
}
if ($fw53u) { Add-Check "firewall_53" "Firewall UDP 53" "ok" "" }
else { Add-Check "firewall_53" "Firewall UDP 53" "warn" "DNS dari LAN ke Technitium" }

function Get-CurlHttpCode {
  param([string]$Url, [switch]$Insecure, [switch]$NoRedirect)
  $curlArgs = @("-s", "-o", "NUL", "-w", "%{http_code}", "--max-time", "12")
  if ($Insecure) { $curlArgs += "-k" }
  if ($NoRedirect) { $curlArgs += "--max-redirs", "0" }
  $curlArgs += $Url
  try {
    $code = (& curl.exe @curlArgs 2>$null | Select-Object -Last 1).Trim()
    if ($code -match '^\d{3}$') { return [int]$code }
  } catch {}
  return 0
}

$httpsWelcomeCode = 0
$httpWelcomeCode = 0
if ($lanIp) {
  $httpsWelcomeCode = Get-CurlHttpCode "https://$lanIp/welcome" -Insecure
  $httpWelcomeCode = Get-CurlHttpCode "http://$lanIp/welcome" -NoRedirect
  if ($httpsWelcomeCode -eq 200) {
    Add-Check "lan_https_welcome" "HTTPS welcome via IP LAN" "ok" "https://$lanIp/welcome -> 200"
  } else {
    Add-Check "lan_https_welcome" "HTTPS welcome via IP LAN" "warn" "https://$lanIp/welcome -> $httpsWelcomeCode"
  }
  if ($httpWelcomeCode -eq 502) {
    Add-Check "lan_http_welcome" "HTTP welcome via IP LAN" "warn" "http://$lanIp/welcome -> 502 - pakai HTTPS"
  } elseif ($httpWelcomeCode -ge 200 -and $httpWelcomeCode -lt 400) {
    Add-Check "lan_http_welcome" "HTTP welcome via IP LAN" "ok" "http://$lanIp/welcome -> $httpWelcomeCode"
  }
}

$hostNginxRunning = [bool]$hostNginx
$routerReady = $dnsResolvedOk -and $fw443 -and $fw53u
$lanReady = $nginxOk -and $httpsWelcomeCode -eq 200 -and $fw443 -and (-not $hostNginxRunning)
$lanOverall = if (-not $lanReady) { if ($nginxOk -and $httpsWelcomeCode -eq 200) { "warn" } else { "fail" } } else { if ($routerReady -and $dnsResolvedOk) { "ok" } else { "warn" } }

$nextAuthUrl = Get-EnvDockerValue "NEXTAUTH_URL"
if (-not $nextAuthUrl) { $nextAuthUrl = "https://$Domain" }

$recommendedWelcome = "https://$Domain/welcome"
$fallbackWelcome = if ($lanIp) { "https://$($lanIp)/welcome" } else { "" }
$nextAuthNoteText = "Semua HP sebaiknya buka URL yang sama dengan NEXTAUTH_URL ($nextAuthUrl). Jangan campur http tanpa s dan IP saja - sering 502 - dengan https://gurubot.sekolah."

$routerGuideLines = @(
  "Di router WiFi sekolah, set DHCP DNS / Primary DNS = IP PC server ($lanIp)."
  ,"TP-Link: DHCP -> Primary DNS. Mikrotik: DHCP Networks -> DNS Server. IndiHome: LAN -> DHCP -> DNS."
  ,"Setelah ubah router: HP disconnect WiFi lalu connect lagi - renew DHCP."
  ,"HP: matikan Private DNS di Android jika masih gagal resolve gurubot.sekolah."
  ,"Di PC server: tombol Sinkronkan DNS + Firewall WiFi di dashboard - Run as Administrator."
  ,"Trust sertifikat mkcert di HP - wizard portal langkah 5."
)

if ($lanIp) {
  $hpChecklistLines = @(
    "Buka $recommendedWelcome - disarankan setelah router DNS benar."
    ,"Fallback: $fallbackWelcome - wajib HTTPS bukan HTTP."
    ,"Jangan pakai http://$($lanIp)/ - sering 502 jika nginx Windows masih jalan."
  )
} else {
  $hpChecklistLines = @("Deteksi IP LAN gagal - jalankan show-server-info.bat")
}

$lanStatusItems = @(
  [ordered]@{ id = "technitium"; name = "DNS Technitium container"; status = if ($dnsTechnitiumRunning) { "ok" } else { "warn" }; detail = if ($dnsTechnitiumRunning) { "gurubot-dns running" } else { "Container belum jalan" } }
  [ordered]@{ id = "dns_record"; name = "Record $Domain"; status = if ($dnsResolvedOk) { "ok" } elseif ($dnsTechnitiumRunning) { "fail" } else { "warn" }; detail = if ($dnsResolvedOk) { "$Domain -> $lanIp" } else { "Jalankan Sinkronkan DNS" } }
  [ordered]@{ id = "router_dns"; name = "Router DHCP DNS ke server"; status = if ($routerReady) { "ok" } else { "warn" }; detail = "Atur manual di router ke $lanIp - tidak bisa dicek otomatis dari PC" }
  [ordered]@{ id = "firewall"; name = "Firewall LAN 443/53"; status = if ($fw443 -and $fw53u) { "ok" } else { "warn" }; detail = if ($fw443 -and $fw53u) { "Aturan GuruBot ada" } else { "Jalankan setup-lan-firewall.bat as Admin" } }
  [ordered]@{ id = "https_ip"; name = "HTTPS welcome via IP"; status = if ($httpsWelcomeCode -eq 200) { "ok" } else { "warn" }; detail = "Kode HTTP $httpsWelcomeCode" }
  [ordered]@{ id = "host_nginx"; name = "nginx Windows port 80"; status = if ($hostNginxRunning) { "warn" } else { "ok" }; detail = if ($hostNginxRunning) { "Bentrok - stop nginx.exe" } else { "Tidak bentrok" } }
)

$lanAccess = [ordered]@{
  overall = $lanOverall
  lanIp = $lanIp
  domain = $Domain
  recommendedUrl = $recommendedWelcome
  fallbackHttpsUrl = $fallbackWelcome
  routerDnsTarget = $lanIp
  routerReady = $routerReady
  httpsWelcomeCode = $httpsWelcomeCode
  httpWelcomeCode = $httpWelcomeCode
  hostNginxOnWindows = $hostNginxRunning
  nextAuthUrl = $nextAuthUrl
  nextAuthNote = $nextAuthNoteText
  routerGuide = $routerGuideLines
  hpChecklist = $hpChecklistLines
  statusItems = $lanStatusItems
}

$containers = @()
try {
  Push-Location $BundleRoot
  docker compose ps --format json 2>$null | ForEach-Object {
    if ($_ -and $_.Trim()) {
      $o = $_ | ConvertFrom-Json
      $containers += [ordered]@{ name = $o.Name; service = $o.Service; state = $o.State; status = $o.Status }
    }
  }
} finally { Pop-Location }

$overall = if ($fail -ne 0) { "fail" } elseif ($warn -ne 0) { "warn" } else { "ok" }

[ordered]@{
  ok        = ($fail -eq 0)
  overall   = $overall
  lanIp     = $lanIp
  domain    = $Domain
  urls      = [ordered]@{
    welcome = "https://$Domain/welcome"
    health  = "https://$Domain/api/health"
    operator = "http://127.0.0.1:2077/"
  }
  checks    = $checks
  warnings  = $warnings
  containers = $containers
  mysql     = $mysqlInfo
  lanAccess = $lanAccess
  generatedAt = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 8 -Compress:$false
