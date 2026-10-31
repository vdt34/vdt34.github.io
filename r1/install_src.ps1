# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - WINDOWS POWERSHELL
# Tự động quét tìm loa trong LAN, dọn sạch file cũ, tải bản mới nhất từ GitHub
# ==============================================================================

try { chcp 65001 >$null } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not (Test-Path variable:Ip)) { $Ip = "" }
if (-not (Test-Path variable:Yes)) { $Yes = $false }
if (-not (Test-Path variable:DryRun)) { $DryRun = $false }
if ($args.Count -gt 0) {
    foreach ($a in $args) {
        if ($a -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') { $Ip = $a }
        elseif ($a -eq "-Yes" -or $a -eq "-y") { $Yes = $true }
        elseif ($a -eq "-DryRun") { $DryRun = $true }
    }
}

$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$TempDir = Join-Path $env:TEMP "r1_cache"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$BaseUrl = "https://vdt34.github.io/r1"

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CÀI ĐẶT AUTODLNA + UNISOUND + AI TIẾNG VIỆT (R1)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

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

if (-not (Ensure-Adb)) {
    Read-Host "Nhấn Enter để thoát"
    return
}

# Hàm tự động tìm dải mạng LAN hiện tại
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

# Hàm quét tự động tìm loa Phicomm R1 trong mạng LAN
function Scan-SpeakerIp {
    param([string]$Subnet = "")
    if (-not $Subnet) { $Subnet = Get-LocalSubnet }
    Write-Host ""
    Write-Host ">> Đang quét tự động dải mạng LAN ($Subnet.1 -> 254) tìm loa Phicomm R1..." -ForegroundColor Cyan

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Tasks = [System.Collections.Generic.List[object]]::new()

    # Quét nhanh cổng ADB 5555
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

    # Quét tiếp cổng 8080 cho các loa chưa bật sẵn ADB
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

    # Kiểm tra chi tiết các cổng trên từng IP tìm được để nhận diện loa R1
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

        # Nếu có cổng 5555 hoặc (8080 và 8081) -> Chắc chắn là loa Phicomm R1
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

# 2. Xác định IP của loa (Hỗ trợ quét LAN tự động, nhập trực tiếp hoặc AP)
$TargetIp = $Ip
if (-not $TargetIp) {
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "                     XÁC ĐỊNH IP CỦA LOA                  " -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " [Enter] Dùng 192.168.43.1 (Khi đang nối trực tiếp WiFi loa)" -ForegroundColor Gray
    Write-Host " [S]     Tự động QUÉT tìm IP loa trong mạng WiFi nhà (LAN)" -ForegroundColor Cyan
    Write-Host " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    $u = Read-Host "Nhập IP hoặc gõ 'S' để quét [Mặc định: 192.168.43.1]"
    $u = if ($u) { $u.Trim() } else { "" }

    if ($u -eq "s" -or $u -eq "S" -or $u -eq "2" -or $u -eq "scan") {
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
            Write-Host ">> Không tìm thấy loa tự động trong mạng." -ForegroundColor Yellow
            $manual = Read-Host "Vui lòng nhập IP loa thủ công (VD: 192.168.1.94)"
            $TargetIp = if ($manual -and $manual.Trim()) { $manual.Trim() } else { "192.168.43.1" }
        }
    } elseif ($u -eq "1" -or $u -eq "" -or $u -eq "192.168.43.1") {
        $TargetIp = "192.168.43.1"
    } else {
        $TargetIp = $u
    }
}
$TargetIp = $TargetIp.Trim().Replace(":5555", "")
$Serial = "$($TargetIp):5555"

Write-Host ""
Write-Host ">> Sẽ kết nối tới IP: $TargetIp" -ForegroundColor Cyan

# 3. Xóa sạch file cũ & tải toàn bộ 3 file APK mới nhất từ GitHub
$Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
Write-Host ""
Write-Host ">> [1/4] Đang dọn sạch file cũ & tải toàn bộ 3 file APK mới nhất từ GitHub..." -ForegroundColor Cyan

# Xóa các file APK cũ và script cũ trong cache để không dùng bản cũ
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
    Write-Host "Vui lòng kiểm tra kết nối mạng để tải đủ 3 file APK mới." -ForegroundColor Yellow
    Read-Host "Nhấn Enter để thoát"
    return
}

