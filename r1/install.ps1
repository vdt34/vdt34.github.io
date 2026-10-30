# ==============================================================================
# Script Cài Đặt & Cập Nhật Phicomm R1 trên Windows (PowerShell)
# Nguồn APK: https://vdt34.github.io/r1/
# Tự động tải ADB nếu chưa có, quét IP song song và cài đặt siêu tốc
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "CÀI ĐẶT & CẬP NHẬT PHICOMM R1 - WINDOWS"

$BaseUrl = "https://vdt34.github.io/r1"
$TempDir = "$env:TEMP\r1_install"
$ApkDLNA = "autodlna.apk"
$ApkUNI  = "unisound.apk"
$ApkAI   = "AIBoxPlus_DLNA.apk"
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Get-Location }

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CÀI ĐẶT & CẬP NHẬT PHICOMM R1 TRÊN WINDOWS" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# 1. KIỂM TRA & TỰ ĐỘNG CÀI ĐẶT ADB NẾU MÁY CHƯA CÓ
# ------------------------------------------------------------------------------
function Ensure-Adb {
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        Write-Host ">> [OK] Đã có công cụ ADB trên hệ thống Windows." -ForegroundColor Green
        return
    }

    $AdbDir = "$TempDir\adb_tools\platform-tools"
    if (Test-Path "$AdbDir\adb.exe") {
        $env:PATH = "$AdbDir;" + $env:PATH
        Write-Host ">> [OK] Sử dụng ADB từ thư mục tạm: $AdbDir" -ForegroundColor Green
        return
    }

    Write-Host ">> [*] Máy tính chưa có ADB. Đang tự động tải bộ công cụ từ Google Android..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "$TempDir\adb_tools" | Out-Null
    $ZipPath = "$TempDir\adb.zip"
    
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $ZipPath -TimeoutSec 60
        Expand-Archive -Path $ZipPath -DestinationPath "$TempDir\adb_tools" -Force
        Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
        if (Test-Path "$AdbDir\adb.exe") {
            $env:PATH = "$AdbDir;" + $env:PATH
            Write-Host ">> [OK] Đã tải và tích hợp ADB thành công!" -ForegroundColor Green
        } else {
            throw "Không tìm thấy adb.exe sau khi giải nén."
        }
    } catch {
        Write-Host ">> [LỖI] Không thể tải ADB tự động: $_" -ForegroundColor Red
        Write-Host "   Vui lòng tải Android Platform-Tools thủ công để tiếp tục!" -ForegroundColor Yellow
        Pause
        exit 1
    }
}

Ensure-Adb

# ------------------------------------------------------------------------------
# 2. HÀM QUÉT MẠNG TÌM IP LOA R1
# ------------------------------------------------------------------------------
function Get-LocalSubnet {
    $Sub = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if ($Sub) {
        $Parts = $Sub.Split('.')
        return "$($Parts[0]).$($Parts[1]).$($Parts[2])"
    }
    return "192.168.1"
}

function Scan-SpeakerIp {
    $CurSub = Get-LocalSubnet
    Write-Host ""
    $UserSub = Read-Host "Nhập dải mạng cần quét [Mặc định: $CurSub]"
    if (-not $UserSub) { $UserSub = $CurSub }

    Write-Host ""
    Write-Host ">> Đang quét nhanh dải mạng $UserSub.1 -> 254 (Port 5555)..." -ForegroundColor Cyan
    
    $FoundIps = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
    1..254 | ForEach-Object -Parallel {
        $ip = "$($using:UserSub).$_"
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $tcp.BeginConnect($ip, 5555, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(350, $false) -and $tcp.Connected) {
                $using:FoundIps.Add($ip)
                Write-Host "`n   [+] Phát hiện loa Phicomm R1 tại IP: $ip" -ForegroundColor Green
            }
        } catch {}
        finally {
            $tcp.Close()
        }
    } -ThrottleLimit 50

    if ($FoundIps.Count -eq 0) {
        Write-Host "`n>> Không tìm thấy thiết bị nào mở cổng 5555 trong dải $UserSub.x." -ForegroundColor Yellow
    }
    return $FoundIps
}

# ------------------------------------------------------------------------------
# 3. MENU LỰA CHỌN PHƯƠNG THỨC CÀI ĐẶT
# ------------------------------------------------------------------------------
$TargetIp = "192.168.43.1"
$Mode = "FULL"

