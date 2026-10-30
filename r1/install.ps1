# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC CHO WINDOWS (POWERSHELL)
# Chuẩn hóa 100% theo new.bat v5.1.3: Kết nối nhanh 1-2s, đẩy lên /data/local/tmp/
# ==============================================================================
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

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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

# 2. Nhập IP của loa (Chuẩn new.bat: Enter lấy 192.168.43.1, hoặc gõ IP WiFi nhà)
$TargetIp = $Ip
if (-not $TargetIp) {
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "                     NHẬP IP CỦA LOA                      " -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " - Nếu đang kết nối WiFi của loa: Nhấn [Enter] để dùng 192.168.43.1" -ForegroundColor Gray
    Write-Host " - Nếu loa đã nối WiFi nhà: Nhập địa chỉ IP của loa (VD: 192.168.1.94)" -ForegroundColor Gray
    Write-Host ""
    $u = Read-Host "Nhập IP của loa (Enter để dùng mặc định 192.168.43.1)"
    if ($u -and $u.Trim()) {
        $TargetIp = $u.Trim().Replace(":5555", "")
    } else {
        $TargetIp = "192.168.43.1"
    }
}
$TargetIp = $TargetIp.Trim().Replace(":5555", "")
$Serial = "$($TargetIp):5555"

Write-Host ""
Write-Host ">> Sẽ kết nối tới IP: $TargetIp" -ForegroundColor Cyan

# 3. Chuẩn bị sẵn 3 file APK
$Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
Write-Host ""
Write-Host ">> [1/4] Chuẩn bị 3 file APK..." -ForegroundColor Cyan
$Missing = $false
foreach ($f in $Apks) {
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
    Write-Host "Vui lòng kiểm tra lại kết nối mạng để tải đủ 3 file APK." -ForegroundColor Yellow
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
        Write-Host " 3. Địa chỉ IP của loa ($TargetIp) có đúng không." -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Red
        Read-Host "Nhấn Enter để thoát"
        return
    }
}
Write-Host ">> [OK] Kết nối thành công tới loa ($Serial)!" -ForegroundColor Green

# 5. ĐẨY HẾT CẢ 3 FILE APK LÊN /data/local/tmp/ CỦA LOA TRƯỚC
Write-Host ""
Write-Host ">> [3/4] Đang đẩy toàn bộ file APK lên bộ nhớ tạm (/data/local/tmp/)..." -ForegroundColor Cyan
foreach ($f in $Apks) {
    Write-Host "   -> Nạp $f..." -ForegroundColor White
    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        adb -s $Serial push (Join-Path $TempDir $f) "/data/local/tmp/$f" 2>$null | Out-Null
    }
}
Write-Host ">> [OK] Đã đưa trọn vẹn 3 file lên loa!" -ForegroundColor Green

# 6. THỰC THI CHUỖI LỆNH CÀI ĐẶT CHUẨN XÁC THEO NEW.BAT
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
