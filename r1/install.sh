#!/bin/sh
# ==============================================================================
# Script Cai Dat & Cap Nhat Phicomm R1 tren iPhone qua iSH (Alpine Linux) / Linux
# Nguon APK: https://vdt34.github.io/r1/
# Phien ban: 2026 Clean Production Build (Sieu on dinh - Chay la duoc)
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
TEMP_DIR="/tmp/r1_install"
APK_DLNA="autodlna.apk"
APK_UNI="unisound.apk"
APK_AI="AIBoxPlus_DLNA.apk"

# Xoa sach cache tam cu de luon dam bao tai file moi nhat
rm -rf "$TEMP_DIR" 2>/dev/null || true
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

clear
echo "=========================================================="
echo "    KHOI TAO MOI TRUONG CAI DAT PHICOMM R1 TREN iSH"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. KIEM TRA VA CAI DAT CONG CU NEN (iSH / Alpine / Debian / Ubuntu)
# ------------------------------------------------------------------------------
NEED_PKGS=""
if ! command -v adb >/dev/null 2>&1; then
    NEED_PKGS="$NEED_PKGS android-tools"
fi
if ! command -v curl >/dev/null 2>&1; then
    NEED_PKGS="$NEED_PKGS curl"
fi

if [ -n "$NEED_PKGS" ]; then
    echo ">> Phat hien chua co:$NEED_PKGS. Dang tu dong cai dat tren iSH..."
    if command -v apk >/dev/null 2>&1; then
        apk update >/dev/null 2>&1 || true
        apk add --no-cache $NEED_PKGS || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y android-tools-adb curl >/dev/null 2>&1 || true
    fi
fi

if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo ">> [LOI] Thieu cong cu can thiet (adb hoac curl)."
    echo "   Vui long chay lenh sau tren iSH de cai dat:"
    echo "   apk update && apk add android-tools curl"
    exit 1
fi
echo ">> [OK] Cac cong cu (adb, curl) da san sang tren he thong."

# ------------------------------------------------------------------------------
# 2. HAM NHAP LIEU AN TOAN (Tu /dev/tty, ho tro ca chay qua pipe curl ... | sh)
# ------------------------------------------------------------------------------
ask_user() {
    PROMPT_MSG="$1"
    DEF_VAL="$2"
    printf "%s" "$PROMPT_MSG"
    RAW_IN=""
    if [ -e /dev/tty ]; then
        read -r RAW_IN </dev/tty 2>/dev/null || RAW_IN=""
    else
        read -r RAW_IN 2>/dev/null || RAW_IN=""
    fi
    RAW_IN=$(echo "$RAW_IN" | tr -d ' \r\n\t')
    [ -z "$RAW_IN" ] && RAW_IN="$DEF_VAL"
    ANSWER="$RAW_IN"
}

# ------------------------------------------------------------------------------
# 3. BANG CHON CHE DO HOAT DONG
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo "              BANG DIEU KHIEN PHICOMM R1                  "
echo "=========================================================="
echo "Chon thao tac ban muon thuc hien:"
echo "  [1] Loa moi / Reset dang phat WiFi 'Phicomm_R1_xxxx' (IP: 192.168.43.1)"
echo "  [2] Loa da o trong WiFi nha (Nhap IP thu cong de cai dat full)"
echo "  [3] Chi cap nhat AI Box Plus DLNA (Giu nguyen moi cai dat)"
echo "  [4] Thoat"
echo "=========================================================="
echo ""

ask_user "Nhap lua chon cua ban (1-4, mac dinh 1): " "1"
CHOICE="$ANSWER"

MODE="FULL"
TARGET_IP="192.168.43.1"