while ($true) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              BẢNG ĐIỀU KHIỂN PHICOMM R1" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  [1] Cài đặt SIÊU TỐC qua WiFi loa phát ra (192.168.43.1) [Khuyên dùng]" -ForegroundColor White
    Write-Host "  [2] Cài đặt đầy đủ qua mạng WiFi nhà (Tự tìm hoặc nhập IP thủ công)" -ForegroundColor White
    Write-Host "  [3] Chỉ cập nhật AI Box Plus DLNA mới nhất (Giữ nguyên cài đặt cũ)" -ForegroundColor White
    Write-Host "  [4] Quét & tìm địa chỉ IP của loa trong mạng WiFi nhà" -ForegroundColor White
    Write-Host "  [5] Thoát" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    $Choice = Read-Host "Nhập lựa chọn của bạn (1-5, mặc định 1)"
    if (-not $Choice) { $Choice = "1" }

    switch ($Choice) {
        "1" {
            $TargetIp = "192.168.43.1"
            $Mode = "FULL"
            break
        }
        "2" {
            $Suggest = Scan-SpeakerIp
            $DefIp = if ($Suggest.Count -gt 0) { ($Suggest | Select-Object -First 1) } else { "192.168.1.50" }
            $UserIp = Read-Host "`nNhập IP của loa [Enter để chọn $DefIp]"
            $TargetIp = if ($UserIp) { $UserIp.Trim().Replace(":5555", "") } else { $DefIp }
            $Mode = "FULL"
            break
        }
        "3" {
            $UserIp = Read-Host "`nNhập IP loa cần cập nhật [Enter để chọn 192.168.43.1]"
            $TargetIp = if ($UserIp) { $UserIp.Trim().Replace(":5555", "") } else { "192.168.43.1" }
            $Mode = "UPDATE_ONLY"
            break
        }
        "4" {
            Scan-SpeakerIp | Out-Null
            continue
        }
        "5" {
            Write-Host "Tạm biệt!" -ForegroundColor Cyan
            exit 0
        }
        default {
            $TargetIp = "192.168.43.1"
            $Mode = "FULL"
            break
        }
    }
    break
}

# ------------------------------------------------------------------------------
# 4. QUẢN LÝ BỘ NHỚ ĐỆM & TẢI FILE APK TỪ GITHUB
# ------------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      KIỂM TRA & CHUẨN BỊ FILE APK CÀI ĐẶT" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

function Download-ApkFile ($FileName, $Desc, $MinSize) {
    $LocalPath = Join-Path $ScriptDir $FileName
    $TempPath  = Join-Path $TempDir $FileName

    # Nếu có file trong cùng thư mục script
    if (Test-Path $LocalPath) {
        $Item = Get-Item $LocalPath
        if ($Item.Length -ge $MinSize) {
            Copy-Item -Path $LocalPath -Destination $TempPath -Force
            Write-Host ">> [CÓ SẴN] Sử dụng $Desc từ thư mục hiện tại ." -ForegroundColor Green
            return $true
        }
    }

    # Nếu đã có trong thư mục tạm
    if (Test-Path $TempPath) {
        $Item = Get-Item $TempPath
        if ($Item.Length -ge $MinSize) {
            Write-Host ">> [CACHE] Đã có sẵn $Desc trong máy ." -ForegroundColor Green
            return $true
        }
    }

    Write-Host ">> Đang tải $Desc từ GitHub ($BaseUrl/$FileName)..." -ForegroundColor White
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri "$BaseUrl/$FileName" -OutFile "$TempPath.tmp" -TimeoutSec 30
        Move-Item -Path "$TempPath.tmp" -Destination $TempPath -Force
        Write-Host ">> [OK] Đã tải $Desc thành công." -ForegroundColor Green
        return $true
    } catch {
        Remove-Item "$TempPath.tmp" -Force -ErrorAction SilentlyContinue
        Write-Host ">> [LỖI] Không thể tải $Desc từ Internet!" -ForegroundColor Red
        return $false
    }
}

$ErrCount = 0
if ($Mode -eq "FULL") {
    if (-not (Download-ApkFile $ApkDLNA "AutoDLNA" 5000000)) { $ErrCount++ }
    if (-not (Download-ApkFile $ApkUNI  "Unisound" 25000000)) { $ErrCount++ }
    if (-not (Download-ApkFile $ApkAI   "AI Box Plus DLNA" 10000000)) { $ErrCount++ }
} else {
    if (-not (Download-ApkFile $ApkAI   "AI Box Plus DLNA" 10000000)) { $ErrCount++ }
}

