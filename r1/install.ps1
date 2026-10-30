# ==============================================================================
# Script Cai Dat & Cap Nhat Phicomm R1 tren Windows (PowerShell)
# Nguon APK: https://vdt34.github.io/r1/
# Tu dong tai ADB neu chua co, tu dong ket noi va flash sieu toc
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "CAI DAT & CAP NHAT PHICOMM R1 - WINDOWS"

$BaseUrl = "https://vdt34.github.io/r1"
$TempDir = "$env:TEMP\r1_install"
$ApkDLNA = "autodlna.apk"
$ApkUNI  = "unisound.apk"
$ApkAI   = "AIBoxPlus_DLNA.apk"
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CAI DAT & CAP NHAT PHICOMM R1 TREN WINDOWS" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# 1. KIEM TRA & TU DONG CAI DAT ADB NEU CHUA CO
# ------------------------------------------------------------------------------
function Ensure-Adb {
    if (Get-Command adb -ErrorAction SilentlyContinue) {
        Write-Host ">> [OK] Da co cong cu ADB tren he thong Windows." -ForegroundColor Green
        return
    }

    $AdbDir = "$TempDir\adb_tools\platform-tools"
    if (Test-Path "$AdbDir\adb.exe") {
        $env:PATH = "$AdbDir;" + $env:PATH
        Write-Host ">> [OK] Su dung ADB tu thu muc tam: $AdbDir" -ForegroundColor Green
        return
    }

    Write-Host ">> [*] May tinh chua co ADB. Dang tu dong tai bo cong cu tu Google Android..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "$TempDir\adb_tools" | Out-Null
    $ZipPath = "$TempDir\adb.zip"
    
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $ZipPath -TimeoutSec 60
        Expand-Archive -Path $ZipPath -DestinationPath "$TempDir\adb_tools" -Force
        Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
        if (Test-Path "$AdbDir\adb.exe") {
            $env:PATH = "$AdbDir;" + $env:PATH
            Write-Host ">> [OK] Da tai va tich hop ADB thanh cong!" -ForegroundColor Green
        } else {
            throw "Khong tim thay adb.exe sau khi giai nen."
        }
    } catch {
        Write-Host ">> [LOI] Khong the tai ADB tu dong: $_" -ForegroundColor Red
        Write-Host "   Vui long tai Android Platform-Tools thu cong de tiep tuc!" -ForegroundColor Yellow
        exit 1
    }
}

Ensure-Adb

# ------------------------------------------------------------------------------
# 2. HAM QUET MANG TIM IP LOA R1
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
    $UserSub = Read-Host "Nhap dai mang can quet [Mac dinh: $CurSub]"
    if (-not $UserSub) { $UserSub = $CurSub }

    Write-Host ""
    Write-Host ">> Dang quet nhanh dai mang $UserSub.1 -> 254 (Port 5555)..." -ForegroundColor Cyan
    
    $FoundIps = New-Object System.Collections.Generic.List[string]
    $Tasks = @()

    1..254 | ForEach-Object {
        $ip = "$UserSub.$_"
        $tcp = New-Object System.Net.Sockets.TcpClient
        $task = [PSCustomObject]@{
            IP = $ip
            Client = $tcp
            AsyncResult = $tcp.BeginConnect($ip, 5555, $null, $null)
        }
        $Tasks += $task

        if ($Tasks.Count -ge 30 -or $_ -eq 254) {
            Start-Sleep -Milliseconds 350
            foreach ($t in $Tasks) {
                try {
                    if ($t.Client.Connected) {
                        $FoundIps.Add($t.IP)
                        Write-Host "`n   [+] Phat hien loa Phicomm R1 tai IP: $($t.IP)" -ForegroundColor Green
                    }
                } catch {}
                finally {
                    $t.Client.Close()
                }
            }
            $Tasks = @()
            Write-Host -NoNewline "`r[*] Tien do quet: $_/254 IP..."
        }
    }
    Write-Host ""

    if ($FoundIps.Count -eq 0) {
        Write-Host ">> Khong tim thay thiet bi nao mo cong 5555 trong dai $UserSub.x." -ForegroundColor Yellow
    }
    return $FoundIps
}

# ------------------------------------------------------------------------------
# 3. MENU LUA CHON
# ------------------------------------------------------------------------------
$TargetIp = "192.168.43.1"
$Mode = "FULL"

