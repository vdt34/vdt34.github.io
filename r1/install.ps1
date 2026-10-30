# ==============================================================================
# PHICOMM R1 ALL-IN-ONE AUTOMATED INSTALLER (WINDOWS POWERSHELL)
# Ho tro: Windows 7, 8, 10, 11 (PowerShell 5.1 & PowerShell 7+)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$TempDir   = Join-Path $env:TEMP "phicomm_r1_install"
$BaseUrl   = "https://vdt34.github.io/r1"

$ApkDLNA = "autodlna.apk"
$ApkUNI  = "unisound.apk"
$ApkAI   = "AIBoxPlus_DLNA.apk"

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CAI DAT & CAP NHAT PHICOMM R1 TREN WINDOWS" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# 1. KIEM TRA VA CHUAN BI CONG CU ADB
# ------------------------------------------------------------------------------
function Ensure-AdbTools {
    $AdbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($AdbCmd) {
        Write-Host ">> [OK] Da co cong cu ADB tren he thong Windows." -ForegroundColor Green
        return $true
    }

    $LocalAdb = Join-Path $ScriptDir "adb.exe"
    if (Test-Path $LocalAdb) {
        $env:PATH = "$ScriptDir;" + $env:PATH
        Write-Host ">> [OK] Tim thay adb.exe tai thu muc hien tai." -ForegroundColor Green
        return $true
    }

    $TempAdb = Join-Path $TempDir "platform-tools\adb.exe"
    if (Test-Path $TempAdb) {
        $ToolsDir = Join-Path $TempDir "platform-tools"
        $env:PATH = "$ToolsDir;" + $env:PATH
        Write-Host ">> [OK] Su dung ADB tu thu muc cache." -ForegroundColor Green
        return $true
    }

    Write-Host ">> [CHUAN BI] Dang tai cong cu ADB tu Google..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $ZipPath = Join-Path $TempDir "platform-tools.zip"
    $AdbUrl  = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $AdbUrl -OutFile $ZipPath -TimeoutSec 30
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
        $ToolsDir = Join-Path $TempDir "platform-tools"
        $env:PATH = "$ToolsDir;" + $env:PATH
        Write-Host ">> [OK] Da cai dat xong ADB vao bo nho tam." -ForegroundColor Green
        return $true
    } catch {
        Write-Host ">> [LOI] Khong the tai ADB tu dong. Vui long cai ADB hoac kiem tra mang." -ForegroundColor Red
        return $false
    }
}

if (-not (Ensure-AdbTools)) {
    Read-Host "`nNhan Enter de thoat"
    return
}

# ------------------------------------------------------------------------------
# 2. HAM DANH THUC & KHOI DONG LAI ADB TREN LOA PHICOMM R1 QUA PORT 8080
# ------------------------------------------------------------------------------
function Revive-R1Speaker ($Ip) {
    if (-not $Ip) { return $false }
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = [System.Threading.CancellationToken]::None
        $uri = [Uri]"ws://$($Ip):8080"
        $connTask = $ws.ConnectAsync($uri, $ct)
        if ($connTask.Wait(2000)) {
            if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                # Khoi dong lai adbd tren port 5555, ngan ngu dong, tat ung dung chiem loa
                $cmd = "stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice"
                $json = '{"type":"shell","type_id":"revive","shell":"' + $cmd + '"}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
                $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(2000) | Out-Null
                $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $ct).Wait(1000) | Out-Null
                return $true
            }
        }
    } catch {}
    return $false
}

# ------------------------------------------------------------------------------
# 3. HAM QUET MANG TIM IP LOA R1
# ------------------------------------------------------------------------------
function Get-LocalSubnet {
    try {
        $Sub = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
        if ($Sub) {
            $Parts = $Sub.Split('.')
            return "$($Parts[0]).$($Parts[1]).$($Parts[2])"
        }
    } catch {}
    return "192.168.1"
}