if ($ErrCount -gt 0) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "  [LỖI THIẾU FILE CÀI ĐẶT DO CHƯA CÓ INTERNET]" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "Máy tính của bạn đang kết nối WiFi của loa (192.168.43.1 không có mạng)"
    Write-Host "nên không thể tải được file APK về."
    Write-Host ""
    Write-Host "GIẢI PHÁP:" -ForegroundColor Yellow
    Write-Host " 1. Chuyển máy tính về mạng WiFi nhà có Internet."
    Write-Host " 2. Chạy lại script để tải trọn vẹn các file APK về máy trước."
    Write-Host " 3. Khi máy đã có file, chuyển sang WiFi loa để FLASH SIÊU TỐC!"
    Write-Host "==========================================================" -ForegroundColor Red
    Pause
    exit 1
}

Write-Host ">> [OK] Toàn bộ file APK đã sẵn sàng trong máy tính!" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 5. KẾT NỐI ADB ĐẾN LOA PHICOMM R1
# ------------------------------------------------------------------------------
$Serial = "$TargetIp`:5555"
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      KIỂM TRA KẾT NỐI ĐẾN LOA R1 ($Serial)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

adb start-server | Out-Null

if ($TargetIp -eq "192.168.43.1") {
    Write-Host "------------------ HƯỚNG DẪN KẾT NỐI WIFI LOA (AP) ------------------" -ForegroundColor Yellow
    Write-Host " 1. Ấn giữ nút tròn trên đỉnh loa 6 giây đến khi kêu bíp & đổi đèn cam."
    Write-Host " 2. Bấm biểu tượng WiFi góc phải Taskbar Windows, chọn: Phicomm_R1_xxxx"
    Write-Host " 3. Nếu Windows báo 'No Internet, secured' -> Vẫn giữ nguyên kết nối!"
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "⚡ HỆ THỐNG SẼ TỰ ĐỘNG BẮT ĐẦU CÀI ĐẶT NGAY KHI PHÁT HIỆN LOA!" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
} else {
    Write-Host ">> Đảm bảo máy tính đang kết nối cùng mạng WiFi với loa tại IP: $TargetIp" -ForegroundColor Yellow
}

Write-Host ">> Đang dò tìm loa liên tục tại $Serial (Bấm Ctrl + C nếu muốn dừng)..." -ForegroundColor White
Write-Host ""

function Test-SpeakerReady {
    $State = (adb -s $Serial get-state 2>$null)
    if ($State -and $State.Trim() -eq "device") { return $true }
    $Devs = (adb devices 2>$null | Out-String)
    if ($Devs -match "$Serial\s+device") { return $true }
    $Out = (adb -s $Serial shell "echo 1" 2>$null)
    if ($Out -and $Out.Trim() -eq "1") { return $true }
    return $false
}

# Thử kết nối lần đầu
$ConnInit = (adb connect $Serial 2>&1 | Out-String).Trim()
Start-Sleep -Milliseconds 800

if (-not (Test-SpeakerReady)) {
    if ($ConnInit -match "already connected") {
        Write-Host ">> Phát hiện socket cũ bị treo, đang làm sạch kết nối..." -ForegroundColor Yellow
        adb disconnect $Serial 2>$null | Out-Null
        adb kill-server 2>$null | Out-Null
        Start-Sleep -Milliseconds 600
        adb start-server 2>$null | Out-Null
        adb connect $Serial 2>$null | Out-Null
        Start-Sleep -Milliseconds 600
    }

    $TryCount = 0
    while ($true) {
        $TryCount++
        if (Test-SpeakerReady) {
            Write-Host "`n>> [KẾT NỐI THÀNH CÔNG] Đã nhận diện loa Phicomm R1 tại $Serial!" -ForegroundColor Green
            break
        }

        $ConnRes = (adb connect $Serial 2>&1 | Out-String).Trim()
        if (Test-SpeakerReady) {
            Write-Host "`n>> [KẾT NỐI THÀNH CÔNG] Đã nhận diện loa Phicomm R1 tại $Serial!" -ForegroundColor Green
            break
        }

        Write-Host -NoNewline "`r[*] Đang chờ kết nối [$Serial] (Lần thử $TryCount) | $ConnRes   "

        # Định kỳ mỗi 6 lần (~7s) hoặc khi kẹt already connected
        if ($ConnRes -match "already connected" -or ($TryCount % 6 -eq 0)) {
            adb disconnect $Serial 2>$null | Out-Null
            adb kill-server 2>$null | Out-Null
            Start-Sleep -Milliseconds 600
            adb start-server 2>$null | Out-Null
        }

        # Nếu thử 18 lần ở WiFi nhà mà không thấy, hỏi đổi IP
        if ($TryCount % 18 -eq 0 -and $TargetIp -ne "192.168.43.1") {
            Write-Host ""
            $Retry = Read-Host "`n>> Chưa thấy loa tại $TargetIp. Bạn có muốn đổi IP khác? (y/n, mặc định n)"
            if ($Retry -eq "y" -or $Retry -eq "Y") {
                $NewIp = Read-Host "Nhập địa chỉ IP mới"
                if ($NewIp) {
                    $TargetIp = $NewIp.Trim().Replace(":5555", "")
                    $Serial = "$TargetIp`:5555"
                    $TryCount = 0
                    Write-Host ">> Đã đổi mục tiêu sang: $Serial" -ForegroundColor Cyan
                }
            }
        }

        Start-Sleep -Milliseconds 1200
    }
} else {
    Write-Host "`n>> [KẾT NỐI THÀNH CÔNG] Đã nhận diện loa Phicomm R1 tại $Serial!" -ForegroundColor Green
}

