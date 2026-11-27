# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - WINDOWS POWERSHELL
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, dọn sạch file cũ, giao diện UTF-8
# Hỗ trợ WiFi AP, Cài đặt qua AP Mode, Cài đặt qua LAN, Quét loa, ADB ổn định
# ==============================================================================

try { chcp 65001 >$null } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not (Test-Path variable:Ip)) { $Ip = "" }
if (-not (Test-Path variable:Yes)) { $Yes = $false }
if (-not (Test-Path variable:DryRun)) { $DryRun = $false }
$RunWifiCli = $false
$RunScanCli = $false
$RunCleanCli = $false
$RunUpdateCli = $false

if ($args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        $a = $args[$i]
        if ($a -eq "192.168.43.1") {
            $Ip = $a
        }
        elseif (($a -eq "-Ip" -or $a -eq "--ip") -and ($i + 1) -lt $args.Count) {
            $Ip = $args[++$i]
        }
        elseif ($a -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
            $Ip = $a
        }
        elseif ($a -eq "-Yes" -or $a -eq "-y") {
            $Yes = $true
        }
        elseif ($a -eq "-DryRun") {
            $DryRun = $true
        }
        elseif ($a -eq "-Wifi" -or $a -eq "--wifi") {
            $RunWifiCli = $true
        }
        elseif ($a -eq "-Scan" -or $a -eq "--scan") {
            $RunScanCli = $true
        }
        elseif ($a -eq "-Clean" -or $a -eq "--clean") {
            $RunCleanCli = $true
        }
        elseif ($a -eq "-Update" -or $a -eq "--update" -or $a -eq "-AiOnly" -or $a -eq "--ai-only" -or $a -eq "-ai") {
            $RunUpdateCli = $true
        }
        elseif ($a -eq "-LocalDir" -and ($i + 1) -lt $args.Count) {
            $ScriptDir = $args[++$i]
        }
        elseif ($a -eq "-ApkBase" -and ($i + 1) -lt $args.Count) {
            $BaseUrl = $args[++$i]
        }
    }
}

function Read-R1Input {
    param(
        [string]$Prompt,
        [string]$DefaultVal = ""
    )
    if ($Yes -or $DryRun -or $env:R1_DRYRUN -eq "1") {
        return $DefaultVal
    }
    $val = Read-Host $Prompt
    if (-not $val -or $val.Trim() -eq "") {
        return $DefaultVal
    }
    return $val.Trim()
}

if (-not $ScriptDir) {
    if ($global:R1_SCRIPT_DIR) {
        $ScriptDir = $global:R1_SCRIPT_DIR
    }
    elseif ($env:R1_BAT_DIR) {
        $ScriptDir = $env:R1_BAT_DIR
    }
    elseif ($PSScriptRoot) {
        $ScriptDir = $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    elseif ($MyInvocation.PSCommandPath) {
        $ScriptDir = Split-Path -Parent $MyInvocation.PSCommandPath
    }
    else {
        $ScriptDir = (Get-Location).Path
    }
}
if ($ScriptDir) {
    $ScriptDir = $ScriptDir.TrimEnd('\/')
}

$TempDir = Join-Path $env:TEMP "r1_cache"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
if (-not $BaseUrl) {
    $BaseUrl = if ($env:NABU_R1_BASE) { $env:NABU_R1_BASE } else { "https://vdt34.github.io/r1" }
}

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
    $client.LingerState = New-Object System.Net.Sockets.LingerOption($false, 0)
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) { return $false }
        $client.EndConnect($asyncResult)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($asyncResult) { $asyncResult.AsyncWaitHandle.Close() }
        try { $client.Client.Close(0) } catch {}
        $client.Close()
    }
}

# 1. Đảm bảo có công cụ ADB
function Ensure-Adb {
    if ($DryRun -or $env:R1_DRYRUN -eq "1") { return $true }
    if (Get-Command adb -ErrorAction SilentlyContinue) { return $true }
    $localAdb = Join-Path $ScriptDir "adb.exe"
    if (Test-Path $localAdb) { $env:PATH = "$ScriptDir;" + $env:PATH; return $true }
    $cachedAdb = Join-Path (Join-Path $TempDir "platform-tools") "adb.exe"
    if (Test-Path $cachedAdb) { $env:PATH = "$TempDir\platform-tools;" + $env:PATH; return $true }

    Write-Host ">> Đang tải công cụ ADB chính thức từ Google..." -ForegroundColor Yellow
    $zip = Join-Path $TempDir "platform-tools.zip"
    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -TimeoutSec 30 -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $TempDir -Force
        $ProgressPreference = $old
        $env:PATH = "$TempDir\platform-tools;" + $env:PATH
        return (Test-Path (Join-Path (Join-Path $TempDir "platform-tools") "adb.exe"))
    }
    catch {
        Write-Host ">> [LỖI] Không thể tải ADB. Vui lòng kiểm tra kết nối mạng." -ForegroundColor Red
        return $false
    }
}