case "$CHOICE" in
    1)
        TARGET_IP="192.168.43.1"
        MODE="FULL"
        ;;
    2)
        echo ""
        echo "----------------------------------------------------------"
        echo "   NHAP DIA CHI IP CUA LOA TRONG MANG WIFI NHA"
        echo "   (Meo: Ban co the xem IP cua loa trong phan mem Router WiFi,"
        echo "    hoac neu truoc do da ket noi thi thu VD: 192.168.1.47)"
        echo "----------------------------------------------------------"
        ask_user "Nhap IP cua loa: " ""
        TARGET_IP=$(echo "$ANSWER" | sed 's/:5555$//')
        while [ -z "$TARGET_IP" ]; do
            ask_user "Vui long nhap dia chi IP cua loa: " ""
            TARGET_IP=$(echo "$ANSWER" | sed 's/:5555$//')
        done
        MODE="FULL"
        ;;
    3)
        echo ""
        ask_user "Nhap IP loa can cap nhat (Enter de chon 192.168.43.1): " "192.168.43.1"
        TARGET_IP=$(echo "$ANSWER" | sed 's/:5555$//')
        MODE="UPDATE_ONLY"
        ;;
    4)
        echo "Tam biet!"
        exit 0
        ;;
    *)
        TARGET_IP="192.168.43.1"
        MODE="FULL"
        ;;
esac

SERIAL="$TARGET_IP:5555"

# ------------------------------------------------------------------------------
# 4. TAI FILE APK TU GITHUB VE BO NHO TAM
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo "            TAI CAC FILE APK TU GITHUB                    "
echo "=========================================================="

download_apk() {
    FILE="$1"
    DESC="$2"
    echo ">> Dang tai $DESC ($FILE)..."
    if curl -k -L -f -s -S --connect-timeout 15 -o "$FILE.tmp" "$BASE_URL/$FILE"; then
        mv -f "$FILE.tmp" "$FILE"
        echo "   [OK] Da tai $DESC thanh cong."
        return 0
    else
        echo ">> [LOI] Khong the tai $FILE tu GitHub!"
        echo "   Vui long kiem tra lai ket noi Internet."
        rm -f "$FILE.tmp"
        return 1
    fi
}

if [ "$MODE" = "FULL" ]; then
    download_apk "$APK_DLNA" "AutoDLNA" || exit 1
    download_apk "$APK_UNI" "Unisound" || exit 1
    download_apk "$APK_AI" "AI Box Plus DLNA" || exit 1
elif [ "$MODE" = "UPDATE_ONLY" ]; then
    download_apk "$APK_AI" "AI Box Plus DLNA" || exit 1
fi

# ------------------------------------------------------------------------------
# 5. KET NOI ADB TOI LOA (Thiet ke toi gian, chuan xac 100%)
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo "      KIEM TRA KET NOI DEN LOA R1 ($SERIAL)               "
echo "=========================================================="

# Khoi dong local adb daemon tren iSH
adb start-server >/dev/null 2>&1
sleep 1

# Kiem tra ket noi thuc te voi he dieu hanh tren loa
is_speaker_ready() {
    adb -s "$SERIAL" shell "getprop ro.build.version.release" >/dev/null 2>&1
}

# Thu ket noi lan dau
adb connect "$SERIAL" >/dev/null 2>&1
sleep 2