Write-Host ""
Write-Host ">> [SẴN SÀNG] BẮT ĐẦU QUÁ TRÌNH CÀI ĐẶT CHO LOA R1..." -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 6. HÀM CÀI ĐẶT APK AN TOÀN QUA ADB
# ------------------------------------------------------------------------------
function Install-ApkToSpeaker ($LocalFile, $PkgName, $AppDesc) {
    Write-Host -NoNewline "   -> Đang chuyển $AppDesc sang loa... "
    adb -s $Serial push $LocalFile /data/local/tmp/app.apk 2>$null | Out-Null
    Write-Host -NoNewline "Đang cài đặt... "
    $InstallLog = (adb -s $Serial shell "pm install -r /data/local/tmp/app.apk" 2>&1 | Out-String).Trim()

    if ($InstallLog -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
        Write-Host -NoNewline "`n   [!] Khác chữ ký cũ, đang gỡ bản cũ để cài mới... " -ForegroundColor Yellow
        adb -s $Serial shell "pm uninstall $PkgName" 2>$null | Out-Null
        $InstallLog = (adb -s $Serial shell "pm install /data/local/tmp/app.apk" 2>&1 | Out-String).Trim()
    }

    if ($InstallLog -match "Success") {
        Write-Host "[THÀNH CÔNG]" -ForegroundColor Green
    } else {
        Write-Host "[LỖI]: $InstallLog" -ForegroundColor Red
    }
    adb -s $Serial shell "rm -f /data/local/tmp/app.apk" 2>$null | Out-Null
}

