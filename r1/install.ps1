<#
==============================================================================
 PHICOMM R1 INSTALLER V2 - WINDOWS (PowerShell 5.1 / 7+)
 Nguon goi cai dat: GitHub (vdt34/vdt34.github.io -> thu muc /r1)

 Cach chay:
   - Nhap dup install.cmd
   - Hoac: powershell -ExecutionPolicy Bypass -File install.ps1
   - Tu xa (khong can tai truoc):
       powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://vdt34.github.io/r1/install.ps1)))"

 Che do khong hoi (dung cho script / kiem thu):
   install.ps1 -Action full    -Ip 192.168.43.1 -Yes
   install.ps1 -Action update  -Ip 192.168.1.94 -Yes
   install.ps1 -Action multi   -Ips 192.168.1.94,192.168.1.95 -Mode full -Yes
   install.ps1 -Action backup|restore|repair|uninstall|info -Ip <IP>
   install.ps1 -Action prefetch | verify | scan
   Them -DryRun (hoac bien moi truong R1_DRYRUN=1) de gia lap, khong can loa.
==============================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('menu', 'full', 'update', 'repair', 'backup', 'restore', 'uninstall', 'scan', 'info', 'prefetch', 'verify', 'multi')]
    [string]$Action = 'menu',
    [string]$Ip = '',
    [string[]]$Ips = @(),
    [ValidateSet('', 'full', 'update', 'repair')]
    [string]$Mode = '',
    [string]$BackupPath = '',
    [string]$Subnet = '',
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$NoBackup,
    [switch]$Offline,
    [int]$ConnectTimeout = 90
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch {}

# ------------------------------------------------------------------------------
# 0. CAU HINH CHUNG
# ------------------------------------------------------------------------------
$Script:InstallerVersion = '2.0.0'
$Script:Mirrors = @(
    'https://vdt34.github.io/r1',
    'https://raw.githubusercontent.com/vdt34/vdt34.github.io/main/r1',
    'https://github.com/vdt34/vdt34.github.io/releases/latest/download'
)
if ($env:R1_BASE_URL) { $Script:Mirrors = @($env:R1_BASE_URL.TrimEnd('/')) + $Script:Mirrors }

$Script:ApIp = '192.168.43.1'
$Script:DryRun = $DryRun.IsPresent -or ($env:R1_DRYRUN -eq '1')
$Script:AssumeYes = $Yes.IsPresent -or ($env:R1_YES -eq '1')
$Script:Interactive = ($Action -eq 'menu')
$Script:OfflineMode = $Offline.IsPresent -or ($env:R1_OFFLINE -eq '1')
$Script:ConnectTimeout = $ConnectTimeout
$Script:IsWin = ($env:OS -eq 'Windows_NT')
$Script:AdbExe = $null
$Script:Serial = ''
$Script:TargetIp = ''
$Script:Manifest = $null
$Script:RemoteTmp = '/sdcard/r1_tmp.apk'

$Script:ScriptDir = $null
if ($PSCommandPath) { $Script:ScriptDir = Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { $Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

if ($env:R1_HOME) { $Script:R1Home = $env:R1_HOME }
elseif ($env:LOCALAPPDATA) { $Script:R1Home = Join-Path $env:LOCALAPPDATA 'R1Installer' }
else { $Script:R1Home = Join-Path ([IO.Path]::GetTempPath()) 'R1Installer' }
$Script:CacheDir = Join-Path $Script:R1Home 'cache'
$Script:LogDir = Join-Path $Script:R1Home 'logs'
$docs = [Environment]::GetFolderPath('MyDocuments')
if ($env:R1_HOME -or -not $docs) { $Script:BackupRoot = Join-Path $Script:R1Home 'backups' }
else { $Script:BackupRoot = Join-Path $docs 'R1Installer\backups' }
foreach ($d in @($Script:CacheDir, $Script:LogDir, $Script:BackupRoot)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
$Script:LogFile = Join-Path $Script:LogDir ('r1_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

# Goi ung dung tren loa
$Script:PkgAiBox = 'info.dourok.voicebot'
$Script:ConflictPkgs = @('com.phicomm.speaker.airskill', 'com.phicomm.speaker.otaservice', 'com.phicomm.speaker.exceptionreporter',
    'com.phicomm.speaker.systemtool', 'com.phicomm.speaker.productiontest', 'com.phicomm.speaker.bugreport',
    'com.phicomm.speaker.remote', 'com.tencent.qqmusic')
$Script:CorePkgs = @('com.phicomm.speaker.player', 'com.phicomm.speaker.device', 'com.phicomm.speaker.ijetty',
    'com.phicomm.speaker.netctl', 'info.dourok.voicebot')
$Script:ManagedPkgs = $Script:CorePkgs + $Script:ConflictPkgs

# Lenh shell tren loa (giu nguyen trinh tu cua bo cai mau)
$Script:CmdRevive = 'stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice'
$Script:CmdClean = 'svc power stayon true 2>/dev/null; for p in info.dourok.voicebot com.phicomm.speaker.player com.phicomm.speaker.device ' + ($Script:ConflictPkgs -join ' ') +
'; do am force-stop $p 2>/dev/null; done; killall -9 shairport dlna mpd 2>/dev/null; for p in ' + ($Script:ConflictPkgs -join ' ') +
'; do pm hide $p 2>/dev/null; pm disable $p 2>/dev/null; done; rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip /sdcard/r1_tmp.apk /sdcard/app.apk 2>/dev/null; rm -rf /data/local/tmp/* 2>/dev/null; pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null'
$Script:CmdPostConfig = 'settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null'
$Script:CmdStart = 'for p in ' + ($Script:CorePkgs -join ' ') + '; do pm unhide $p 2>/dev/null; pm enable $p 2>/dev/null; done; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; ' + $Script:CmdPostConfig
$Script:CmdStartAiBox = 'pm unhide info.dourok.voicebot 2>/dev/null; pm enable info.dourok.voicebot 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; ' + $Script:CmdPostConfig
$Script:CmdUnhideStock = 'for p in ' + ($Script:ConflictPkgs -join ' ') + ' com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl; do pm unhide $p 2>/dev/null; pm enable $p 2>/dev/null; done; svc power stayon false 2>/dev/null'

# ------------------------------------------------------------------------------
# 1. TIEN ICH: LOG, NHAP LIEU
# ------------------------------------------------------------------------------
function Write-LogFile([string]$Text) {
    try { Add-Content -Path $Script:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text) -Encoding UTF8 } catch {}
}

function Write-Log([string]$Msg, [string]$Level = 'INFO') {
    $colors = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERR = 'Red'; STEP = 'Cyan'; TITLE = 'Yellow'; HI = 'White' }
    $c = $colors[$Level]; if (-not $c) { $c = 'Gray' }
    Write-Host $Msg -ForegroundColor $c
    Write-LogFile "[$Level] $Msg"
}

function Write-Title([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 62) -ForegroundColor Cyan
    Write-Log ('  ' + $Text) 'TITLE'
    Write-Host ('=' * 62) -ForegroundColor Cyan
}

function Read-Input([string]$Prompt, [string]$Default = '') {
    if (-not $Script:Interactive) { return $Default }
    $v = Read-Host $Prompt
    if ($null -eq $v -or -not $v.Trim()) { return $Default }
    return $v.Trim()
}

function Confirm-Action([string]$Prompt, [bool]$Default = $false) {
    if ($Script:AssumeYes) { return $true }
    if (-not $Script:Interactive) { return $Default }
    $d = 'n'; if ($Default) { $d = 'y' }
    $v = Read-Host "$Prompt (y/n, mac dinh $d)"
    if (-not $v -or -not $v.Trim()) { return $Default }
    return ($v.Trim().ToLower() -in @('y', 'yes', 'c', 'co'))
}

function Wait-Enter { if ($Script:Interactive) { Read-Host "`nNhan Enter de tiep tuc" | Out-Null } }

function ConvertTo-Ip([string]$Text) {
    if (-not $Text) { return '' }
    $t = $Text.Trim() -replace ':5555$', ''
    if ($t -match '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$') {
        foreach ($i in 1..4) { if ([int]$Matches[$i] -gt 255) { return '' } }
        return $t
    }
    return ''
}

function Test-TcpPort([string]$HostIp, [int]$Port, [int]$TimeoutMs = 800) {
    if ($Script:DryRun) { return $true }
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect($HostIp, $Port, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne($TimeoutMs) -and $c.Connected) { return $true }
        return $false
    } catch { return $false } finally { $c.Close() }
}

# ------------------------------------------------------------------------------
# 2. ADB: TIM / TAI CONG CU, GOI LENH CO TIMEOUT, GIA LAP (DRY-RUN)
# ------------------------------------------------------------------------------
function Initialize-Adb {
    if ($Script:AdbExe) { return $true }
    if ($Script:DryRun) { $Script:AdbExe = 'adb'; Write-Log '>> [DRY-RUN] Gia lap ADB - khong ket noi loa that.' 'WARN'; return $true }

    $cands = @()
    if ($Script:ScriptDir) { $cands += (Join-Path $Script:ScriptDir 'adb.exe'); $cands += (Join-Path $Script:ScriptDir 'platform-tools\adb.exe') }
    $cands += (Join-Path $Script:R1Home 'platform-tools\adb.exe')
    $cmd = Get-Command adb -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $cands = @($cmd.Path) + $cands }
    foreach ($c in $cands) {
        if ($c -and (Test-Path $c)) { $Script:AdbExe = $c; Write-Log ">> [OK] ADB: $c" 'OK'; return $true }
    }

    if (-not $Script:IsWin) { Write-Log '>> [LOI] Khong tim thay adb. Hay cai android-platform-tools.' 'ERR'; return $false }
    Write-Log '>> [CHUAN BI] Dang tai Android platform-tools tu Google...' 'WARN'
    $zip = Join-Path $Script:R1Home 'platform-tools.zip'
    if (Save-Url 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' $zip) {
        try {
            Expand-Archive -Path $zip -DestinationPath $Script:R1Home -Force
            $p = Join-Path $Script:R1Home 'platform-tools\adb.exe'
            if (Test-Path $p) { $Script:AdbExe = $p; Write-Log '>> [OK] Da cai ADB vao bo nho cache.' 'OK'; return $true }
        } catch { Write-LogFile "Expand-Archive loi: $_" }
    }
    Write-Log '>> [LOI] Khong the chuan bi ADB. Kiem tra Internet hoac dat adb.exe canh install.ps1.' 'ERR'
    return $false
}

