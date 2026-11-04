# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - WINDOWS POWERSHELL
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, dọn sạch file cũ, giao diện UTF-8
# ==============================================================================

try { chcp 65001 >$null } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not (Test-Path variable:Ip)) { $Ip = "" }
if (-not (Test-Path variable:Yes)) { $Yes = $false }
if (-not (Test-Path variable:DryRun)) { $DryRun = $false }
$RunWifiCli = $false
$RunScanCli = $false

if ($args.Count -gt 0) {
    foreach ($a in $args) {
        if ($a -eq "192.168.43.1") {
            $Ip = $a
            $RunWifiCli = $true
        } elseif ($a -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
            $Ip = $a
        } elseif ($a -eq "-Yes" -or $a -eq "-y") {
            $Yes = $true
        } elseif ($a -eq "-DryRun") {
            $DryRun = $true
        } elseif ($a -eq "-Wifi" -or $a -eq "--wifi") {
            $RunWifiCli = $true
        } elseif ($a -eq "-Scan" -or $a -eq "--scan") {
            $RunScanCli = $true
        }
    }
}

$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$TempDir = Join-Path $env:TEMP "r1_cache"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$BaseUrl = "https://vdt34.github.io/r1"

function Set-R1InstallProgress {
    param(
        [int]$Percent,
        [string]$Status
    )

    if ([Console]::IsOutputRedirected) { return }

    $filled = [Math]::Floor($Percent / 2)
    $bar = ("█" * $filled) + ("░" * (50 - $filled))
    $bufferWidth = [Console]::BufferWidth
    if (-not $script:R1ProgressActive) {
        $script:R1ProgressTop = [Math]::Min([Console]::CursorTop, [Console]::BufferHeight - 3)
    }

    $top = $script:R1ProgressTop
    foreach ($line in @("   $Status", ("   [{0}] {1,3}%" -f $bar, $Percent))) {
        [Console]::SetCursorPosition(0, $top)
        [Console]::Write((' ' * ($bufferWidth - 1)))
        [Console]::SetCursorPosition(0, $top)
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::WriteLine($line)
        $top++
    }
    [Console]::ResetColor()
    $script:R1ProgressActive = $true
}

function Complete-R1InstallProgress {
    if ([Console]::IsOutputRedirected -or -not $script:R1ProgressActive) { return }

    $bufferWidth = [Console]::BufferWidth
    $top = $script:R1ProgressTop
    for ($i = 0; $i -lt 2; $i++) {
        [Console]::SetCursorPosition(0, $top + $i)
        [Console]::Write((' ' * ($bufferWidth - 1)))
    }
    [Console]::SetCursorPosition(0, $top)
    $script:R1ProgressActive = $false
}

function Wait-R1SpeakerBoot {
    param(
        [string]$Serial,
        [int]$Attempts = 45
    )

    for ($try = 1; $try -le $Attempts; $try++) {
        & adb connect $Serial 2>$null | Out-Null
        $state = (& adb -s $Serial get-state 2>$null | Out-String).Trim()
        if ($state -eq "device") {
            $bootState = (& adb -s $Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
            if ($bootState -eq "1") { return $true }
        }

        Set-R1InstallProgress -Percent 98 -Status "Đang chờ loa khởi động lại ($try/$Attempts)"
        Start-Sleep -Seconds 2
    }

    return $false
}

function Test-R1TcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 1000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) { return $false }
        $client.EndConnect($asyncResult)
        return $true
    } catch {
        return $false
    } finally {
        if ($asyncResult) { $asyncResult.AsyncWaitHandle.Close() }
        $client.Close()
    }
}

# 1. Đảm bảo có công cụ ADB
function Ensure-Adb {
    if ($DryRun -or $env:R1_DRYRUN -eq "1") { return $true }
    if (Get-Command adb -ErrorAction SilentlyContinue) { return $true }
    $localAdb = Join-Path $ScriptDir "adb.exe"
    if (Test-Path $localAdb) { $env:PATH = "$ScriptDir;" + $env:PATH; return $true }
    $cachedAdb = Join-Path $TempDir "platform-tools\adb.exe"
    if (Test-Path $cachedAdb) { $env:PATH = "$TempDir\platform-tools;" + $env:PATH; return $true }

    Write-Host ">> Đang tải công cụ ADB chính thức từ Google..." -ForegroundColor Yellow
    $zip = Join-Path $TempDir "platform-tools.zip"
    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -TimeoutSec 30 -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $TempDir -Force
        $ProgressPreference = $old
        $env:PATH = "$TempDir\platform-tools;" + $env:PATH
        return (Test-Path (Join-Path $TempDir "platform-tools\adb.exe"))
    } catch {
        Write-Host ">> [LỖI] Không thể tải ADB. Vui lòng kiểm tra kết nối mạng." -ForegroundColor Red
        return $false
    }
}