# 2. Hàm đánh thức & kích hoạt ADB qua WebSocket cổng 8080
function Revive-Speaker {
    param([string]$TargetIp)
    if (-not $TargetIp) { return $false }
    $wsWoke = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.LingerState = New-Object System.Net.Sockets.LingerOption($false, 0)
        $ar = $tcp.BeginConnect($TargetIp, 8080, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne(1200)) {
            $tcp.EndConnect($ar)
            $stream = $tcp.GetStream()
            $stream.ReadTimeout = 1200
            $stream.WriteTimeout = 1200
            $req = "GET / HTTP/1.1`r`nHost: $($TargetIp):8080`r`nUpgrade: websocket`r`nConnection: Upgrade`r`nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==`r`nSec-WebSocket-Version: 13`r`n`r`n"
            $reqBytes = [System.Text.Encoding]::ASCII.GetBytes($req)
            $stream.Write($reqBytes, 0, $reqBytes.Length)
            $buf = New-Object byte[] 1024
            $read = $stream.Read($buf, 0, $buf.Length)
            $resp = [System.Text.Encoding]::ASCII.GetString($buf, 0, [Math]::Max(0, $read))
            if ($resp -match "101") {
                $wsWoke = $true
                $payload = [System.Text.Encoding]::UTF8.GetBytes('{"type":"shell","type_id":"myshell","shell":"setprop service.adb.tcp.port 5555; stop adbd; start adbd"}')
                $mask = [byte[]](0x12, 0x34, 0x56, 0x78)
                $frame = New-Object System.Collections.Generic.List[byte]
                $frame.Add(0x81)
                $frame.Add([byte](0x80 -bor $payload.Length))
                $frame.AddRange($mask)
                for ($i = 0; $i -lt $payload.Length; $i++) {
                    $frame.Add([byte]($payload[$i] -bxor $mask[$i % 4]))
                }
                $frameArr = $frame.ToArray()
                $stream.Write($frameArr, 0, $frameArr.Length)
                Start-Sleep -Milliseconds 200
            }
        }
        try { $tcp.Client.Close(0) } catch {}
        $tcp.Close()
    }
    catch {}

    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "http://$($TargetIp):8080/" -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
        Invoke-WebRequest -Uri "http://$($TargetIp):8081/" -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
        $ProgressPreference = $old
    }
    catch {}

    return $wsWoke
}

# 3. Cấu hình WiFi cho loa qua AP API (Hỗ trợ cả cổng 8081 và 8089)
function Send-WifiConfig {
    param(
        [string]$TargetIp = "192.168.43.1",
        [string]$Ssid,
        [string]$Password,
        [string]$Secure = "WPA"
    )

    $bodyObj = @{
        ssid     = $Ssid
        secure   = $Secure
        password = $Password
        mac      = ""
    }
    $json = $bodyObj | ConvertTo-Json -Compress

    if ($DryRun -or $env:R1_DRYRUN -eq "1") {
        Write-Host "   [DRY-RUN] Đã gửi cấu hình WiFi SSID='$Ssid' tới http://$($TargetIp):8081 và 8089" -ForegroundColor Yellow
        return $true
    }

    $targetPorts = @()
    if (Test-R1TcpPort -HostName $TargetIp -Port 8081 -TimeoutMilliseconds 1500) {
        $targetPorts += 8081
    }
    if (Test-R1TcpPort -HostName $TargetIp -Port 8089 -TimeoutMilliseconds 1500) {
        $targetPorts += 8089
    }
    if ($targetPorts.Count -eq 0) {
        $targetPorts = @(8081, 8089)
    }

    $success = $false
    foreach ($p in $targetPorts) {
        try {
            Write-Host ">> Đang gửi cấu hình tới http://$($TargetIp):$p/api/configwifi..." -ForegroundColor Cyan
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            $resp = Invoke-RestMethod -Uri "http://$($TargetIp):$p/api/configwifi" -Method Post -ContentType "application/json" -Body $json -TimeoutSec 6 -UseBasicParsing -ErrorAction Stop
            $ProgressPreference = $old
            $respStr = ($resp | Out-String)
            if ($respStr -match '(?i)success.*true' -or ($resp.success -eq $true)) {
                Write-Host "   [OK] Loa đã xác nhận lưu cấu hình WiFi qua cổng $p!" -ForegroundColor Green
                $success = $true
                break
            }
        }
        catch {
            # Loa có thể ngắt AP ngay sau khi nhận cấu hình để switch mạng
            $exMsg = $_.Exception.Message
            if ($exMsg -match 'timed out' -or $exMsg -match 'closed' -or $exMsg -match 'reset') {
                Write-Host "   [OK] Loa đã tiếp nhận cấu hình và đang chuyển mạng WiFi qua cổng $p!" -ForegroundColor Green
                $success = $true
                break
            }
        }
    }
    return $success
}