function ConvertTo-ArgString([string]$s) {
    if ($s -eq '') { return '""' }
    if ($s -match '[\s"]') { return '"' + ($s -replace '"', '\"') + '"' }
    return $s
}

function Get-FakeAdbOutput([string[]]$A) {
    $l = $A -join ' '
    if ($l -match '(^| )connect (\S+)') { return "connected to $($Matches[2])" }
    if ($l -match 'disconnect') { return 'disconnected' }
    if ($l -match 'get-state') { return 'device' }
    if ($l -match '(^| )devices') { return "List of devices attached`n$($Script:Serial)`tdevice" }
    if ($l -match ' push ') { return '1 file pushed. 4.1 MB/s' }
    if ($l -match ' pull ') {
        $dst = $A[-1]
        try { if (-not (Test-Path $dst)) { Set-Content -Path $dst -Value 'dryrun' } } catch {}
        return '1 file pulled.'
    }
    if ($l -match 'pm install') { return 'Success' }
    if ($l -match 'pm uninstall') { return 'Success' }
    if ($l -match 'pm path (\S+)') { return "package:/system/app/$($Matches[1])/base.apk" }
    if ($l -match 'pm list packages -d') { return 'package:com.phicomm.speaker.otaservice' }
    if ($l -match 'pm list packages') { return (($Script:ManagedPkgs | ForEach-Object { "package:/system/app/$_/base.apk=$_" }) -join "`n") }
    if ($l -match 'dumpsys package') { return '    versionCode=4 targetSdk=33' }
    if ($l -match 'ls -ld') { return 'drwxr-x--x u0_a45   u0_a45            2026-10-30 10:00 info.dourok.voicebot' }
    if ($l -match 'echo MODEL') { return "MODEL=R1`nANDROID=5.1.1`nSERIAL=DRYRUN0001`nWIFIIP=192.168.1.94`nMAC=00:11:22:33:44:55`nUID=uid=0(root)" }
    if ($l -match '(^| )ps$') { return "u0_a45 1234 1 info.dourok.voicebot`nsystem 999 1 com.phicomm.speaker.player`nsystem 998 1 com.phicomm.speaker.device" }
    if ($l -match 'echo 1$') { return '1' }
    if ($l -match 'getprop$') { return '[ro.product.model]: [R1]' }
    return ''
}

function Invoke-Adb([string[]]$A, [int]$TimeoutSec = 60) {
    Write-LogFile ('ADB> ' + ($A -join ' '))
    if ($Script:DryRun) { $o = Get-FakeAdbOutput $A; Write-LogFile "<< $o"; return $o }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Script:AdbExe
        $psi.Arguments = (($A | ForEach-Object { ConvertTo-ArgString $_ }) -join ' ')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $so = $p.StandardOutput.ReadToEndAsync()
        $se = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill() } catch {}
            Write-LogFile '<< R1_TIMEOUT'
            return 'R1_TIMEOUT'
        }
        $out = ''
        if ($so.Wait(3000)) { $out += $so.Result }
        if ($se.Wait(1000)) { $out += "`n" + $se.Result }
        $out = ($out -replace "`r", '').Trim()
        $logOut = $out; if ($logOut.Length -gt 1500) { $logOut = $logOut.Substring(0, 1500) + '...' }
        Write-LogFile "<< $logOut"
        return $out
    } catch {
        Write-LogFile "<< EXCEPTION $_"
        return "R1_ERROR $_"
    }
}

function Invoke-AdbShell([string]$Command, [int]$TimeoutSec = 60) {
    return (Invoke-Adb @('-s', $Script:Serial, 'shell', $Command) $TimeoutSec)
}

function Start-AdbServer {
    if ($Script:DryRun) { return }
    # Chay rieng (khong chuyen huong output) de tien trinh adb server khong giu pipe
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Script:AdbExe
        $psi.Arguments = 'start-server'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        [void]$p.WaitForExit(15000)
    } catch {}
}