# 2. Hàm đánh thức loa R1 qua cổng 8080/8081
function Revive-Speaker {
    param([string]$TargetIp)
    if (-not $TargetIp) { return }
    try {
        $c8080 = New-Object System.Net.Sockets.TcpClient
        $ar1 = $c8080.BeginConnect($TargetIp, 8080, $null, $null)
        if ($ar1.AsyncWaitHandle.WaitOne(800)) { $c8080.EndConnect($ar1) }
        $c8080.Close()
    } catch {}
    try {
        $c8081 = New-Object System.Net.Sockets.TcpClient
        $ar2 = $c8081.BeginConnect($TargetIp, 8081, $null, $null)
        if ($ar2.AsyncWaitHandle.WaitOne(800)) { $c8081.EndConnect($ar2) }
        $c8081.Close()
    } catch {}
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadStringAsync([uri]"http://$($TargetIp):8080/")
        $wc.DownloadStringAsync([uri]"http://$($TargetIp):8081/")
    } catch {}
}

# 3. [MỤC 1] Cấu hình WiFi cho loa qua AP API (192.168.43.1:8989)
function Send-WifiConfig {
    param(
        [string]$TargetIp = "192.168.43.1",
        [string]$Ssid,
        [string]$Password,
        [string]$Secure = "WPA"
    )

    $bodyObj = @{
        ssid = $Ssid
        secure = $Secure
        password = $Password
        mac = ""
    }
    $json = $bodyObj | ConvertTo-Json -Compress

    if ($DryRun -or $env:R1_DRYRUN -eq "1") {
        Write-Host "   [DRY-RUN] Đã gửi cấu hình WiFi SSID='$Ssid' tới http://$($TargetIp):8989/api/configwifi" -ForegroundColor Yellow
        return $true
    }

    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        $resp = Invoke-RestMethod -Uri "http://$($TargetIp):8989/api/configwifi" -Method Post -ContentType "application/json" -Body $json -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = $old
        return $true
    } catch {
        # Loa thường ngắt kết nối ngay khi nhận lệnh để chuyển mạng, coi như đã gửi thành công
        return $true
    }
}

function Run-WifiConfig {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  CẤU HÌNH WIFI CHO LOA VỪA RESET (CHẾ ĐỘ AP 192.168.43.1)" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Hướng dẫn chuẩn bị:" -ForegroundColor White
    Write-Host "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'." -ForegroundColor White
    Write-Host "  2. Trên máy tính: Vào Cài đặt WiFi -> Kết nối mạng 'Phicomm_R1_xxxx'." -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Nhấn Enter khi đã kết nối WiFi của loa"
    }

    # Kiểm tra cổng 8989 trên loa AP
    Write-Host ""
    Write-Host ">> Đang kiểm tra kết nối tới loa (192.168.43.1:8989)..." -ForegroundColor Cyan
    $connectedApi = $false
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $ar = $client.BeginConnect("192.168.43.1", 8989, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne(1500)) {
            $client.EndConnect($ar)
            $connectedApi = $true
        }
        $client.Close()
    } catch {}

    if ($connectedApi) {
        Write-Host "   [OK] Đã kết nối được API của loa." -ForegroundColor Green
    } else {
        if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
            Write-Host "   [CẢNH BÁO] Chưa kết nối được 192.168.43.1:8989." -ForegroundColor Yellow
            Write-Host "   Kiểm tra: Máy tính đã chọn WiFi Phicomm_R1 chưa? Loa còn phát AP không?" -ForegroundColor Gray
            if (-not $Yes) {
                $cont = Read-Host "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]"
                if ($cont -ne "y" -and $cont -ne "Y") { return $false }
            }
        }
    }

    Write-Host ""
    Write-Host "Nhập thông tin mạng WiFi nhà để loa kết nối:" -ForegroundColor White
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    $ssid = ""
    $pass = ""
    if ($Yes -or $DryRun -or $env:R1_DRYRUN -eq "1") {
        $ssid = "MyWiFi"
        $pass = "12345678"
    } else {
        while (-not $ssid) {
            $ssid = Read-Host ">> Tên WiFi nhà (SSID, phân biệt HOA/thường)"
            $ssid = if ($ssid) { $ssid.Trim() } else { "" }
            if (-not $ssid) {
                Write-Host "   [!] Tên WiFi không được để trống!" -ForegroundColor Yellow
            }
        }
        $pass = Read-Host ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass)"
        $pass = if ($pass) { $pass.Trim() } else { "" }
    }

    $secure = "WPA"
    if (-not $pass) {
        $secure = "INSECURE"
        Write-Host "   -> Chế độ WiFi không mật khẩu (INSECURE)" -ForegroundColor Gray
    } else {
        if ($pass.Length -lt 8) {
            Write-Host "   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host ">> Đang gửi cấu hình tới loa (192.168.43.1:8989)..." -ForegroundColor Cyan
    Send-WifiConfig -TargetIp "192.168.43.1" -Ssid $ssid -Password $pass -Secure $secure | Out-Null

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG!              " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " THÔNG BÁO QUAN TRỌNG:" -ForegroundColor White
    Write-Host "  1. Loa đang kết nối WiFi nhà, chờ khoảng 20 giây sẽ có IP." -ForegroundColor White
    Write-Host "  2. Hãy chuyển máy tính về lại mạng WiFi nhà." -ForegroundColor White
    Write-Host "  3. Sau đó quay lại menu chọn [2] để tìm IP và cài APK." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Write-Host ""
        Read-Host "Nhấn Enter để quay lại menu chính"
    }
    return $true
}

