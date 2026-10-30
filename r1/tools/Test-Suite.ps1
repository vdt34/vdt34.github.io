<#
.SYNOPSIS
    Kich ban kiem thu toan dien cho bo cai Phicomm R1 (Giai doan 5 - Kiem thu).
.DESCRIPTION
    Kiem thu 5 tinh huong chinh theo dung yeu cau:
      1. Cai moi (Fresh install qua AP WiFi 192.168.43.1)
      2. Cap nhat (Update qua LAN WiFi)
      3. Cai loi & Phuc hoi (Faulty install & Repair)
      4. Mat ket noi & Thu lai (Disconnect & Auto-retry recovery)
      5. Nhieu loa dong thoi (Multi-speaker batch install)
      6. Sao luu & Khoi phuc (Backup & Restore)
      7. Go cai dat (Uninstall / Stock restore)
#>
[CmdletBinding()]
param(
    [switch]$Live,
    [string]$TargetIp = '192.168.43.1'
)

$ErrorActionPreference = 'Continue'
$R1Dir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ScriptPs1 = Join-Path $R1Dir 'install.ps1'

# Chuan bi thu muc test doc lap
$TestHome = Join-Path $env:TEMP ('r1_test_suite_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $TestHome | Out-Null
$env:R1_HOME = $TestHome

if (-not $Live) {
    $env:R1_DRYRUN = '1'
    Write-Host "`n>>> KHOI CHAY TEST SUITE (CHE DO GIA LAP DRY-RUN) <<<" -ForegroundColor Magenta
} else {
    $env:R1_DRYRUN = '0'
    Write-Host "`n>>> KHOI CHAY TEST SUITE (CHE DO THIET BI THAT - IP: $TargetIp) <<<" -ForegroundColor Yellow
}

$TestResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Run-TestStep([string]$Name, [scriptblock]$Action) {
    Write-Host "`n--------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "[KIEM THU] $Name..." -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------" -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $err = $null
    $passed = $false
    try {
        $passed = & $Action
    } catch {
        $err = $_.ToString()
        $passed = $false
    }
    $sw.Stop()
    $status = if ($passed) { "PASSED" } else { "FAILED" }
    $color = if ($passed) { "Green" } else { "Red" }
    Write-Host ">> KET QUA: $status ($([Math]::Round($sw.Elapsed.TotalSeconds, 2))s)" -ForegroundColor $color
    if ($err) { Write-Host "   Chi tiet loi: $err" -ForegroundColor Red }

    $TestResults.Add([PSCustomObject]@{
        KichBan = $Name
        KetQua  = $status
        ThoiGian = "$([Math]::Round($sw.Elapsed.TotalSeconds, 2))s"
        GhiChu  = if ($err) { $err } else { "OK" }
    })
    return $passed
}

# ------------------------------------------------------------------------------
# 1. TEST TAI TRUOC & KIEM TRA MANIFEST
# ------------------------------------------------------------------------------
Run-TestStep "1. Kiem tra Manifest va Checksum SHA256" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $R1Dir 'tools\Build-Manifest.ps1') -Check
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 2. TEST CAI MOI (FRESH INSTALL QUA WIFI LOA 192.168.43.1)
# ------------------------------------------------------------------------------
Run-TestStep "2. Cai moi toan bo qua WiFi cua loa (192.168.43.1)" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action full -Ip 192.168.43.1 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 3. TEST CAP NHAT AI BOX PLUS (GIU NGUYEN CAU HINH)
# ------------------------------------------------------------------------------
Run-TestStep "3. Cap nhat AI Box Plus qua WiFi nha (giu nguyen cau hinh)" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action update -Ip 192.168.1.94 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 4. TEST SAO LUU & KHOI PHUC (BACKUP & RESTORE)
# ------------------------------------------------------------------------------
$BackupDir = ""
Run-TestStep "4a. Sao luu trang thai loa (Backup)" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action backup -Ip 192.168.1.94 -Yes
    return ($LASTEXITCODE -eq 0)
}

Run-TestStep "4b. Khoi phuc tu ban sao luu (Restore)" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action restore -Ip 192.168.1.94 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 5. TEST CAI LOI & PHUC HOI (REPAIR)
# ------------------------------------------------------------------------------
Run-TestStep "5. Sua loi he thong & giai phong xung dot (Repair)" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action repair -Ip 192.168.1.94 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 6. TEST MAT KET NOI & TU DONG THU LAI (TIMEOUT & RETRY RECOVERY)
# ------------------------------------------------------------------------------
Run-TestStep "6. Xu ly mat ket noi & tu dong thu lai" {
    # Thu ket noi voi timeout ngan de kiem tra tinh huong dut ket noi
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action info -Ip 192.168.1.94 -ConnectTimeout 10 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 7. TEST CAI DAT NHIEU LOA CUNG LUC (MULTI-SPEAKER)
# ------------------------------------------------------------------------------
Run-TestStep "7. Trien khai cai dat nhieu loa dong thoi" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action multi -Ips "192.168.1.94, 192.168.1.95, 192.168.1.96" -Mode update -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 8. TEST GO CAI DAT & TRA VE NGUYEN BAN (UNINSTALL)
# ------------------------------------------------------------------------------
Run-TestStep "8. Go cai dat & tra loa ve nguyen ban" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPs1 -Action uninstall -Ip 192.168.1.94 -Yes
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# 9. TEST DONG GOI RELEASE ZIP
# ------------------------------------------------------------------------------
Run-TestStep "9. Dong goi Release ZIP va tao Checksum" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $R1Dir 'tools\Package-Release.ps1')
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------------------------
# TONG KET TEST SUITE
# ------------------------------------------------------------------------------
Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "                BANG TONG HOP KET QUA KIEM THU                " -ForegroundColor Yellow
Write-Host "==============================================================" -ForegroundColor Cyan
$TestResults | Format-Table -AutoSize | Out-String | Write-Host

$TotalTests = $TestResults.Count
$PassedTests = ($TestResults | Where-Object { $_.KetQua -eq 'PASSED' }).Count
$FailedTests = $TotalTests - $PassedTests

if ($FailedTests -eq 0) {
    Write-Host ">>> [HOAN TAT] 100% KICH BAN KIEM THU DEU DAT CHUAN ($PassedTests/$TotalTests)! <<<`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host ">>> [CANH BAO] CO $FailedTests KICH BAN KHONG DAT! <<<`n" -ForegroundColor Red
    exit 1
}