# ------------------------------------------------------------------------------
# 3. TAI FILE, MANIFEST VA KIEM TRA CHECKSUM
# ------------------------------------------------------------------------------
function Save-Url([string]$Url, [string]$Dest) {
    Write-LogFile "GET $Url"
    $part = "$Dest.part"
    Remove-Item $part -Force -ErrorAction SilentlyContinue
    $curl = $null
    if ($Script:IsWin) { $curl = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    try {
        if ($curl) {
            & $curl.Path -fL --retry 2 --connect-timeout 15 -# -o $part $Url
            if ($LASTEXITCODE -ne 0) { throw "curl exit $LASTEXITCODE" }
        } else {
            $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            try { Invoke-WebRequest -Uri $Url -OutFile $part -UseBasicParsing -TimeoutSec 120 } finally { $ProgressPreference = $old }
        }
        Move-Item -Path $part -Destination $Dest -Force
        return $true
    } catch {
        Write-LogFile "Tai loi: $_"
        Remove-Item $part -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Get-WebText([string]$Url) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
        $c = $r.Content
        if ($c -is [byte[]]) { $c = [Text.Encoding]::UTF8.GetString($c) }
        return [string]$c
    } catch { Write-LogFile "GET $Url loi: $_"; return $null }
}

function ConvertFrom-Manifest([string]$Text) {
    $items = @()
    foreach ($raw in ($Text -split "`n")) {
        $l = $raw.Trim()
        if (-not $l -or $l.StartsWith('#')) { continue }
        $f = $l.Split('|')
        if ($f.Count -lt 9) { continue }
        $items += [pscustomobject]@{
            Id = $f[0]; File = $f[1]; Package = $f[2]; VersionCode = [int]$f[3]; Sha256 = $f[4].ToLower()
            Size = [long]$f[5]; Type = $f[6]; Order = [int]$f[7]; Desc = $f[8]
        }
    }
    return , @($items | Sort-Object Order)
}

function Get-Manifest {
    if ($Script:Manifest) { return $Script:Manifest }
    $text = $null; $src = ''
    if ($Script:ScriptDir) {
        $local = Join-Path $Script:ScriptDir 'manifest.txt'
        if (Test-Path $local) { $text = Get-Content $local -Raw; $src = "thu muc bo cai ($local)" }
    }
    $cache = Join-Path $Script:CacheDir 'manifest.txt'
    if (-not $text -and -not $Script:OfflineMode) {
        foreach ($m in $Script:Mirrors) {
            $t = Get-WebText ("$m/manifest.txt?t=" + [DateTime]::UtcNow.Ticks)
            if ($t -and $t -match '\|') { $text = $t; $src = $m; Set-Content -Path $cache -Value $t -Encoding UTF8; break }
        }
    }
    if (-not $text -and (Test-Path $cache)) { $text = Get-Content $cache -Raw; $src = 'cache trong may (offline)' }
    if (-not $text) { Write-Log '>> [LOI] Khong lay duoc manifest.txt (chua co Internet va chua co cache).' 'ERR'; return $null }
    $Script:Manifest = ConvertFrom-Manifest $text
    Write-Log (">> Manifest: {0} ({1} goi)" -f $src, $Script:Manifest.Count)
    return $Script:Manifest
}

function Test-FileSha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path $Path)) { return $false }
    $h = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLower()
    return ($h -eq $Expected.ToLower())
}