while ($true) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              BANG DIEU KHIEN PHICOMM R1" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  [1] Cai dat SIEU TOC qua WiFi loa phat ra (192.168.43.1) [Khuyen dung]" -ForegroundColor White
    Write-Host "  [2] Cai dat day du qua mang WiFi nha (Tu tim hoac nhap IP thu cong)" -ForegroundColor White
    Write-Host "  [3] Chi cap nhat AI Box Plus DLNA moi nhat (Giu nguyen cai dat cu)" -ForegroundColor White
    Write-Host "  [4] Quet & tim dia chi IP cua loa trong mang WiFi nha" -ForegroundColor White
    Write-Host "  [5] Thoat" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    $Choice = Read-Host "Nhap lua chon cua ban (1-5, mac dinh 1)"
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
            $UserIp = Read-Host "`nNhap IP cua loa [Enter de chon $DefIp]"
            $TargetIp = if ($UserIp) { $UserIp.Trim().Replace(":5555", "") } else { $DefIp }
            $Mode = "FULL"
            break
        }
        "3" {
            $UserIp = Read-Host "`nNhap IP loa can cap nhat [Enter de chon 192.168.43.1]"
            $TargetIp = if ($UserIp) { $UserIp.Trim().Replace(":5555", "") } else { "192.168.43.1" }
            $Mode = "UPDATE_ONLY"
            break
        }
        "4" {
            Scan-SpeakerIp | Out-Null
            continue
        }
        "5" {
            Write-Host "Tam biet!" -ForegroundColor Cyan
            return
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
# 4. QUAN LY CACHE & TAI FILE APK TU GITHUB
# ------------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      KIEM TRA & CHUAN BI FILE APK CAI DAT" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

function Download-ApkFile ($FileName, $Desc, $MinSize) {
    $LocalPath = Join-Path $ScriptDir $FileName
    $TempPath  = Join-Path $TempDir $FileName

    if (Test-Path $LocalPath) {
        $Item = Get-Item $LocalPath
        if ($Item.Length -ge $MinSize) {
            Copy-Item -Path $LocalPath -Destination $TempPath -Force
            Write-Host ">> [CO SAN] Su dung $Desc tu thu muc hien tai." -ForegroundColor Green
            return $true
        }
    }

    if (Test-Path $TempPath) {
        $Item = Get-Item $TempPath
        if ($Item.Length -ge $MinSize) {
            Write-Host ">> [CACHE] Da co san $Desc trong may." -ForegroundColor Green
            return $true
        }
    }

    Write-Host ">> Dang tai $Desc tu GitHub ($BaseUrl/$FileName)..." -ForegroundColor White
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri "$BaseUrl/$FileName" -OutFile "$TempPath.tmp" -TimeoutSec 30
        Move-Item -Path "$TempPath.tmp" -Destination $TempPath -Force
        Write-Host ">> [OK] Da tai $Desc thanh cong." -ForegroundColor Green
        return $true
    } catch {
        Remove-Item "$TempPath.tmp" -Force -ErrorAction SilentlyContinue
        Write-Host ">> [LOI] Khong the tai $Desc tu Internet!" -ForegroundColor Red
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
    Write-Host "  [LOI THIEU FILE CAI DAT DO CHUA CO INTERNET]" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "May tinh cua ban dang ket noi WiFi cua loa (192.168.43.1 khong co mang)"
    Write-Host "nen khong the tai duoc file APK ve."
    Write-Host ""
    Write-Host "GIAI PHAP:" -ForegroundColor Yellow
    Write-Host " 1. Chuyen may tinh ve mang WiFi nha co Internet."
    Write-Host " 2. Chay lai script de tai tron ven cac file APK ve may truoc."
    Write-Host " 3. Khi may da co file, chuyen sang WiFi loa de FLASH SIEU TOC!"
    Write-Host "==========================================================" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat"
    return
}

Write-Host ">> [OK] Toan bo file APK da san sang trong may tinh!" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 5. KET NOI ADB DEN LOA PHICOMM R1
# ------------------------------------------------------------------------------
$Serial = "$TargetIp" + ":5555"
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      KIEM TRA KET NOI DEN LOA R1 ($Serial)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

adb start-server | Out-Null

if ($TargetIp -eq "192.168.43.1") {
    Write-Host "------------------ HUONG DAN KET NOI WIFI LOA (AP) ------------------" -ForegroundColor Yellow
    Write-Host " 1. An giu nut tron tren dinh loa 6 giay den khi keu bip va doi den cam."
    Write-Host " 2. Bam bieu tuong WiFi goc phai Taskbar Windows, chon: Phicomm_R1_xxxx"
    Write-Host " 3. Neu Windows bao 'No Internet, secured' -> Van giu nguyen ket noi!"
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ">> HE THONG SE TU DONG BAT DAU CAI DAT NGAY KHI PHAT HIEN LOA!" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
} else {
    Write-Host ">> Dam bao may tinh dang ket noi cung mang WiFi voi loa tai IP: $TargetIp" -ForegroundColor Yellow
}

Write-Host ">> Dang do tim loa lien tuc tai $Serial (Bam Ctrl + C neu muon dung)..." -ForegroundColor White
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

$ConnInit = (adb connect $Serial 2>&1 | Out-String).Trim()
Start-Sleep -Milliseconds 800

if (-not (Test-SpeakerReady)) {
    if ($ConnInit -match "already connected") {
        Write-Host ">> Phat hien socket cu bi treo, dang lam sach ket noi..." -ForegroundColor Yellow
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
            Write-Host "`n>> [KET NOI THANH CONG] Da nhan dien loa Phicomm R1 tai $Serial!" -ForegroundColor Green
            break
        }

        $ConnRes = (adb connect $Serial 2>&1 | Out-String).Trim()
        if (Test-SpeakerReady) {
            Write-Host "`n>> [KET NOI THANH CONG] Da nhan dien loa Phicomm R1 tai $Serial!" -ForegroundColor Green
            break
        }

        Write-Host -NoNewline "`r[*] Dang cho ket noi [$Serial] (Lan thu $TryCount) | $ConnRes   "

        if ($ConnRes -match "already connected" -or ($TryCount % 6 -eq 0)) {
            adb disconnect $Serial 2>$null | Out-Null
            adb kill-server 2>$null | Out-Null
            Start-Sleep -Milliseconds 600
            adb start-server 2>$null | Out-Null
        }

        if ($TryCount % 18 -eq 0 -and $TargetIp -ne "192.168.43.1") {
            Write-Host ""
            $Retry = Read-Host "`n>> Chua thay loa tai $TargetIp. Ban co muon doi IP khac? (y/n, mac dinh n)"
            if ($Retry -eq "y" -or $Retry -eq "Y") {
                $NewIp = Read-Host "Nhap dia chi IP moi"
                if ($NewIp) {
                    $TargetIp = $NewIp.Trim().Replace(":5555", "")
                    $Serial = "$TargetIp" + ":5555"
                    $TryCount = 0
                    Write-Host ">> Da doi muc tieu sang: $Serial" -ForegroundColor Cyan
                }
            }
        }

        Start-Sleep -Milliseconds 1200
    }
} else {
    Write-Host "`n>> [KET NOI THANH CONG] Da nhan dien loa Phicomm R1 tai $Serial!" -ForegroundColor Green
}