# ------------------------------------------------------------------------------
# 7. THỰC THI CÀI ĐẶT
# ------------------------------------------------------------------------------
if ($Mode -eq "FULL") {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  BẮT ĐẦU CÀI ĐẶT: AutoDLNA + Unisound + AI Box Plus DLNA" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ">> [1/5] Tắt toàn bộ tiến trình chiếm quyền, xung đột âm thanh & micro..." -ForegroundColor White
    $CleanCmd = @"
svc power stayon true 2>/dev/null
am force-stop info.dourok.voicebot 2>/dev/null
am force-stop com.phicomm.speaker.player 2>/dev/null
am force-stop com.phicomm.speaker.device 2>/dev/null
am force-stop com.phicomm.speaker.airskill 2>/dev/null
am force-stop com.phicomm.speaker.otaservice 2>/dev/null
am force-stop com.phicomm.speaker.exceptionreporter 2>/dev/null
am force-stop com.phicomm.speaker.systemtool 2>/dev/null
am force-stop com.phicomm.speaker.productiontest 2>/dev/null
am force-stop com.phicomm.speaker.bugreport 2>/dev/null
am force-stop com.phicomm.speaker.remote 2>/dev/null
am force-stop com.tencent.qqmusic 2>/dev/null
killall -9 shairport dlna mpd 2>/dev/null
for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do
    pm hide `$p 2>/dev/null
    pm disable `$p 2>/dev/null
done
rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null
rm -rf /data/local/tmp/* 2>/dev/null
pm clear com.phicomm.speaker.otaservice 2>/dev/null
settings put secure install_non_market_apps 1 2>/dev/null
"@
    adb -s $Serial shell $CleanCmd 2>$null | Out-Null
    Write-Host "   [OK] Đã giải phóng hoàn toàn âm thanh, micro và các cổng mạng!" -ForegroundColor Green

    Write-Host ">> [2/5] Cài đặt AutoDLNA (Điều khiển nhạc & Web Control)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkDLNA) "com.phicomm.speaker.player" "AutoDLNA"

    Write-Host ">> [3/5] Cài đặt Unisound (Điều khiển phần cứng & hệ thống)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkUNI) "com.phicomm.speaker.device" "Unisound"

    Write-Host ">> [4/5] Cài đặt AI Box Plus DLNA (Trợ lý Tiếng Việt & DLNA)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkAI) "info.dourok.voicebot" "AI Box Plus DLNA"

    Write-Host ">> [5/5] Mở khóa và khởi chạy toàn bộ dịch vụ hệ thống..." -ForegroundColor White
    $StartCmd = @"
for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do
    pm unhide `$p 2>/dev/null
    pm enable `$p 2>/dev/null
done
am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null
am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null
am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null
settings put global bluetooth_on 1 2>/dev/null
service call bluetooth_manager 6 2>/dev/null
mkdir -p /data/data/info.dourok.voicebot/shared_prefs 2>/dev/null
setprop persist.sys.r1_led 0 2>/dev/null
lights_test set 7fffff8000 0 2>/dev/null
lights_test set 7fffff0000 ffffff 2>/dev/null
"@
    adb -s $Serial shell $StartCmd 2>$null | Out-Null
    Start-Sleep -Seconds 1

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "     [HOÀN TẤT] CÀI ĐẶT LOA PHICOMM R1 THÀNH CÔNG!" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Toàn bộ ứng dụng & dịch vụ đã được kích hoạt SẴN SÀNG DÙNG NGAY!"
    Write-Host ""

    if ($TargetIp -eq "192.168.43.1") {
        Write-Host ">>> CÁC BƯỚC CẤU HÌNH WIFI NHÀ CHO LOA:" -ForegroundColor Yellow
        Write-Host " 1. Mở trình duyệt Web (Chrome, Edge), truy cập:" -ForegroundColor White
        Write-Host "    👉 http://192.168.43.1:8081/wifi.html" -ForegroundColor Cyan
        Write-Host "    (hoặc: http://192.168.43.1:8081/ giao diện Web Control)" -ForegroundColor Gray
        Write-Host " 2. Chọn tên WiFi nhà bạn, nhập mật khẩu -> Loa sẽ phát âm thông báo." -ForegroundColor White
        Write-Host " 3. Chuyển máy tính về lại WiFi nhà và tận hưởng âm nhạc!" -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Green
        Start-Process "http://192.168.43.1:8081/wifi.html"
    } else {
        Write-Host "Truy cập giao diện web điều khiển loa tại: http://$TargetIp`:8081/" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Green
        Start-Process "http://$TargetIp`:8081/"
    }
} else {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  CẬP NHẬT NHANH AI BOX PLUS DLNA (GIỮ NGUYÊN CẤU HÌNH)" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ">> [1/2] Tắt tiến trình cũ..." -ForegroundColor White
    adb -s $Serial shell "am force-stop info.dourok.voicebot 2>/dev/null; rm -rf /data/local/tmp/* 2>/dev/null" 2>$null | Out-Null

    Write-Host ">> [2/2] Cài đặt bản AI Box Plus DLNA mới nhất..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkAI) "info.dourok.voicebot" "AI Box Plus DLNA"

    $UpdStart = @"
pm unhide info.dourok.voicebot 2>/dev/null
pm enable info.dourok.voicebot 2>/dev/null
am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null
settings put global bluetooth_on 1 2>/dev/null
service call bluetooth_manager 6 2>/dev/null
setprop persist.sys.r1_led 0 2>/dev/null
lights_test set 7fffff8000 0 2>/dev/null
lights_test set 7fffff0000 ffffff 2>/dev/null
"@
    adb -s $Serial shell $UpdStart 2>$null | Out-Null

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "     [HOÀN TẤT] CẬP NHẬT AI BOX PLUS DLNA THÀNH CÔNG!" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Toàn bộ cấu hình cũ (mDNS, PayOS, hẹn giờ...) được giữ nguyên 100%!"
    Write-Host "Truy cập giao diện web điều khiển tại: http://$TargetIp`:8081/" -ForegroundColor Cyan
    Start-Process "http://$TargetIp`:8081/"
}

Write-Host ""
Read-Host "Nhấn phím Enter để kết thúc"