function Get-PackageFile($Item) {
    $cache = Join-Path $Script:CacheDir $Item.File
    $cands = @()
    if ($Script:ScriptDir) { $cands += (Join-Path $Script:ScriptDir $Item.File) }
    $cands += $cache
    foreach ($c in $cands) {
        if (Test-Path $c) {
            if (Test-FileSha256 $c $Item.Sha256) { Write-Log "   [OK] $($Item.Desc): checksum dung ($c)" 'OK'; return $c }
            Write-Log "   [!] $($Item.File) tai $c sai checksum -> bo qua." 'WARN'
        }
    }
    if ($Script:OfflineMode) { Write-Log "   [LOI] Thieu $($Item.File) va dang o che do offline." 'ERR'; return $null }
    foreach ($m in $Script:Mirrors) {
        Write-Log "   -> Tai $($Item.Desc) tu $m ..." 'HI'
        $tmp = "$cache.download"
        if (Save-Url "$m/$($Item.File)" $tmp) {
            if (Test-FileSha256 $tmp $Item.Sha256) {
                Move-Item $tmp $cache -Force
                Write-Log "   [OK] Da tai va xac minh SHA256 $($Item.File)." 'OK'
                return $cache
            }
            Write-Log "   [!] Sai checksum khi tai tu $m (file hong / chua cap nhat). Thu nguon khac..." 'WARN'
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "   [LOI] Khong the tai $($Item.File) tu bat ky nguon nao." 'ERR'
    return $null
}

function Get-RequiredFiles($Items) {
    Write-Title 'KIEM TRA & CHUAN BI FILE CAI DAT (SHA256)'
    $map = @{}
    $err = 0
    foreach ($it in $Items) {
        $p = Get-PackageFile $it
        if ($p) { $map[$it.Id] = $p } else { $err++ }
        if ($it.Type -ne 'apk') { Write-Log "   [CANH BAO] $($it.File) khong phai APK hop le (loai: $($it.Type)) - se bo qua khi cai." 'WARN' }
    }
    if ($err -gt 0) {
        Write-Log '>> [LOI] Thieu file cai dat. Neu dang noi WiFi loa (khong co Internet):' 'ERR'
        Write-Log '   1. Chuyen ve WiFi nha, chay muc [11] "Tai truoc" de luu file vao may.' 'WARN'
        Write-Log '   2. Sau do ket noi WiFi loa va cai dat (file da co trong cache).' 'WARN'
        return $null
    }
    return $map
}

function Invoke-Prefetch {
    $m = Get-Manifest; if (-not $m) { return $false }
    $files = Get-RequiredFiles $m
    if (-not $files) { return $false }
    Write-Log ">> [OK] Tat ca file da san sang trong cache: $Script:CacheDir" 'OK'
    return $true
}

# ------------------------------------------------------------------------------
# 4. KET NOI LOA: DANH THUC QUA WEBSOCKET 8080 + ADB 5555, TU THU LAI
# ------------------------------------------------------------------------------
function Send-Revive([string]$TargetIp) {
    if ($Script:DryRun -or -not $TargetIp) { return $false }
    try {
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = [System.Threading.CancellationToken]::None
        $t = $ws.ConnectAsync([Uri]"ws://$($TargetIp):8080", $ct)
        if ($t.Wait(2000) -and $ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $json = '{"type":"shell","type_id":"revive","shell":"' + $Script:CmdRevive + '"}'
            $bytes = [Text.Encoding]::UTF8.GetBytes($json)
            $seg = New-Object System.ArraySegment[byte] -ArgumentList @(, $bytes)
            [void]$ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(2000)
            [void]$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait(1000)
            Write-LogFile "Revive gui toi $TargetIp OK"
            return $true
        }
    } catch { Write-LogFile "Revive loi: $_" }
    return $false
}

function Test-SpeakerReady {
    $s = Invoke-Adb @('-s', $Script:Serial, 'get-state') 10
    if ($s -eq 'device') { return $true }
    $o = Invoke-AdbShell 'echo 1' 10
    return ($o -eq '1')
}

function Show-ConnectHint([string]$TargetIp) {
    if ($TargetIp -eq $Script:ApIp) {
        Write-Host '------------------ HUONG DAN KET NOI WIFI LOA (AP) ------------------' -ForegroundColor Yellow
        Write-Host ' 1. An giu nut tron tren dinh loa ~6 giay den khi keu bip & den doi mau.'
        Write-Host ' 2. Tren may tinh chon WiFi: Phicomm_R1_xxxx'
        Write-Host " 3. Windows bao 'No Internet' -> van giu ket noi."
        Write-Host '---------------------------------------------------------------------' -ForegroundColor Yellow
    } else {
        Write-Log ">> Dam bao may tinh dang cung mang WiFi voi loa ($TargetIp)." 'WARN'
    }
}

function Connect-Speaker([string]$TargetIp, [int]$TimeoutSec = 0) {
    if ($TimeoutSec -le 0) { $TimeoutSec = $Script:ConnectTimeout }
    $TargetIp = ConvertTo-Ip $TargetIp
    if (-not $TargetIp) { Write-Log '>> [LOI] Dia chi IP khong hop le.' 'ERR'; return $false }
    if (-not (Initialize-Adb)) { return $false }
    $Script:TargetIp = $TargetIp
    $Script:Serial = "$($TargetIp):5555"

    Write-Title "KET NOI DEN LOA R1 ($($Script:Serial))"
    Show-ConnectHint $TargetIp
    Start-AdbServer
    Write-Log ">> Dang danh thuc loa tai $TargetIp (cong 8080)..." 'STEP'
    Send-Revive $TargetIp | Out-Null
    Start-Sleep -Milliseconds 600

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $try = 0
    while ($true) {
        $try++
        $res = Invoke-Adb @('connect', $Script:Serial) 15
        if (Test-SpeakerReady) {
            Write-Host ''
            Write-Log ">> [KET NOI THANH CONG] $($Script:Serial)" 'OK'
            return $true
        }
        Write-Host -NoNewline ("`r[*] Dang ket noi {0} (lan {1}, {2}s/{3}s)...   " -f $Script:Serial, $try, [int]$sw.Elapsed.TotalSeconds, $TimeoutSec)
        if ($res -match 'already connected|offline|R1_TIMEOUT' -or ($try % 3 -eq 0)) {
            Invoke-Adb @('disconnect', $Script:Serial) 10 | Out-Null
            Send-Revive $TargetIp | Out-Null
            Start-Sleep -Milliseconds 600
        }
        if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
            Write-Host ''
            if (-not $Script:Interactive) { Write-Log ">> [LOI] Het $TimeoutSec giay ma khong ket noi duoc $($Script:Serial)." 'ERR'; return $false }
            $ans = Read-Host ">> Chua ket noi duoc $TargetIp. [Enter]=cho tiep, nhap IP moi, hoac 'q' de huy"
            if ($ans -and $ans.Trim().ToLower() -eq 'q') { return $false }
            $newIp = ConvertTo-Ip $ans
            if ($newIp) {
                $TargetIp = $newIp; $Script:TargetIp = $newIp; $Script:Serial = "$($newIp):5555"
                Write-Log ">> Doi muc tieu sang $($Script:Serial)" 'STEP'
                Send-Revive $TargetIp | Out-Null
            }
            $sw.Restart(); $try = 0
        }
        Start-Sleep -Milliseconds 1000
    }
}

function Confirm-Connected {
    if (Test-SpeakerReady) { return $true }
    Write-Log '   [!] Mat ket noi voi loa - dang ket noi lai...' 'WARN'
    $saved = $Script:Interactive; $Script:Interactive = $false
    try { return (Connect-Speaker $Script:TargetIp 60) } finally { $Script:Interactive = $saved }
}

# ------------------------------------------------------------------------------
# 5. THONG TIN THIET BI, PHIEN BAN, SUC KHOE
# ------------------------------------------------------------------------------
function Get-DeviceInfo {
    $o = Invoke-AdbShell 'echo MODEL=$(getprop ro.product.model); echo ANDROID=$(getprop ro.build.version.release); echo SERIAL=$(getprop ro.serialno); echo WIFIIP=$(getprop dhcp.wlan0.ipaddress); echo MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null); echo UID=$(id)'
    $h = @{ MODEL = ''; ANDROID = ''; SERIAL = ''; WIFIIP = ''; MAC = ''; UID = '' }
    foreach ($line in ($o -split "`n")) {
        if ($line -match '^([A-Z]+)=(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() }
    }
    $id = $h.SERIAL; if (-not $id) { $id = $h.MAC }; if (-not $id) { $id = $Script:TargetIp }
    $h.DevId = ($id -replace '[^A-Za-z0-9_.-]', '_')
    return $h
}

function Get-RemotePath([string]$Pkg) {
    $o = Invoke-AdbShell "pm path $Pkg" 30
    if ($o -match 'package:(\S+)') { return $Matches[1] }
    return ''
}

function Get-RemoteVersionCode([string]$Pkg) {
    if (-not (Get-RemotePath $Pkg)) { return -1 }
    $o = Invoke-AdbShell "dumpsys package $Pkg" 30
    if ($o -match 'versionCode=(\d+)') { return [int]$Matches[1] }
    return 0
}

function Show-DeviceInfo {
    $i = Get-DeviceInfo
    Write-Log ("   Model: {0} | Android: {1} | Serial: {2}" -f $i.MODEL, $i.ANDROID, $i.SERIAL) 'HI'
    Write-Log ("   MAC: {0} | IP WiFi nha: {1} | Quyen: {2}" -f $i.MAC, $i.WIFIIP, ($i.UID -split ' ')[0]) 'HI'
    return $i
}

function Test-Health {
    Write-Title 'KIEM TRA SUC KHOE LOA'
    Start-Sleep -Seconds 2
    $ps = Invoke-AdbShell 'ps' 30
    $disabled = Invoke-AdbShell 'pm list packages -d' 30
    $ok = $true
    foreach ($p in $Script:CorePkgs) {
        $path = Get-RemotePath $p
        $state = 'CHUA CAI'; $lvl = 'WARN'
        if ($path) {
            $state = 'Da cai'; $lvl = 'OK'
            if ($disabled -match [regex]::Escape("package:$p")) { $state += ' | BI TAT'; $lvl = 'WARN' }
            if ($ps -match [regex]::Escape($p)) { $state += ' | dang chay' } else { $state += ' | khong chay' }
        }
        if ($p -eq $Script:PkgAiBox -and (-not $path)) { $ok = $false; $lvl = 'ERR' }
        Write-Log ("   {0,-32} {1}" -f $p, $state) $lvl
    }
    $vc = Get-RemoteVersionCode $Script:PkgAiBox
    Write-Log "   AI Box Plus versionCode tren loa: $vc" 'HI'
    if (Test-TcpPort $Script:TargetIp 8081 1500) { Write-Log "   Web Control: http://$($Script:TargetIp):8081/ [MO]" 'OK' }
    else { Write-Log "   Web Control: http://$($Script:TargetIp):8081/ [chua phan hoi - co the can vai giay]" 'WARN' }
    return $ok
}

# ------------------------------------------------------------------------------
# 6. CAI DAT APK AN TOAN (KIEM TRA KICH THUOC, THU LAI KHI MAT KET NOI)
# ------------------------------------------------------------------------------
function Install-ApkFile([string]$LocalPath, [string]$Pkg, [string]$Desc, [long]$Size = 0) {
    if ($Size -le 0 -and (Test-Path $LocalPath)) { $Size = (Get-Item $LocalPath).Length }
    $remote = $Script:RemoteTmp
    for ($a = 1; $a -le 3; $a++) {
        if (-not (Confirm-Connected)) { break }
        Write-Log ("   -> [{0}/3] Chuyen {1} sang loa ({2:N1} MB)..." -f $a, $Desc, ($Size / 1MB))
        Invoke-Adb @('-s', $Script:Serial, 'push', $LocalPath, $remote) 900 | Out-Null
        $ls = Invoke-AdbShell "ls -l $remote" 20
        if (-not $Script:DryRun -and $ls -notmatch ('\s' + $Size + '\s')) {
            Write-Log '   [!] File tren loa chua du dung luong (mat ket noi?) - thu lai...' 'WARN'
            Start-Sleep -Seconds 2
            continue
        }
        Write-Log '   -> Dang cai dat (pm install)...'
        $out = Invoke-AdbShell "pm install -r $remote" 600
        if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match|INSTALL_FAILED_SHARED_USER_INCOMPATIBLE') {
            Write-Log '   [!] Khac chu ky ban cu -> go ban cu roi cai lai...' 'WARN'
            Invoke-AdbShell "pm uninstall $Pkg" 120 | Out-Null
            $out = Invoke-AdbShell "pm install $remote" 600
        } elseif ($out -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
            Write-Log '   [!] Ban tren loa moi hon -> cai de (downgrade)...' 'WARN'
            $out = Invoke-AdbShell "pm install -r -d $remote" 600
        }
        if ($out -match 'Success') {
            Invoke-AdbShell "rm -f $remote" 20 | Out-Null
            Write-Log "   [THANH CONG] Da cai $Desc." 'OK'
            return 'OK'
        }
        if (-not $out -or $out -match 'R1_TIMEOUT|R1_ERROR|closed|offline|no devices|not found|protocol fault|Broken pipe') {
            Write-Log '   [!] Mat ket noi trong luc cai - se ket noi lai va thu tiep...' 'WARN'
            Start-Sleep -Seconds 2
            continue
        }
        Write-Log "   [LOI] $out" 'ERR'
        break
    }
    Invoke-AdbShell "rm -f $remote; pm unhide $Pkg 2>/dev/null; pm enable $Pkg 2>/dev/null" 30 | Out-Null
    Write-Log "   [THAT BAI] Khong cai duoc $Desc (xem log: $($Script:LogFile))" 'ERR'
    return 'FAIL'
}

function Install-ManifestItem($Item, [string]$LocalPath) {
    if ($Item.Type -ne 'apk') {
        Write-Log "   [BO QUA] $($Item.File) khong phai APK hop le (loai '$($Item.Type)'). Can thay bang APK day du tren GitHub." 'WARN'
        return 'SKIP'
    }
    return (Install-ApkFile $LocalPath $Item.Package $Item.Desc $Item.Size)
}

# ------------------------------------------------------------------------------
# 7. SAO LUU / KHOI PHUC
# ------------------------------------------------------------------------------
function Get-Backups([string]$DevId = '') {
    $root = $Script:BackupRoot
    if ($DevId) { $root = Join-Path $root $DevId }
    if (-not (Test-Path $root)) { return , @() }
    $list = @(Get-ChildItem -Path $root -Recurse -Filter 'backup.txt' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Directory } | Sort-Object Name -Descending)
    return , $list
}