function Run-WifiConfig {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  CẤU HÌNH WIFI CHO LOA (CHẾ ĐỘ AP 192.168.43.1)" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Hướng dẫn chuẩn bị:" -ForegroundColor White
    Write-Host "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'." -ForegroundColor White
    Write-Host "  2. Trên máy tính: Vào Cài đặt WiFi -> Kết nối mạng 'Phicomm_R1_xxxx'." -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Nhấn Enter khi đã kết nối WiFi của loa"
    }

    # Kiểm tra cổng 8081 hoặc 8089 trên loa AP
    Write-Host ""
    Write-Host ">> Đang kiểm tra kết nối tới loa (192.168.43.1:8081 / 8089)..." -ForegroundColor Cyan
    $port8081Open = Test-R1TcpPort -HostName "192.168.43.1" -Port 8081 -TimeoutMilliseconds 2000
    $port8089Open = Test-R1TcpPort -HostName "192.168.43.1" -Port 8089 -TimeoutMilliseconds 2000

    if ($port8081Open) {
        Write-Host "   [OK] Đã kết nối API loa qua cổng 8081 (AIBoxPlus)." -ForegroundColor Green
    }
    elseif ($port8089Open) {
        Write-Host "   [OK] Đã kết nối API loa qua cổng 8089 (Daemon gốc)." -ForegroundColor Green
    }
    else {
        if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
            Write-Host "   [CẢNH BÁO] Chưa kết nối được cổng 8081/8089 trên 192.168.43.1." -ForegroundColor Yellow
            Write-Host "   Kiểm tra: Máy tính đã chọn WiFi Phicomm_R1 chưa? Loa còn phát AP không?" -ForegroundColor Gray
            if (-not $Yes) {
                $cont = Read-Host "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]"
                if ($cont -ne "y" -and $cont -ne "Y") { return $false }
            }
        }
    }

    $ssid = ""
    $pass = ""
    $secure = "WPA"

    if ($Yes -or $DryRun -or $env:R1_DRYRUN -eq "1") {
        $ssid = "MyWiFi"
        $pass = "12345678"
    }
    else {
        # Thử quét danh sách WiFi từ loa nếu cổng 8081 mở
        $scannedList = @()
        if ($port8081Open) {
            Write-Host ""
            Write-Host ">> Đang quét các mạng WiFi xung quanh loa..." -ForegroundColor Cyan
            try {
                $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                $scanResp = Invoke-RestMethod -Uri "http://192.168.43.1:8081/api/getwifilist" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                $ProgressPreference = $old
                if ($scanResp -and $scanResp.networks) {
                    $seen = @{}
                    foreach ($net in $scanResp.networks) {
                        $sName = [string]$net.ssid
                        if ($sName -and $sName.Trim() -ne "" -and -not $seen.ContainsKey($sName)) {
                            $seen[$sName] = $true
                            $scannedList += $net
                        }
                    }
                }
            }
            catch {}
        }

        if ($scannedList.Count -gt 0) {
            Write-Host ">> Tìm thấy $($scannedList.Count) mạng WiFi xung quanh loa:" -ForegroundColor Green
            Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
            $maxShow = [Math]::Min(15, $scannedList.Count)
            for ($i = 0; $i -lt $maxShow; $i++) {
                $net = $scannedList[$i]
                $secLabel = if ($net.is_secure) { "Khóa" } else { "Mở" }
                $padIdx = (" " + ($i + 1)).Substring((" " + ($i + 1)).Length - 2)
                $lvlStr = "$($net.level) dBm"
                Write-Host "  [$padIdx] $($net.ssid.PadRight(28)) ($lvlStr) [$secLabel]" -ForegroundColor White
            }
            Write-Host "  [ 0] Nhập tên WiFi thủ công (nếu WiFi bị ẩn)" -ForegroundColor Gray
            Write-Host "----------------------------------------------------------" -ForegroundColor Cyan

            $pickStr = Read-Host ">> Chọn số thứ tự WiFi (1-$maxShow) hoặc 0 để tự nhập [Mặc định: 1]"
            $pickStr = if ($pickStr) { $pickStr.Trim() } else { "1" }
            if ($pickStr -match '^\d+$' -and [int]$pickStr -ge 1 -and [int]$pickStr -le $maxShow) {
                $selectedNet = $scannedList[[int]$pickStr - 1]
                $ssid = $selectedNet.ssid
                $secure = if ($selectedNet.is_secure) { "WPA" } else { "INSECURE" }
                Write-Host "   -> Đã chọn mạng: $ssid ($secure)" -ForegroundColor Green
            }
        }

        # Nếu chưa chọn được từ danh sách (hoặc chọn 0 / quét không ra)
        while (-not $ssid) {
            Write-Host ""
            Write-Host "Nhập thông tin mạng WiFi nhà để loa kết nối:" -ForegroundColor White
            Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
            $ssid = Read-Host ">> Tên WiFi nhà (SSID, phân biệt HOA/thường)"
            if (-not $ssid) {
                Write-Host "   [!] Tên WiFi không được để trống!" -ForegroundColor Yellow
            }
        }

        # Nhập mật khẩu nếu mạng có bảo mật
        if ($secure -eq "INSECURE") {
            Write-Host "   -> Mạng không có mật khẩu (INSECURE)" -ForegroundColor White
            $pass = ""
        }
        else {
            $pass = Read-Host ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass)"
            if (-not $pass -or $pass -eq "") {
                $secure = "INSECURE"
                Write-Host "   -> Chế độ WiFi không mật khẩu (INSECURE)" -ForegroundColor White
            }
            else {
                if ($pass.Length -lt 8) {
                    Write-Host "   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!" -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host ""
    Send-WifiConfig -TargetIp "192.168.43.1" -Ssid $ssid -Password $pass -Secure $secure | Out-Null

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "            ĐÃ GỬI CẤU HÌNH WIFI CHO LOA!                 " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " THÔNG BÁO QUAN TRỌNG:" -ForegroundColor White
    Write-Host "  1. Loa đang chuyển sang kết nối WiFi '$ssid'." -ForegroundColor White
    Write-Host "  2. Hãy chuyển máy tính về lại mạng WiFi nhà '$ssid'." -ForegroundColor White
    Write-Host "  3. Chờ loa khởi động lại và nhận IP mới (khoảng 15-20s)." -ForegroundColor White
    Write-Host "  4. Sau đó bạn có thể chọn mục [4] trong menu để quét tìm IP mới của loa." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Write-Host ""
        Read-Host "Nhấn Enter để quay lại menu chính"
    }
    return $true
}

# 4. Tìm kiếm IP Subnet và Quét IP loa Phicomm R1
function Get-LocalSubnet {
    $subnet = $null
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Connect("8.8.8.8", 53)
        $localIp = $udp.Client.LocalEndPoint.Address.ToString()
        $udp.Close()
        if ($localIp -and $localIp -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$') {
            $subnet = $matches[1]
        }
    }
    catch {}

    if (-not $subnet) {
        $ips = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
        Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -notmatch '^(127\.|169\.254\.)' }
        if ($ips) {
            $subnet = ($ips[0].IPAddressToString -split '\.')[0..2] -join '.'
        }
    }

    if (-not $subnet) { $subnet = "192.168.1" }
    return $subnet
}

