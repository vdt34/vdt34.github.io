<#
.SYNOPSIS
    Dong goi ban phat hanh bo cai Phicomm R1 (ZIP + Checksums).
.DESCRIPTION
    - Chay Build-Manifest.ps1 de dong bo manifest.txt & SHA256SUMS.
    - Tao thu muc phat hanh 'dist'.
    - Dong goi cac file can thiet thanh r1-installer-v<VERSION>.zip.
    - Sinh SHA256 cho file ZIP.
#>
[CmdletBinding()]
param(
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$R1Dir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Version = (Get-Content (Join-Path $R1Dir 'VERSION') -Raw).Trim()

Write-Host ">> [1/4] Cap nhat manifest va SHA256..." -ForegroundColor Cyan
& (Join-Path $R1Dir 'tools\Build-Manifest.ps1')

if (-not $OutDir) { $OutDir = Join-Path $R1Dir 'dist' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ZipName = "r1-installer-v$Version.zip"
$ZipPath = Join-Path $OutDir $ZipName
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

$StagingDir = Join-Path $env:TEMP "r1_pkg_$Version"
if (Test-Path $StagingDir) { Remove-Item -Recurse -Force $StagingDir }
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null

Write-Host ">> [2/4] Sao chep file vao staging..." -ForegroundColor Cyan
$FilesToInclude = @(
    'install.cmd',
    'install.ps1',
    'install.sh',
    'manifest.txt',
    'SHA256SUMS',
    'packages.conf',
    'VERSION',
    'README.md'
)

foreach ($f in $FilesToInclude) {
    $src = Join-Path $R1Dir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $StagingDir $f) -Force
    }
}

Write-Host ">> [3/4] Tao file ZIP: $ZipName..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($StagingDir, $ZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Remove-Item -Recurse -Force $StagingDir

$ZipHash = (Get-FileHash -Algorithm SHA256 -Path $ZipPath).Hash.ToLower()
$ZipSize = (Get-Item $ZipPath).Length
$ChecksumFile = Join-Path $OutDir "$ZipName.sha256"
"$ZipHash  $ZipName" | Set-Content -Path $ChecksumFile -Encoding UTF8

Write-Host ">> [4/4] HOAN TAT DONG GOI!" -ForegroundColor Green
Write-Host "   File ZIP : $ZipPath ($([Math]::Round($ZipSize / 1KB, 1)) KB)" -ForegroundColor Yellow
Write-Host "   SHA256   : $ZipHash" -ForegroundColor Yellow
Write-Host "   Checksum : $ChecksumFile" -ForegroundColor Yellow
