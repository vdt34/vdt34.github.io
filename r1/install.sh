#!/bin/sh
# Script Cai Dat & Cap Nhat Phicomm R1 tren iPhone qua iSH (Alpine Linux)
# Nguon APK: https://vdt34.github.io/r1/

set -e

BASE_URL="https://vdt34.github.io/r1"
TEMP_DIR="/tmp/r1_install"
APK_DLNA="autodlna.apk"
APK_UNI="unisound.apk"
APK_AI="AIBoxPlus_DLNA.apk"
APK_ECHO="new_EchoService.apk"

clear
echo "=========================================================="
echo "    KHOI TAO MOI TRUONG CAI DAT PHICOMM R1 TREN iSH"
echo "=========================================================="
echo ""

# 1. Tu dong kiem tra va cai dat cong cu tren iSH neu chua co
NEED_INSTALL=""
if ! command -v adb >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL android-tools"
fi
if ! command -v curl >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL curl"
fi

if [ -n "$NEED_INSTALL" ]; then
    echo ">> Phat hien chua co:$NEED_INSTALL. Dang tu dong cai dat qua apk..."
    apk update
    apk add --no-cache $NEED_INSTALL
    echo ">> [OK] Da cai dat xong cac cong cu can thiet tren iSH!"
else
    echo ">> [OK] Cac cong cu (adb, curl) da co san tren iSH. Bo qua buoc cai dat."
fi

# 2. Tao thu muc tam tren iSH va tai cac file APK tu GitHub ve
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo ""
echo "=========================================================="
echo "    TAI CAC FILE APK TU GITHUB ($BASE_URL)"
echo "=========================================================="

download_file() {
    FILE="$1"
    if [ -f "$FILE" ] && [ -s "$FILE" ]; then
        echo ">> File $FILE da co trong cache (/tmp). Bo qua tai lai."
    else
        echo ">> Dang tai $FILE tu GitHub..."
        curl -k -L -# -o "$FILE.tmp" "$BASE_URL/$FILE"
        mv "$FILE.tmp" "$FILE"
        echo ">> [OK] Da tai $FILE thanh cong."
    fi
}

download_file "$APK_AI"
download_file "$APK_DLNA"
download_file "$APK_UNI"
download_file "$APK_ECHO"

echo ""
echo "=========================================================="
echo "  [DA TAI XONG TOAN BO 4 FILE APK VE IPHONE THANH CONG]   "
echo "=========================================================="
echo ""

ARG1="$1"
ARG2="$2"
TARGET_IP="192.168.43.1"
MODE="FULL"

if [ "$ARG1" = "menu" ] || [ "$ARG1" = "-m" ]; then
    echo "Chon thao tac ban muon thuc hien:"
    echo "  [1] Cai dat day du (AutoDLNA + Unisound + AI Box DLNA) [IP: 192.168.43.1]"
    echo "  [2] Cai dat day du qua IP WiFi nha (nhap IP hoac chon san)"
    echo "  [3] Chi cap nhat AI Box DLNA moi (giu nguyen cai dat cu)"
    echo "  [4] Kiem tra IP cua loa trong mang WiFi"
    echo "  [5] Thoat"
    echo ""
    printf "Nhap lua chon cua ban (1-5, mac dinh 1): "
    read CHOICE </dev/tty || CHOICE="1"

    case "$CHOICE" in
        2)
            echo ""
            echo "Chon IP loa trong mang WiFi nha:"
            echo "  a) Loa CH         (192.168.1.47)"
            echo "  b) Loa Phong Ngu  (192.168.1.58)"
            echo "  c) Nhap IP khac"
            printf "Chon (a/b/c, mac dinh a): "
            read SUB_IP </dev/tty || SUB_IP="a"
            if [ "$SUB_IP" = "b" ]; then
                TARGET_IP="192.168.1.58"
            elif [ "$SUB_IP" = "c" ]; then
                printf "Nhap IP loa: "
                read TARGET_IP </dev/tty || TARGET_IP="192.168.1.47"
            else
                TARGET_IP="192.168.1.47"
            fi
            MODE="FULL"
            ;;
        3)
            echo ""
            printf "Nhap IP loa can cap nhat (VD: 192.168.1.47 hoac 192.168.43.1): "
            read TARGET_IP </dev/tty || TARGET_IP="192.168.1.47"
            [ -z "$TARGET_IP" ] && TARGET_IP="192.168.43.1"
            MODE="UPDATE_ONLY"
            ;;
        4)
            TARGET_IP="192.168.43.1"
            MODE="CHECK_IP"
            ;;
        5)
            echo "Thoat chuong trinh."
            exit 0
            ;;
        *)
            TARGET_IP="192.168.43.1"
            MODE="FULL"
            ;;
    esac
