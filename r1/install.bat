
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
mode con lines=32 cols=90
title Phicomm R1 - AIBoxPlus Installer

set "APK_DLNA=autodlna.apk"
set "APK_UNI=unisound.apk"
set "APK_AI=AIBoxPlus_DLNA.apk"
if exist "AIBoxPlus_DLNA_VOV_Patched.apk" set "APK_AI=AIBoxPlus_DLNA_VOV_Patched.apk"
set "DEFAULT_IP=192.168.1.4"

for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

set "IP="
set "SERIAL="
set "ipaddress="
set "hostname="

:menu
cls
echo.
echo ================================================
echo             PHICOMM R1 - AI BOX PLUS
echo ================================================
echo.
echo 1. Tim IP cua loa
echo 2. Cai dat ca 3 ung dung (AutoDLNA + Unisound + AI)
echo 3. Chi cai dat / cap nhat AIBoxPlus
echo 4. Thoat
echo.
echo ================================================
echo.
set "choice="
set /p "choice=Chon thao tac (1-4): "
if not defined choice goto menu
set "choice=%choice:~0,1%"

if "%choice%"=="1" goto check_ip
if "%choice%"=="2" goto install_all
if "%choice%"=="3" goto install_ai_only
if "%choice%"=="4" goto exit

echo.
echo Lua chon khong hop le!
timeout /t 1 >nul
goto menu

:check_ip
call :scan_select_ip
if errorlevel 1 goto menu
call :connect_retry "%DEFAULT_IP%" 3
if errorlevel 1 (
    cls
    echo.
    echo Khong the ket noi loa qua ADB.
    echo Kiem tra IP, ket noi Wi-Fi va thu lai.
    pause
    goto menu
)
call :device_info
cls
echo.
echo ================================================
echo                 THONG TIN LOA
echo ================================================
echo.
if defined hostname echo Ten thiet bi: %hostname%
if defined ipaddress (
    echo IP cua loa: %ipaddress%
) else (
    echo Khong doc duoc IP WLAN tu loa.
    echo IP ADB dang ket noi: %IP%
)
echo.
echo ADB: %SERIAL%
echo.
pause
goto menu

:install_all
call :scan_select_ip
if errorlevel 1 goto menu
call :connect_retry "%DEFAULT_IP%" 5
if errorlevel 1 (
    cls
    echo.
    echo Khong the ket noi loa qua ADB.
    echo Kiem tra IP va ket noi mang roi thu lai.
    pause
    goto menu
)
call :device_info
cls
echo.
echo ================================================
echo       CAI DAT DAY DU 3 UNG DUNG
echo ================================================
echo.
echo 1. AutoDLNA: %APK_DLNA%
echo 2. Unisound: %APK_UNI%
echo 3. AIBoxPlus: %APK_AI%
echo.
call :require_file "%APK_DLNA%" || goto menu
call :require_file "%APK_UNI%" || goto menu
call :require_file "%APK_AI%" || goto menu

echo.
echo Dang bat quyen cai dat ung dung...
adb -s "%SERIAL%" shell settings put secure install_non_market_apps 1 >nul 2>&1

echo.
echo Dang vo hieu hoa mot so ung dung he thong theo cau hinh bo cai goc...
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.airskill
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.systemtool
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.device
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.otaservice
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.productiontest
adb -s "%SERIAL%" shell /system/bin/pm hide com.phicomm.speaker.bugreport

echo.
echo Dang tai AutoDLNA va Unisound len loa...
call :push_or_fail "%APK_DLNA%" "/data/local/tmp/%APK_DLNA%" || goto menu
call :push_or_fail "%APK_UNI%" "/data/local/tmp/%APK_UNI%" || goto menu

echo.
echo Dang cai AutoDLNA...
call :install_or_fail "/data/local/tmp/%APK_DLNA%" || goto menu
echo.
echo Dang cai Unisound...
call :install_or_fail "/data/local/tmp/%APK_UNI%" || goto menu

adb -s "%SERIAL%" shell rm "/data/local/tmp/%APK_DLNA%" >nul 2>&1
adb -s "%SERIAL%" shell rm "/data/local/tmp/%APK_UNI%" >nul 2>&1

echo.
echo Dang khoi dong dich vu loa...
adb -s "%SERIAL%" shell am startservice com.phicomm.speaker.player/.EchoService
adb -s "%SERIAL%" shell am start -n com.phicomm.speaker.device/.ui.MainActivity

echo.
echo Cai dat AutoDLNA va Unisound hoan tat.
echo Tiep tuc cai dat AIBoxPlus...
timeout /t 2 /nobreak >nul
goto install_ai_common