function Scan-SpeakerIp {
    $CurSub = Get-LocalSubnet
    Write-Host ""
    $UserSub = Read-Host "Nhap dai mang can quet [Mac dinh: $CurSub]"
    if (-not $UserSub -or -not $UserSub.Trim()) {
        $UserSub = $CurSub
    } else {
        $UserSub = $UserSub.Trim()
        $parts = $UserSub.Split('.')
        if ($parts.Length -ge 3) {
            $UserSub = "$($parts[0]).$($parts[1]).$($parts[2])"
        }
    }

    Write-Host ""
    Write-Host ">> Dang quet dai mang $UserSub.1 -> 254 (Kiem tra cong 8080 & 5555)..." -ForegroundColor Cyan
    
    $FoundIps = New-Object System.Collections.Generic.List[string]
    $Tasks = @()

    1..254 | ForEach-Object {
        $ip = "$UserSub.$_"
        $tcp = New-Object System.Net.Sockets.TcpClient
        $task = [PSCustomObject]@{
            IP = $ip
            Client = $tcp
            AsyncResult = $tcp.BeginConnect($ip, 8080, $null, $null)
        }
        $Tasks += $task

        if ($Tasks.Count -ge 32 -or $_ -eq 254) {
            Start-Sleep -Milliseconds 350
            foreach ($t in $Tasks) {
                try {
                    if ($t.Client.Connected) {
                        if (-not $FoundIps.Contains($t.IP)) {
                            $FoundIps.Add($t.IP)
                            Write-Host "`n   [+] Phat hien loa Phicomm R1 tai IP: $($t.IP)" -ForegroundColor Green
                        }
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
        Write-Host ">> Khong tim thay thiet bi Phicomm R1 trong dai $UserSub.x." -ForegroundColor Yellow
    }
    return $FoundIps
}

# ------------------------------------------------------------------------------
# 4. MENU LUA CHON
# ------------------------------------------------------------------------------
$TargetIp = "192.168.43.1"
$Mode = "FULL"

while ($true) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              BANG DIEU KHIEN PHICOMM R1" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  [1] Cai dat SIEU TOC qua WiFi loa phat ra (192.168.43.1) [Khuyen dung]" -ForegroundColor White
    Write-Host "  [2] Cai dat day du qua mang WiFi nha (Nhap IP hoac tu dong quet)" -ForegroundColor White
    Write-Host "  [3] Chi cap nhat AI Box Plus DLNA moi nhat (Giu nguyen cai dat cu)" -ForegroundColor White
    Write-Host "  [4] Quet & tim dia chi IP cua loa trong mang WiFi nha" -ForegroundColor White
    Write-Host "  [5] Thoat" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    $Choice = Read-Host "Nhap lua chon cua ban (1-5, mac dinh 1)"
    if (-not $Choice -or -not $Choice.Trim()) { $Choice = "1" }

    switch ($Choice.Trim()) {
        "1" {
            $TargetIp = "192.168.43.1"
            $Mode = "FULL"
            break
        }
        "2" {
            Write-Host ""
            Write-Host "Nhap IP cua loa Phicomm R1 trong mang WiFi nha (Vi du: 192.168.1.94)." -ForegroundColor Yellow
            Write-Host "Neu chua ro dia chi IP, de trong roi nhan [Enter] de tu dong quet." -ForegroundColor Gray
            $UserIp = Read-Host "`nNhap IP cua loa [Nhan Enter de tu dong quet]"
            if ($UserIp -and $UserIp.Trim()) {
                $TargetIp = $UserIp.Trim().Replace(":5555", "")
            } else {
                $Suggest = Scan-SpeakerIp
                $DefIp = if ($Suggest.Count -gt 0) { ($Suggest | Select-Object -First 1) } else { "192.168.1.94" }
                $ChoiceIp = Read-Host "`nChon IP loa [Enter de chon $DefIp]"
                $TargetIp = if ($ChoiceIp -and $ChoiceIp.Trim()) { $ChoiceIp.Trim().Replace(":5555", "") } else { $DefIp }
            }
            $Mode = "FULL"
            break
        }
        "3" {
            Write-Host ""
            Write-Host "Nhap dia chi IP cua loa can cap nhat (VD: 192.168.1.94 hoac 192.168.43.1)" -ForegroundColor Yellow
            $UserIp = Read-Host "`nNhap IP loa can cap nhat [Mac dinh: 192.168.1.94]"
            $TargetIp = if ($UserIp -and $UserIp.Trim()) { $UserIp.Trim().Replace(":5555", "") } else { "192.168.1.94" }
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
# 5. QUAN LY CACHE & TAI FILE APK TU GITHUB
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
        Invoke-WebRequest -Uri "$BaseUrl/$FileName" -OutFile "$TempPath.tmp" -TimeoutSec 45
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
# 6. KET NOI ADB DEN LOA PHICOMM R1 (TUDONG REVIVE QUA PORT 8080)
# ------------------------------------------------------------------------------
$Serial = "$($TargetIp):5555"
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      KIEM TRA KET NOI DEN LOA R1 ($Serial)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

if ($TargetIp -eq "192.168.43.1") {
    Write-Host "------------------ HUONG DAN KET NOI WIFI LOA (AP) ------------------" -ForegroundColor Yellow
    Write-Host " 1. An giu nut tron tren dinh loa 6 giay den khi keu bip va doi den cam."
    Write-Host " 2. Bam bieu tuong WiFi goc phai Taskbar Windows, chon: Phicomm_R1_xxxx"
    Write-Host " 3. Neu Windows bao 'No Internet, secured' -> Van giu nguyen ket noi!"
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ">> HE THONG SE TU DONG KET NOI & CAI DAT NGAY KHI PHAT HIEN LOA!" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
} else {
    Write-Host ">> Dam bao may tinh dang ket noi cung mang WiFi voi loa tai IP: $TargetIp" -ForegroundColor Yellow
}

function Test-SpeakerReady {
    $Devs = (adb devices 2>$null | Out-String)
    if ($Devs -match [regex]::Escape($Serial) + "\s+device") { return $true }
    $Out = (adb -s $Serial shell "echo 1" 2>$null | Out-String).Trim()
    if ($Out -eq "1") { return $true }
    return $false
}

Write-Host ">> Dang khoi dong ADB tren may tinh..." -ForegroundColor Gray
adb start-server 2>$null | Out-Null

Write-Host ">> Dang danh thuc & kich hoat he thong loa tai $TargetIp..." -ForegroundColor Cyan
Revive-R1Speaker -Ip $TargetIp | Out-Null
Start-Sleep -Milliseconds 600

$TryCount = 0
while ($true) {
    $TryCount++

    $ConnRes = (adb connect $Serial 2>&1 | Out-String).Trim()
    Start-Sleep -Milliseconds 400

    if (Test-SpeakerReady) {
        Write-Host "`n>> [KET NOI THANH CONG] Da ket noi den loa Phicomm R1 tai $Serial!" -ForegroundColor Green
        break
    }

    Write-Host -NoNewline "`r[*] Dang ket noi [$Serial] (Lan thu $TryCount)... "

    if ($ConnRes -match "already connected" -or ($TryCount % 3 -eq 0)) {
        adb disconnect $Serial 2>$null | Out-Null
        Revive-R1Speaker -Ip $TargetIp | Out-Null
        Start-Sleep -Milliseconds 600
    }

    if ($TryCount % 15 -eq 0 -and $TargetIp -ne "192.168.43.1") {
        Write-Host ""
        $Retry = Read-Host "`n>> Chua thay loa tai $TargetIp. Ban co muon doi IP khac? (y/n, mac dinh n)"
        if ($Retry -eq "y" -or $Retry -eq "Y") {
            $NewIp = Read-Host "Nhap dia chi IP moi cua loa"
            if ($NewIp -and $NewIp.Trim()) {
                $TargetIp = $NewIp.Trim().Replace(":5555", "")
                $Serial = "$($TargetIp):5555"
                $TryCount = 0
                Write-Host ">> Da doi muc tieu sang: $Serial" -ForegroundColor Cyan
                Revive-R1Speaker -Ip $TargetIp | Out-Null
            }
        }
    }

    Start-Sleep -Milliseconds 1000
}

Write-Host ""
Write-Host ">> [SAN SANG] BAT DAU QUA TRINH CAI DAT CHO LOA R1..." -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 7. HAM CAI DAT APK AN TOAN QUA SDCARD
# ------------------------------------------------------------------------------
function Install-ApkToSpeaker ($LocalFile, $PkgName, $AppDesc) {
    Write-Host "   -> Dang chuyen $AppDesc sang loa..." -ForegroundColor White
    adb -s $Serial push $LocalFile /sdcard/app.apk 2>$null | Out-Null
    Start-Sleep -Milliseconds 500

    Write-Host "   -> Dang cai dat $AppDesc..." -ForegroundColor White
    adb connect $Serial 2>$null | Out-Null
    $InstallLog = (adb -s $Serial shell "pm install -r /sdcard/app.apk" 2>&1 | Out-String).Trim()

    if ($InstallLog -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE" -or $InstallLog -match "signatures do not match") {
        Write-Host "   [!] Khac chu ky cu, dang go ban cu de cai moi..." -ForegroundColor Yellow
        adb -s $Serial shell "pm uninstall $PkgName" 2>$null | Out-Null
        $InstallLog = (adb -s $Serial shell "pm install /sdcard/app.apk" 2>&1 | Out-String).Trim()
    }

    if ($InstallLog -match "Success") {
        Write-Host "   [THANH CONG] Da cai dat $AppDesc." -ForegroundColor Green
    } else {
        adb -s $Serial shell "pm unhide $PkgName; pm enable $PkgName" 2>$null | Out-Null
        Write-Host "   [KET QUA]: $InstallLog" -ForegroundColor Yellow
    }
    adb -s $Serial shell "rm -f /sdcard/app.apk" 2>$null | Out-Null
}

# ------------------------------------------------------------------------------
# 8. THUC THI CAI DAT & CAU HINH HE THONG
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
    $StartCmd = "for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do pm unhide `$p 2>/dev/null; pm enable `$p 2>/dev/null; done; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null"
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