elif [ "$ARG1" = "update" ]; then
    MODE="UPDATE_ONLY"
    [ -n "$ARG2" ] && TARGET_IP="$ARG2"
elif [ -n "$ARG1" ]; then
    TARGET_IP="$ARG1"
fi

# 3. Kiem tra va cho ket noi - KET NOI LA LAP TUC CAI DAT NGAY
SERIAL="$TARGET_IP:5555"

echo ""
echo "=========================================================="
echo "      KIEM TRA KET NOI DEN LOA R1 ($SERIAL)               "
echo "=========================================================="

set +e
# Kiem tra nhanh
adb disconnect "$SERIAL" >/dev/null 2>&1
CONN_CHECK=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

if [ "$DEV_STATE" != "device" ] && ! echo "$CONN_CHECK" | grep -q "connected to"; then
    echo ">> [CHUA KET NOI] Chua thay loa tai $TARGET_IP!"
    echo ""
    echo "------------------ LUU Y QUAN TRONG CHO IPHONE ------------------"
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo " 1. TAT 4G/5G (Du lieu di dong) tren iPhone:"
        echo "    * WiFi loa KHONG CO INTERNET, neu bat 4G thi iPhone se ban"
        echo "      goi tin qua 4G khien iSH khong the ket noi toi loa duoc!"
        echo " 2. An giu nut tron tren dinh loa 6s den khi loa phat tieng & den cam."
        echo " 3. Vao Cai dat -> Wi-Fi tren iPhone va chon: Phicomm_R1_xxxx"
        echo " 4. Neu iPhone bao 'Wi-Fi khong co Internet' -> Chon 'Tiep tuc su dung'!"
    else
        echo " * Dam bao iPhone dang ket noi cung mang WiFi voi loa tai IP: $TARGET_IP"
    fi
    echo " 5. Kiem tra: Cai dat -> iSH -> Bat 'Mang cuc bo' (Local Network) neu co."
    echo "-----------------------------------------------------------------"
    echo ">> He thong dang tu dong cho ket noi (Nhan Ctrl + C neu muon dung)..."
    echo ""

    TRY_COUNT=0
    while true; do
        TRY_COUNT=$((TRY_COUNT + 1))

        # Reset disconnect de tranh loi ket socket offline cua ADB
        adb disconnect "$SERIAL" >/dev/null 2>&1

        # Thu connect
        CONN_RES=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
        DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

        if [ "$DEV_STATE" = "device" ] || echo "$CONN_RES" | grep -q "connected to"; then
            if adb -s "$SERIAL" shell getprop ro.build.version.release >/dev/null 2>&1; then
                echo ""
                echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
                break
            fi
        fi

        printf "\r[*] Dang cho ket noi [%s] (Thu %d) | Trang thai: %s   " "$SERIAL" "$TRY_COUNT" "$CONN_RES"

        # Sau moi 8 lan thu, neu chua duoc, khoi dong lai nhe adb server de lam sach cache network tren iOS
        if [ $((TRY_COUNT % 8)) -eq 0 ]; then
            adb kill-server >/dev/null 2>&1 || true
            adb start-server >/dev/null 2>&1 || true
        fi

        sleep 1.5
    done
fi
set -e

echo ""
echo ">> [DA KET NOI] PHAT HIEN THIET BI TAI $SERIAL!"
echo ">> [LAP TUC CAI DAT] BAT DAU TIEN HANH CAI DAT CHO LOA..."
echo ""

if [ "$MODE" = "CHECK_IP" ]; then
    echo ">> Dang lay thong tin loa..."
    DEV_IP=$(adb -s "$SERIAL" shell getprop dhcp.wlan0.ipaddress | tr -d '\r')
    DEV_NAME=$(adb -s "$SERIAL" shell getprop net.hostname | tr -d '\r')
    DEV_VER=$(adb -s "$SERIAL" shell getprop ro.build.version.incremental | tr -d '\r')
    echo "Device Name : $DEV_NAME"
    echo "Firmware Ver: $DEV_VER"
    echo "IP trong mang: $DEV_IP"
    exit 0