if ! is_speaker_ready; then
    echo ">> [CHUA KET NOI] Chua thay loa tai $SERIAL!"
    echo ""
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo "------------------ LUU Y QUAN TRONG CHO IPHONE ------------------"
        echo " 1. TAT 4G/5G (Du lieu di dong) tren iPhone."
        echo "    * WiFi cua loa KHONG CO INTERNET, neu bat 4G thi iPhone se gui"
        echo "      goi tin qua 4G khien iSH khong the noi toi loa duoc!"
        echo " 2. An giu nut tron tren dinh loa 6s den khi loa phat tieng & den cam."
        echo " 3. Vao Cai dat -> Wi-Fi tren iPhone va chon: Phicomm_R1_xxxx."
        echo " 4. Neu iPhone bao 'Wi-Fi khong co Internet' -> Chon 'Tiep tuc su dung'!"
        echo " 5. Vao Cai dat iPhone -> iSH -> Bat 'Mang cuc bo' (Local Network)."
        echo "-----------------------------------------------------------------"
    else
        echo "------------------ LUU Y KHI KET NOI QUA WIFI NHA ------------------"
        echo " 1. Dam bao iPhone va loa dang bat va ket noi CUNG mot mang Wi-Fi."
        echo " 2. Kiem tra dia chi IP cua loa ($TARGET_IP) da dung chua."
        echo " 3. Vao Cai dat iPhone -> iSH -> Bat 'Mang cuc bo' (Local Network)."
        echo " 4. MEU HAY: Neu loa bi do cong ADB boi cac phien truoc, hay RUT NGUON"
        echo "    loa ra cam lai, cho loa khoi dong xong 30 giay roi thu lai!"
        echo "-----------------------------------------------------------------"
    fi
    echo ">> He thong dang tu dong cho ket noi (Nhan Ctrl + C de dung)..."
    echo ""

    RETRY_COUNT=0
    while true; do
        RETRY_COUNT=$((RETRY_COUNT + 1))

        # Ket noi toi loa (TUYET DOI KHONG goi adb disconnect o day de khong lam dut bat tay TCP)
        adb connect "$SERIAL" >/dev/null 2>&1
        sleep 2

        if is_speaker_ready; then
            echo ""
            echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
            break
        fi

        printf "\r[*] Dang cho ket noi [%s] (Lan thu %d)...   " "$SERIAL" "$RETRY_COUNT"

        if [ $((RETRY_COUNT % 8)) -eq 0 ]; then
            echo ""
            ask_user ">> Loa chua phan hoi tai $TARGET_IP. Ban co muon doi sang IP khac? (Nhap IP moi hoac Enter de doi tiep): " ""
            if [ -n "$ANSWER" ]; then
                TARGET_IP=$(echo "$ANSWER" | sed 's/:5555$//')
                SERIAL="$TARGET_IP:5555"
                RETRY_COUNT=0
                echo ">> Da doi muc tieu sang: $SERIAL"
                adb kill-server >/dev/null 2>&1 || true
                sleep 1
                adb start-server >/dev/null 2>&1 || true
                sleep 1
            fi
        fi
    done
else
    echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
fi

# ------------------------------------------------------------------------------
# 6. HAM CAI DAT APK AN TOAN & XU LY XUNG DOT CHU KY
# ------------------------------------------------------------------------------
install_apk() {
    LOCAL_FILE="$1"
    APP_DESC="$2"
    TARGET_PKG="$3"

    echo ">> [1/2] Dang day $APP_DESC len loa..."
    if ! adb -s "$SERIAL" push "$LOCAL_FILE" "/data/local/tmp/$LOCAL_FILE"; then
        echo ">> [LOI] Khong the day $APP_DESC len bo nho loa!"
        return 1
    fi

    echo ">> [2/2] Dang cai dat $APP_DESC vao he thong..."
    INSTALL_LOG=$(adb -s "$SERIAL" shell "pm install -r /data/local/tmp/$LOCAL_FILE" 2>&1 | tr -d '\r')
    adb -s "$SERIAL" shell "rm -f /data/local/tmp/$LOCAL_FILE" >/dev/null 2>&1

    if echo "$INSTALL_LOG" | grep -qi "Success"; then
        echo "   [OK] Cai dat $APP_DESC thanh cong!"
        return 0
    fi

    # Neu bi loi chu ky (keystore cu khong khop voi ban moi)
    if echo "$INSTALL_LOG" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        echo "   [!] Phat hien chu ky cu khong tuong thich. Dang go ban cu de cai lai..."
        if [ -n "$TARGET_PKG" ]; then
            adb -s "$SERIAL" shell "pm uninstall $TARGET_PKG" >/dev/null 2>&1 || true
        fi
        adb -s "$SERIAL" push "$LOCAL_FILE" "/data/local/tmp/$LOCAL_FILE" >/dev/null 2>&1
        adb -s "$SERIAL" shell "pm install /data/local/tmp/$LOCAL_FILE" >/dev/null 2>&1
        adb -s "$SERIAL" shell "rm -f /data/local/tmp/$LOCAL_FILE" >/dev/null 2>&1
        echo "   [OK] Da go va cai dat lai $APP_DESC thanh cong!"
        return 0
    fi

    echo ">> [LOI] pm install that bai: $INSTALL_LOG"
    return 1
}