function Scan-SpeakerIp {
    param([string]$Subnet = "")
    if (-not $Subnet) { $Subnet = Get-LocalSubnet }
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                         🔍 ĐANG TÌM KIẾM LOA                       ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   📡 Mạng: $Subnet.0/24" -ForegroundColor White
    Write-Host "   ⏱️  Thời gian: khoảng 15-30 giây" -ForegroundColor Gray
    Write-Host ""

    # Quét bất đồng bộ cổng 5555 trên 254 IP
    $clients = @{}
    $handles = @{}

    for ($i = 1; $i -le 254; $i++) {
        $targetIp = "$Subnet.$i"
        $c = [System.Net.Sockets.TcpClient]::new()
        $c.LingerState = [System.Net.Sockets.LingerOption]::new($false, 0)
        $clients[$targetIp] = $c
        try {
            $handles[$targetIp] = $c.BeginConnect($targetIp, 5555, $null, $null)
        }
        catch {}
    }

    $adbIps = @()
    $checked = [System.Collections.Generic.HashSet[string]]::new()
    $start = [DateTime]::UtcNow
    $totalDuration = 2.5

    while (([DateTime]::UtcNow - $start).TotalSeconds -lt $totalDuration) {
        $elapsed = ([DateTime]::UtcNow - $start).TotalSeconds
        $percent = [Math]::Min(100, [int](($elapsed / $totalDuration) * 100))

        foreach ($ip in @($clients.Keys)) {
            if (-not $checked.Contains($ip)) {
                $h = $handles[$ip]
                if ($h -ne $null -and $h.IsCompleted) {
                    $checked.Add($ip) | Out-Null
                    try {
                        $clients[$ip].EndConnect($h)
                        $adbIps += $ip
                    }
                    catch {}
                }
            }
        }

        $filled = [int]($percent / 2)
        $bar = ('█' * $filled) + ('░' * (50 - $filled))
        Write-Host -NoNewline "`r   [$bar] $percent% • Đã tìm thấy: $($adbIps.Count) loa   "
        Start-Sleep -Milliseconds 50
    }

    Write-Host -NoNewline "`r   [$('█' * 50)] 100% • Đã tìm thấy: $($adbIps.Count) loa   "
    Write-Host ""
    Write-Host ""

    # Đóng ngay lập tức các kết nối socket đã tìm thấy để giải phóng cổng cho ADB
    foreach ($ip in $adbIps) {
        if ($clients.ContainsKey($ip)) {
            try { $clients[$ip].Client.Close(0) } catch {}
            try { $clients[$ip].Close() } catch {}
        }
    }
    # Giải phóng các socket còn lại ngầm ở background
    [System.Threading.Tasks.Task]::Run([Action] {
            foreach ($c in $clients.Values) {
                try { $c.Close() } catch {}
            }
        }) | Out-Null

    Start-Sleep -Milliseconds 300

    # Nếu không tìm thấy qua cổng 5555 trực tiếp, thử quét thêm cổng 8080 để đánh thức ADB nếu loa đang ngủ
    if ($adbIps.Count -eq 0) {
        $wokeAny = $false
        for ($i = 1; $i -le 254; $i++) {
            $tip = "$Subnet.$i"
            if (Test-R1TcpPort -HostName $tip -Port 8080 -TimeoutMilliseconds 150) {
                if (Revive-Speaker -TargetIp $tip) {
                    $wokeAny = $true
                }
            }
        }
        if ($wokeAny) {
            Start-Sleep -Seconds 1
            for ($i = 1; $i -le 254; $i++) {
                $tip = "$Subnet.$i"
                if (Test-R1TcpPort -HostName $tip -Port 5555 -TimeoutMilliseconds 250) {
                    $adbIps += $tip
                }
            }
        }
    }

    if ($adbIps.Count -eq 0) {
        Write-Host "   ❌ Không tìm thấy loa Phicomm R1 trên mạng này." -ForegroundColor Red
        Write-Host ""
        Write-Host "   📝 Gợi ý:" -ForegroundColor Yellow
        Write-Host "      • Kiểm tra loa đã bật và kết nối WiFi" -ForegroundColor White
        Write-Host "      • Đảm bảo loa và máy tính cùng mạng" -ForegroundColor White
        Write-Host ""
        return @()
    }

    Write-Host "   Tìm thấy $($adbIps.Count) thiết bị, đang kết nối..." -ForegroundColor Cyan
    Write-Host ""

    $phicommDevices = @()
    $otherDevices = @()
    $adbCmd = if (Get-Command adb -ErrorAction SilentlyContinue) { "adb" } else { "adb.exe" }

    foreach ($ip in $adbIps) {
        Write-Host "   🔗 Kết nối đến $ip... " -NoNewline
        $endpoint = "$ip" + ":5555"

        $connRaw = (& $adbCmd connect $endpoint 2>&1) -join "`n"

        if ($connRaw -match "connected") {
            $model = ((& $adbCmd -s $endpoint shell getprop ro.product.model 2>&1) -join "`n").Trim()
            $hostname = ((& $adbCmd -s $endpoint shell getprop net.hostname 2>&1) -join "`n").Trim()
            $androidVer = ((& $adbCmd -s $endpoint shell getprop ro.build.version.release 2>&1) -join "`n").Trim()

            & $adbCmd disconnect $endpoint >$null 2>&1

            $isPhicomm = ($model -match "(?i)r1") -or ($hostname -match "(?i)phicomm_r1") -or ($model -match "(?i)rk322x")

            $devInfo = [PSCustomObject]@{
                IP       = $ip
                Hostname = if ($hostname) { $hostname } else { "Phicomm_R1" }
                Model    = if ($model) { $model } else { "Phicomm R1" }
                Android  = if ($androidVer) { $androidVer } else { "5.1.1" }
            }

            if ($isPhicomm) {
                Write-Host "✓" -ForegroundColor Green
                $phicommDevices += $devInfo
            }
            else {
                Write-Host " (không phải Phicomm R1)" -ForegroundColor Yellow
                $otherDevices += $devInfo
            }
        }
        else {
            Write-Host "✗" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                            🎯 KẾT QUẢ QUÉT                         ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if ($phicommDevices.Count -gt 0) {
        Write-Host "   ✅ Tìm thấy $($phicommDevices.Count) loa Phicomm R1:" -ForegroundColor Green
        Write-Host ""
        for ($i = 0; $i -lt $phicommDevices.Count; $i++) {
            $dev = $phicommDevices[$i]
            Write-Host "   ┌─── Loa #$($i + 1) ──────────────────────────────────────────────────────" -ForegroundColor Green
            Write-Host "   │  📍 IP:         $($dev.IP)" -ForegroundColor Yellow
            Write-Host "   │  🏷️  Hostname:   $($dev.Hostname)" -ForegroundColor White
            Write-Host "   │  📱 Model:      $($dev.Model)" -ForegroundColor White
            Write-Host "   │  🤖 Android:    $($dev.Android)" -ForegroundColor White
            Write-Host "   └────────────────────────────────────────────────────────────────" -ForegroundColor Green
            Write-Host ""
        }
    }

    if ($otherDevices.Count -gt 0) {
        Write-Host "   ℹ️  Tìm thấy $($otherDevices.Count) thiết bị khác có ADB:" -ForegroundColor Yellow
        foreach ($dev in $otherDevices) {
            Write-Host "      • $($dev.IP) - $($dev.Model)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Write-Host "   ──────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Tổng số thiết bị:    $($phicommDevices.Count + $otherDevices.Count)" -ForegroundColor White
    Write-Host "   Loa Phicomm R1:      $($phicommDevices.Count)" -ForegroundColor White
    Write-Host "   ──────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   ✓ Quét hoàn tất!" -ForegroundColor Green
    Write-Host ""

    return $phicommDevices
}

# 5. Chuẩn bị file APK duy nhất (AIBoxPlus All-in-One)
function Get-LocalAiApk {
    $dirs = @($ScriptDir, (Get-Location).Path, $env:USERPROFILE, $env:TEMP) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    foreach ($d in $dirs) {
        # 1. Tìm bản có phiên bản cao nhất theo dạng ai-box-plus-X-Y-Z.apk
        $files = Get-ChildItem -Path $d -File -Filter 'ai-box-plus-*-*-*.apk' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^ai-box-plus-(\d+)-(\d+)-(\d+)$' } |
        Sort-Object { [version]($_.BaseName -replace '^ai-box-plus-', '' -replace '-', '.') } -Descending
        if ($files -and $files.Count -gt 0) {
            return $files[0]
        }

        # 2. Tìm bất kỳ file apk nào có tên bắt đầu bằng ai-box hoặc aiboxplus
        $fallbackFiles = Get-ChildItem -Path $d -File -Filter "*.apk" -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '(?i)ai[-_]?box' }
        if ($fallbackFiles -and $fallbackFiles.Count -gt 0) {
            return $fallbackFiles[0]
        }
    }
    return $null
}

function Ensure-Apk {
    $targetApkName = "ai-box-plus-app.apk"
    $cacheFile = Join-Path $TempDir $targetApkName

    # 1. Ưu tiên kiểm tra file đã tải sẵn trong CACHE (đã tải ở Bước 1 của Cài đặt AP Mode hoặc lần chạy trước)
    if ((Test-Path $cacheFile) -and ((Get-Item $cacheFile).Length -ge 1000000)) {
        $mb = [math]::Round((Get-Item $cacheFile).Length / 1MB, 1)
        Write-Host ">> [CACHE] Đã có sẵn file APK đã tải: $targetApkName (~$mb MB). Bỏ qua bước tải lại!" -ForegroundColor Green
        return $true
    }

    # 2. Ưu tiên tìm file local trước
    $aiFile = Get-LocalAiApk
    if ($aiFile) {
        Write-Host ">> [LOCAL] Đã tìm thấy file APK cục bộ: $($aiFile.Name)" -ForegroundColor Green
        if ($aiFile.FullName -ne $cacheFile) {
            Copy-Item $aiFile.FullName $cacheFile -Force
        }
        return $true
    }

    # 3. Nếu local và cache đều chưa có, tìm và tải trên server
    Write-Host ">> [ONLINE] Đang kiểm tra phiên bản mới nhất từ máy chủ ($BaseUrl/version.json)..." -ForegroundColor Cyan

    try {
        $UnixTs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $jsonRaw = (Invoke-RestMethod -Uri "$BaseUrl/version.json`?t=$UnixTs" -UseBasicParsing -TimeoutSec 15)
        if ($jsonRaw -is [string]) {
            $meta = $jsonRaw.TrimStart([char]0xFEFF) | ConvertFrom-Json
        }
        else {
            $meta = $jsonRaw
        }

        $aiDownloadUrl = $meta.files[0].url
        $aiApkName = $meta.files[0].name
        $aiVersion = $meta.version
        if (-not $aiDownloadUrl -and $meta.url) {
            $aiDownloadUrl = $meta.url
            $aiApkName = $meta.name
        }
        if (-not $aiDownloadUrl) {
            $aiDownloadUrl = "$BaseUrl/ai-box-plus-1-1-17.apk"
            $aiApkName = "ai-box-plus-1-1-17.apk"
            $aiVersion = "1.1.17"
        }
        Write-Host ">> Phiên bản mới nhất trên máy chủ: $aiApkName (v$aiVersion)" -ForegroundColor Green
        Write-Host ">> Đang tải: $aiDownloadUrl..." -ForegroundColor Cyan

        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "$aiDownloadUrl`?t=$UnixTs" -OutFile "$cacheFile.tmp" -TimeoutSec 60 -UseBasicParsing
        Move-Item "$cacheFile.tmp" $cacheFile -Force
        $ProgressPreference = $old
        return $true
    }
    catch {
        $ProgressPreference = $old
        # Fallback thử tải trực tiếp file APK nếu tải version.json lỗi
        Write-Host ">> [THỬ LẠI] Đang thử tải trực tiếp file APK từ máy chủ..." -ForegroundColor Yellow
        try {
            $directUrl = "$BaseUrl/ai-box-plus-1-1-17.apk"
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri "$directUrl" -OutFile "$cacheFile.tmp" -TimeoutSec 60 -UseBasicParsing
            Move-Item "$cacheFile.tmp" $cacheFile -Force
            $ProgressPreference = $old
            Write-Host ">> Đã tải thành công file APK!" -ForegroundColor Green
            return $true
        }
        catch {
            $ProgressPreference = $old
            Write-Host ">> [LỖI] Không tìm thấy file APK cục bộ và không thể tải APK từ máy chủ ($($_.Exception.Message))." -ForegroundColor Red
            Write-Host ">> Lưu ý: Nếu máy tính đang kết nối vào WiFi AP của loa (192.168.43.1), hãy chuyển về WiFi nhà có Internet trước để tải APK!" -ForegroundColor Yellow
            Read-R1Input "Nhấn Enter để quay lại menu"
            return $false
        }
    }
}

# 6. Thực thi bước cài đặt ADB
function Invoke-AdbInstallStep {
    param(
        [string[]]$Arguments,
        [switch]$RequirePackageSuccess,
        [string]$TargetSerial = ""
    )

    $output = & adb @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $packageInstallFailed = $RequirePackageSuccess -and (($output -join "`n") -notmatch '(?m)^Success\s*$')

    if ($exitCode -ne 0 -or $packageInstallFailed) {
        # Xử lý khi rớt stream ADB do dex2oat (30-45s)
        if ($RequirePackageSuccess -and $TargetSerial) {
            for ($chk = 1; $chk -le 10; $chk++) {
                Start-Sleep -Seconds 3
                & adb connect $TargetSerial 2>$null | Out-Null
                $chkPath = (& adb -s $TargetSerial shell pm path info.dourok.voicebot 2>$null | Out-String)
                if ($chkPath -match 'info\.dourok\.voicebot') {
                    return $true
                }
            }
        }

        Complete-R1InstallProgress
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            Write-Host ">> [LỖI] ADB kết thúc với mã lỗi $exitCode." -ForegroundColor Red
        }
        elseif ($packageInstallFailed) {
            Write-Host ">> [LỖI] ADB không xác nhận cài đặt thành công." -ForegroundColor Red
        }
        return $false
    }
    return $true
}

# 7. Kết nối ADB tin cậy & tự động đánh thức cổng 5555
function Robust-AdbConnect {
    param(
        [string]$Serial,
        [string]$TargetIp
    )

    if ($DryRun -or $env:R1_DRYRUN -eq "1") { return $true }

    # Đảm bảo adb server đã chạy
    adb start-server 2>$null | Out-Null

    # Bước 1: Thử nhanh nếu cổng 5555 đã mở sẵn
    if (Test-R1TcpPort -HostName $TargetIp -Port 5555 -TimeoutMilliseconds 800) {
        adb disconnect $Serial 2>$null | Out-Null
        adb connect $Serial 2>$null | Out-Null
        Start-Sleep -Milliseconds 600

        $state = (adb -s $Serial get-state 2>$null | Out-String).Trim()
        if ($state -eq "device") {
            adb -s $Serial shell echo 1 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $true }
        }
    }

    # Bước 2: Cổng 5555 chưa mở -> Đánh thức qua WebSocket cổng 8080
    Write-Host ">> Cổng ADB 5555 chưa mở. Đang kích hoạt ADB qua WebSocket 8080..." -ForegroundColor Yellow
    Revive-Speaker -TargetIp $TargetIp | Out-Null
    Start-Sleep -Seconds 2

    # Bước 3: Vòng lặp chờ cổng 5555 sẵn sàng và kết nối
    for ($try = 1; $try -le 8; $try++) {
        if (Test-R1TcpPort -HostName $TargetIp -Port 5555 -TimeoutMilliseconds 800) {
            adb disconnect $Serial 2>$null | Out-Null
            adb connect $Serial 2>$null | Out-Null
            Start-Sleep -Milliseconds 600

            $state = (adb -s $Serial get-state 2>$null | Out-String).Trim()
            if ($state -eq "device") {
                adb -s $Serial shell echo 1 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            }
        }
        Start-Sleep -Milliseconds 1200
    }

    return $false
}

# 8. Hàm thực thi nạp APK (Do-ExecuteInstall)
function Do-ExecuteInstall {
    param(
        [string]$TargetIpParam,
        [int]$CleanMode = 0   # 1 = Clean Install, 0 = Update
    )

    $TargetIp = $TargetIpParam.Trim().Replace(":5555", "")
    $Serial = "$($TargetIp):5555"

    $modeTitle = if ($CleanMode -eq 1) { "CÀI ĐẶT MỚI HOÀN TOÀN (CLEAN INSTALL)" } else { "CẬP NHẬT / NÂNG CẤP (GIỮ DỮ LIỆU)" }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  BẮT ĐẦU: $modeTitle" -ForegroundColor Yellow
    Write-Host "  Mục tiêu: $Serial" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    if (-not (Ensure-Adb)) {
        Write-Host ">> [LỖI] Không thể khởi tạo công cụ ADB." -ForegroundColor Red
        Read-R1Input "Nhấn Enter để quay lại menu"
        return
    }

    Set-R1InstallProgress -Percent 15 -Status "Đang chuẩn bị file APK AIBoxPlus"
    if (-not (Ensure-Apk)) {
        Complete-R1InstallProgress
        return
    }

    Set-R1InstallProgress -Percent 30 -Status "Đang kết nối ADB tới $Serial"
    if (-not (Robust-AdbConnect -Serial $Serial -TargetIp $TargetIp)) {
        Complete-R1InstallProgress
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI $Serial" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "Vui lòng kiểm tra:" -ForegroundColor Yellow
        Write-Host " 1. Loa đã cắm nguồn và đang bật." -ForegroundColor White
        Write-Host " 2. Máy tính đang kết nối ĐÚNG mạng (WiFi AP hoặc WiFi nhà)." -ForegroundColor White
        Write-Host " 3. Địa chỉ IP của loa ($TargetIp) đã chính xác." -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Red
        Read-R1Input "Nhấn Enter để quay lại menu"
        return
    }

    Set-R1InstallProgress -Percent 45 -Status "Đang cấu hình quyền cài đặt hệ thống"
    adb -s $Serial shell settings put secure install_non_market_apps 1 2>$null | Out-Null

    if ($CleanMode -eq 1) {
        Set-R1InstallProgress -Percent 50 -Status "Đang dọn dẹp hệ thống và ứng dụng rác"
        adb -s $Serial shell rm /sdcard/otaprop.txt 2>$null | Out-Null
        adb -s $Serial shell rm /sdcard/incremental*.zip 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm clear com.phicomm.speaker.otaservice 2>$null | Out-Null
        adb -s $Serial shell "rm -rf /data/local/tmp/* 2>/dev/null" 2>$null | Out-Null

        # Ẩn các app rác gây crash / xung đột mic
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.airskill 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.systemtool 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.device 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.otaservice 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.productiontest 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm hide com.phicomm.speaker.bugreport 2>$null | Out-Null

        # Gỡ sạch các app cũ nếu còn sót lại (AutoDLNA và Unisound cũ)
        adb -s $Serial shell "am force-stop com.phicomm.speaker.player 2>/dev/null; /system/bin/pm uninstall com.phicomm.speaker.player 2>/dev/null; /system/bin/pm uninstall --user 0 com.phicomm.speaker.player 2>/dev/null" 2>$null | Out-Null
        adb -s $Serial shell "am force-stop com.phicomm.speaker.device 2>/dev/null; /system/bin/pm uninstall com.phicomm.speaker.device 2>/dev/null; /system/bin/pm uninstall --user 0 com.phicomm.speaker.device 2>/dev/null" 2>$null | Out-Null

        # Đảm bảo dịch vụ hệ thống cần thiết hoạt động
        adb -s $Serial shell /system/bin/pm unhide com.phicomm.speaker.ijetty 2>$null | Out-Null
        adb -s $Serial shell /system/bin/pm unhide com.phicomm.speaker.netctl 2>$null | Out-Null

        Set-R1InstallProgress -Percent 60 -Status "Đang gỡ bỏ bản AI cũ"
        adb -s $Serial shell /system/bin/pm uninstall info.dourok.voicebot 2>$null | Out-Null
    }

    # Đẩy APK vào /data/local/tmp
    $localApk = Join-Path $TempDir "ai-box-plus-app.apk"
    $remoteApk = "/data/local/tmp/ai-box-plus-app.apk"

    Set-R1InstallProgress -Percent 70 -Status "Đang truyền file APK vào loa"
    if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "push", $localApk, $remoteApk))) {
        Complete-R1InstallProgress
        Write-Host ">> [LỖI] Không thể truyền file APK lên loa tại $Serial." -ForegroundColor Red
        Read-R1Input "Nhấn Enter để quay lại menu"
        return
    }

    Set-R1InstallProgress -Percent 80 -Status "Đang cài đặt APK (pm install -r)..."
    if (-not (Invoke-AdbInstallStep -Arguments @("-s", $Serial, "shell", "/system/bin/pm", "install", "-r", $remoteApk) -RequirePackageSuccess -TargetSerial $Serial)) {
        Complete-R1InstallProgress
        Write-Host ">> [LỖI] Cài đặt APK thất bại." -ForegroundColor Red
        Read-R1Input "Nhấn Enter để quay lại menu"
        return
    }
    adb -s $Serial shell rm $remoteApk 2>$null | Out-Null

    Set-R1InstallProgress -Percent 90 -Status "Đang khởi động dịch vụ AI & WebUI (8081)"
    adb -s $Serial shell "tinymix -D 2 0 5; tinymix -D 2 1 5; tinymix -D 2 6 207; tinymix -D 2 7 207; tinymix -D 2 8 207; tinymix -D 2 9 207; tinymix -D 2 17 1; tinymix -D 2 18 1; tinymix -D 2 46 1; tinymix -D 2 47 1" 2>$null | Out-Null
    adb -s $Serial shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" 2>$null | Out-Null

    adb -s $Serial shell am start -n info.dourok.voicebot/.java.activities.MainActivity 2>$null | Out-Null
    adb -s $Serial shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n info.dourok.voicebot/info.dourok.voicebot.java.activities.MainActivity 2>$null | Out-Null
    adb -s $Serial shell am broadcast -a info.dourok.voicebot.START 2>$null | Out-Null
    adb -s $Serial shell am broadcast -a android.intent.action.BOOT_COMPLETED 2>$null | Out-Null
    adb -s $Serial shell am startservice -n info.dourok.voicebot/info.dourok.voicebot.java.services.BootStartService 2>$null | Out-Null

    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep -Seconds 2
        if (Test-R1TcpPort -HostName $TargetIp -Port 8081 -TimeoutMilliseconds 1000) { break }
        adb -s $Serial shell am start -n info.dourok.voicebot/info.dourok.voicebot.java.activities.MainActivity 2>$null | Out-Null
    }

    Set-R1InstallProgress -Percent 100 -Status "Hoàn tất cài đặt!"
    Complete-R1InstallProgress

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "                 CÀI ĐẶT THÀNH CÔNG!                      " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    if ($CleanMode -eq 1) {
        Write-Host ">> Đã cài mới hoàn toàn AIBoxPlus All-in-One." -ForegroundColor White
        Write-Host ">> Truy cập Xiaozhi.me để nhập mã kích hoạt 6 số nếu cần." -ForegroundColor White
    }
    else {
        Write-Host ">> Đã cập nhật thành công AIBoxPlus (giữ nguyên dữ liệu & token)." -ForegroundColor White
    }
    Write-Host ">> Bảng điều khiển WebUI: http://$($TargetIp):8081/" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Write-Host ""
        $rb = Read-R1Input "Khởi động lại loa ngay bây giờ? [y/N]: "
        if ($rb -eq "y" -or $rb -eq "Y") {
            adb -s $Serial reboot 2>$null | Out-Null
            Write-Host ">> Đã gửi lệnh khởi động lại loa." -ForegroundColor Green
        }
        Write-Host ""
        Read-R1Input "Nhấn Enter để quay lại menu chính"
    }
}