function Backup-Speaker([string]$Tag = 'manual') {
    Write-Title 'SAO LUU TRANG THAI LOA (BACKUP)'
    $info = Get-DeviceInfo
    $dir = Join-Path (Join-Path $Script:BackupRoot $info.DevId) ((Get-Date -Format 'yyyyMMdd-HHmmss') + "_$Tag")
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'apk') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'data') | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    Write-Log '>> Luu thong tin he thong, danh sach goi va trang thai...' 'STEP'
    [IO.File]::WriteAllText((Join-Path $dir 'getprop.txt'), (Invoke-AdbShell 'getprop' 30), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'packages_all.txt'), (Invoke-AdbShell 'pm list packages -f' 60), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'packages_u.txt'), (Invoke-AdbShell 'pm list packages -u' 60), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'packages_disabled.txt'), (Invoke-AdbShell 'pm list packages -d' 60), $utf8)

    Write-Log '>> Sao luu file APK cua cac goi lien quan...' 'STEP'
    $paths = @()
    foreach ($p in $Script:ManagedPkgs) {
        $rp = Get-RemotePath $p
        if (-not $rp) { continue }
        $paths += "$p|$rp"
        $r = Invoke-Adb @('-s', $Script:Serial, 'pull', $rp, (Join-Path $dir "apk\$p.apk")) 600
        Write-Log ("   {0,-36} {1}" -f $p, $rp)
        Write-LogFile $r
    }
    [IO.File]::WriteAllText((Join-Path $dir 'apk_paths.txt'), ($paths -join "`n"), $utf8)

    Write-Log '>> Sao luu cau hinh AI Box Plus (shared_prefs)...' 'STEP'
    $owner = Invoke-AdbShell "ls -ld /data/data/$($Script:PkgAiBox)" 20
    if ($owner -match $Script:PkgAiBox) {
        Invoke-Adb @('-s', $Script:Serial, 'pull', "/data/data/$($Script:PkgAiBox)/shared_prefs", (Join-Path $dir 'data')) 120 | Out-Null
        $n = @(Get-ChildItem (Join-Path $dir 'data') -Recurse -Filter *.xml -ErrorAction SilentlyContinue).Count
        if ($n -gt 0) { Write-Log "   [OK] Da luu $n file cau hinh." 'OK' } else { Write-Log '   [!] Khong doc duoc cau hinh (thieu quyen root?) - bo qua.' 'WARN' }
    } else { Write-Log '   (AI Box Plus chua cai - khong co cau hinh de luu)' }

    $vc = Get-RemoteVersionCode $Script:PkgAiBox
    $meta = @(
        "installer=$($Script:InstallerVersion)", "date=$(Get-Date -Format s)", "tag=$Tag", "ip=$($Script:TargetIp)",
        "model=$($info.MODEL)", "android=$($info.ANDROID)", "serial=$($info.SERIAL)", "mac=$($info.MAC)", "aibox_version=$vc"
    )
    [IO.File]::WriteAllText((Join-Path $dir 'backup.txt'), ($meta -join "`n"), $utf8)
    Write-Log ">> [OK] Da sao luu tai: $dir" 'OK'
    return $dir
}

function Read-PkgList([string]$Path) {
    $set = @{}
    if (-not (Test-Path $Path)) { return $set }
    foreach ($l in (Get-Content $Path)) {
        $t = $l.Trim()
        if ($t -match '^package:(.+)=([^=]+)$') { $set[$Matches[2]] = $Matches[1] }
        elseif ($t -match '^package:(\S+)$') { $set[$Matches[1]] = '' }
    }
    return $set
}

function Select-Backup([string]$DevId) {
    $list = Get-Backups $DevId
    if ($list.Count -eq 0 -and $DevId) { $list = Get-Backups '' }
    if ($list.Count -eq 0) { Write-Log '>> Chua co ban sao luu nao.' 'WARN'; return $null }
    Write-Host ''
    for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("  [{0}] {1}\{2}" -f ($i + 1), $list[$i].Parent.Name, $list[$i].Name) }
    $sel = Read-Input "Chon ban sao luu (1-$($list.Count), mac dinh 1 = moi nhat)" '1'
    $n = 0; if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $list.Count) { $n = 1 }
    return $list[$n - 1].FullName
}

function Restore-Speaker([string]$Dir = '') {
    Write-Title 'KHOI PHUC TU BAN SAO LUU (RESTORE)'
    if (-not $Dir) { $info = Get-DeviceInfo; $Dir = Select-Backup $info.DevId }
    if (-not $Dir -or -not (Test-Path (Join-Path $Dir 'backup.txt'))) { Write-Log '>> [LOI] Ban sao luu khong hop le.' 'ERR'; return $false }
    Write-Log ">> Dung ban sao luu: $Dir" 'STEP'
    if (-not (Confirm-Action 'Khoi phuc se thay the ung dung & trang thai hien tai. Tiep tuc?' $true)) { return $false }

    $bk = @{}
    $pf = Join-Path $Dir 'apk_paths.txt'
    if (Test-Path $pf) { foreach ($l in (Get-Content $pf)) { $f = $l.Split('|'); if ($f.Count -ge 2) { $bk[$f[0]] = $f[1] } } }
    $all = Read-PkgList (Join-Path $Dir 'packages_all.txt')
    $u = Read-PkgList (Join-Path $Dir 'packages_u.txt')
    $dis = Read-PkgList (Join-Path $Dir 'packages_disabled.txt')

    Write-Log '>> [1/3] Khoi phuc ung dung...' 'STEP'
    foreach ($p in $Script:ManagedPkgs) {
        $cur = Get-RemotePath $p
        if ($bk.ContainsKey($p)) {
            $bp = $bk[$p]
            if ($bp -like '/system/*') {
                if ($cur -and $cur -notlike '/system/*') {
                    Write-Log "   $p : go ban cap nhat -> tra ve ban goc trong /system"
                    Invoke-AdbShell "pm uninstall $p" 120 | Out-Null
                }
            } else {
                $apk = Join-Path $Dir "apk\$p.apk"
                if ((Test-Path $apk) -and (Get-Item $apk).Length -gt 1000) {
                    Write-Log "   $p : cai lai ban da sao luu"
                    Install-ApkFile $apk $p $p | Out-Null
                }
            }
        } elseif ($cur -and $cur -notlike '/system/*') {
            Write-Log "   $p : khong co trong ban sao luu -> go bo"
            Invoke-AdbShell "pm uninstall $p" 120 | Out-Null
        }
    }

    Write-Log '>> [2/3] Khoi phuc trang thai bat/tat/an cua ung dung...' 'STEP'
    $cmds = @()
    foreach ($p in $Script:ManagedPkgs) {
        if (-not $u.ContainsKey($p)) { continue }
        if (-not $all.ContainsKey($p)) { $cmds += "pm hide $p" }
        elseif ($dis.ContainsKey($p)) { $cmds += "pm unhide $p; pm disable $p" }
        else { $cmds += "pm unhide $p; pm enable $p" }
    }
    if ($cmds.Count -gt 0) { Invoke-AdbShell (($cmds -join ' 2>/dev/null; ') + ' 2>/dev/null') 120 | Out-Null }

    Write-Log '>> [3/3] Khoi phuc cau hinh AI Box Plus...' 'STEP'
    $xmls = @(Get-ChildItem (Join-Path $Dir 'data') -Recurse -Filter *.xml -ErrorAction SilentlyContinue)
    $owner = Invoke-AdbShell "ls -ld /data/data/$($Script:PkgAiBox)" 20
    if ($xmls.Count -gt 0 -and $owner -match '^\S+\s+(\S+)\s+(\S+)') {
        $uid = $Matches[1]; $gid = $Matches[2]
        $sp = "/data/data/$($Script:PkgAiBox)/shared_prefs"
        Invoke-AdbShell "am force-stop $($Script:PkgAiBox); mkdir -p $sp" 20 | Out-Null
        foreach ($x in $xmls) { Invoke-Adb @('-s', $Script:Serial, 'push', $x.FullName, "$sp/$($x.Name)") 60 | Out-Null }
        Invoke-AdbShell "chown -R $($uid):$($gid) $sp; chmod 771 $sp; chmod 660 $sp/*" 20 | Out-Null
        Write-Log "   [OK] Da khoi phuc $($xmls.Count) file cau hinh." 'OK'
    } else { Write-Log '   (Khong co cau hinh can khoi phuc)' }

    Write-Log '>> [OK] Khoi phuc xong. Nen khoi dong lai loa.' 'OK'
    if (Confirm-Action 'Khoi dong lai loa ngay?' $false) { Invoke-Adb @('-s', $Script:Serial, 'reboot') 20 | Out-Null }
    return $true
}

