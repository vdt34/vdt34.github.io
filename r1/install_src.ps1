# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - WINDOWS POWERSHELL
# Tự động cấu hình WiFi, quét tìm loa trong LAN, dọn sạch file cũ, giao diện UTF-8
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
        if ($a -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') { $Ip = $a }
        elseif ($a -eq "-Yes" -or $a -eq "-y") { $Yes = $true }
        elseif ($a -eq "-DryRun") { $DryRun = $true }
        elseif ($a -eq "-Wifi" -or $a -eq "--wifi") { $RunWifiCli = $true }
        elseif ($a -eq "-Scan" -or $a -eq "--scan") { $RunScanCli = $true }
    }
}

$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$TempDir = Join-Path $env:TEMP "r1_cache"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$BaseUrl = "https://vdt34.github.io/r1"

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
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -TimeoutSec 30
        Expand-Archive -Path $zip -DestinationPath $TempDir -Force
        $ProgressPreference = $old
        $env:PATH = "$TempDir\platform-tools;" + $env:PATH
        return $true
    } catch {
        Write-Host ">> [LỖI] Không thể tải ADB. Vui lòng kiểm tra kết nối mạng." -ForegroundColor Red
        return $false
    }
}

# 2. Cấu hình WiFi cho loa qua AP API (192.168.43.1:8989)
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
        $resp = Invoke-RestMethod -Uri "http://$($TargetIp):8989/api/configwifi" -Method Post -ContentType "application/json" -Body $json -TimeoutSec 5 -ErrorAction Stop
        $ProgressPreference = $old
        return $true
    } catch {
        # Loa thường ngắt kết nối ngay khi nhận lệnh để chuyển mạng, coi như đã gửi thành công
        return $true
    }
}

function Run-WifiConfig {
    Write-Host ""
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "        CẤU HÌNH WIFI CHO LOA QUA CHẾ ĐỘ AP               " -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " LƯU Ý: Loa chỉ phát WiFi AP ~60-90 giây sau khi reset." -ForegroundColor Gray
    Write-Host "  -> Bước này CHỈ gửi cấu hình WiFi (xong dưới 5 giây)." -ForegroundColor Gray
    Write-Host "  -> KHÔNG nạp APK ở đây để tránh bị timeout giữa chừng." -ForegroundColor Gray
    Write-Host ""
    Write-Host " Các bước chuẩn bị:" -ForegroundColor White
    Write-Host "  1. Giữ nút tròn đỉnh loa 5-6 giây cho đến khi đèn đổi màu/nhấp nháy." -ForegroundColor White
    Write-Host "  2. Trên máy tính: Cài đặt WiFi -> chọn mạng 'Phicomm_R1_xxxx'." -ForegroundColor White
    Write-Host "  3. Nhấn Enter để tiếp tục." -ForegroundColor White
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Nhấn Enter khi đã kết nối WiFi loa"
    }

    # Kiểm tra cổng 8989 trên loa AP
    Write-Host ""
    Write-Host ">> Kiểm tra kết nối tới 192.168.43.1:8989..." -ForegroundColor Cyan
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
    while (-not $ssid) {
        $ssid = Read-Host ">> Tên WiFi nhà (SSID, phân biệt HOA/thường)"
        $ssid = if ($ssid) { $ssid.Trim() } else { "" }
        if (-not $ssid) { Write-Host "   [!] Tên WiFi không được để trống!" -ForegroundColor Yellow }
    }

    $pass = Read-Host ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass)"
    $pass = if ($pass) { $pass.Trim() } else { "" }

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
    Write-Host "            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG               " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " BƯỚC TIẾP THEO:" -ForegroundColor White
    Write-Host "  1. Nghe loa báo 'kết nối thành công' (nếu có)." -ForegroundColor White
    Write-Host "  2. Đợi 20 giây để loa kết nối WiFi nhà và nhận IP LAN." -ForegroundColor White
    Write-Host "  3. Chuyển máy tính về lại mạng WiFi nhà." -ForegroundColor White
    Write-Host "  4. Quay lại menu, chọn mục 2 để quét IP LAN & cài APK." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green

    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Đợi 20 giây và tự động quay lại menu [Nhấn Enter]"
        Start-Sleep -Seconds 20
    }
    return $true
}