# 4. Hàm dò tìm dải mạng LAN & Quét loa Phicomm R1
function Get-LocalSubnet {
    try {
        $ip = (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -and $_.DefaultIPGateway } | Select-Object -ExpandProperty IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -notlike '127.*' -and $_ -notlike '169.254.*' } | Select-Object -First 1)
        if ($ip) {
            $parts = $ip.Split('.')
            return "$($parts[0]).$($parts[1]).$($parts[2])"
        }
    } catch {}
    return "192.168.1"
}

function Scan-SpeakerIp {
    param([string]$Subnet = "")
    if (-not $Subnet) { $Subnet = Get-LocalSubnet }
    Write-Host ""
    Write-Host ">> Đang quét tự động dải mạng LAN ($Subnet.1 -> 254) tìm loa Phicomm R1..." -ForegroundColor Cyan

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Tasks = [System.Collections.Generic.List[object]]::new()

    1..254 | ForEach-Object {
        $ipStr = "$Subnet.$_"
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $client.BeginConnect($ipStr, 5555, $null, $null)
            $Tasks.Add([PSCustomObject]@{ IP = $ipStr; Client = $client })
        } catch {}
    }

    Start-Sleep -Milliseconds 800

    foreach ($t in $Tasks) {
        try {
            if ($t.Client.Connected) {
                if (-not $Candidates.Contains($t.IP)) { $Candidates.Add($t.IP) }
            }
        } catch {}
        finally { $t.Client.Close() }
    }

    $Tasks8080 = [System.Collections.Generic.List[object]]::new()
    1..254 | ForEach-Object {
        $ipStr = "$Subnet.$_"
        if (-not $Candidates.Contains($ipStr)) {
            $client = New-Object System.Net.Sockets.TcpClient
            try {
                $ar = $client.BeginConnect($ipStr, 8080, $null, $null)
                $Tasks8080.Add([PSCustomObject]@{ IP = $ipStr; Client = $client })
            } catch {}
        }
    }

    Start-Sleep -Milliseconds 800

    foreach ($t in $Tasks8080) {
        try {
            if ($t.Client.Connected) {
                if (-not $Candidates.Contains($t.IP)) { $Candidates.Add($t.IP) }
            }
        } catch {}
        finally { $t.Client.Close() }
    }

    $FoundSpeakers = [System.Collections.Generic.List[object]]::new()
    foreach ($cand in $Candidates) {
        $has5555 = $false
        $has8080 = $false
        $has8081 = $false

        foreach ($p in 5555, 8080, 8081) {
            $c = New-Object System.Net.Sockets.TcpClient
            try {
                $ar = $c.BeginConnect($cand, $p, $null, $null)
                if ($ar.AsyncWaitHandle.WaitOne(300)) {
                    $c.EndConnect($ar)
                    if ($p -eq 5555) { $has5555 = $true }
                    elseif ($p -eq 8080) { $has8080 = $true }
                    elseif ($p -eq 8081) { $has8081 = $true }
                }
            } catch {}
            finally { $c.Close() }
        }

        if ($has5555 -or ($has8080 -and $has8081)) {
            $ports = @()
            if ($has5555) { $ports += "ADB: 5555" }
            if ($has8081) { $ports += "Web AI Box: 8081" }
            if ($has8080) { $ports += "R1: 8080" }
            $FoundSpeakers.Add([PSCustomObject]@{ IP = $cand; Ports = ($ports -join ", ") })
        }
    }

    return $FoundSpeakers
}