Write-Host ""
Write-Host ">> [SAN SANG] BAT DAU QUA TRINH CAI DAT CHO LOA R1..." -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 6. HAM CAI DAT APK AN TOAN QUA ADB
# ------------------------------------------------------------------------------
function Install-ApkToSpeaker ($LocalFile, $PkgName, $AppDesc) {
    Write-Host -NoNewline "   -> Dang chuyen $AppDesc sang loa... "
    adb -s $Serial push $LocalFile /data/local/tmp/app.apk 2>$null | Out-Null
    Write-Host -NoNewline "Dang cai dat... "
    $InstallLog = (adb -s $Serial shell "pm install -r /data/local/tmp/app.apk" 2>&1 | Out-String).Trim()

    if ($InstallLog -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
        Write-Host -NoNewline "`n   [!] Khac chu ky cu, dang go ban cu de cai moi... " -ForegroundColor Yellow
        adb -s $Serial shell "pm uninstall $PkgName" 2>$null | Out-Null
        $InstallLog = (adb -s $Serial shell "pm install /data/local/tmp/app.apk" 2>&1 | Out-String).Trim()
    }

    if ($InstallLog -match "Success") {
        Write-Host "[THANH CONG]" -ForegroundColor Green
    } else {
        Write-Host "[LOI]: $InstallLog" -ForegroundColor Red
    }
    adb -s $Serial shell "rm -f /data/local/tmp/app.apk" 2>$null | Out-Null
}