fi

if [ "$MODE" = "FULL" ]; then
    echo "=========================================================="
    echo "  BAT DAU CAI DAT: Auto DLNA + Unisound + AI Box Tieng Viet"
    echo "=========================================================="
    echo ""
    echo ">> [1/8] Dang don dep bo nho dem va tat ung dung khong can thiet..."
    adb -s "$SERIAL" shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip"
    adb -s "$SERIAL" shell "rm -rf /data/local/tmp/*"
    adb -s "$SERIAL" shell "/system/bin/pm clear com.phicomm.speaker.otaservice" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "settings put secure install_non_market_apps 1"

    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.airskill" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.exceptionreporter" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.systemtool" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.device" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.otaservice" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.productiontest" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.bugreport" >/dev/null 2>&1 || true

    echo ">> [2/8] Dang day AutoDLNA len loa..."
    adb -s "$SERIAL" push "$APK_DLNA" /data/local/tmp/autodlna.apk
    echo ">> [3/8] Dang cai dat AutoDLNA..."
    adb -s "$SERIAL" shell "/system/bin/pm install -r /data/local/tmp/autodlna.apk"
    adb -s "$SERIAL" shell "rm -f /data/local/tmp/autodlna.apk"

    echo ">> [4/8] Dang day Unisound len loa..."
    adb -s "$SERIAL" push "$APK_UNI" /data/local/tmp/unisound.apk
    echo ">> [5/8] Dang cai dat Unisound..."
    adb -s "$SERIAL" shell "/system/bin/pm install -r /data/local/tmp/unisound.apk"
    adb -s "$SERIAL" shell "rm -f /data/local/tmp/unisound.apk"

    echo ">> [6/8] Khoi chay service EchoService va Unisound..."
    adb -s "$SERIAL" shell "am startservice com.phicomm.speaker.player/.EchoService" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "am start com.phicomm.speaker.device/.ui.MainActivity" >/dev/null 2>&1 || true

    adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.ijetty" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.netctl" >/dev/null 2>&1 || true

    echo ">> [7/8] Dang go ban AI cu (bao luu cai dat cu bang -k)..."
    adb -s "$SERIAL" shell "/system/bin/pm uninstall -k info.dourok.voicebot" >/dev/null 2>&1 || true

    echo ">> [8/8] Dang day va cai dat AI Box Plus DLNA moi..."
    adb -s "$SERIAL" push "$APK_AI" /data/local/tmp/AIBoxPlus_DLNA.apk
    adb -s "$SERIAL" shell "/system/bin/pm install /data/local/tmp/AIBoxPlus_DLNA.apk"
    adb -s "$SERIAL" shell "rm -f /data/local/tmp/AIBoxPlus_DLNA.apk"

    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1 || true

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!        "
    echo "=========================================================="
    echo "Loa da khoi chay AI Box Plus voi day du tinh nang!"
    echo "Neu dang o WiFi phat cua loa (192.168.43.1), hay dung Safari tren iPhone"
    echo "truy cap vao: http://192.168.43.1:8081/ de ket noi WiFi nha cho loa."
fi

if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo "=========================================================="
    echo "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAI DAT)    "
    echo "=========================================================="
    echo ""
    echo ">> [1/3] Dang day AIBoxPlus_DLNA.apk len loa..."
    adb -s "$SERIAL" push "$APK_AI" /sdcard/AIBoxPlus_DLNA.apk

    echo ">> [2/3] Dang go ban cu (giu nguyen cau hinh cu bang -k)..."
    adb -s "$SERIAL" shell "pm uninstall -k info.dourok.voicebot"

    echo ">> [3/3] Dang cai dat ban moi..."
    adb -s "$SERIAL" shell "pm install /sdcard/AIBoxPlus_DLNA.apk"
    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity"

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!     "
    echo "=========================================================="
    echo "Toan bo cai dat (mDNS, PayOS, hen gio...) duoc giu nguyen 100%!"
    echo "Truy cap giao dien web: http://$TARGET_IP:8081/"
fi