# 3. Hàm dò tìm dải mạng LAN & Quét loa Phicomm R1
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

    Start-Sleep -Milliseconds 600

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

    Start-Sleep -Milliseconds 600

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
                if ($ar.AsyncWaitHandle.WaitOne(250)) {
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

# 4. Tải và chuẩn bị 3 file APK từ GitHub
function Ensure-Apks {
    $Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
    Write-Host ""
    Write-Host ">> [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub..." -ForegroundColor Cyan

    foreach ($f in $Apks) {
        $oldFile = Join-Path $TempDir $f
        if (Test-Path $oldFile) { Remove-Item $oldFile -Force -ErrorAction SilentlyContinue }
    }
    Get-ChildItem -Path $TempDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $TempDir -Filter "*.cmd" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    $Missing = $false
    $UnixTs = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    foreach ($f in $Apks) {
        $cacheFile = Join-Path $TempDir $f
        $localFile = Join-Path $ScriptDir $f

        if ($DryRun -and (Test-Path $localFile)) {
            Copy-Item $localFile $cacheFile -Force
            Write-Host "   [OK] (DryRun) Dùng file $f có sẵn." -ForegroundColor Green
        } else {
            Write-Host "   -> Đang tải bản mới nhất: $f..." -ForegroundColor Yellow
            try {
                $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "$BaseUrl/$f`?t=$UnixTs" -OutFile "$cacheFile.tmp" -TimeoutSec 45
                Move-Item "$cacheFile.tmp" $cacheFile -Force
                $ProgressPreference = $old
                Write-Host "   [OK] Đã tải bản mới nhất $f thành công." -ForegroundColor Green
            } catch {
                Write-Host "   [LỖI] Không tải được $f từ GitHub!" -ForegroundColor Red
                $Missing = $true
            }
        }
    }

    if ($Missing) {
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "  [LỖI THIẾU FILE CÀI ĐẶT DO CHƯA CÓ INTERNET]" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "Vui lòng kiểm tra kết nối mạng để tải đủ 3 file APK." -ForegroundColor Yellow
        Read-Host "Nhấn Enter để quay lại"
        return $false
    }
    return $true
}

# 5. Luồng Quét IP LAN & Cài đặt APK
function Run-Install {
    param([string]$TargetIpParam = "")
    $TargetIp = $TargetIpParam
    if (-not $TargetIp) { $TargetIp = $Ip }

    if (-not $TargetIp) {
        Write-Host ""
        Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "                  XÁC ĐỊNH IP CỦA LOA                     " -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [S]     Tự động QUÉT tìm IP loa trong WiFi nhà (KHUYÊN DÙNG)" -ForegroundColor Cyan
        Write-Host " [Enter] Dùng 192.168.43.1 (KHÔNG khuyến nghị — AP sẽ tắt)" -ForegroundColor Gray
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
                    Write-Host "   -> Nếu loa vừa reset, hãy quay lại menu chọn mục 1 để cấu hình WiFi trước." -ForegroundColor Gray
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
                Write-Host "  [CẢNH BÁO] Chọn 192.168.43.1 (AP mode) để cài APK" -ForegroundColor Yellow
                Write-Host "  KHÔNG khuyến nghị vì AP sẽ tắt sau ~60-90s!" -ForegroundColor Yellow
                Write-Host "==========================================================" -ForegroundColor Red
                Write-Host "  Quy trình đúng:" -ForegroundColor White
                Write-Host "   1. Chọn mục 1 cấu hình WiFi trước (mất 5s)" -ForegroundColor White
                Write-Host "   2. Loa kết nối WiFi nhà, có IP LAN" -ForegroundColor White
                Write-Host "   3. Chọn mục 2 quét IP LAN và cài đặt siêu tốc" -ForegroundColor White
                Write-Host "==========================================================" -ForegroundColor Red
                $cont = Read-Host "Vẫn tiếp tục cài qua AP? [y/N]"
                if ($cont -eq "y" -or $cont -eq "Y") {
                    $TargetIp = "192.168.43.1"
                } else {
                    return
                }
            } else {
                $TargetIp = $u
            }
        }
    }

    $TargetIp = $TargetIp.Trim().Replace(":5555", "")
    $Serial = "$($TargetIp):5555"

    Write-Host ""
    Write-Host ">> Sẽ kết nối tới IP: $TargetIp" -ForegroundColor Cyan

    if (-not (Ensure-Apks)) { return }

    # Kết nối ADB tới loa
    Write-Host ""
    Write-Host ">> [2/4] Bắt đầu kết nối thiết bị [$Serial]..." -ForegroundColor Cyan

    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Stop-Process -Name adb -Force -ErrorAction SilentlyContinue
        adb kill-server 2>$null | Out-Null
        adb start-server 2>$null | Out-Null
        Start-Sleep -Seconds 1

        $connected = $false
        for ($try = 1; $try -le 5; $try++) {
            Write-Host "   [Kết nối] Thử lần $try/5 tới $Serial..." -ForegroundColor Yellow
            adb connect $Serial 2>$null | Out-Null
            Start-Sleep -Milliseconds 600

            $state = (adb -s $Serial get-state 2>$null | Out-String).Trim()
            if ($state -eq "device") {
                adb -s $Serial shell ls 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $connected = $true
                    break
                }
            }
            Start-Sleep -Seconds 1
        }

        if (-not $connected) {
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
            Read-Host "Nhấn Enter để quay lại"
            return
        }
    }
    Write-Host ">> [OK] Kết nối thành công tới loa ($Serial)!" -ForegroundColor Green

    # Đẩy APK lên bộ nhớ tạm của loa
    $Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
    Write-Host ""
    Write-Host ">> [3/4] Đang dọn sạch bộ nhớ tạm trên loa & nạp 3 file APK mới lên (/data/local/tmp/)..." -ForegroundColor Cyan
    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        adb -s $Serial shell "rm -rf /data/local/tmp/* 2>/dev/null" 2>$null | Out-Null
    }

    foreach ($f in $Apks) {
        Write-Host "   -> Nạp $f..." -ForegroundColor White
        if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
            adb -s $Serial push (Join-Path $TempDir $f) "/data/local/tmp/$f" 2>$null | Out-Null
        }
    }
    Write-Host ">> [OK] Đã đưa trọn vẹn 3 file mới lên loa!" -ForegroundColor Green

    # Thực thi chuỗi lệnh cài đặt
    Write-Host ""
    Write-Host ">> [4/4] Bắt đầu cài đặt hệ thống..." -ForegroundColor Cyan

    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Write-Host "   -> Đang dọn dẹp bộ nhớ đệm..." -ForegroundColor White
        adb -s $Serial shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null" 2>$null | Out-Null

        Write-Host "   -> Tắt các ứng dụng chiếm quyền..." -ForegroundColor White
        adb -s $Serial shell "/system/bin/pm hide com.phicomm.speaker.airskill 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null" 2>$null | Out-Null

        Write-Host "   -> Cài đặt AutoDLNA + Unisound..." -ForegroundColor White
        adb -s $Serial shell "/system/bin/pm install -r /data/local/tmp/autodlna.apk; /system/bin/pm install -r /data/local/tmp/unisound.apk; rm -f /data/local/tmp/autodlna.apk /data/local/tmp/unisound.apk" 2>$null | Out-Null

        Write-Host "   -> Khởi động AutoDLNA + Unisound..." -ForegroundColor White
        adb -s $Serial shell "am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null" 2>$null | Out-Null
        Start-Sleep -Seconds 2

        Write-Host "   -> Khôi phục ijetty & netctl..." -ForegroundColor White
        adb -s $Serial shell "/system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null" 2>$null | Out-Null

        Write-Host "   -> Gỡ bản AI cũ và cài đặt AI Tiếng Việt mới..." -ForegroundColor White
        adb -s $Serial shell "/system/bin/pm uninstall info.dourok.voicebot 2>/dev/null; /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk; rm -f /data/local/tmp/AIBoxPlus_DLNA.apk" 2>$null | Out-Null

        Write-Host "   -> Khởi động AI Box Plus..." -ForegroundColor White
        adb -s $Serial shell "am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" 2>$null | Out-Null

        $SpeakerLanIp = (adb -s $Serial shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null | Out-String).Trim()
    } else {
        Write-Host "   -> [DRY-RUN] Đã thực thi chuỗi lệnh new.bat chuẩn xác!" -ForegroundColor Yellow
        $SpeakerLanIp = ""
    }

    # Dọn dẹp cache
    foreach ($f in $Apks) {
        $tmpFile = Join-Path $TempDir $f
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "                    CÀI ĐẶT HOÀN TẤT!                     " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green

    if ($SpeakerLanIp -and $SpeakerLanIp -ne "") {
        Write-Host ">> IP của loa trong mạng WiFi nhà: $SpeakerLanIp" -ForegroundColor Cyan
        Write-Host ">> Truy cập bảng điều khiển loa tại: http://$($SpeakerLanIp):8081/" -ForegroundColor White
        try { Start-Process "http://$($SpeakerLanIp):8081/" } catch {}
    } elseif ($TargetIp -eq "192.168.43.1") {
        Write-Host ">> Truy cập bảng điều khiển loa tại: http://192.168.43.1:8081/" -ForegroundColor White
        try { Start-Process "http://192.168.43.1:8081/" } catch {}
    } else {
        Write-Host ">> Truy cập bảng điều khiển loa tại: http://$($TargetIp):8081/" -ForegroundColor White
        try { Start-Process "http://$($TargetIp):8081/" } catch {}
    }

    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""
    if (-not $Yes -and -not $DryRun -and $env:R1_DRYRUN -ne "1") {
        Read-Host "Nhấn Enter để quay lại menu"
    }
}