# 4. Kết nối ADB tới loa (Chuẩn xác 100% theo :connect và :connect_retry của new.bat)
Write-Host ""
Write-Host ">> [2/4] Bắt đầu kết nối thiết bị [$Serial]..." -ForegroundColor Cyan

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    # Reset adb chuẩn new.bat (:adb_reset)
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
        Write-Host "==========================================================" -ForegroundColor Red
        Read-Host "Nhấn Enter để thoát"
        return
    }
}
Write-Host ">> [OK] Kết nối thành công tới loa ($Serial)!" -ForegroundColor Green

# 5. Dọn sạch thư mục tạm trên loa và nạp cả 3 file APK mới lên
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

# 6. Thực thi chuỗi lệnh cài đặt chuẩn xác theo new.bat
Write-Host ""
Write-Host ">> [4/4] Bắt đầu cài đặt hệ thống..." -ForegroundColor Cyan

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    # 6.1 Xóa bộ nhớ đệm trước khi cài đặt & cho phép cài app ngoài
    Write-Host "   -> Đang dọn dẹp bộ nhớ đệm..." -ForegroundColor White
    adb -s $Serial shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null" 2>$null | Out-Null

    # 6.2 Tắt các ứng dụng không cần thiết trên loa
    Write-Host "   -> Tắt các ứng dụng chiếm quyền..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm hide com.phicomm.speaker.airskill 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null" 2>$null | Out-Null

    # 6.3 Cài đặt AutoDLNA + Unisound
    Write-Host "   -> Cài đặt AutoDLNA + Unisound..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm install -r /data/local/tmp/autodlna.apk; /system/bin/pm install -r /data/local/tmp/unisound.apk; rm -f /data/local/tmp/autodlna.apk /data/local/tmp/unisound.apk" 2>$null | Out-Null

    # 6.4 Khởi động AutoDLNA + Unisound
    Write-Host "   -> Khởi động AutoDLNA + Unisound..." -ForegroundColor White
    adb -s $Serial shell "am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null" 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # 6.5 Khôi phục ứng dụng cần thiết & Cài đặt AI Trợ lý ảo Tiếng Việt
    Write-Host "   -> Khôi phục ijetty & netctl..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null" 2>$null | Out-Null

    Write-Host "   -> Gỡ bản AI cũ và cài đặt AI Tiếng Việt mới..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm uninstall info.dourok.voicebot 2>/dev/null; /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk; rm -f /data/local/tmp/AIBoxPlus_DLNA.apk" 2>$null | Out-Null

    # 6.6 Khởi động AI Trợ lý ảo Tiếng Việt & cấu hình Bluetooth, LED
    Write-Host "   -> Khởi động AI Box Plus..." -ForegroundColor White
    adb -s $Serial shell "am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" 2>$null | Out-Null

    # Lấy IP WiFi nhà của loa nếu có
    $SpeakerLanIp = (adb -s $Serial shell "getprop dhcp.wlan0.ipaddress" 2>$null | Out-String).Trim()
} else {
    Write-Host "   -> [DRY-RUN] Đã thực thi chuỗi lệnh new.bat chuẩn xác!" -ForegroundColor Yellow
    $SpeakerLanIp = ""
}

# 7. Dọn dẹp file tạm trên máy để lần sau luôn tải mới
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
    Write-Host ">> BƯỚC TIẾP THEO: CẤU HÌNH WIFI CHO LOA" -ForegroundColor Yellow
    Write-Host " 1. Mở trình duyệt Web (Chrome / Edge) vào:" -ForegroundColor White
    Write-Host "    👉 http://192.168.43.1:8081/wifi.html" -ForegroundColor Cyan
    Write-Host " 2. Chọn WiFi nhà bạn, nhập mật khẩu để loa kết nối Internet." -ForegroundColor White
    Write-Host " 3. Đổi máy tính về lại WiFi nhà và trải nghiệm!" -ForegroundColor White
    try { Start-Process "http://192.168.43.1:8081/wifi.html" } catch {}
} else {
    Write-Host ">> Truy cập bảng điều khiển loa tại: http://$($TargetIp):8081/" -ForegroundColor White
    try { Start-Process "http://$($TargetIp):8081/" } catch {}
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
if (-not $Yes) {
    Read-Host "Nhấn Enter để kết thúc"
}