:install_ai_only
call :scan_select_ip
if errorlevel 1 goto menu
call :connect_retry "%DEFAULT_IP%" 5
if errorlevel 1 (
    cls
    echo.
    echo Khong the ket noi loa qua ADB.
    echo Kiem tra IP va ket noi mang roi thu lai.
    pause
    goto menu
)
call :device_info
cls
echo.
echo ================================================
echo          CHI CAI DAT / CAP NHAT AI
echo ================================================
echo.
echo Che do nay KHONG cai AutoDLNA va KHONG cai Unisound.
echo Khong thay doi cac ung dung DLNA / Unisound hien co.
echo.
call :require_file "%APK_AI%" || goto menu
goto install_ai_common

:install_ai_common
echo.
echo -----------------------------------------------
echo             CAI DAT AIBoxPlus
echo -----------------------------------------------
echo.
call :require_file "%APK_AI%" || goto menu

echo Dang bat quyen cai dat ung dung...
adb -s "%SERIAL%" shell settings put secure install_non_market_apps 1 >nul 2>&1

echo.
echo Dang go phien ban AI cu...
adb -s "%SERIAL%" shell /system/bin/pm uninstall info.dourok.voicebot
echo.
echo Dang tai %APK_AI% len loa...
call :push_or_fail "%APK_AI%" "/data/local/tmp/%APK_AI%" || goto menu

echo.
echo Dang cai dat AIBoxPlus...
call :install_or_fail "/data/local/tmp/%APK_AI%" || goto menu
adb -s "%SERIAL%" shell rm "/data/local/tmp/%APK_AI%" >nul 2>&1

echo.
echo Dang khoi dong AIBoxPlus...
adb -s "%SERIAL%" shell tinymix -D 2 0 8 >nul 2>&1
adb -s "%SERIAL%" shell tinymix -D 2 1 8 >nul 2>&1
adb -s "%SERIAL%" shell am start -n info.dourok.voicebot/.java.activities.MainActivity
timeout /t 5 /nobreak >nul

echo.
echo ================================================
echo              CAI DAT HOAN TAT
echo ================================================
echo.
echo AIBoxPlus da duoc cai dat.
echo Neu la lan dau cau hinh, truy cap Xiaozhi.me
echo de nhap ma lien ket 6 so va cau hinh AI.
echo.
set "ip_for_panel=%ipaddress%"
if not defined ip_for_panel set "ip_for_panel=%IP%"
echo Bang dieu khien loa: http://%ip_for_panel%:8081
echo.
set "REBOOT_CHOICE="
set /p "REBOOT_CHOICE=Khoi dong lai loa ngay bay gio? (Y/N): "
if /I "%REBOOT_CHOICE%"=="Y" (
    adb -s "%SERIAL%" reboot
)
echo.
pause
goto menu

:exit
endlocal
exit /b 0