# ------------------------------------------------------------------------------
# 8. CAC QUY TRINH CHINH
# ------------------------------------------------------------------------------
function Open-WebPage([string]$Url) {
    if ($Script:IsWin -and $Script:Interactive -and -not $Script:DryRun) { try { Start-Process $Url } catch {} }
}

function Invoke-FullInstall([string]$TargetIp) {
    Write-Title 'CAI DAT DAY DU PHICOMM R1'
    $m = Get-Manifest; if (-not $m) { return $false }
    $files = Get-RequiredFiles $m
    if (-not $files) { return $false }
    if (-not (Connect-Speaker $TargetIp)) { return $false }
    $info = Show-DeviceInfo

    if (-not $NoBackup -and $env:R1_NO_BACKUP -ne '1') {
        $existing = Get-Backups $info.DevId
        if ($existing.Count -eq 0) {
            Write-Log '>> [AN TOAN] Loa nay chua co ban sao luu - tu dong sao luu trang thai goc truoc khi cai...' 'STEP'
            Backup-Speaker 'goc' | Out-Null
        } else { Write-Log ">> [AN TOAN] Da co $($existing.Count) ban sao luu cho loa nay (giu nguyen ban goc)." 'OK' }
    }

    $total = $m.Count + 2
    $step = 1
    Write-Log ">> [$step/$total] Tat tien trinh chiem quyen, xung dot am thanh & micro..." 'STEP'
    Invoke-AdbShell $Script:CmdClean 120 | Out-Null
    Write-Log '   [OK] Da giai phong am thanh, micro va cong mang.' 'OK'

    $results = @()
    foreach ($it in $m) {
        $step++
        Write-Log ">> [$step/$total] $($it.Desc)..." 'STEP'
        $r = Install-ManifestItem $it $files[$it.Id]
        $results += [pscustomobject]@{ Goi = $it.Desc; KetQua = $r }
    }

    $step++
    Write-Log ">> [$step/$total] Mo khoa & khoi chay dich vu..." 'STEP'
    Invoke-AdbShell $Script:CmdStart 120 | Out-Null
    $healthy = Test-Health

    Write-Title 'KET QUA CAI DAT'
    foreach ($r in $results) {
        $lvl = 'OK'; if ($r.KetQua -eq 'SKIP') { $lvl = 'WARN' } elseif ($r.KetQua -ne 'OK') { $lvl = 'ERR' }
        Write-Log ("   {0,-42} {1}" -f $r.Goi, $r.KetQua) $lvl
    }
    $failed = @($results | Where-Object { $_.KetQua -eq 'FAIL' }).Count
    if ($failed -eq 0 -and $healthy) { Write-Log '>> [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!' 'OK' }
    else { Write-Log '>> [CHUA HOAN TAT] Co loi - thu muc [7] Sua loi (Repair) hoac xem log.' 'ERR' }
    Write-Log "   Log: $($Script:LogFile)"

    if ($TargetIp -eq $Script:ApIp) {
        Write-Log '>>> CAU HINH WIFI NHA CHO LOA: mo http://192.168.43.1:8081/wifi.html, chon WiFi va nhap mat khau.' 'HI'
        Open-WebPage 'http://192.168.43.1:8081/wifi.html'
    } else {
        Write-Log ">>> Giao dien dieu khien: http://$($Script:TargetIp):8081/" 'HI'
        Open-WebPage "http://$($Script:TargetIp):8081/"
    }
    return ($failed -eq 0 -and $healthy)
}

function Invoke-Update([string]$TargetIp) {
    Write-Title 'CAP NHAT AI BOX PLUS (GIU NGUYEN CAU HINH)'
    $m = Get-Manifest; if (-not $m) { return $false }
    $item = $m | Where-Object { $_.Package -eq $Script:PkgAiBox } | Select-Object -First 1
    if (-not $item) { Write-Log '>> [LOI] Manifest khong co goi AI Box Plus.' 'ERR'; return $false }
    $files = Get-RequiredFiles @($item)
    if (-not $files) { return $false }
    if (-not (Connect-Speaker $TargetIp)) { return $false }

    $cur = Get-RemoteVersionCode $Script:PkgAiBox
    Write-Log ">> Phien ban tren loa: $cur | Phien ban tren GitHub: $($item.VersionCode)" 'HI'
    if ($cur -gt 0 -and $item.VersionCode -gt 0 -and $cur -ge $item.VersionCode) {
        if (-not (Confirm-Action 'Loa da co ban moi nhat. Van cai lai?' $false)) { return $true }
    }
    Write-Log '>> [1/3] Dung tien trinh cu & chan app xung dot...' 'STEP'
    Invoke-AdbShell ('am force-stop info.dourok.voicebot 2>/dev/null; for p in ' + ($Script:ConflictPkgs -join ' ') + '; do pm hide $p 2>/dev/null; pm disable $p 2>/dev/null; done; rm -rf /data/local/tmp/* 2>/dev/null') 60 | Out-Null
    Write-Log '>> [2/3] Cai dat ban moi...' 'STEP'
    $r = Install-ManifestItem $item $files[$item.Id]
    Write-Log '>> [3/3] Khoi chay AI Box Plus...' 'STEP'
    Invoke-AdbShell $Script:CmdStartAiBox 60 | Out-Null
    $after = Get-RemoteVersionCode $Script:PkgAiBox
    if ($r -eq 'OK') { Write-Log ">> [HOAN TAT] Cap nhat thanh cong (versionCode $cur -> $after). Cau hinh cu duoc giu nguyen." 'OK' }
    else { Write-Log '>> [THAT BAI] Cap nhat khong thanh cong.' 'ERR' }
    Write-Log ">>> Giao dien dieu khien: http://$($Script:TargetIp):8081/" 'HI'
    return ($r -eq 'OK')
}

