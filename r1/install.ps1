# ==============================================================================
# BO CAI PHICOMM R1 SIEU TOC CHO WINDOWS (POWERSHELL)
# Chuan hoa 100% theo new.bat: Ket noi 1-2s, day len /data/local/tmp/
# ==============================================================================
try { chcp 65001 >$null } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

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
Write-Host "     CAI DAT AUTODLNA + UNISOUND + AI TIENG VIET (R1)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Dam bao co cong cu ADB
function Ensure-Adb {
    if ($DryRun -or $env:R1_DRYRUN -eq "1") { return $true }
    if (Get-Command adb -ErrorAction SilentlyContinue) { return $true }
    $localAdb = Join-Path $ScriptDir "adb.exe"
    if (Test-Path $localAdb) { $env:PATH = "$ScriptDir;" + $env:PATH; return $true }
    $cachedAdb = Join-Path $TempDir "platform-tools\adb.exe"
    if (Test-Path $cachedAdb) { $env:PATH = "$TempDir\platform-tools;" + $env:PATH; return $true }

    Write-Host ">> Dang tai cong cu ADB tu Google..." -ForegroundColor Yellow
    $zip = Join-Path $TempDir "platform-tools.zip"
    try {
        $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -TimeoutSec 30
        Expand-Archive -Path $zip -DestinationPath $TempDir -Force
        $ProgressPreference = $old
        $env:PATH = "$TempDir\platform-tools;" + $env:PATH
        return $true
    } catch {
        Write-Host ">> [LOI] Khong tai duoc ADB. Hay kiem tra ket noi mang." -ForegroundColor Red
        return $false
    }
}

if (-not (Ensure-Adb)) {
    Read-Host "Nhan Enter de thoat"
    return
}

# 2. Nhap IP cua loa (Chuan new.bat: Enter lay 192.168.43.1, hoac go IP WiFi nha)
$TargetIp = $Ip
if (-not $TargetIp) {
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "                     NHAP IP CUA LOA                      " -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " - Neu dang ket noi WiFi cua loa: Nhan [Enter] dung 192.168.43.1" -ForegroundColor Gray
    Write-Host " - Neu loa da noi WiFi nha: Nhap dia chi IP cua loa (VD: 192.168.1.94)" -ForegroundColor Gray
    Write-Host ""
    $u = Read-Host "Nhap IP cua loa (Enter de dung mac dinh 192.168.43.1)"
    if ($u -and $u.Trim()) {
        $TargetIp = $u.Trim().Replace(":5555", "")
    } else {
        $TargetIp = "192.168.43.1"
    }
}
$TargetIp = $TargetIp.Trim().Replace(":5555", "")
$Serial = "$($TargetIp):5555"

Write-Host ""
Write-Host ">> Se ket noi toi IP: $TargetIp" -ForegroundColor Cyan

# 3. Chuan bi 3 file APK
$Apks = @("autodlna.apk", "unisound.apk", "AIBoxPlus_DLNA.apk")
Write-Host ""
Write-Host ">> [1/4] Chuan bi 3 file APK..." -ForegroundColor Cyan
$Missing = $false
foreach ($f in $Apks) {
    $localFile = Join-Path $ScriptDir $f
    $cacheFile = Join-Path $TempDir $f

    if ((Test-Path $localFile) -and (Get-Item $localFile).Length -gt 1000000) {
        Copy-Item $localFile $cacheFile -Force
        Write-Host "   [OK] Co san $f trong thu muc." -ForegroundColor Green
    } elseif ((Test-Path $cacheFile) -and (Get-Item $cacheFile).Length -gt 1000000) {
        Write-Host "   [OK] Co san $f trong bo nho tam." -ForegroundColor Green
    } else {
        Write-Host "   -> Dang tai $f tu GitHub..." -ForegroundColor Yellow
        try {
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri "$BaseUrl/$f" -OutFile "$cacheFile.tmp" -TimeoutSec 45
            Move-Item "$cacheFile.tmp" $cacheFile -Force
            $ProgressPreference = $old
            Write-Host "   [OK] Da tai xong $f." -ForegroundColor Green
        } catch {
            Write-Host "   [LOI] Khong tai duoc $f!" -ForegroundColor Red
            $Missing = $true
        }
    }
}

if ($Missing) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "  [LOI THIEU FILE CAI DAT DO CHUA CO INTERNET]" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "Vui long kiem tra ket noi mang de tai du 3 file APK." -ForegroundColor Yellow
    Read-Host "Nhan Enter de thoat"
    return
}

# 4. Ket noi ADB toi loa (Chuan xac 100% theo :connect va :connect_retry cua new.bat)
Write-Host ""
Write-Host ">> [2/4] Bat dau ket noi thiet bi [$Serial]..." -ForegroundColor Cyan

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    # Reset adb chuan new.bat (:adb_reset)
    Stop-Process -Name adb -Force -ErrorAction SilentlyContinue
    adb kill-server 2>$null | Out-Null
    adb start-server 2>$null | Out-Null
    Start-Sleep -Seconds 1

    $connected = $false
    for ($try = 1; $try -le 5; $try++) {
        Write-Host "   [Ket noi] Thu lan $try/5 toi $Serial..." -ForegroundColor Yellow
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
        Write-Host "  [LOI] KET NOI THAT BAI TOI LOA TAI $Serial" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host "Vui long kiem tra:" -ForegroundColor Yellow
        Write-Host " 1. Loa da cam nguon va dang bat." -ForegroundColor White
        Write-Host " 2. May tinh va loa dang ket noi CUNG MANG WiFi." -ForegroundColor White
        Write-Host " 3. Dia chi IP cua loa ($TargetIp) da dung chua." -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Red
        Read-Host "Nhan Enter de thoat"
        return
    }
}
Write-Host ">> [OK] Ket noi thanh cong toi loa ($Serial)!" -ForegroundColor Green