# 5. Tải và chuẩn bị 3 file APK từ GitHub
function Ensure-Apks {
    $Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
    Write-Host ""
    Write-Host ">> Đang chuẩn bị và tự động cài AI..." -ForegroundColor Cyan

    foreach ($f in $Apks) {
        $oldFile = Join-Path $TempDir $f
        if (Test-Path $oldFile) { Remove-Item $oldFile -Force -ErrorAction SilentlyContinue }
    }
    Get-ChildItem -Path $TempDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $TempDir -Filter "*.cmd" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    $Missing = $false
    $UnixTs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    for ($i = 0; $i -lt $Apks.Count; $i++) {
        $f = $Apks[$i]
        Set-R1InstallProgress -Percent (5 + ($i * 10)) -Status "Đang chuẩn bị $f"
        $cacheFile = Join-Path $TempDir $f
        $localFile = Join-Path $ScriptDir $f

        if ($DryRun -and (Test-Path $localFile)) {
            Copy-Item $localFile $cacheFile -Force
        } else {
            try {
                $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "$BaseUrl/$f`?t=$UnixTs" -OutFile "$cacheFile.tmp" -TimeoutSec 45 -UseBasicParsing
                Move-Item "$cacheFile.tmp" $cacheFile -Force
                $ProgressPreference = $old
            } catch {
                $ProgressPreference = $old
                $Missing = $true
            }
        }
        Set-R1InstallProgress -Percent (15 + ($i * 10)) -Status "Đã xử lý $f"
    }

    if ($Missing) {
        Complete-R1InstallProgress
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  [LỖI THIẾU FILE CÀI ĐẶT DO CHƯA CÓ INTERNET]" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "Vui lòng kiểm tra kết nối mạng để tải đủ 3 file APK." -ForegroundColor Yellow
        Read-Host "Nhấn Enter để quay lại menu"
        return $false
    }
    return $true
}

function Invoke-AdbInstallStep {
    param(
        [string[]]$Arguments,
        [switch]$RequirePackageSuccess
    )

    $output = & adb @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $packageInstallFailed = $RequirePackageSuccess -and (($output -join "`n") -notmatch '(?m)^Success\s*$')
    if ($exitCode -ne 0 -or $packageInstallFailed) {
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            Write-Host ">> [LỖI] ADB kết thúc với mã lỗi $exitCode." -ForegroundColor Red
        } elseif ($packageInstallFailed) {
            Write-Host ">> [LỖI] ADB không xác nhận cài đặt thành công." -ForegroundColor Red
        }
        return $false
    }
    return $true
}

