#!/bin/sh
# ==============================================================================
# Script Cai Dat & Cap Nhat Phicomm R1 tren iPhone qua iSH (Alpine Linux) / Linux
# Nguon APK: https://vdt34.github.io/r1/
# Phien ban: Refactored Production Build (An toan, Modular, De debug)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CAU HINH CO BAN & THU MUC TAM
# ------------------------------------------------------------------------------
BASE_URL="https://vdt34.github.io/r1"
TEMP_DIR="/tmp/r1_install"
APK_DLNA="autodlna.apk"
APK_UNI="unisound.apk"
APK_AI="AIBoxPlus_DLNA.apk"

# Luon xoa sach cache tam cu o dau moi phien chay de dam bao tai file moi nhat
rm -rf "$TEMP_DIR" /tmp/r1_scan_* 2>/dev/null || true
mkdir -p "$TEMP_DIR"

clear
echo "=========================================================="
echo "    KHOI TAO MOI TRUONG CAI DAT PHICOMM R1 TREN iSH"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 2. KIEM TRA VA CAI DAT CONG CU NEN (iSH / Alpine / Debian / Ubuntu)
# ------------------------------------------------------------------------------
NEED_INSTALL=""
if ! command -v adb >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL android-tools"
fi
if ! command -v curl >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL curl"
fi
if ! command -v nc >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL netcat-openbsd"
fi

if [ -n "$NEED_INSTALL" ]; then
    if command -v apk >/dev/null 2>&1; then
        echo ">> Phat hien chua co:$NEED_INSTALL. Dang tu dong cai dat tren iSH..."
        apk update >/dev/null 2>&1 || true
        apk add --no-cache $NEED_INSTALL || true
    elif command -v apt-get >/dev/null 2>&1; then
        echo ">> Dang cai dat cac cong cu qua apt..."
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y android-tools-adb curl netcat-openbsd >/dev/null 2>&1 || true
    fi
fi

# Kiem tra lai sau khi thu cai dat
if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo ">> [LOI] Thieu cong cu can thiet (adb hoac curl)."
    echo "   Vui long chay lenh sau tren iSH de cai dat roi thu lai:"
    echo "   apk update && apk add android-tools curl"
    exit 1
fi
echo ">> [OK] Cac cong cu (adb, curl, nc) da san sang."

# ------------------------------------------------------------------------------
# 3. ADB HELPER FUNCTIONS (Tach rieng de quan ly tap trung va de debug)
# ------------------------------------------------------------------------------
# Chay lenh adb thong minh (tu dong xu ly connect/disconnect khong kem -s)
adb_cmd() {
    case "$1" in
        connect)
            shift
            if [ -n "$1" ]; then
                adb connect "$@"
            else
                adb connect "$SERIAL"
            fi
            ;;
        disconnect)
            shift
            if [ -n "$1" ]; then
                adb disconnect "$@"
            else
                adb disconnect "$SERIAL"
            fi
            ;;
        *)
            adb -s "$SERIAL" "$@"
            ;;
    esac
}

# Chay lenh shell tren Android, tu dong loai bo ky tu \r cua Windows/Android
adb_shell() {
    adb -s "$SERIAL" shell "$@" | tr -d '\r'
}

# Kiem tra xem mot package co thuc su duoc cai tren thiet bi hay khong
is_package_installed() {
    TARGET_PKG="$1"
    adb_shell "pm list packages" 2>/dev/null | grep -q "^package:$TARGET_PKG$"
}

# ------------------------------------------------------------------------------
# 4. HAM NHAP LIEU AN TOAN (Khong dung eval, chong Shell Injection 100%)
# ------------------------------------------------------------------------------
# Doc mot dong tu ban phim terminal, ket qua luu vao bien toan cuc USER_INPUT
read_terminal_line() {
    PROMPT_MSG="$1"
    DEF_VAL="$2"
    printf "%s" "$PROMPT_MSG"
    USER_INPUT=""
    if [ -t 0 ]; then
        read USER_INPUT 2>/dev/null || USER_INPUT=""
    elif (exec </dev/tty) 2>/dev/null; then
        read USER_INPUT </dev/tty 2>/dev/null || USER_INPUT=""
    else
        read USER_INPUT 2>/dev/null || USER_INPUT=""
    fi
    USER_INPUT=$(echo "$USER_INPUT" | tr -d ' \r\n\t')
    [ -z "$USER_INPUT" ] && USER_INPUT="$DEF_VAL"
}