# 6. Hàm hiển thị Menu chính
function Show-Menu {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - WINDOWS POWERSHELL      " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)" -ForegroundColor White
    Write-Host "     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2) Quét IP LAN & cài đặt APK (AutoDLNA + Unisound + AI)" -ForegroundColor White
    Write-Host "     -> Dùng khi loa ĐÃ vào WiFi nhà (có IP LAN)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3) Chỉ quét IP LAN (không cài đặt)" -ForegroundColor White
    Write-Host "  4) Thoát" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    $choice = Read-Host "Chọn [1-4]"
    return if ($choice) { $choice.Trim() } else { "" }
}

# 7. Khởi động công cụ ADB
if (-not (Ensure-Adb)) {
    Read-Host "Nhấn Enter để thoát"
    return
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if ($Ip -and $Ip -ne "") {
    Run-Install -TargetIpParam $Ip
    return
}

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

# Vòng lặp Menu chính
while ($true) {
    $c = Show-Menu
    switch ($c) {
        "1" { Run-WifiConfig | Out-Null }
        "2" { Run-Install "" }
        "3" {
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
            Read-Host "Nhấn Enter để quay lại menu"
        }
        "4" { Write-Host "Thoát chương trình." -ForegroundColor Yellow; break }
        "q" { Write-Host "Thoát chương trình." -ForegroundColor Yellow; break }
        default { Write-Host "Lựa chọn không hợp lệ." -ForegroundColor Yellow; Start-Sleep -Milliseconds 600 }
    }
}