# 6. [MỤC 2] Luồng Quét IP LAN & Cài đặt APK (GIỮ NGUYÊN CODE CHUẨN)
function Run-Install {
    param([string]$TargetIpParam = "")
    $TargetIp = $TargetIpParam

    if (-not $TargetIp) {
        Write-Host ""
        Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "                  TÌM IP CỦA LOA TRONG LAN                " -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [S] hoặc [Enter]: Tự động QUÉT tìm IP loa trong WiFi nhà (LAN)" -ForegroundColor Cyan
        Write-Host " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------" -ForegroundColor Cyan

        while (-not $TargetIp) {
            $u = Read-Host "Nhập IP hoặc 'S' để quét [Mặc định: S]"
            $u = if ($u) { $u.Trim() } else { "S" }

            if ($u -eq "s" -or $u -eq "S" -or $u -eq "scan") {
                $foundList = Scan-SpeakerIp
                if ($foundList -and $foundList.Count -gt 0) {
                    Write-Host ""
                    Write-Host ">> Phát hiện $($foundList.Count) loa Phicomm R1 trong mạng LAN:" -ForegroundColor Green
                    for ($i = 0; $i -lt $foundList.Count; $i++) {
                        $item = $foundList[$i]
                        Write-Host "   [$($i+1)] $($item.IP) ($($item.Ports))" -ForegroundColor Yellow
                    }
                    Write-Host ""
                    $pick = Read-Host "Chọn số thứ tự loa (1-$($foundList.Count)) hoặc nhập IP khác [Mặc định: 1]"
                    $pick = if ($pick) { $pick.Trim() } else { "" }
                    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $foundList.Count) {
                        $TargetIp = $foundList[[int]$pick - 1].IP
                    } elseif ($pick -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                        $TargetIp = $pick
                    } else {
                        $TargetIp = $foundList[0].IP
                    }
                } else {
                    Write-Host ""
                    Write-Host ">> Không tìm thấy loa trong mạng LAN." -ForegroundColor Yellow
                    $manual = Read-Host "Hoặc nhập IP loa thủ công (Enter=quay lại menu)"
                    if ($manual -and $manual.Trim()) {
                        $TargetIp = $manual.Trim()
                    } else {
                        return
                    }
                }
            } elseif ($u -eq "1" -or $u -eq "192.168.43.1") {
                Write-Host ""
                Write-Host "==========================================================" -ForegroundColor Red
                Write-Host "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!" -ForegroundColor Yellow
                Write-Host "==========================================================" -ForegroundColor Red
                Write-Host "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng." -ForegroundColor White
                Write-Host "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!" -ForegroundColor White
                Write-Host "==========================================================" -ForegroundColor Red
                Read-Host "Nhấn Enter để quay lại menu"
                return
            } else {
                $TargetIp = $u
            }
        }
    }

    # Kiểm tra lại nếu người dùng nhập nhầm 192.168.43.1
    if ($TargetIp -eq "192.168.43.1") {
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!" -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng." -ForegroundColor White
        Write-Host "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!" -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Red
        Read-Host "Nhấn Enter để quay lại menu"
        return
    }

    $TargetIp = $TargetIp.Trim().Replace(":5555", "")
    $Serial = "$($TargetIp):5555"

    Write-Host ""
    Write-Host ">> Sẽ kết nối tới IP: $TargetIp" -ForegroundColor Cyan

    # Đảm bảo có ADB trước khi cài đặt
    if (-not (Ensure-Adb)) {
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  [LỖI] KHÔNG THỂ KHỞI TẠO CÔNG CỤ ADB!" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "Vui lòng kiểm tra kết nối Internet để tải bộ công cụ ADB." -ForegroundColor Yellow
        Read-Host "Nhấn Enter để quay lại menu"
        return
    }

    if (-not (Ensure-Apks)) { return }

    # [2/4] Bắt đầu kết nối thiết bị ADB
    Complete-R1InstallProgress
    Write-Host ""
    Set-R1InstallProgress -Percent 38 -Status "Đang kết nối với loa"

    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Stop-Process -Name adb -Force -ErrorAction SilentlyContinue
        adb kill-server 2>$null | Out-Null
        adb start-server 2>$null | Out-Null
        Start-Sleep -Seconds 1

        $connected = $false
        adb connect $Serial 2>$null | Out-Null
        Start-Sleep -Milliseconds 1200

        $state = (adb -s $Serial get-state 2>$null | Out-String).Trim()
        if ($state -eq "device") {
            adb -s $Serial shell ls /data 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $connected = $true }
        }

        if (-not $connected) {
            Set-R1InstallProgress -Percent 40 -Status "Đang đánh thức loa"
            Revive-Speaker -TargetIp $TargetIp
            Start-Sleep -Milliseconds 1800

            for ($try = 1; $try -le 5; $try++) {
                Set-R1InstallProgress -Percent (40 + ($try * 2)) -Status "Đang chờ loa phản hồi ($try/5)"
                adb connect $Serial 2>$null | Out-Null
                Start-Sleep -Milliseconds 1200

                $state = (adb -s $Serial get-state 2>$null | Out-String).Trim()
                if ($state -eq "device") {
                    adb -s $Serial shell ls /data 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $connected = $true
                        break
                    }
                }
                Start-Sleep -Seconds 1
            }
        }

        if (-not $connected) {
            Complete-R1InstallProgress
            Write-Host ""
            Write-Host "==========================================================" -ForegroundColor Red
            Write-Host "  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI $Serial" -ForegroundColor Red
            Write-Host "==========================================================" -ForegroundColor Red
            Write-Host "Vui lòng kiểm tra:" -ForegroundColor Yellow
            Write-Host " 1. Loa đã cắm nguồn và đang bật." -ForegroundColor White
            Write-Host " 2. Máy tính và loa đang kết nối CÙNG MẠNG WiFi." -ForegroundColor White
            Write-Host " 3. Địa chỉ IP của loa ($TargetIp) đã đúng chưa." -ForegroundColor White
            Write-Host " 4. Nếu loa vừa reset -> hãy chọn mục 1 để cấu hình WiFi trước." -ForegroundColor White
            Write-Host "==========================================================" -ForegroundColor Red
            Read-Host "Nhấn Enter để quay lại menu"
            return
        }
    }
    Set-R1InstallProgress -Percent 52 -Status "Đã kết nối với loa"

    # [3/4] Đẩy APK lên bộ nhớ tạm của loa
    $Apks = @("autodlna.apk", "unisound.apk")
    Set-R1InstallProgress -Percent 54 -Status "Đang dọn dẹp và chuẩn bị loa"
    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        adb -s $Serial shell rm /sdcard/otaprop.txt 2>$null | Out-Null
        adb -s $Serial shell rm /sdcard/incremental*.zip 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm clear com.phicomm.speaker.otaservice 2>$null | Out-Null
        adb -s $Serial shell "rm -rf /data/local/tmp/* 2>/dev/null" 2>$null | Out-Null
        adb -s $Serial shell settings put secure install_non_market_apps 1 2>$null | Out-Null

        Set-R1InstallProgress -Percent 58 -Status "Đang tắt ứng dụng xung đột"
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.airskill 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.systemtool 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.device 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.otaservice 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.productiontest 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.bugreport 2>$null | Out-Null
    }

    for ($i = 0; $i -lt $Apks.Count; $i++) {
        $f = $Apks[$i]
        Set-R1InstallProgress -Percent (60 + ($i * 4)) -Status "Đang chuyển $f vào loa"
        if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
            $localApk = Join-Path $TempDir $f
            if (-not (Test-Path -LiteralPath $localApk -PathType Leaf)) {
                Complete-R1InstallProgress
                Write-Host ">> [LỖI] Không tìm thấy file APK trên máy: $localApk" -ForegroundColor Red
                Read-Host "Nhấn Enter để quay lại menu"
                return
            }

            if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "push", $localApk, "/data/local/tmp/$f"))) {
                Complete-R1InstallProgress
                Write-Host ">> [LỖI] Tải file lên loa thất bại: $f" -ForegroundColor Red
                Read-Host "Nhấn Enter để quay lại menu"
                return
            }
        }
    }
    if ($DryRun -or $env:R1_DRYRUN -eq "1") {
        Set-R1InstallProgress -Percent 68 -Status "[DRY-RUN] Đã mô phỏng chuẩn bị loa"
    }

    # [4/4] Thực thi chuỗi lệnh cài đặt hệ thống chuẩn theo new.bat

    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        $PostRebootAiStarted = $false
        $WebUiReady = $false
        for ($i = 0; $i -lt $Apks.Count; $i++) {
            $f = $Apks[$i]
            Set-R1InstallProgress -Percent (70 + ($i * 5)) -Status "Đang cài $f"
            if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "shell", "/system/bin/pm", "install", "-r", "/data/local/tmp/$f") -RequirePackageSuccess)) {
                Complete-R1InstallProgress
                Write-Host ">> [LỖI] Cài đặt thất bại: $f" -ForegroundColor Red
                Read-Host "Nhấn Enter để quay lại menu"
                return
            }
        }
        foreach ($f in $Apks) {
            adb -s $Serial shell rm "/data/local/tmp/$f" 2>$null | Out-Null
        }

        Set-R1InstallProgress -Percent 80 -Status "Đang khởi chạy dịch vụ loa"
        adb -s $Serial shell am startservice com.phicomm.speaker.player/.EchoService 2>$null | Out-Null
        adb -s $Serial shell am start com.phicomm.speaker.device/.ui.MainActivity 2>$null | Out-Null
        Start-Sleep -Seconds 3

        Set-R1InstallProgress -Percent 83 -Status "Đang khôi phục dịch vụ hệ thống"
        adb -s $Serial shell /system/bin/pm unhide com.phicomm.speaker.ijetty 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm unhide com.phicomm.speaker.netctl 2>$null | Out-Null

        Set-R1InstallProgress -Percent 85 -Status "Đang gỡ phiên bản AI cũ"
        adb -s $Serial shell /system/bin/pm uninstall info.dourok.voicebot 2>$null | Out-Null

        $aiApk = "AIBoxPlus_DLNA.apk"
        $localAiApk = Join-Path $TempDir $aiApk
        if (-not (Test-Path -LiteralPath $localAiApk -PathType Leaf)) {
            Complete-R1InstallProgress
            Write-Host ">> [LỖI] Không tìm thấy file APK trên máy: $localAiApk" -ForegroundColor Red
            Read-Host "Nhấn Enter để quay lại menu"
            return
        }

        Set-R1InstallProgress -Percent 88 -Status "Đang chuyển AI Box vào loa"
        if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "push", $localAiApk, "/data/local/tmp/$aiApk"))) {
            Complete-R1InstallProgress
            Write-Host ">> [LỖI] Tải file lên loa thất bại: $aiApk" -ForegroundColor Red
            Read-Host "Nhấn Enter để quay lại menu"
            return
        }

        Set-R1InstallProgress -Percent 92 -Status "Đang cài AI Box Plus"
        if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "shell", "/system/bin/pm", "install", "-r", "/data/local/tmp/$aiApk") -RequirePackageSuccess)) {
            Complete-R1InstallProgress
            Write-Host ">> [LỖI] Cài đặt thất bại: $aiApk" -ForegroundColor Red
            Read-Host "Nhấn Enter để quay lại menu"
            return
        }
        adb -s $Serial shell rm "/data/local/tmp/$aiApk" 2>$null | Out-Null

        Set-R1InstallProgress -Percent 95 -Status "Đang khởi chạy AI Box Plus"
        adb -s $Serial shell am start -n info.dourok.voicebot/.java.activities.MainActivity 2>$null | Out-Null
        Start-Sleep -Seconds 5

        Complete-R1InstallProgress
        Write-Host ""
        Write-Host "------------------------------------------------------------------------"
        Write-Host "Truy cập Xiaozhi.me để nhập mã 6 số và cấu hình AI."
        Write-Host "Nếu AI đã được cấu hình trước đó, có thể bỏ qua bước này."
        Write-Host "------------------------------------------------------------------------"
        Start-Sleep -Seconds 2

        adb -s $Serial shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" 2>$null | Out-Null

        Write-Host ">> Cài đặt thành công, loa sẽ tự khởi động lại." -ForegroundColor Green
        $SpeakerLanIp = (adb -s $Serial shell "getprop dhcp.wlan0.ipaddress 2>/dev/null" 2>$null | Out-String).Trim()

        Set-R1InstallProgress -Percent 98 -Status "Đang khởi động lại loa"
        adb -s $Serial reboot 2>$null | Out-Null
        if (Wait-R1SpeakerBoot -Serial $Serial) {
            Set-R1InstallProgress -Percent 99 -Status "Đang khởi chạy AI sau reboot"
            $launchOutput = & adb -s $Serial shell am start -n info.dourok.voicebot/.java.activities.MainActivity 2>&1
            $launchExitCode = $LASTEXITCODE
            $launchFailed = (($launchOutput -join "`n") -match '(?im)^\s*(Error:|Exception|.*does not exist)')
            if ($launchExitCode -eq 0 -and -not $launchFailed) {
                $PostRebootAiStarted = $true
                Start-Sleep -Seconds 5
                for ($try = 1; $try -le 15; $try++) {
                    if (Test-R1TcpPort -HostName $TargetIp -Port 8081) {
                        $WebUiReady = $true
                        break
                    }
                    Set-R1InstallProgress -Percent 99 -Status "Đang chờ WebUI khởi động ($try/15)"
                    Start-Sleep -Seconds 1
                }
            } else {
                Complete-R1InstallProgress
                Write-Host ">> [CẢNH BÁO] Không khởi chạy được AI sau reboot:" -ForegroundColor Yellow
                if ($launchOutput) { $launchOutput | ForEach-Object { Write-Host $_ } }
            }
        } else {
            Complete-R1InstallProgress
            Write-Host ">> [CẢNH BÁO] Loa chưa kết nối lại sau reboot; không xác minh được AI/WebUI." -ForegroundColor Yellow
        }
        Set-R1InstallProgress -Percent 100 -Status "Hoàn tất"
    } else {
        $PostRebootAiStarted = $false
        $WebUiReady = $false
        Set-R1InstallProgress -Percent 100 -Status "[DRY-RUN] Hoàn tất, loa chưa reboot"
        $SpeakerLanIp = ""
    }

    # Dọn dẹp cache
    foreach ($f in @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")) {
        $tmpFile = Join-Path $TempDir $f
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
    }

    $UiIp = if ($SpeakerLanIp -and $SpeakerLanIp -ne "") { $SpeakerLanIp } else { $TargetIp }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "                    CÀI ĐẶT HOÀN TẤT!                     " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    if ($DryRun -or $env:R1_DRYRUN -eq "1") {
        Write-Host ">> Chạy thử hoàn tất; loa chưa được reboot." -ForegroundColor Yellow
    } else {
        Write-Host ">> Đã gửi lệnh khởi động lại (Reboot) loa." -ForegroundColor Green
        Write-Host ">> Loa đang khởi động lại (thường mất khoảng 30 - 45 giây)." -ForegroundColor White
        if ($PostRebootAiStarted) {
            Write-Host ">> AI đã được khởi chạy sau reboot." -ForegroundColor Green
        } else {
            Write-Host ">> [CẢNH BÁO] Chưa xác minh được AI chạy sau reboot." -ForegroundColor Yellow
        }
        if ($WebUiReady) {
            Write-Host ">> WebUI đã phản hồi tại cổng 8081." -ForegroundColor Green
        } else {
            Write-Host ">> [CẢNH BÁO] WebUI chưa phản hồi tại cổng 8081." -ForegroundColor Yellow
        }
    }
    Write-Host ""
    if ($DryRun -or $env:R1_DRYRUN -eq "1") {
        Write-Host ">> Khi cài thật, truy cập bảng điều khiển sau khi loa khởi động:" -ForegroundColor White
    } else {
        Write-Host ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:" -ForegroundColor White
    }
    Write-Host "   👉 http://$($UiIp):8081/" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""
    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Nhấn Enter để quay lại menu chính"
    }
}