# 9. Giao diện Menu chính & Chọn loa
function Select-TargetSpeaker {
    $devs = Scan-SpeakerIp
    $target = ""
    if ($devs -and $devs.Count -gt 0) {
        Write-Host ""
        $pick = Read-R1Input "   Chọn số thứ tự loa (1-$($devs.Count)) hoặc nhập IP khác [Mặc định: 1]"
        $pick = if ($pick) { $pick.Trim() } else { "1" }
        if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $devs.Count) {
            $target = $devs[[int]$pick - 1].IP
        }
        elseif ($pick -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
            $target = $pick
        }
        else {
            $target = $devs[0].IP
        }
    }
    else {
        Write-Host ""
        $manual = Read-R1Input "   Không tìm thấy loa tự động. Nhập IP loa thủ công (Enter để quay lại)"
        if ($manual -and $manual.Trim()) { $target = $manual.Trim() }
    }
    return $target
}

# 8B. Cài đặt trực tiếp qua chế độ AP Mode (192.168.43.1)
function Run-ApInstall {
    Write-Host ""
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    Write-Host "   CÀI ĐẶT TRỰC TIẾP QUA WIFI CỦA LOA (AP)   " -ForegroundColor Yellow
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ">> BƯỚC 1: Tải sẵn file APK trước khi ngắt mạng Internet..." -ForegroundColor Cyan

    $apkFile = Ensure-Apk
    if (-not $apkFile) {
        Write-Host ">> [LỖI] Không thể tải trước file APK. Vui lòng kiểm tra mạng Internet." -ForegroundColor Red
        Read-R1Input "Nhấn Enter để quay lại menu chính..." | Out-Null
        return
    }

    Write-Host ""
    Write-Host ">> BƯỚC 2: Kết nối thiết bị vào WiFi của Loa R1" -ForegroundColor Yellow
    Write-Host "---------------------------------------------" -ForegroundColor Gray
    Write-Host "  1. Nếu loa chưa phát WiFi AP:"
    Write-Host "     -> Nhấn giữ nút [||] (Play/Pause) trên đỉnh loa khoảng 5-6 giây."
    Write-Host "     -> Đèn loa nhấp nháy tím/xanh và phát WiFi: Phicomm_R1_xxxx."
    Write-Host "  2. Trên Điện thoại / Máy tính:"
    Write-Host "     -> Vào Cài đặt WiFi -> Kết nối vào mạng 'Phicomm_R1_xxxx'."
    Write-Host "     -> (Nếu máy hỏi 'WiFi không có internet, giữ kết nối?': Chọn CÓ)."
    Write-Host "---------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Read-R1Input "Nhấn Enter khi ĐÃ KẾT NỐI vào WiFi của Loa: " | Out-Null

    Write-Host ""
    Write-Host ">> Đang kiểm tra kết nối tới loa (192.168.43.1)..." -ForegroundColor Cyan
    $apOk = $false
    for ($i = 1; $i -le 5; $i++) {
        if ((Test-R1TcpPort -HostName "192.168.43.1" -Port 5555 -TimeoutMilliseconds 1000) -or (Test-R1TcpPort -HostName "192.168.43.1" -Port 8080 -TimeoutMilliseconds 1000) -or (Test-R1TcpPort -HostName "192.168.43.1" -Port 8081 -TimeoutMilliseconds 1000)) {
            $apOk = $true
            break
        }
        Start-Sleep -Seconds 1
    }

    if (-not $apOk) {
        Write-Host ">> [CẢNH BÁO] Chưa kết nối được IP 192.168.43.1 của loa." -ForegroundColor Yellow
        Write-Host "   Hãy kiểm tra: Bạn đã kết nối đúng WiFi Phicomm_R1 chưa?" -ForegroundColor Gray
        $cont = Read-R1Input "   Bạn vẫn muốn thử kết nối và cài đặt? [y/N]: "
        if ($cont -ne "y" -and $cont -ne "Y") { return }
    } else {
        Write-Host "   [OK] Đã kết nối thành công tới loa tại 192.168.43.1!" -ForegroundColor Green
    }

    Do-ExecuteInstall -TargetIpParam "192.168.43.1" -CleanMode 1
}