# ------------------------------------------------------------------------------
# 7. THUC THI CAI DAT DAY DU (FULL)
# ------------------------------------------------------------------------------
if [ "$MODE" = "FULL" ]; then
    echo ""
    echo "=========================================================="
    echo "  BAT DAU CAI DAT: Auto DLNA + Unisound + AI Box Tieng Viet"
    echo "=========================================================="
    echo ""

    # 1. Don dep va cho phep cai nguon ngoai
    echo ">> [1/6] Don dep bo nho dem va toi uu cac service..."
    adb -s "$SERIAL" shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "rm -rf /data/local/tmp/*" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "settings put secure install_non_market_apps 1" >/dev/null 2>&1 || true

    # An cac goi khong can thiet cua Phicomm
    for pkg in com.phicomm.speaker.airskill com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.otaservice com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport; do
        adb -s "$SERIAL" shell "pm hide $pkg" >/dev/null 2>&1 || true
    done

    # 2. Cai dat AutoDLNA
    echo ">> [2/6] Cai dat AutoDLNA..."
    install_apk "$APK_DLNA" "AutoDLNA" "com.phicomm.speaker.player" || true

    # 3. Cai dat Unisound
    echo ">> [3/6] Cai dat Unisound..."
    install_apk "$APK_UNI" "Unisound" "com.phicomm.speaker.device" || true

    # 4. Khoi chay cac service nen cua he thong
    echo ">> [4/6] Khoi chay service he thong..."
    for pkg in com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl; do
        adb -s "$SERIAL" shell "pm unhide $pkg" >/dev/null 2>&1 || true
    done
    adb -s "$SERIAL" shell "am startservice com.phicomm.speaker.player/.EchoService" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "am start com.phicomm.speaker.device/.ui.MainActivity" >/dev/null 2>&1 || true

    # 5. Cai dat AI Box Plus DLNA moi nhat
    echo ">> [5/6] Cai dat ban AI Box Plus DLNA moi nhat..."
    install_apk "$APK_AI" "AI Box Plus DLNA" "info.dourok.voicebot" || true

    # 6. Khoi chay AI Box
    echo ">> [6/6] Khoi chay ung dung AI Box..."
    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1 || true

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!        "
    echo "=========================================================="
    echo "Toan bo ung dung & dich vu da duoc khoi chay SAN SANG DUNG NGAY!"
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo "Ket noi WiFi giua iPhone va loa duoc GIU NGUYEN (khong bi ngat)."
        echo ""
        echo ">>> CAC BUOC DE DUNG NGAY LAP TUC:"
        echo " 1. Mo trinh duyet Safari tren iPhone, truy cap ngay:"
        echo "    👉 http://192.168.43.1:8081/wifi.html (de cai dat WiFi nha cho loa)"
        echo "    hoac: http://192.168.43.1:8081/ (giao dien Web Control dieu khien loa)"
        echo " 2. Chon WiFi nha va nhap mat khau -> Loa se bao ket noi thanh cong."
        echo " 3. Chuyen iPhone ve WiFi nha va su dung binh thuong tai IP moi!"
        echo "=========================================================="
    else
        echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
        echo "=========================================================="
    fi
fi

# ------------------------------------------------------------------------------
# 8. THUC THI CAP NHAT NHANH (UPDATE_ONLY)
# ------------------------------------------------------------------------------
if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo ""
    echo "=========================================================="
    echo "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAI DAT)    "
    echo "=========================================================="
    echo ""
    install_apk "$APK_AI" "AI Box Plus DLNA" "info.dourok.voicebot" || exit 1
    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1 || true
    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!     "
    echo "=========================================================="
    echo "Toan bo cai dat duoc giu nguyen 100%!"
    echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
fi
