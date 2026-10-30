# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC CHO WINDOWS (POWERSHELL)
# Không cảnh báo, không sao lưu rườm rà - Đẩy toàn bộ lên temp của loa rồi cài!
# ==============================================================================
[CmdletBinding()]
param(
    [string]$Ip = "",
    [switch]$Yes,
    [switch]$DryRun
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$TempDir = Join-Path $env:TEMP "r1_cache"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
$BaseUrl = "https://vdt34.github.io/r1"

$Apks = @(
    @{ File = "autodlna.apk";       Pkg = "com.phicomm.speaker.player"; Desc = "AutoDLNA" }
    @{ File = "unisound.apk";       Pkg = "com.phicomm.speaker.device"; Desc = "Unisound" }
    @{ File = "AIBoxPlus_DLNA.apk"; Pkg = "info.dourok.voicebot";       Desc = "AI Box Plus DLNA" }
)

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC (WINDOWS)" -ForegroundColor Yellow
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

    Write-Host ">> Đang tải công cụ ADB từ Google..." -ForegroundColor Yellow
    $zip = Join-Path $TempDir "platform-tools.zip"
    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -TimeoutSec 30
        Expand-Archive -Path $zip -DestinationPath $TempDir -Force
        $ProgressPreference = $old
        $env:PATH = "$TempDir\platform-tools;" + $env:PATH
        return $true
    } catch {
        Write-Host ">> [LỖI] Không tải được ADB. Hãy kiểm tra kết nối mạng." -ForegroundColor Red
        return $false
    }
}

if (-not (Ensure-Adb)) {
    Read-Host "Nhấn Enter để thoát"
    return
}

# 2. Xác định IP mục tiêu của loa
$TargetIp = $Ip
if (-not $TargetIp) {
    Write-Host "Chọn cách kết nối:" -ForegroundColor White
    Write-Host "  [1] Cài qua WiFi loa phát ra (192.168.43.1) [Khuyên dùng]" -ForegroundColor Cyan
    Write-Host "  [2] Cài qua WiFi nhà (Nhập IP của loa)" -ForegroundColor White
    Write-Host ""
    $c = Read-Host "Lựa chọn của bạn (1-2, mặc định 1)"
    if ($c -eq "2") {
        $u = Read-Host "Nhập IP của loa (Ví dụ: 192.168.1.94)"
        $TargetIp = if ($u -and $u.Trim()) { $u.Trim().Replace(":5555", "") } else { "192.168.1.94" }
    } else {
        $TargetIp = "192.168.43.1"
    }
}
$TargetIp = $TargetIp.Trim().Replace(":5555", "")
$Serial = "$($TargetIp):5555"

# 3. Chuẩn bị sẵn 3 file APK (ưu tiên có sẵn ở thư mục, nếu thiếu mới tải)
Write-Host ""
Write-Host ">> [1/4] Chuẩn bị toàn bộ 3 file APK..." -ForegroundColor Cyan
$Missing = $false
foreach ($app in $Apks) {
    $f = $app.File
    $localFile = Join-Path $ScriptDir $f
    $cacheFile = Join-Path $TempDir $f

    if ((Test-Path $localFile) -and (Get-Item $localFile).Length -gt 1000000) {
        Copy-Item $localFile $cacheFile -Force
        Write-Host "   [OK] Dùng $f có sẵn trong thư mục." -ForegroundColor Green
    } elseif ((Test-Path $cacheFile) -and (Get-Item $cacheFile).Length -gt 1000000) {
        Write-Host "   [OK] Đã có sẵn $f trong bộ nhớ tạm." -ForegroundColor Green
    } else {
        Write-Host "   -> Đang tải $f từ GitHub..." -ForegroundColor Yellow
        try {
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri "$BaseUrl/$f" -OutFile "$cacheFile.tmp" -TimeoutSec 45
            Move-Item "$cacheFile.tmp" $cacheFile -Force
            $ProgressPreference = $old
            Write-Host "   [OK] Đã tải xong $f." -ForegroundColor Green
        } catch {
            Write-Host "   [LỖI] Không tải được $f!" -ForegroundColor Red
            $Missing = $true
        }
    }
}

if ($Missing) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "  [LỖI THIẾU FILE CÀI ĐẶT DO CHƯA CÓ INTERNET]" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "Nếu đang nối WiFi của loa (không có Internet), hãy đổi máy tính"
    Write-Host "về WiFi nhà chạy lại script để tải sẵn file vào máy trước."
    Write-Host "==========================================================" -ForegroundColor Red
    Read-Host "Nhấn Enter để thoát"
    return
}

# 4. Đánh thức và kết nối ADB tới loa
Write-Host ""
Write-Host ">> [2/4] Đang kết nối tới loa tại $Serial..." -ForegroundColor Cyan
if ($TargetIp -eq "192.168.43.1") {
    Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " 1. Ấn giữ nút tròn đỉnh loa 6 giây cho đến khi đổi đèn cam." -ForegroundColor White
    Write-Host " 2. Chọn WiFi trên máy tính: Phicomm_R1_xxxx" -ForegroundColor White
    Write-Host " 3. Windows báo 'No Internet' -> Vẫn giữ nguyên kết nối!" -ForegroundColor White
    Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
}