function Show-Menu {
    Write-Host ""
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    Write-Host "     BỘ CÀI ĐẶT PHICOMM R1 (AI-BOX PLUS)     " -ForegroundColor Yellow
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    Write-Host "  1) Cài đặt trực tiếp qua WiFi Loa (AP Mode)" -ForegroundColor White
    Write-Host "     -> Tải sẵn APK, kết nối WiFi loa và cài sạch ngay" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2) Cài đặt mới hoàn toàn (Clean Install qua mạng LAN)" -ForegroundColor White
    Write-Host "     -> Gỡ sạch app rác cũ, cài đặt bản mới nhất" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3) Cập nhật / Nâng cấp (Update qua mạng LAN)" -ForegroundColor White
    Write-Host "     -> Nâng cấp app, giữ nguyên cấu hình và token/license" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4) Cấu hình WiFi cho loa (chế độ AP 192.168.43.1)" -ForegroundColor White
    Write-Host "     -> Kết nối loa vào WiFi nhà sau khi reset" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5) Quét tìm IP loa Phicomm R1 trong mạng LAN" -ForegroundColor White
    Write-Host "  6) Thoát" -ForegroundColor White
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
    $choice = Read-R1Input "Chọn [1-6]"
    if ($null -eq $choice) { return "6" }
    if ($choice) { return $choice.Trim() }
    return ""
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if ($RunWifiCli) {
    Run-WifiConfig | Out-Null
    return
}

