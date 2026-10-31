:config_wifi_ap
cls
echo.
echo --------------------------------------------
echo     CAU HINH WIFI CHO LOA QUA CHE DO AP
echo --------------------------------------------
echo.
echo HUONG DAN:
echo   1. An va giu nut tron tren loa R1 khoang 5-6 giay
echo      cho den khi loa bao "Bat dau cau hinh mang"
echo      (den trang nhap nhay)
echo   2. Tren may tinh, ket noi WiFi: Phicomm_R1_XXXX
echo   3. Tat ket noi 4G/5G neu co
echo.
echo HD video: %ESC%[33mhttps://youtu.be/71aPeIQm55o%ESC%[0m
echo.
pause >nul

set "WIFI_SSID="
set "WIFI_PASS="
set "WIFI_SEC=WPA"

:ask_ssid
set /p "WIFI_SSID=Nhap TEN WIFI nha ban (SSID): "
if not defined WIFI_SSID (
    echo %ESC%[31mSSID khong duoc de trong!%ESC%[0m
    goto ask_ssid
)

echo.
echo Kieu ma hoa:
echo   1. WPA/WPA2 (mac dinh - pho bien nhat)
echo   2. WEP
echo   3. Khong ma hoa (INSECURE)
set "sec_choice="
set /p "sec_choice=Chon (1-3, Enter = 1): "
if not defined sec_choice set "sec_choice=1"
if "%sec_choice%"=="2" set "WIFI_SEC=WEP"
if "%sec_choice%"=="3" set "WIFI_SEC=INSECURE"

if /I not "%WIFI_SEC%"=="INSECURE" (
    :ask_pass
    set /p "WIFI_PASS=Nhap MAT KHAU WiFi (>=8 ky tu): "
    if not defined WIFI_PASS (
        echo %ESC%[31mMat khau khong duoc de trong!%ESC%[0m
        goto ask_pass
    )
    call :strlen WIFI_PASS pass_len
    if !pass_len! LSS 8 (
        echo %ESC%[31mMat khau phai >= 8 ky tu!%ESC%[0m
        goto ask_pass
    )
)

echo.
echo --------------------------------------------
echo SSID     : %WIFI_SSID%
echo Ma hoa   : %WIFI_SEC%
if /I not "%WIFI_SEC%"=="INSECURE" echo Mat khau : ********
echo --------------------------------------------
echo.
echo Dang gui cau hinh toi loa (192.168.43.1:8989)...
echo.

:: Thoat ky tu dac biet trong JSON (\, ")
set "SSID_JSON=%WIFI_SSID%"
set "SSID_JSON=%SSID_JSON:\=\\%"
set "SSID_JSON=%SSID_JSON:"=\"%"

set "PASS_JSON=%WIFI_PASS%"
set "PASS_JSON=%PASS_JSON:\=\\%"
set "PASS_JSON=%PASS_JSON:"=\"%"

set "JSON_BODY={\"ssid\":\"%SSID_JSON%\",\"secure\":\"%WIFI_SEC%\",\"password\":\"%PASS_JSON%\",\"mac\":\"\"}"

:: Uu tien curl.exe (co san tren Win10 1803+ / Win11)
where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -s -o nul -w "HTTP_CODE:%%{http_code}" ^
        -X POST "http://192.168.43.1:8989/api/configwifi" ^
        -H "Content-Type: application/json" ^
        --data "%JSON_BODY%" ^
        --max-time 5 > "%TEMP%\r1_wifi_result.txt" 2>&1
    set /p HTTP_RESULT=<"%TEMP%\r1_wifi_result.txt"
    del "%TEMP%\r1_wifi_result.txt" >nul 2>&1
    echo %HTTP_RESULT%
    goto wifi_sent
)

:: Fallback: PowerShell
echo curl khong co, dung PowerShell...
powershell -NoProfile -Command ^
  "try { $r = Invoke-WebRequest -Uri 'http://192.168.43.1:8989/api/configwifi' -Method POST -Body '%JSON_BODY%' -ContentType 'application/json' -TimeoutSec 5 -UseBasicParsing; Write-Host ('HTTP_CODE:' + $r.StatusCode) } catch { Write-Host ('ERROR:' + $_.Exception.Message) }"

:wifi_sent
echo.
echo %ESC%[32mDa gui cau hinh WiFi toi loa!%ESC%[0m
echo.
echo %ESC%[33mQUAN TRONG:%ESC%[0m
echo   - Nghe loa bao "ket noi thanh cong" la OK
echo   - Neu browser/tool bao loi nhung loa van nhan duoc la binh thuong
echo   - Sau khi loa ket noi WiFi nha, loa se co IP LAN moi
echo   - Doi khoang 15-30 giay de loa on dinh
echo.
echo Ban co muon kiem tra IP loa ngay bay gio? (Y/N)
set "chk="
set /p "chk=Chon: "
if /I "%chk%"=="Y" (
    call :input_ip
    call :connect_retry "%DEFAULT_IP%" 5
)
exit /b 0

:: Ham tinh do dai chuoi
:strlen
setlocal EnableDelayedExpansion
set "s=!%~1!"
set "len=0"
for %%A in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
    if "!s:~%%A!" NEQ "" (
        set /a len+=%%A
        set "s=!s:~%%A!"
    )
)
endlocal & set "%~2=%len%"
exit /b 0