function Revive-Speaker($IpAddr) {
    if ($DryRun -or $env:R1_DRYRUN -eq "1") { return }
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = [System.Threading.CancellationToken]::None
        $t = $ws.ConnectAsync([Uri]"ws://$($IpAddr):8080", $ct)
        if ($t.Wait(2000) -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $cmd = "stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice"
            $json = '{"type":"shell","type_id":"revive","shell":"' + $cmd + '"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $seg = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
            $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(2000) | Out-Null
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $ct).Wait(1000) | Out-Null
        }
    } catch {}
}

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    adb start-server 2>$null | Out-Null
    Revive-Speaker $TargetIp
    Start-Sleep -Milliseconds 600

    $try = 0
    while ($true) {
        $try++
        $res = (adb connect $Serial 2>&1 | Out-String).Trim()
        $devs = (adb devices 2>$null | Out-String)
        if ($devs -match [regex]::Escape($Serial) + "\s+device") { break }

        Write-Host -NoNewline "`r[*] Đang chờ kết nối [$Serial] (lần $try)... "
        if ($try % 3 -eq 0 -or $res -match "already connected") {
            adb disconnect $Serial 2>$null | Out-Null
            Revive-Speaker $TargetIp
        }
        Start-Sleep -Milliseconds 1000
    }
    Write-Host ""
}
Write-Host ">> [OK] Đã kết nối thành công tới loa ($Serial)!" -ForegroundColor Green

# 5. ĐẨY HẾT 3 FILE LÊN BỘ NHỚ TẠM CỦA LOA TRƯỚC (/sdcard/)
Write-Host ""
Write-Host ">> [3/4] Đang đẩy toàn bộ 3 file APK lên bộ nhớ loa (/sdcard/)..." -ForegroundColor Cyan
foreach ($app in $Apks) {
    $f = $app.File
    Write-Host "   -> Đẩy $f..." -ForegroundColor White
    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        adb -s $Serial push (Join-Path $TempDir $f) "/sdcard/$f" 2>$null | Out-Null
    }
}
Write-Host ">> [OK] Đã đưa trọn vẹn 3 file lên loa!" -ForegroundColor Green

# 6. DỌN DẸP, CÀI ĐẶT VÀ KHỞI CHẠY TOÀN BỘ
Write-Host ""
Write-Host ">> [4/4] Bắt đầu cài đặt và kích hoạt hệ thống..." -ForegroundColor Cyan

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    # 6.1 Dọn tiến trình xung đột
    $CleanCmd = "svc power stayon true 2>/dev/null; am force-stop info.dourok.voicebot 2>/dev/null; am force-stop com.phicomm.speaker.player 2>/dev/null; am force-stop com.phicomm.speaker.device 2>/dev/null; for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do pm hide `$p 2>/dev/null; pm disable `$p 2>/dev/null; done; killall -9 shairport dlna mpd 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null"
    adb -s $Serial shell $CleanCmd 2>$null | Out-Null

    # 6.2 Cài đặt lần lượt 3 file từ /sdcard/
    foreach ($app in $Apks) {
        $f = $app.File
        $pkg = $app.Pkg
        $desc = $app.Desc
        Write-Host "   -> Đang cài đặt $desc..." -ForegroundColor White

        $out = (adb -s $Serial shell "pm install -r /sdcard/$f" 2>&1 | Out-String).Trim()
        if ($out -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE" -or $out -match "signatures do not match") {
            adb -s $Serial shell "pm uninstall $pkg" 2>$null | Out-Null
            $out = (adb -s $Serial shell "pm install /sdcard/$f" 2>&1 | Out-String).Trim()
        }
        adb -s $Serial shell "rm -f /sdcard/$f" 2>$null | Out-Null
    }

    # 6.3 Khởi chạy dịch vụ, bluetooth, chỉnh đèn led
    $StartCmd = "for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do pm unhide `$p 2>/dev/null; pm enable `$p 2>/dev/null; done; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null"
    adb -s $Serial shell $StartCmd 2>$null | Out-Null
} else {
    Write-Host "   -> [DRY-RUN] Giả lập cài đặt AutoDLNA, Unisound, AI Box Plus thành công!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "    [HOÀN TẤT] ĐÃ CÀI ĐẶT LOA PHICOMM R1 THÀNH CÔNG!" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green

if ($TargetIp -eq "192.168.43.1") {
    Write-Host ">> CÁC BƯỚC CÀI ĐẶT WIFI CHO LOA:" -ForegroundColor Yellow
    Write-Host " 1. Mở trình duyệt Web (Edge / Chrome) vào:" -ForegroundColor White
    Write-Host "    👉 http://192.168.43.1:8081/wifi.html" -ForegroundColor Cyan
    Write-Host " 2. Chọn WiFi nhà bạn, nhập mật khẩu để loa kết nối mạng." -ForegroundColor White
    Write-Host " 3. Đổi máy tính về lại WiFi nhà và thưởng thức âm nhạc!" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
    try { Start-Process "http://192.168.43.1:8081/wifi.html" } catch {}
} else {
    $webUrl = "http://" + $TargetIp + ":8081/"
    Write-Host "Truy cập giao diện điều khiển loa tại: $webUrl" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green
    try { Start-Process $webUrl } catch {}
}

Write-Host ""
if (-not $Yes) {
    Read-Host "Nhấn Enter để kết thúc"
}