# 5. DAY HET CA 3 FILE APK LEN /data/local/tmp/ CUA LOA TRUOC
Write-Host ""
Write-Host ">> [3/4] Dang day toan bo file APK len bo nho tam (/data/local/tmp/)..." -ForegroundColor Cyan
foreach ($f in $Apks) {
    Write-Host "   -> Nap $f..." -ForegroundColor White
    if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
        adb -s $Serial push (Join-Path $TempDir $f) "/data/local/tmp/$f" 2>$null | Out-Null
    }
}
Write-Host ">> [OK] Da dua tron ven 3 file len loa!" -ForegroundColor Green

# 6. THUC THI CHUOI LENH CAI DAT CHUAN XAC THEO NEW.BAT
Write-Host ""
Write-Host ">> [4/4] Bat dau cai dat he thong..." -ForegroundColor Cyan

if (-not $DryRun -and $env:R1_DRYRUN -ne "1") {
    # 6.1 Xoa bo nho dem truoc khi cai dat & cho phep cai app ngoai
    Write-Host "   -> Dang don dep bo nho dem..." -ForegroundColor White
    adb -s $Serial shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null" 2>$null | Out-Null

    # 6.2 Tat cac ung dung khong can thiet tren loa
    Write-Host "   -> Tat cac ung dung chiem quyen..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm hide com.phicomm.speaker.airskill 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null" 2>$null | Out-Null

    # 6.3 Cai dat AutoDLNA + Unisound
    Write-Host "   -> Cai dat AutoDLNA + Unisound..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm install -r /data/local/tmp/autodlna.apk; /system/bin/pm install -r /data/local/tmp/unisound.apk; rm -f /data/local/tmp/autodlna.apk /data/local/tmp/unisound.apk" 2>$null | Out-Null

    # 6.4 Khoi dong AutoDLNA + Unisound
    Write-Host "   -> Khoi dong AutoDLNA + Unisound..." -ForegroundColor White
    adb -s $Serial shell "am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null" 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # 6.5 Khoi phuc ung dung can thiet & Cai dat AI Tro ly ao Tieng Viet
    Write-Host "   -> Khoi phuc ijetty & netctl..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null" 2>$null | Out-Null

    Write-Host "   -> Go ban AI cu va cai dat AI Tieng Viet moi..." -ForegroundColor White
    adb -s $Serial shell "/system/bin/pm uninstall info.dourok.voicebot 2>/dev/null; /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk; rm -f /data/local/tmp/AIBoxPlus_DLNA.apk" 2>$null | Out-Null

    # 6.6 Khoi dong AI Tro ly ao Tieng Viet & cau hinh Bluetooth, LED
    Write-Host "   -> Khoi dong AI Box Plus..." -ForegroundColor White
    adb -s $Serial shell "am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" 2>$null | Out-Null

    # Lay IP WiFi nha cua loa neu co
    $SpeakerLanIp = (adb -s $Serial shell "getprop dhcp.wlan0.ipaddress" 2>$null | Out-String).Trim()
} else {
    Write-Host "   -> [DRY-RUN] Da thuc thi chuoi lenh new.bat chuan xac!" -ForegroundColor Yellow
    $SpeakerLanIp = ""
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "                    CAI DAT HOAN TAT!                     " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green

if ($SpeakerLanIp -and $SpeakerLanIp -ne "") {
    Write-Host ">> IP cua loa trong mang WiFi nha: $SpeakerLanIp" -ForegroundColor Cyan
    Write-Host ">> Truy cap bang dieu khien loa tai: http://$($SpeakerLanIp):8081/" -ForegroundColor White
    try { Start-Process "http://$($SpeakerLanIp):8081/" } catch {}
} elseif ($TargetIp -eq "192.168.43.1") {
    Write-Host ">> BUOC TIEP THEO: CAU HINH WIFI CHO LOA" -ForegroundColor Yellow
    Write-Host " 1. Mo trinh duyet Web (Chrome / Edge) vao:" -ForegroundColor White
    Write-Host "    👉 http://192.168.43.1:8081/wifi.html" -ForegroundColor Cyan
    Write-Host " 2. Chon WiFi nha ban, nhap mat khau de loa ket noi Internet." -ForegroundColor White
    Write-Host " 3. Doi may tinh ve lai WiFi nha va trai nghiem!" -ForegroundColor White
    try { Start-Process "http://192.168.43.1:8081/wifi.html" } catch {}
} else {
    Write-Host ">> Truy cap bang dieu khien loa tai: http://$($TargetIp):8081/" -ForegroundColor White
    try { Start-Process "http://$($TargetIp):8081/" } catch {}
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
if (-not $Yes) {
    Read-Host "Nhan Enter de ket thuc"
}