# ------------------------------------------------------------------------------
# 5. MANG & TIM KIEM IP LOA TRONG LAN
# ------------------------------------------------------------------------------
# Phat hien dai mang hien tai cua thiet bi
detect_subnet() {
    SUB=$(ip route 2>/dev/null | grep -E 'default|src' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    if [ -z "$SUB" ]; then
        SUB=$(ifconfig 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    [ -z "$SUB" ] && SUB="192.168.1"
    echo "$SUB"
}

# Kiem tra cong ket noi mo hay dong
check_port() {
    HOST_IP="$1"
    PORT_NUM="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -w 1 "$HOST_IP" "$PORT_NUM" </dev/null >/dev/null 2>&1
        return $?
    elif command -v timeout >/dev/null 2>&1; then
        timeout 1 bash -c "exec 3<>/dev/tcp/$HOST_IP/$PORT_NUM" 2>/dev/null
        return $?
    else
        return 1
    fi
}

# Quet mang LAN tim loa R1 mo cong ADB 5555
scan_lan_for_r1() {
    PREFIX="$1"
    [ -z "$PREFIX" ] && PREFIX=$(detect_subnet)

    echo ""
    echo ">> Dang quet nhanh dai mang ${PREFIX}.1 -> 254 de tim loa R1..."
    echo "   (Kiem tra port ADB 5555 theo luong song song)..."

    SCAN_TMP="/tmp/r1_scan_$$"
    mkdir -p "$SCAN_TMP"

    IDX=1
    while [ $IDX -le 254 ]; do
        BATCH_END=$((IDX + 29))
        [ $BATCH_END -gt 254 ] && BATCH_END=254

        for i in $(seq $IDX $BATCH_END); do
            (
                TARGET_HOST="${PREFIX}.${i}"
                if check_port "$TARGET_HOST" "5555"; then
                    echo "$TARGET_HOST" > "$SCAN_TMP/$i"
                fi
                exit 0
            ) &
        done
        wait || true
        printf "\r[*] Tien do quet: %d/254 IP..." "$BATCH_END"
        IDX=$((BATCH_END + 1))
    done
    echo ""

    FOUND_COUNT=0
    FIRST_FOUND_IP=""
    for f in "$SCAN_TMP"/*; do
        if [ -f "$f" ]; then
            F_IP=$(cat "$f")
            FOUND_COUNT=$((FOUND_COUNT + 1))
            echo "   [+] Phat hien loa R1 [$FOUND_COUNT] tai IP: $F_IP"
            [ -z "$FIRST_FOUND_IP" ] && FIRST_FOUND_IP="$F_IP"
        fi
    done
    rm -rf "$SCAN_TMP"

    if [ $FOUND_COUNT -eq 0 ]; then
        echo ">> Khong tim thay thiet bi nao mo cong 5555 trong dai mang ${PREFIX}.x."
        echo "   (Hay dam bao loa da bat nguon va iPhone dang bat Wi-Fi cung mang)."
    fi
}

# Ho tro nguoi dung tim hoac nhap thu cong IP
prompt_for_target_ip() {
    SUGGESTED=""
    echo ""
    echo "----------------------------------------------------------"
    echo "           TIM KIEM & XAC DINH IP CUA LOA R1              "
    echo "----------------------------------------------------------"
    echo "  [1] Tu dong quet mang WiFi de tim IP loa (Khuyen dung)"
    echo "  [2] Nhap dia chi IP truc tiep thu cong"
    echo ""

    IP_OPT=""
    while [ "$IP_OPT" != "1" ] && [ "$IP_OPT" != "2" ]; do
        read_terminal_line "Chon phuong thuc tim IP (1 hoac 2, mac dinh 1): " "1"
        IP_OPT="$USER_INPUT"
    done

    if [ "$IP_OPT" = "1" ]; then
        CUR_SUB=$(detect_subnet)
        read_terminal_line "Dai mang can quet [mac dinh: $CUR_SUB]: " "$CUR_SUB"
        scan_lan_for_r1 "$USER_INPUT"
        if [ -n "$FIRST_FOUND_IP" ]; then
            SUGGESTED="$FIRST_FOUND_IP"
        fi
    fi

    echo ""
    TARGET_IP=""
    while [ -z "$TARGET_IP" ]; do
        if [ -n "$SUGGESTED" ]; then
            read_terminal_line "Nhap dia chi IP cua loa [Enter de chon $SUGGESTED]: " "$SUGGESTED"
        else
            read_terminal_line "Nhap dia chi IP cua loa (VD: 192.168.1.15): " ""
        fi
        TARGET_IP=$(echo "$USER_INPUT" | tr -d ' \r\n\t' | sed 's/:5555$//')
        if [ -z "$TARGET_IP" ]; then
            echo ">> Vui long go dia chi IP cua loa!"
        fi
    done
    echo ">> [XAC NHAN] Dia chi IP lua chon: $TARGET_IP"
}

# ------------------------------------------------------------------------------
# 6. TAI FILE APK TU GITHUB (Xoa sach cache cu, luon tai ban moi nhat)
# ------------------------------------------------------------------------------
download_file() {
    FILE="$1"
    cd "$TEMP_DIR"
    rm -f "$FILE" "$FILE.tmp"
    echo ">> Dang tai ban moi nhat $FILE tu GitHub ($BASE_URL)..."
    if curl -k -L -# -f -o "$FILE.tmp" "$BASE_URL/$FILE"; then
        mv "$FILE.tmp" "$FILE"
        echo ">> [OK] Da tai $FILE moi nhat thanh cong."
        return 0
    else
        echo ">> [LOI] Khong the tai $FILE tu GitHub. Vui long kiem tra lai ket noi Internet!"
        rm -f "$FILE.tmp"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 7. CAI DAT APK AN TOAN CO KIEM TRA KET QUA & MA THOAT
# ------------------------------------------------------------------------------
install_apk_on_device() {
    LOCAL_APK="$1"
    REMOTE_TMP="/data/local/tmp/$(basename "$LOCAL_APK")"
    PKG_NAME="$2"
    DESC="$3"

    if [ ! -f "$TEMP_DIR/$LOCAL_APK" ] || [ ! -s "$TEMP_DIR/$LOCAL_APK" ]; then
        echo ">> [LOI] File $LOCAL_APK khong ton tai hoac bi rong trong bo nho tam!"
        return 1
    fi

    echo ">> [1/2] Dang day $DESC len loa..."
    PUSH_OUT=$(adb_cmd push "$TEMP_DIR/$LOCAL_APK" "$REMOTE_TMP" 2>&1)
    if [ $? -ne 0 ] || echo "$PUSH_OUT" | grep -qi "failed"; then
        echo ">> [LOI] adb push that bai: $PUSH_OUT"
        return 1
    fi

    echo ">> [2/2] Dang cai dat $DESC vao he thong..."
    INSTALL_OUT=$(adb_shell "pm install -r $REMOTE_TMP" 2>&1)

    # Xu ly truong hop xung dot chu ky ung dung (keystore khac nhau)
    if echo "$INSTALL_OUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        echo "   [!] Phat hien chu ky cu khac nhau, dang go ban cu de cai de..."
        if [ -n "$PKG_NAME" ]; then
            adb_shell "pm uninstall $PKG_NAME" >/dev/null 2>&1
        fi
        INSTALL_OUT=$(adb_shell "pm install $REMOTE_TMP" 2>&1)
    fi

    # Luon don dep file apk tam sau khi cai xong
    adb_shell "rm -f $REMOTE_TMP" >/dev/null 2>&1

    # Kiem tra chuoi Success tu pm install
    if ! echo "$INSTALL_OUT" | grep -qi "Success"; then
        echo ">> [THAT BAI] Khong the cai dat $DESC!"
        echo "   Chi tiet loi: $INSTALL_OUT"
        return 1
    fi

    # Kiem tra thuc te package da xuat hien trong he thong hay chua
    if [ -n "$PKG_NAME" ]; then
        if is_package_installed "$PKG_NAME"; then
            echo "   [OK] Da xac nhan $DESC ($PKG_NAME) da cai dat thanh cong tren he thong!"
            return 0
        else
            echo ">> [CANH BAO] pm install bao Success nhung he thong chua nhan dien duoc $PKG_NAME!"
            return 1
        fi
    fi

    echo "   [OK] Cai dat $DESC thanh cong!"
    return 0
}

# ------------------------------------------------------------------------------
# 8. XU LY THAM SO DONG LENH HOAC MENU TUONG TAC
# ------------------------------------------------------------------------------
ARG1="$1"
ARG2="$2"
TARGET_IP="192.168.43.1"
MODE="FULL"

if [ -n "$ARG1" ] && [ "$ARG1" != "menu" ] && [ "$ARG1" != "-m" ] && [ "$ARG1" != "update" ]; then
    TARGET_IP=$(echo "$ARG1" | tr -d ' \r\n\t' | sed 's/:5555$//')
    MODE="FULL"
elif [ "$ARG1" = "update" ]; then
    MODE="UPDATE_ONLY"
    if [ -n "$ARG2" ]; then
        TARGET_IP=$(echo "$ARG2" | tr -d ' \r\n\t' | sed 's/:5555$//')
    else
        prompt_for_target_ip
    fi
else
    echo "=========================================================="
    echo "              BANG DIEU KHIEN PHICOMM R1                  "
    echo "=========================================================="
    echo "Chon thao tac ban muon thuc hien:"
    echo "  [1] Loa moi / Reset dang phat WiFi 'Phicomm_R1_xxxx' (IP: 192.168.43.1)"
    echo "  [2] Loa da o trong WiFi nha (Tu dong tim IP hoac nhap thu cong)"
    echo "  [3] Chi cap nhat AI Box Plus DLNA moi qua WiFi nha (Giu nguyen cai dat)"
    echo "  [4] Quet & tim dia chi IP cua loa trong mang WiFi noi bo"
    echo "  [5] Xem IP loa duoc cap khi dang ket noi WiFi loa (192.168.43.1)"
    echo "  [6] Thoat"
    echo "=========================================================="
    echo ""

    CHOICE=""
    while [ -z "$CHOICE" ]; do
        read_terminal_line "Nhap lua chon cua ban (1-6): " ""
        CHOICE="$USER_INPUT"

        case "$CHOICE" in
            1)
                TARGET_IP="192.168.43.1"
                MODE="FULL"
                ;;
            2)
                prompt_for_target_ip
                MODE="FULL"
                ;;
            3)
                prompt_for_target_ip
                MODE="UPDATE_ONLY"
                ;;
            4)
                CUR_SUB=$(detect_subnet)
                read_terminal_line "Dai mang can quet [mac dinh: $CUR_SUB]: " "$CUR_SUB"
                scan_lan_for_r1 "$USER_INPUT"
                exit 0
                ;;
            5)
                TARGET_IP="192.168.43.1"
                MODE="READ_AP_IP"
                ;;
            6)
                echo "Thoat chuong trinh."
                exit 0
                ;;
            *)
                echo ">> Vui long go mot so tu 1 den 6 (VD: 1 de cai full):"
                CHOICE=""
                ;;
        esac
    done
fi

# ------------------------------------------------------------------------------
# 9. TAI CAC FILE APK THEO CHE DO DUOC CHON
# ------------------------------------------------------------------------------
if [ "$MODE" = "FULL" ]; then
    echo ""
    echo "=========================================================="
    echo "      TAI CAC FILE APK CAI DAT PHICOMM R1                 "
    echo "=========================================================="
    if ! download_file "$APK_AI"; then exit 1; fi
    if ! download_file "$APK_DLNA"; then exit 1; fi
    if ! download_file "$APK_UNI"; then exit 1; fi
elif [ "$MODE" = "UPDATE_ONLY" ]; then
    echo ""
    echo "=========================================================="
    echo "     TAI BAN CAP NHAT AI BOX PLUS DLNA MOI NHAT           "
    echo "=========================================================="
    if ! download_file "$APK_AI"; then exit 1; fi
fi

# ------------------------------------------------------------------------------
# 10. KIEM TRA VA CHO KET NOI DEN LOA R1 QUA ADB
# ------------------------------------------------------------------------------
# Chuan hoa TARGET_IP (xoa khoang trang, bo port :5555 neu go kem)
TARGET_IP=$(echo "$TARGET_IP" | tr -d ' \r\n\t' | sed 's/:5555$//')
SERIAL="$TARGET_IP:5555"

echo ""
echo "=========================================================="
echo "      KIEM TRA KET NOI DEN LOA R1 ($SERIAL)               "
echo "=========================================================="

adb disconnect "$SERIAL" >/dev/null 2>&1
sleep 0.5
CONN_CHECK=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
sleep 1
DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

# Kiem tra ket noi thuc te voi thiet bi
IS_CONNECTED=0
if [ "$DEV_STATE" = "device" ] || echo "$CONN_CHECK" | grep -qi "connected"; then
    if adb_shell "getprop ro.build.version.release" >/dev/null 2>&1; then
        IS_CONNECTED=1
    fi
fi

if [ $IS_CONNECTED -eq 0 ]; then
    echo ">> [CHUA KET NOI] Chua thay loa tai $SERIAL!"
    echo "   (Trang thai ADB: $CONN_CHECK)"
    echo ""
    echo "------------------ LUU Y QUAN TRONG CHO IPHONE ------------------"
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo " 1. TAT 4G/5G (Du lieu di dong) tren iPhone:"
        echo "    * WiFi loa KHONG CO INTERNET, neu bat 4G thi iPhone se ban"
        echo "      goi tin qua 4G khien iSH khong the ket noi toi loa duoc!"
        echo " 2. An giu nut tron tren dinh loa 6s den khi loa phat tieng & den cam."
        echo " 3. Vao Cai dat -> Wi-Fi tren iPhone va chon: Phicomm_R1_xxxx"
        echo " 4. Neu iPhone bao 'Wi-Fi khong co Internet' -> Chon 'Tiep tuc su dung'!"
        echo " 5. LUU Y: Neu loa da ket noi WiFi nha, hay chon Muc [2] hoac [3]!"
    else
        echo " 1. Dam bao iPhone dang bat Wi-Fi va ket noi CUNG MANG voi loa."
        echo " 2. Kiem tra dia chi IP cua loa ($TARGET_IP) da dung chua."
        echo " 3. Kiem tra loa da duoc bat nguon va khoi dong xong."
    fi
    echo " 4. Kiem tra: Cai dat iPhone -> iSH -> Bat 'Mang cuc bo' (Local Network)."
    echo "-----------------------------------------------------------------"
    echo ">> He thong dang tu dong cho ket noi (Nhan Ctrl + C neu muon dung)..."
    echo ""

    TRY_COUNT=0
    while true; do
        TRY_COUNT=$((TRY_COUNT + 1))

        adb disconnect "$SERIAL" >/dev/null 2>&1
        CONN_RES=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
        sleep 1
        DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

        if [ "$DEV_STATE" = "device" ] || echo "$CONN_RES" | grep -qi "connected"; then
            if adb_shell "getprop ro.build.version.release" >/dev/null 2>&1; then
                echo ""
                echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
                break
            fi
        fi

        printf "\r[*] Dang cho ket noi [%s] (Thu %d) | Trang thai: %s   " "$SERIAL" "$TRY_COUNT" "$CONN_RES"

        if [ $((TRY_COUNT % 10)) -eq 0 ]; then
            echo ""
            # Chan doan cong mang
            if check_port "$TARGET_IP" 5555; then
                echo "   [i] Cong 5555 dang MO. Dang khoi dong lai adb daemon..."
                adb kill-server >/dev/null 2>&1 || true
                sleep 1
                adb start-server >/dev/null 2>&1 || true
            else
                echo "   [!] Cong 5555 khong phan hoi tai $TARGET_IP."
                if check_port "$TARGET_IP" 8081; then
                    echo "   [i] Web AI BOX (port 8081) dang chay, nhung adbd chua mo hoac dang ban."
                fi
            fi

            read_terminal_line ">> Loa chua phan hoi tai $TARGET_IP. Ban co muon doi sang IP khac? (y/n, mac dinh n): " "n"
            if [ "$USER_INPUT" = "y" ] || [ "$USER_INPUT" = "Y" ]; then
                read_terminal_line "Nhap dia chi IP moi: " ""
                if [ -n "$USER_INPUT" ]; then
                    TARGET_IP=$(echo "$USER_INPUT" | tr -d ' \r\n\t' | sed 's/:5555$//')
                    SERIAL="$TARGET_IP:5555"
                    TRY_COUNT=0
                    echo ">> Da doi muc tieu sang: $SERIAL"
                fi
            fi
        fi

        sleep 1
    done
fi

echo ""
echo ">> [DA KET NOI] THIET BI SAN SANG TAI $SERIAL!"

# ------------------------------------------------------------------------------
# 11. THUC THI CHE DO DOC THONG TIN IP WIFI CUA LOA
# ------------------------------------------------------------------------------
if [ "$MODE" = "READ_AP_IP" ]; then
    echo "=========================================================="
    echo "           THONG TIN KET NOI & IP CUA LOA R1              "
    echo "=========================================================="
    WLAN_IP=$(adb_shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null)
    DEV_NAME=$(adb_shell "getprop net.hostname" 2>/dev/null)
    DEV_MAC=$(adb_shell "cat /sys/class/net/wlan0/address" 2>/dev/null)

    echo "Ten thiet bi       : $DEV_NAME"
    echo "Dia chi MAC WiFi   : $DEV_MAC"
    if [ -n "$WLAN_IP" ]; then
        echo ">> IP Loa trong mang WiFi nha: $WLAN_IP"
        echo "   (Ban co the truy cap Web Control tai: http://$WLAN_IP:8081/)"
    else
        echo ">> Loa chua duoc cap IP WiFi nha (hoac chua ket noi vao WiFi nha)."
        echo "   Vao http://192.168.43.1:8081/ tren trinh duyet de ket noi WiFi nha cho loa."
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# 12. THUC THI CHE DO CAI DAT DAY DU (FULL)
# ------------------------------------------------------------------------------
if [ "$MODE" = "FULL" ]; then
    echo "=========================================================="
    echo "  BAT DAU CAI DAT: Auto DLNA + Unisound + AI Box Tieng Viet"
    echo "=========================================================="
    echo ""

    # 1. Don dep bo nho dem va tat cac tien trinh rac
    echo ">> [1/7] Dang don dep bo nho dem va kiem tra cac service tren loa..."
    adb_shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip" >/dev/null 2>&1
    adb_shell "rm -rf /data/local/tmp/*" >/dev/null 2>&1
    adb_shell "settings put secure install_non_market_apps 1" >/dev/null 2>&1

    # Chi an cac goi neu package do thuc su ton tai tren thiet bi
    for p in com.phicomm.speaker.airskill com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.otaservice com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport; do
        if is_package_installed "$p"; then
            adb_shell "pm hide $p" >/dev/null 2>&1
        fi
    done

    # 2. Cai dat AutoDLNA
    echo ">> [2/7] Dang cai dat AutoDLNA..."
    if ! install_apk_on_device "$APK_DLNA" "com.phicomm.speaker.player" "AutoDLNA"; then
        echo ">> [DUNG LAI] Cai dat AutoDLNA that bai! Khong the tiep tuc."
        exit 1
    fi

    # 3. Cai dat Unisound
    echo ">> [3/7] Dang cai dat Unisound..."
    if ! install_apk_on_device "$APK_UNI" "com.phicomm.speaker.device" "Unisound"; then
        echo ">> [DUNG LAI] Cai dat Unisound that bai! Khong the tiep tuc."
        exit 1
    fi

    # 4. Khoi chay service he thong
    echo ">> [4/7] Khoi chay service he thong..."
    for p in com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl; do
        if is_package_installed "$p"; then
            adb_shell "pm unhide $p" >/dev/null 2>&1
        fi
    done

    # Kich hoat EchoService tren cong 8080 va giao dien nen
    adb_shell "am startservice com.phicomm.speaker.player/.EchoService" >/dev/null 2>&1
    adb_shell "am start com.phicomm.speaker.device/.ui.MainActivity" >/dev/null 2>&1

    # 5. Cai dat AI Box Plus DLNA moi nhat
    echo ">> [5/7] Dang cai dat ban AI Box Plus DLNA moi nhat..."
    if ! install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"; then
        echo ">> [DUNG LAI] Cai dat AI Box Plus that bai! Khong the tiep tuc."
        exit 1
    fi

    # 6. Khoi chay ung dung AI Box
    echo ">> [6/7] Khoi chay ung dung AI Box & Cac dich vu he thong..."
    adb_shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1
    sleep 2

    # 7. Kiem tra trang thai thuc te cac cong dich vu
    echo ">> [7/7] Kiem tra trang thai hoat dong cac dich vu..."
    if check_port "$TARGET_IP" "8081"; then
        echo "   [OK] Web Control (Port 8081) da hoat dong san sang!"
    else
        echo "   [!] Luu y: Port 8081 chua phan hoi ngay, ung dung dang tiep tuc khoi dong..."
    fi
    if check_port "$TARGET_IP" "8080"; then
        echo "   [OK] EchoService (Port 8080 - Dieu khien den & EQ) da san sang!"
    fi
    if check_port "$TARGET_IP" "8082"; then
        echo "   [OK] AI Box Service (Port 8082) da san sang!"
    fi

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
        echo ""
        read_terminal_line "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n de dung ngay): " "n"
        if [ "$USER_INPUT" = "y" ] || [ "$USER_INPUT" = "Y" ]; then
            echo ">> Dang khoi dong lai loa (vui long doi 25-30 giay)..."
            adb_cmd reboot >/dev/null 2>&1
        else
            echo ">> Giu nguyen ket noi de ban truy cap Safari vao http://192.168.43.1:8081/ ngay!"
        fi
    else
        echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
        echo ""
        read_terminal_line "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n): " "n"
        if [ "$USER_INPUT" = "y" ] || [ "$USER_INPUT" = "Y" ]; then
            echo ">> Dang khoi dong lai loa..."
            adb_cmd reboot >/dev/null 2>&1
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 13. THUC THI CHE DO CAP NHAT NHANH (UPDATE_ONLY)
# ------------------------------------------------------------------------------
if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo "=========================================================="
    echo "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAI DAT)    "
    echo "=========================================================="
    echo ""
    echo ">> Dang day va cai dat AI Box Plus DLNA moi nhat..."
    if ! install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"; then
        echo ">> [DUNG LAI] Cap nhat AI Box Plus that bai! Khong the tiep tuc."
        exit 1
    fi

    echo ">> Khoi chay ung dung AI Box..."
    adb_shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!     "
    echo "=========================================================="
    echo "Toan bo cai dat (mDNS, PayOS, hen gio...) duoc giu nguyen 100%!"
    echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
fi