function Invoke-Repair([string]$TargetIp) {
    Write-Title 'SUA LOI (REPAIR)'
    $m = Get-Manifest
    if (-not (Connect-Speaker $TargetIp)) { return $false }
    Show-DeviceInfo | Out-Null
    Write-Log '>> [1/4] Don file tam, chan app xung dot, bat cai dat ngoai...' 'STEP'
    Invoke-AdbShell $Script:CmdClean 120 | Out-Null

    Write-Log '>> [2/4] Kiem tra AI Box Plus...' 'STEP'
    $res = 'OK'
    if ($m) {
        $item = $m | Where-Object { $_.Package -eq $Script:PkgAiBox } | Select-Object -First 1
        $cur = Get-RemoteVersionCode $Script:PkgAiBox
        if ($item -and ($cur -lt 0 -or ($item.VersionCode -gt 0 -and $cur -lt $item.VersionCode))) {
            Write-Log "   AI Box Plus thieu hoac cu (versionCode $cur) -> cai lai." 'WARN'
            $files = Get-RequiredFiles @($item)
            if ($files) { $res = Install-ManifestItem $item $files[$item.Id] } else { $res = 'FAIL' }
        } else { Write-Log "   [OK] AI Box Plus da cai (versionCode $cur)." 'OK' }
    } else { Write-Log '   [!] Khong co manifest - bo qua buoc cai lai.' 'WARN' }

    Write-Log '>> [3/4] Mo khoa & khoi dong lai dich vu...' 'STEP'
    Invoke-AdbShell $Script:CmdStart 120 | Out-Null
    Write-Log '>> [4/4] Kiem tra lai...' 'STEP'
    $ok = Test-Health
    if ($ok -and $res -ne 'FAIL') { Write-Log '>> [OK] Sua loi hoan tat.' 'OK' } else { Write-Log '>> [!] Van con loi - thu Restore hoac cai lai day du.' 'ERR' }
    if (Confirm-Action 'Khoi dong lai loa de ap dung?' $false) { Invoke-Adb @('-s', $Script:Serial, 'reboot') 20 | Out-Null }
    return ($ok -and $res -ne 'FAIL')
}

function Invoke-Uninstall([string]$TargetIp) {
    Write-Title 'GO CAI DAT / TRA LOA VE TRANG THAI GOC'
    if (-not (Connect-Speaker $TargetIp)) { return $false }
    $info = Show-DeviceInfo
    if (-not (Confirm-Action 'Go AI Box Plus va mo lai cac ung dung goc Phicomm?' $false)) { return $false }

    $bks = Get-Backups $info.DevId
    if ($bks.Count -gt 0) {
        $oldest = $bks[$bks.Count - 1].FullName
        if (Confirm-Action "Co ban sao luu goc ($oldest). Khoi phuc tu ban nay (khuyen dung)?" $true) {
            Invoke-AdbShell "am force-stop $($Script:PkgAiBox); pm uninstall $($Script:PkgAiBox)" 120 | Out-Null
            return (Restore-Speaker $oldest)
        }
    }
    Write-Log '>> [1/3] Go AI Box Plus...' 'STEP'
    $o = Invoke-AdbShell "am force-stop $($Script:PkgAiBox); pm uninstall $($Script:PkgAiBox)" 120
    Write-Log "   $o"
    Write-Log '>> [2/3] Tra ung dung he thong ve ban goc (go ban cap nhat)...' 'STEP'
    foreach ($p in @('com.phicomm.speaker.player', 'com.phicomm.speaker.device')) {
        $cur = Get-RemotePath $p
        if ($cur -and $cur -notlike '/system/*') { Invoke-AdbShell "pm uninstall $p" 120 | Out-Null; Write-Log "   $p -> ban goc" }
    }
    Write-Log '>> [3/3] Mo lai ung dung goc Phicomm, tat che do luon thuc...' 'STEP'
    Invoke-AdbShell $Script:CmdUnhideStock 120 | Out-Null
    Write-Log '>> [OK] Da go cai dat.' 'OK'
    if (Confirm-Action 'Khoi dong lai loa ngay?' $true) { Invoke-Adb @('-s', $Script:Serial, 'reboot') 20 | Out-Null }
    return $true
}

function Invoke-Info([string]$TargetIp) {
    if (-not (Connect-Speaker $TargetIp)) { return $false }
    Write-Title 'THONG TIN LOA'
    Show-DeviceInfo | Out-Null
    return (Test-Health)
}

# ------------------------------------------------------------------------------
# 9. QUET MANG & NHIEU LOA
# ------------------------------------------------------------------------------
function Get-LocalSubnet {
    try {
        $nics = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' }
        foreach ($n in $nics) {
            $props = $n.GetIPProperties()
            $hasGw = @($props.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.ToString() -ne '0.0.0.0' }).Count -gt 0
            if (-not $hasGw) { continue }
            foreach ($a in $props.UnicastAddresses) {
                if ($a.Address.AddressFamily -eq 'InterNetwork') {
                    $s = $a.Address.ToString()
                    if ($s -notlike '127.*' -and $s -notlike '169.254.*') { $p = $s.Split('.'); return "$($p[0]).$($p[1]).$($p[2])" }
                }
            }
        }
    } catch {}
    return '192.168.1'
}

function Find-Speakers([string]$Prefix = '') {
    if (-not $Prefix) {
        $cur = Get-LocalSubnet
        $Prefix = Read-Input "Dai mang can quet [mac dinh $cur]" $cur
    }
    $parts = $Prefix.Trim().Split('.')
    if ($parts.Count -ge 3) { $Prefix = "$($parts[0]).$($parts[1]).$($parts[2])" }
    Write-Log ">> Dang quet $Prefix.1-254 (cong 8080 & 5555)..." 'STEP'
    $found = New-Object System.Collections.Generic.List[string]
    if ($Script:DryRun) { $found.Add("$Prefix.94"); Write-Log "   [+] (gia lap) $Prefix.94" 'OK'; return , $found.ToArray() }
    $batch = 64
    for ($start = 1; $start -le 254; $start += $batch) {
        $end = [Math]::Min(254, $start + $batch - 1)
        $tasks = @()
        foreach ($i in $start..$end) {
            foreach ($port in @(8080, 5555)) {
                $c = New-Object System.Net.Sockets.TcpClient
                try { $tasks += [pscustomobject]@{ Ip = "$Prefix.$i"; C = $c; R = $c.BeginConnect("$Prefix.$i", $port, $null, $null) } } catch { $c.Close() }
            }
        }
        Start-Sleep -Milliseconds 500
        foreach ($t in $tasks) {
            try { if ($t.C.Connected -and -not $found.Contains($t.Ip)) { $found.Add($t.Ip); Write-Host ''; Write-Log "   [+] Phat hien loa R1 tai: $($t.Ip)" 'OK' } } catch {}
            finally { $t.C.Close() }
        }
        Write-Host -NoNewline "`r[*] Tien do: $end/254"
    }
    Write-Host ''
    if ($found.Count -eq 0) { Write-Log ">> Khong tim thay loa trong $Prefix.x" 'WARN' }
    return , $found.ToArray()
}

function Select-SpeakerIp([string]$Default = '') {
    Write-Host ''
    Write-Host 'Nhap IP loa (VD 192.168.1.94). De trong + Enter de tu dong quet.' -ForegroundColor Yellow
    $v = ConvertTo-Ip (Read-Input 'IP loa' '')
    if ($v) { return $v }
    $list = Find-Speakers $Subnet
    if ($list.Count -eq 0) { return (ConvertTo-Ip (Read-Input 'Nhap IP loa thu cong' $Default)) }
    for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $list[$i]) }
    $s = Read-Input 'Chon loa (so thu tu hoac IP, mac dinh 1)' '1'
    $n = 0
    if ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $list.Count) { return $list[$n - 1] }
    return (ConvertTo-Ip $s)
}

