<#
.SYNOPSIS
    Sinh manifest.txt va SHA256SUMS cho bo cai Phicomm R1 tu packages.conf.

.DESCRIPTION
    - Doc r1/packages.conf
    - Tinh SHA256, kich thuoc, nhan dien loai file (apk / dex / unknown)
    - Lay versionCode bang aapt (neu co Android SDK build-tools)
    - Ghi r1/manifest.txt va r1/SHA256SUMS
    Chay duoc tren Windows PowerShell 5.1 va PowerShell 7 (Linux - GitHub Actions).

.PARAMETER Check
    Chi kiem tra: so sanh manifest hien tai voi ket qua tinh lai, tra ve exit 1 neu lech.

.PARAMETER Strict
    Bao loi (exit 1) neu co goi khong phai APK hop le.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File r1\tools\Build-Manifest.ps1
    pwsh r1/tools/Build-Manifest.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Strict,
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$R1Dir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfPath = Join-Path $R1Dir 'packages.conf'
$ManifestPath = Join-Path $R1Dir 'manifest.txt'
$SumsPath = Join-Path $R1Dir 'SHA256SUMS'
if (-not $Version) { $Version = (Get-Content (Join-Path $R1Dir 'VERSION') -Raw).Trim() }

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

function Find-Aapt {
    $roots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    foreach ($r in $roots) {
        if (-not $r) { continue }
        $bt = Join-Path $r 'build-tools'
        if (-not (Test-Path $bt)) { continue }
        $dirs = Get-ChildItem $bt -Directory | Sort-Object { try { [version]($_.Name -replace '[^0-9.]', '') } catch { [version]'0.0' } } -Descending
        foreach ($d in $dirs) {
            foreach ($n in @('aapt.exe', 'aapt')) {
                $p = Join-Path $d.FullName $n
                if (Test-Path $p) { return $p }
            }
        }
    }
    $c = Get-Command aapt -ErrorAction SilentlyContinue
    if ($c) { return $c.Path }
    return $null
}

function Get-FileKind([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    try {
        $buf = New-Object byte[] 4
        [void]$fs.Read($buf, 0, 4)
    } finally { $fs.Close() }
    if ($buf[0] -eq 0x50 -and $buf[1] -eq 0x4B -and $buf[2] -eq 3 -and $buf[3] -eq 4) {
        try {
            $zip = [IO.Compression.ZipFile]::OpenRead($Path)
            try {
                $hasManifest = $false
                foreach ($e in $zip.Entries) { if ($e.FullName -eq 'AndroidManifest.xml') { $hasManifest = $true; break } }
                if ($hasManifest) { return 'apk' } else { return 'zip' }
            } finally { $zip.Dispose() }
        } catch { return 'zip' }
    }
    if ($buf[0] -eq 0x64 -and $buf[1] -eq 0x65 -and $buf[2] -eq 0x78 -and $buf[3] -eq 0x0A) { return 'dex' }
    return 'unknown'
}

$aapt = Find-Aapt
if ($aapt) { Write-Host "aapt: $aapt" } else { Write-Warning 'Khong tim thay aapt - versionCode se de 0 (khong kiem tra phien ban).' }

$rows = @()
$sums = @()
$problems = @()
foreach ($raw in Get-Content $ConfPath) {
    $l = $raw.Trim()
    if (-not $l -or $l.StartsWith('#')) { continue }
    $f = $l.Split('|')
    if ($f.Count -lt 5) { throw "Dong khong hop le trong packages.conf: $l" }
    $id, $file, $pkg, $order, $desc = $f[0], $f[1], $f[2], $f[3], $f[4]
    $path = Join-Path $R1Dir $file
    if (-not (Test-Path $path)) { throw "Thieu file: $file" }

    $hash = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLower()
    $size = (Get-Item $path).Length
    $kind = Get-FileKind $path
    $vc = 0
    if ($kind -eq 'apk' -and $aapt) {
        $badging = (& $aapt dump badging $path 2>$null | Select-Object -First 1) -join ''
        if ($badging -match "name='([^']+)'") {
            if ($Matches[1] -ne $pkg) { $problems += "$file : package that la '$($Matches[1])' khac voi packages.conf '$pkg'" }
        }
        if ($badging -match "versionCode='(\d+)'") { $vc = [int]$Matches[1] }
    }
    if ($kind -ne 'apk') {
        $problems += "$file : khong phai APK hop le (loai '$kind'). Bo cai se BO QUA goi nay."
    }
    $rows += ('{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}' -f $id, $file, $pkg, $vc, $hash, $size, $kind, $order, $desc)
    $sums += ('{0}  {1}' -f $hash, $file)
}

$header = @(
    '# Phicomm R1 Installer manifest - TU DONG SINH boi tools/Build-Manifest.ps1, khong sua tay',
    "# version=$Version",
    '# id|file|package|versionCode|sha256|size|type|order|desc'
)
$manifest = ($header + $rows) -join "`n"
$sumsText = ($sums -join "`n")

foreach ($p in $problems) {
    if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::warning::$p" } else { Write-Warning $p }
}

if ($Check) {
    $old = ''
    if (Test-Path $ManifestPath) { $old = ((Get-Content $ManifestPath) | Where-Object { $_ -and -not $_.StartsWith('#') }) -join "`n" }
    $new = ($rows -join "`n")
    if ($old.Trim() -ne $new.Trim()) {
        Write-Host '::error::manifest.txt KHONG khop voi file APK hien tai. Hay chay tools/Build-Manifest.ps1 roi commit lai.'
        Write-Host "--- hien tai ---`n$old`n--- dung ---`n$new"
        exit 1
    }
    Write-Host '[OK] manifest.txt khop voi cac file APK.'
} else {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($ManifestPath, $manifest + "`n", $utf8)
    [IO.File]::WriteAllText($SumsPath, $sumsText + "`n", $utf8)
    Write-Host "[OK] Da ghi $ManifestPath"
    Write-Host "[OK] Da ghi $SumsPath"
    $rows | ForEach-Object { Write-Host "   $_" }
}

if ($Strict -and $problems.Count -gt 0) { exit 1 }
exit 0