# 7. Hàm hiển thị Menu chính
function Show-Menu {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - WINDOWS POWERSHELL      " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)" -ForegroundColor White
    Write-Host "     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2) Quét IP LAN & Cài đặt APK (AutoDLNA + Unisound + AI)" -ForegroundColor White
    Write-Host "     -> Dùng khi loa ĐÃ vào WiFi nhà (có IP LAN)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3) Chỉ quét tìm IP loa trong LAN (không cài đặt)" -ForegroundColor White
    Write-Host "  4) Thoát" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    $choice = Read-Host "Chọn [1-4]"
    if ($null -eq $choice) { return "4" }
    if ($choice) { return $choice.Trim() }
    return ""
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if ($RunWifiCli) {
    Run-WifiConfig | Out-Null
    return
}

if ($Ip -and $Ip -ne "") {
    Run-Install -TargetIpParam $Ip
    return
}

if ($RunScanCli) {
    $foundList = Scan-SpeakerIp
    if ($foundList -and $foundList.Count -gt 0) {
        Write-Host ">> Tìm thấy $($foundList.Count) loa Phicomm R1 trong mạng LAN." -ForegroundColor Green
    }
    return
}

# Vòng lặp Menu chính
while ($true) {
    $c = Show-Menu
    if ($c -eq "1") {
        Run-WifiConfig | Out-Null
    } elseif ($c -eq "2") {
        Run-Install ""
    } elseif ($c -eq "3") {
        $foundList = Scan-SpeakerIp
        if ($foundList -and $foundList.Count -gt 0) {
            Write-Host ""
            Write-Host ">> Phát hiện $($foundList.Count) loa Phicomm R1 trong mạng LAN:" -ForegroundColor Green
            for ($i = 0; $i -lt $foundList.Count; $i++) {
                $item = $foundList[$i]
                Write-Host "   [$($i+1)] $($item.IP) ($($item.Ports))" -ForegroundColor Yellow
            }
        } else {
            Write-Host ""
            Write-Host ">> Không tìm thấy loa R1 trong dải mạng hiện tại." -ForegroundColor Yellow
        }
        Write-Host ""
        Read-Host "Nhấn Enter để quay lại menu chính"
    } elseif ($c -eq "4" -or $c -eq "q" -or $c -eq "Q" -or $c -eq "exit") {
        Write-Host "Thoát chương trình." -ForegroundColor Yellow
        break
    } elseif ($c -eq "") {
        continue
    } else {
        Write-Host "Lựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 4." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 600
    }
}