:scan_select_ip
set "DEFAULT_IP="
set "SCAN_FILE=%TEMP%\r1_scan_%RANDOM%_%RANDOM%.txt"
set "R1_SCAN_OUT=%SCAN_FILE%"
cls
echo.
echo ================================================
echo       TU DONG QUET IP LOA PHICOMM R1
echo ================================================
echo.
echo Dang xac dinh mang LAN va quet cac cong 5555, 8080, 8081...
echo Vui long doi trong khi quet.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan_r1.ps1"
if errorlevel 1 (
    echo.
    echo Khong the quet mang tu dong. Hay nhap IP thu cong.
)
set /a SCAN_COUNT=0
if exist "%SCAN_FILE%" (
    for /f "usebackq tokens=1,2,3 delims=|" %%A in ("%SCAN_FILE%") do (
        set /a SCAN_COUNT+=1
        set "SCAN_IP_!SCAN_COUNT!=%%B"
        echo   [!SCAN_COUNT!] %%B  (%%C)
    )
)
if !SCAN_COUNT! GTR 0 (
    echo.
    set "PICK="
    set /p "PICK=Chon so thu tu loa (Enter = 1, hoac nhap IP): "
    if not defined PICK set "PICK=1"
    set "PICK_IP="
    set "PICK_VALID="
    for /f "delims=0123456789" %%Z in ("!PICK!") do set "PICK_VALID=0"
    if not defined PICK_VALID (
        for /L %%N in (1,1,!SCAN_COUNT!) do if "!PICK!"=="%%N" set "PICK_IP=!SCAN_IP_%%N!"
    )
    if defined PICK_IP (
        set "DEFAULT_IP=!PICK_IP!"
    ) else (
        echo(!PICK!| findstr /r /x "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
        if not errorlevel 1 set "DEFAULT_IP=!PICK!"
    )
) else (
    echo.
    set /p "DEFAULT_IP=Khong tim thay loa. Nhap IP loa thu cong (Enter de quay lai): "
)
del "%SCAN_FILE%" >nul 2>&1
if not defined DEFAULT_IP (
    echo.
    echo Chua chon IP loa.
    pause
    exit /b 1
)
echo.
echo Da chon IP loa: %DEFAULT_IP%
timeout /t 1 >nul
exit /b 0

:input_ip
cls
echo.
echo --------------------------------------------
echo        NHAP IP CUA LOA
echo --------------------------------------------
echo.
if defined DEFAULT_IP (
  echo IP hien tai: %ESC%[33m%DEFAULT_IP%%ESC%[0m
  echo.
)
set "NEW_IP="
set /p "NEW_IP=Nhap IP cua loa (Enter de dung mac dinh 192.168.43.1): "
if defined NEW_IP (
  set "DEFAULT_IP=%NEW_IP%"
) else (
  set "DEFAULT_IP=192.168.43.1"
)
echo.
echo Se ket noi toi IP: %ESC%[33m%DEFAULT_IP%%ESC%[0m
timeout /t 1 >nul
exit /b 0

:connect_retry
call :require_adb || exit /b 1
set "IP_RETRY=%~1"
set "MAX_RETRY=%~2"
if not defined MAX_RETRY set "MAX_RETRY=3"
if not defined IP_RETRY exit /b 1
set /a "CRT_N=0"

:connect_retry_loop
set /a "CRT_N+=1"
echo.
echo %ESC%[33m[Ket noi] Thu lan thu !CRT_N!/%MAX_RETRY% toi %IP_RETRY% %ESC%[0m
call :connect %IP_RETRY%
if not errorlevel 1 exit /b 0
if !CRT_N! LSS %MAX_RETRY% (
  echo %ESC%[33mKet noi that bai, se thu lai sau 1 giay...%ESC%[0m
  timeout /t 1 >nul
  goto connect_retry_loop
)
exit /b 1

:connect
call :require_adb || exit /b 1
set "IP=%~1"
if not defined IP exit /b 1
set "SERIAL=%IP%:5555"
echo Bat dau ket noi thiet bi [%SERIAL%]...
call :adb_reset
adb connect "%SERIAL%" >nul 2>&1
set "STATE="
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" get-state 2^>nul`) do set "STATE=%%i"
if /I not "!STATE!"=="device" (
  call :Warn "Ket noi that bai (ADB chua thay thiet bi). Hay kiem tra lai ket noi va thu lai!"
  exit /b 1
)
adb -s "%SERIAL%" shell ls >nul 2>&1
if errorlevel 1 (
  call :Warn "adb shell bi loi (co the 'unauthorized' / mat ket noi). Hay thu ket noi lai!"
  exit /b 1
)
echo Ket noi thanh cong!
exit /b 0

:device_info
set "ver="
set "ipaddress="
set "hostname="
set "r1="
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" shell getprop ro.build.version.incremental 2^>nul`) do set "ver=%%i"
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" shell getprop dhcp.wlan0.ipaddress 2^>nul`) do set "ipaddress=%%i"
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" shell getprop net.hostname 2^>nul`) do set "hostname=%%i"
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" shell getprop ro.build.host 2^>nul`) do set "build_host=%%i"
for /f "usebackq delims=" %%i in (`adb -s "%SERIAL%" shell getprop ro.product.model 2^>nul`) do set "build_model=%%i"
if /I "%build_host%"=="phicomm" if /I "%build_model%"=="rk322x-box" set "r1=true"
exit /b 0

:push_or_fail
adb -s "%SERIAL%" push "%~1" "%~2"
if errorlevel 1 (
  call :fail "Tai file len that bai: %~1"
  exit /b 1
)
exit /b 0

:install_or_fail
adb -s "%SERIAL%" shell /system/bin/pm install -r "%~1"
if errorlevel 1 (
  call :fail "Cai dat that bai: %~1"
  exit /b 1
)
exit /b 0

:Warn
echo %ESC%[31m%~1%ESC%[0m
timeout /t 1 >nul
exit /b 0

:adb_reset
taskkill /f /t /im adb.exe >nul 2>&1
adb kill-server >nul 2>&1
adb start-server >nul 2>&1
timeout /t 1 /nobreak >nul
exit /b 0

:require_adb
if exist "adb.exe" exit /b 0
call :adb_not_found
exit /b 1

:require_file
if exist "%~1" exit /b 0
call :fail "Khong tim thay file: %~1"
exit /b 1

:fail
cls
color 04
echo.
echo %~1
pause >nul
exit /b 0

:adb_not_found
cls
color 04
echo.
echo Khong tim thay file adb, hay giai nen toan bo thu muc cai dat va chay lai file Update_R1 trong thu muc da giai nen!
pause >nul
exit
