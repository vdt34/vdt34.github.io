@echo off
rem Bo cai Lily R1 cho loa Phicomm R1 - bam dup tep nay.
rem Tu tai bo cai (install.ps1) va ban moi nhat cua app tu heylily.net/r1/ roi cai vao loa.
rem Neu canh tep nay co install.ps1 thi dung tep do (khong tai bo cai).
title Cai dat AIbox Phicomm R1 vao loa Phicomm R1
setlocal EnableExtensions
if not defined NABU_R1_BASE set "NABU_R1_BASE=https://vdt34.github.io/r1"
cd /d "%~dp0"

rem =====================================================================
rem ===== TU KIEM TRA VA TU CAI ADB NEU CHUA CO =========================
rem =====================================================================
adb version >nul 2>nul
if errorlevel 1 (
    echo [INFO] Khong tim thay adb.exe ^(hoac adb bi loi^), dang tu dong tai Platform-Tools...
    set "ADB_DIR=%LOCALAPPDATA%\Android\Sdk\platform-tools"

    if not exist "%ADB_DIR%\adb.exe" (
        echo [INFO] Dang tai Platform-Tools tu Google...
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
            "$ProgressPreference='SilentlyContinue';" ^
            "$url='https://dl.google.com/android/repository/platform-tools-latest-windows.zip';" ^
            "$zip=Join-Path $env:TEMP 'platform-tools.zip';" ^
            "$dest=Join-Path $env:LOCALAPPDATA 'Android\Sdk';" ^
            "New-Item -ItemType Directory -Force -Path $dest | Out-Null;" ^
            "try { Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri $url -OutFile $zip } catch { Write-Host ('[LOI] Tai Platform-Tools that bai: '+$_.Exception.Message) -ForegroundColor Red; exit 1 };" ^
            "try { Expand-Archive -Path $zip -DestinationPath $dest -Force -ErrorAction Stop } catch { Write-Host ('[LOI] Giai nen that bai: '+$_.Exception.Message) -ForegroundColor Red; exit 1 };" ^
            "Remove-Item $zip -Force -ErrorAction SilentlyContinue"
        if errorlevel 1 (
            echo [LOI] Khong the tai/giai nen Platform-Tools. Kiem tra mang roi thu lai.
            pause
            exit /b 1
        )
    )

    rem Set PATH cho phien hien tai (de install.ps1 thay adb ngay)
    set "PATH=%ADB_DIR%;%PATH%"

    rem Set PATH vinh vien an toan: chi append neu chua co, tranh lam hong PATH dai
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$d=Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools';" ^
        "$p=[Environment]::GetEnvironmentVariable('Path','User');" ^
        "if(-not $p){$p=''};" ^
        "if($p -notlike ('*'+$d+'*')){ [Environment]::SetEnvironmentVariable('Path', $d+';'+$p, 'User'); Write-Host ('[OK] Da them vao PATH User: '+$d) } else { Write-Host '[OK] PATH User da co ADB' }"

    rem Kiem tra lai sau khi cai
    adb version >nul 2>nul
    if errorlevel 1 (
        echo [LOI] Tu dong cai ADB that bai. Vui long cai thu cong Platform-Tools.
        pause
        exit /b 1
    )
    echo [OK] Da cai ADB vao %ADB_DIR%
) else (
    echo [OK] Da tim thay adb.exe trong he thong.
)
rem =====================================================================
rem ===== KET THUC PHAN TU CAI ADB ======================================
rem =====================================================================

if exist "%~dp0install.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}; $f = Join-Path $env:TEMP ('lily-r1-' + [guid]::NewGuid().ToString('N') + '.ps1'); try { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri ($env:NABU_R1_BASE + '/install.ps1') -OutFile $f; & $f -ApkBase $env:NABU_R1_BASE } catch { Write-Host ('[LOI] Khong tai duoc bo cai: ' + $_.Exception.Message) -ForegroundColor Red } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }"
)
echo.
pause