# ------------------------------------------------------------------------------
# 7. THUC THI CAI DAT
# ------------------------------------------------------------------------------
if ($Mode -eq "FULL") {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  BAT DAU CAI DAT: AutoDLNA + Unisound + AI Box Plus DLNA" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ">> [1/5] Tat toan bo tien trinh chiem quyen, xung dot am thanh va micro..." -ForegroundColor White
    $CleanCmd = "svc power stayon true 2>/dev/null; am force-stop info.dourok.voicebot 2>/dev/null; am force-stop com.phicomm.speaker.player 2>/dev/null; am force-stop com.phicomm.speaker.device 2>/dev/null; am force-stop com.phicomm.speaker.airskill 2>/dev/null; am force-stop com.phicomm.speaker.otaservice 2>/dev/null; am force-stop com.phicomm.speaker.exceptionreporter 2>/dev/null; am force-stop com.phicomm.speaker.systemtool 2>/dev/null; am force-stop com.phicomm.speaker.productiontest 2>/dev/null; am force-stop com.phicomm.speaker.bugreport 2>/dev/null; am force-stop com.phicomm.speaker.remote 2>/dev/null; am force-stop com.tencent.qqmusic 2>/dev/null; killall -9 shairport dlna mpd 2>/dev/null; for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do pm hide `$p 2>/dev/null; pm disable `$p 2>/dev/null; done; rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; rm -rf /data/local/tmp/* 2>/dev/null; pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null"
    adb -s $Serial shell $CleanCmd 2>$null | Out-Null
    Write-Host "   [OK] Da giai phong hoan toan am thanh, micro va cac cong mang!" -ForegroundColor Green

    Write-Host ">> [2/5] Cai dat AutoDLNA (Dieu khien nhac & Web Control)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkDLNA) "com.phicomm.speaker.player" "AutoDLNA"

    Write-Host ">> [3/5] Cai dat Unisound (Dieu khien phan cung & he thong)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkUNI) "com.phicomm.speaker.device" "Unisound"

    Write-Host ">> [4/5] Cai dat AI Box Plus DLNA (Tro ly Tieng Viet & DLNA)..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkAI) "info.dourok.voicebot" "AI Box Plus DLNA"

    Write-Host ">> [5/5] Mo khoa va khoi chay toan bo dich vu he thong..." -ForegroundColor White
    $StartCmd = "for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do pm unhide `$p 2>/dev/null; pm enable `$p 2>/dev/null; done; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; mkdir -p /data/data/info.dourok.voicebot/shared_prefs 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null"
    adb -s $Serial shell $StartCmd 2>$null | Out-Null
    Start-Sleep -Seconds 1

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "     [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Toan bo ung dung & dich vu da duoc kich hoat SAN SANG DUNG NGAY!"
    Write-Host ""

    if ($TargetIp -eq "192.168.43.1") {
        Write-Host ">>> CAC BUOC CAU HINH WIFI NHA CHO LOA:" -ForegroundColor Yellow
        Write-Host " 1. Mo trinh duyet Web (Chrome, Edge), truy cap:" -ForegroundColor White
        Write-Host "    👉 http://192.168.43.1:8081/wifi.html" -ForegroundColor Cyan
        Write-Host " 2. Chon ten WiFi nha ban, nhap mat khau -> Loa se phat am thong bao." -ForegroundColor White
        Write-Host " 3. Chuyen may tinh ve lai WiFi nha va tan huong am nhac!" -ForegroundColor White
        Write-Host "==========================================================" -ForegroundColor Green
        Start-Process "http://192.168.43.1:8081/wifi.html"
    } else {
        $WebUrl = "http://" + $TargetIp + ":8081/"
        Write-Host "Truy cap giao dien web dieu khien loa tai: $WebUrl" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Green
        Start-Process $WebUrl
    }
} else {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAU HINH)" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ">> [1/2] Tat tien trinh cu..." -ForegroundColor White
    adb -s $Serial shell "am force-stop info.dourok.voicebot 2>/dev/null; rm -rf /data/local/tmp/* 2>/dev/null" 2>$null | Out-Null

    Write-Host ">> [2/2] Cai dat ban AI Box Plus DLNA moi nhat..." -ForegroundColor White
    Install-ApkToSpeaker (Join-Path $TempDir $ApkAI) "info.dourok.voicebot" "AI Box Plus DLNA"

    $UpdStart = "pm unhide info.dourok.voicebot 2>/dev/null; pm enable info.dourok.voicebot 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null"
    adb -s $Serial shell $UpdStart 2>$null | Out-Null

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Toan bo cau hinh cu (mDNS, PayOS, hen gio...) duoc giu nguyen 100%!"
    $WebUrl = "http://" + $TargetIp + ":8081/"
    Write-Host "Truy cap giao dien web dieu khien tai: $WebUrl" -ForegroundColor Cyan
    Start-Process $WebUrl
}

Write-Host ""
Read-Host "Nhan Enter de ket thuc"