if ($RunScanCli) {
    $foundList = Scan-SpeakerIp
    if ($foundList -and $foundList.Count -gt 0) {
        Write-Host ">> Tìm thấy $($foundList.Count) loa Phicomm R1 trong mạng LAN." -ForegroundColor Green
    }
    return
}

if ($RunCleanCli -and $Ip) {
    Do-ExecuteInstall -TargetIpParam $Ip -CleanMode 1
    return
}

if ($RunUpdateCli -and $Ip) {
    Do-ExecuteInstall -TargetIpParam $Ip -CleanMode 0
    return
}

if ($Ip -and $Ip -ne "") {
    Do-ExecuteInstall -TargetIpParam $Ip -CleanMode 0
    return
}

# Vòng lặp Menu chính
while ($true) {
    $c = Show-Menu
    if ($c -eq "1") {
        Run-ApInstall | Out-Null
    }
    elseif ($c -eq "2") {
        $target = Select-TargetSpeaker
        if ($target) {
            Do-ExecuteInstall -TargetIpParam $target -CleanMode 1
        }
    }
    elseif ($c -eq "3") {
        $target = Select-TargetSpeaker
        if ($target) {
            Do-ExecuteInstall -TargetIpParam $target -CleanMode 0
        }
    }
    elseif ($c -eq "4") {
        Run-WifiConfig | Out-Null
    }
    elseif ($c -eq "5") {
        $null = Scan-SpeakerIp
        Read-R1Input "   Nhấn Enter để quay lại menu chính"
    }
    elseif ($c -eq "6" -or $c -eq "q" -or $c -eq "Q" -or $c -eq "exit") {
        Write-Host "Thoát chương trình." -ForegroundColor Yellow
        break
    }
    elseif ($c -eq "") {
        continue
    }
    else {
        Write-Host "Lựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 6." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 600
    }
}