function Invoke-Multi([string[]]$List, [string]$RunMode) {
    Write-Title 'CAI DAT CHO NHIEU LOA'
    $ipsAll = @()
    foreach ($x in $List) { foreach ($y in ($x -split '[,;\s]+')) { $v = ConvertTo-Ip $y; if ($v) { $ipsAll += $v } } }
    if ($ipsAll.Count -eq 0 -and $Script:Interactive) {
        $raw = Read-Input 'Nhap danh sach IP (cach nhau dau phay). Enter = quet mang' ''
        foreach ($y in ($raw -split '[,;\s]+')) { $v = ConvertTo-Ip $y; if ($v) { $ipsAll += $v } }
        if ($ipsAll.Count -eq 0) {
            $ipsAll = @(Find-Speakers $Subnet)
            if ($ipsAll.Count -gt 0 -and -not (Confirm-Action "Cai cho ca $($ipsAll.Count) loa vua tim thay?" $true)) { return $false }
        }
    }
    $ipsAll = @($ipsAll | Select-Object -Unique)
    if ($ipsAll.Count -eq 0) { Write-Log '>> Khong co IP nao.' 'ERR'; return $false }
    if ($ipsAll -contains $Script:ApIp) { Write-Log ">> [!] $($Script:ApIp) la IP WiFi phat cua loa - che do nhieu loa chi dung qua WiFi nha." 'WARN' }
    if (-not $RunMode) {
        Write-Host '  [1] Cai day du   [2] Chi cap nhat AI Box   [3] Sua loi'
        switch (Read-Input 'Chon che do (mac dinh 1)' '1') { '2' { $RunMode = 'update' } '3' { $RunMode = 'repair' } default { $RunMode = 'full' } }
    }
    # Tai & xac minh file mot lan truoc khi cai cho tung loa
    if ($RunMode -ne 'repair' -and -not (Invoke-Prefetch)) { return $false }

    $saved = $Script:Interactive; $savedYes = $Script:AssumeYes
    $Script:Interactive = $false
    $rows = @()
    $idx = 0
    foreach ($t in $ipsAll) {
        $idx++
        Write-Title "LOA $idx/$($ipsAll.Count): $t"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $ok = $false
        try {
            switch ($RunMode) {
                'update' { $ok = Invoke-Update $t }
                'repair' { $ok = Invoke-Repair $t }
                default { $ok = Invoke-FullInstall $t }
            }
        } catch { Write-Log "   [LOI] $_" 'ERR'; $ok = $false }
        Invoke-Adb @('disconnect', "$($t):5555") 10 | Out-Null
        $kq = 'THAT BAI'; if ($ok) { $kq = 'THANH CONG' }
        $rows += [pscustomobject]@{ IP = $t; CheDo = $RunMode; KetQua = $kq; ThoiGian = ('{0:N0}s' -f $sw.Elapsed.TotalSeconds) }
    }
    $Script:Interactive = $saved; $Script:AssumeYes = $savedYes
    Write-Title 'TONG KET NHIEU LOA'
    foreach ($r in $rows) {
        $lvl = 'OK'; if ($r.KetQua -ne 'THANH CONG') { $lvl = 'ERR' }
        Write-Log ("   {0,-16} {1,-8} {2,-11} {3}" -f $r.IP, $r.CheDo, $r.KetQua, $r.ThoiGian) $lvl
    }
    return (@($rows | Where-Object { $_.KetQua -ne 'THANH CONG' }).Count -eq 0)
}

# ------------------------------------------------------------------------------
# 10. MENU & DIEM VAO
# ------------------------------------------------------------------------------
function Show-Banner {
    Write-Host ''
    Write-Host ('=' * 62) -ForegroundColor Cyan
    Write-Host ("   PHICOMM R1 INSTALLER V{0} - WINDOWS" -f $Script:InstallerVersion) -ForegroundColor Yellow
    Write-Host '   Nguon: github.com/vdt34/vdt34.github.io (thu muc r1)' -ForegroundColor Gray
    if ($Script:DryRun) { Write-Host '   *** CHE DO GIA LAP (DRY-RUN) ***' -ForegroundColor Magenta }
    Write-Host ('=' * 62) -ForegroundColor Cyan
}

function Get-TargetForAction([string]$Act) {
    $v = ConvertTo-Ip $Ip
    if ($v) { return $v }
    if (-not $Script:Interactive) {
        if ($Act -eq 'full') { return $Script:ApIp }
        Write-Log '>> [LOI] Can tham so -Ip.' 'ERR'; return ''
    }
    return (Select-SpeakerIp)
}

function Invoke-ActionByName([string]$Act) {
    switch ($Act) {
        'full' { $t = Get-TargetForAction 'full'; if ($t) { return (Invoke-FullInstall $t) } }
        'update' { $t = Get-TargetForAction 'update'; if ($t) { return (Invoke-Update $t) } }
        'repair' { $t = Get-TargetForAction 'repair'; if ($t) { return (Invoke-Repair $t) } }
        'uninstall' { $t = Get-TargetForAction 'uninstall'; if ($t) { return (Invoke-Uninstall $t) } }
        'info' { $t = Get-TargetForAction 'info'; if ($t) { return (Invoke-Info $t) } }
        'backup' { $t = Get-TargetForAction 'backup'; if ($t -and (Connect-Speaker $t)) { return [bool](Backup-Speaker 'manual') } }
        'restore' { $t = Get-TargetForAction 'restore'; if ($t -and (Connect-Speaker $t)) { return (Restore-Speaker $BackupPath) } }
        'scan' { $r = Find-Speakers $Subnet; return ($r.Count -gt 0) }
        'prefetch' { return (Invoke-Prefetch) }
        'verify' { return (Invoke-Prefetch) }
        'multi' { return (Invoke-Multi $Ips $Mode) }
    }
    return $false
}

function Show-Menu {
    while ($true) {
        Show-Banner
        Write-Host '  [1]  Cai moi day du qua WiFi loa phat ra (192.168.43.1) [Khuyen dung]'
        Write-Host '  [2]  Cai moi day du qua WiFi nha (nhap IP / tu quet)'
        Write-Host '  [3]  Cap nhat AI Box Plus moi nhat (giu cau hinh)'
        Write-Host '  [4]  Cai / cap nhat cho NHIEU LOA'
        Write-Host '  [5]  Sao luu (Backup) loa'
        Write-Host '  [6]  Khoi phuc (Restore) tu ban sao luu'
        Write-Host '  [7]  Sua loi (Repair)'
        Write-Host '  [8]  Go cai dat / tra ve goc (Uninstall)'
        Write-Host '  [9]  Quet tim loa trong mang'
        Write-Host '  [10] Thong tin & kiem tra suc khoe loa'
        Write-Host '  [11] Tai truoc & kiem tra checksum (khong can loa)'
        Write-Host '  [0]  Thoat'
        Write-Host ('=' * 62) -ForegroundColor Cyan
        $c = Read-Host 'Lua chon (mac dinh 1)'
        if (-not $c -or -not $c.Trim()) { $c = '1' }
        $script:Ip = ''
        switch ($c.Trim()) {
            '1' { $script:Ip = $Script:ApIp; Invoke-ActionByName 'full' | Out-Null }
            '2' { Invoke-ActionByName 'full' | Out-Null }
            '3' { Invoke-ActionByName 'update' | Out-Null }
            '4' { Invoke-Multi @() '' | Out-Null }
            '5' { Invoke-ActionByName 'backup' | Out-Null }
            '6' { Invoke-ActionByName 'restore' | Out-Null }
            '7' { Invoke-ActionByName 'repair' | Out-Null }
            '8' { Invoke-ActionByName 'uninstall' | Out-Null }
            '9' { Invoke-ActionByName 'scan' | Out-Null }
            '10' { Invoke-ActionByName 'info' | Out-Null }
            '11' { Invoke-Prefetch | Out-Null }
            '0' { Write-Host 'Tam biet!' -ForegroundColor Cyan; return }
            default { Write-Log 'Lua chon khong hop le.' 'WARN' }
        }
        Wait-Enter
    }
}

Write-LogFile "=== R1 Installer $($Script:InstallerVersion) | Action=$Action | DryRun=$($Script:DryRun) | PS $($PSVersionTable.PSVersion) ==="
if ($Action -eq 'menu') {
    Show-Menu
} else {
    Show-Banner
    $ok = [bool](Invoke-ActionByName $Action)
    Write-Log ">> Ket thuc: $Action -> $(if ($ok) { 'OK' } else { 'LOI' }) | Log: $($Script:LogFile)"
    if ($ok) { exit 0 } else { exit 1 }
}
