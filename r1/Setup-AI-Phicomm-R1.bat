@echo off
rem Bo cai Lily R1 cho loa Phicomm R1 - bam dup tep nay.
rem Tu tai bo cai (install.ps1) va ban moi nhat cua app tu heylily.net/r1/ roi cai vao loa.
rem Neu canh tep nay co install.ps1 thi dung tep do (khong tai bo cai).
title Cai dat AIbox Phicomm R1 vao loa Phicomm R1
setlocal
if not defined LILY_R1_BASE set "LILY_R1_BASE=https://vdt34.github.io/r1"
cd /d "%~dp0"
if exist "%~dp0install.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}; $f = Join-Path $env:TEMP ('lily-r1-' + [guid]::NewGuid().ToString('N') + '.ps1'); try { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri ($env:LILY_R1_BASE + '/install.ps1') -OutFile $f; & $f -ApkBase $env:LILY_R1_BASE } catch { Write-Host ('[LOI] Khong tai duoc bo cai: ' + $_.Exception.Message) -ForegroundColor Red } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }"
)
echo.
pause
