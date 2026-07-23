# GuruBot - Konfigurasi Technitium DNS Server via API
# Dipanggil oleh scripts\setup-dns.bat (jangan jalankan manual tanpa env var password).
#
# Password admin diambil dari env var GURUBOT_DNS_ADMIN_PASSWORD (bukan parameter)
# supaya tidak muncul di daftar proses (Task Manager / Get-Process CommandLine).

param(
  [Parameter(Mandatory = $true)][string]$LanIp,
  [Parameter(Mandatory = $true)][string]$Domain,
  # Host 15380 (docker-compose); 5380 hanya di dalam container — bind ke 5380 di Windows sering gagal.
  [string]$ApiBase = "http://127.0.0.1:15380"
)

function Enc([string]$s) {
  [Uri]::EscapeDataString($s)
}

$AdminPassword = $env:GURUBOT_DNS_ADMIN_PASSWORD
if ([string]::IsNullOrEmpty($AdminPassword)) {
  Write-Host "[ERROR] Env var GURUBOT_DNS_ADMIN_PASSWORD tidak diset."
  exit 1
}

Write-Host "[1/6] Menunggu Technitium DNS API ($ApiBase)..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  try {
    Invoke-WebRequest -Uri $ApiBase -UseBasicParsing -TimeoutSec 2 | Out-Null
    $ready = $true
    break
  } catch {
    Start-Sleep -Seconds 2
  }
}
if (-not $ready) {
  Write-Host "[ERROR] Technitium API tidak merespons setelah 60 detik."
  Write-Host "        Cek: docker compose logs dns"
  exit 1
}
Write-Host "[ OK ] Technitium API siap"

Write-Host "[2/6] Login ke Technitium API..."
$loginUrl = "$ApiBase/api/user/login?user=admin&pass=$(Enc $AdminPassword)&includeInfo=true"
try {
  $loginResp = Invoke-RestMethod -Uri $loginUrl -Method Get -TimeoutSec 10
} catch {
  Write-Host "[ERROR] Login Technitium gagal: $($_.Exception.Message)"
  exit 1
}
if ($loginResp.status -ne "ok") {
  Write-Host "[ERROR] Login Technitium gagal: $($loginResp.errorMessage)"
  Write-Host "        Jika DNS_SERVER_ADMIN_PASSWORD baru diubah setelah container pernah start,"
  Write-Host "        password lama tetap dipakai (env var cuma berlaku saat volume dns-config kosong)."
  Write-Host "        Reset: docker compose down; lalu 'docker volume ls' cari volume '..._dns-config'; docker volume rm <nama>"
  exit 1
}
$token = $loginResp.token
Write-Host "[ OK ] Login sukses"

Write-Host "[3/6] Memastikan zone '$Domain' ada..."
$createZoneUrl = "$ApiBase/api/zones/create?zone=$(Enc $Domain)&type=Primary&token=$(Enc $token)"
try {
  $zoneResp = Invoke-RestMethod -Uri $createZoneUrl -Method Get -TimeoutSec 10
  if ($zoneResp.status -eq "ok") {
    Write-Host "[ OK ] Zone '$Domain' dibuat"
  } else {
    Write-Host "[INFO] Zone: $($zoneResp.errorMessage) (kemungkinan sudah ada - lanjut)"
  }
} catch {
  Write-Host "[INFO] Zone create: $($_.Exception.Message) (kemungkinan sudah ada - lanjut)"
}

Write-Host "[4/6] Set A record $Domain -> $LanIp..."
$addRecordUrl = "$ApiBase/api/zones/records/add?domain=$(Enc $Domain)&zone=$(Enc $Domain)&type=A&ipAddress=$(Enc $LanIp)&ttl=300&overwrite=true&token=$(Enc $token)"
try {
  $recResp = Invoke-RestMethod -Uri $addRecordUrl -Method Get -TimeoutSec 10
} catch {
  Write-Host "[ERROR] Gagal set A record: $($_.Exception.Message)"
  exit 1
}
if ($recResp.status -ne "ok") {
  Write-Host "[ERROR] Gagal set A record: $($recResp.errorMessage)"
  exit 1
}
Write-Host "[ OK ] A record: $Domain -> $LanIp"

Write-Host "[5/6] Set DNS adapter Windows aktif -> 127.0.0.1, 8.8.8.8..."
try {
  $adapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
  if ($adapter) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("127.0.0.1", "8.8.8.8") -ErrorAction Stop
    Write-Host "[ OK ] Adapter '$($adapter.Name)' -> 127.0.0.1, 8.8.8.8"
  } else {
    Write-Host "[WARN] Tidak ada adapter jaringan aktif terdeteksi - set DNS manual jika perlu."
  }
} catch {
  Write-Host "[WARN] Gagal set DNS adapter (butuh Administrator): $($_.Exception.Message)"
}

Write-Host "[6/6] Menambah entri hosts fallback ($Domain -> 127.0.0.1)..."
try {
  $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
  $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
  if ($hostsContent -match "\b$([regex]::Escape($Domain))\b") {
    Write-Host "[INFO] hosts entry sudah ada"
  } else {
    Add-Content -Path $hostsPath -Value "127.0.0.1   $Domain" -ErrorAction Stop
    Write-Host "[ OK ] hosts: 127.0.0.1 $Domain"
  }
  ipconfig /flushdns | Out-Null
} catch {
  Write-Host "[WARN] Gagal menulis hosts (butuh Administrator): $($_.Exception.Message)"
}

exit 0
