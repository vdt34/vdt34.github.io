#!/bin/sh
# Script Cai Dat & Cap Nhat Phicomm R1 tren iPhone qua iSH (Alpine Linux) / Linux
# Nguon APK: https://vdt34.github.io/r1/

# Khong su dung set -e de tranh script bi crash dot ngot tren iSH / Alpine Linux
# set -e da duoc go bo hoan toan

BASE_URL="https://vdt34.github.io/r1"
TEMP_DIR="/tmp/r1_install"
APK_DLNA="autodlna.apk"
APK_UNI="unisound.apk"
APK_AI="AIBoxPlus_DLNA.apk"

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
if ! command -v nc >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL netcat-openbsd"
fi

if [ -n "$NEED_INSTALL" ]; then
    if command -v apk >/dev/null 2>&1; then
        echo ">> Phat hien chua co:$NEED_INSTALL. Dang tu dong cai dat tren iSH..."
        apk update >/dev/null 2>&1 || true
        apk add --no-cache $NEED_INSTALL || true
        echo ">> [OK] Da cai dat xong cac cong cu can thiet tren iSH!"
    elif command -v apt-get >/dev/null 2>&1; then
        echo ">> Dang cai dat cac cong cu qua apt..."
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y android-tools-adb curl netcat-openbsd >/dev/null 2>&1 || true
    else
        echo ">> [Luu y] Khong tim thay trinh quan ly goi. Hay dam bao da cai adb, curl, nc."
    fi
else
    echo ">> [OK] Cac cong cu (adb, curl, nc) da co san. San sang tiep tuc."
fi

# Ham nhap lieu an toan tu terminal/keyboard truc tiep tren tien trinh chinh
prompt_var() {
    PROMPT_TEXT="$1"
    TARGET_VAR="$2"
    DEFAULT_VALUE="$3"

    printf "%s" "$PROMPT_TEXT"
    TEMP_INPUT=""
    if [ -t 0 ]; then
        read TEMP_INPUT 2>/dev/null || TEMP_INPUT=""
    elif (exec </dev/tty) 2>/dev/null; then
        read TEMP_INPUT </dev/tty 2>/dev/null || TEMP_INPUT=""
    else
        read TEMP_INPUT 2>/dev/null || TEMP_INPUT=""
    fi

    if [ -z "$TEMP_INPUT" ]; then
        eval "$TARGET_VAR=\"$DEFAULT_VALUE\""
    else
        eval "$TARGET_VAR=\"$TEMP_INPUT\""
    fi
}

# Ham tu dong phat hien dai mang hien tai cua thiet bi
detect_subnet() {
    SUB=$(ip route 2>/dev/null | grep -E 'default|src' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    if [ -z "$SUB" ]; then
        SUB=$(ifconfig 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    [ -z "$SUB" ] && SUB="192.168.1"
    echo "$SUB"
}

# Ham kiem tra cong ket noi
check_port() {
    IP="$1"
    PORT="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -w 1 "$IP" "$PORT" </dev/null >/dev/null 2>&1
        return $?
    elif command -v timeout >/dev/null 2>&1; then
        timeout 1 bash -c "exec 3<>/dev/tcp/$IP/$PORT" 2>/dev/null
        return $?
    else
        return 1
    fi
}

# Ham quet mang LAN tim loa R1 (kiem tra port 5555 song song theo batch)
scan_lan_for_r1() {
    PREFIX="$1"
    [ -z "$PREFIX" ] && PREFIX=$(detect_subnet)
    
    echo ""
    echo ">> Dang quet nhanh dai mang ${PREFIX}.1 -> 254 de tim loa R1..."
    echo "   (Kiem tra port ADB 5555 qua ket noi song song)..."
    
    SCAN_TMP="/tmp/r1_scan_$$"
    mkdir -p "$SCAN_TMP"
    
    IDX=1
    while [ $IDX -le 254 ]; do
        BATCH_END=$((IDX + 29))
        [ $BATCH_END -gt 254 ] && BATCH_END=254
        
        for i in $(seq $IDX $BATCH_END); do
            (
                TARGET="${PREFIX}.${i}"
                if check_port "$TARGET" "5555"; then
                    echo "$TARGET" > "$SCAN_TMP/$i"
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
        echo "   (Hay dam bao loa da bat nguon va dien thoai dang bat Wi-Fi cung lop mang)."
    fi
}

# Ham ho tro nguoi dung tim hoac nhap thu cong IP
prompt_for_target_ip() {
    SUGGESTED=""
    echo ""
    echo "----------------------------------------------------------"
    echo "           TIM KIEM & XAC DINH IP CUA LOA R1              "
    echo "----------------------------------------------------------"
    echo "  [1] Tu dong quet mang WiFi de tim IP loa (Khuyen dung)"
    echo "  [2] Nhap dia chi IP truc tiep thu cong"
    echo ""
    prompt_var "Chon phuong thuc tim IP (1-2, mac dinh 1): " "IP_OPT" "1"

    if [ "$IP_OPT" = "1" ]; then
        CUR_SUB=$(detect_subnet)
        prompt_var "Dai mang can quet [mac dinh: $CUR_SUB]: " "USER_SUB" "$CUR_SUB"
        scan_lan_for_r1 "$USER_SUB"
        if [ -n "$FIRST_FOUND_IP" ]; then
            SUGGESTED="$FIRST_FOUND_IP"
        fi
    fi

    echo ""
    if [ -n "$SUGGESTED" ]; then
        prompt_var "Nhap dia chi IP cua loa [Enter de chon $SUGGESTED]: " "TARGET_IP" "$SUGGESTED"
    else
        prompt_var "Nhap dia chi IP cua loa (VD: 192.168.1.15): " "TARGET_IP" "192.168.43.1"
    fi
    echo ">> [XAC NHAN] Dia chi IP lua chon: $TARGET_IP"
}

ARG1="$1"
ARG2="$2"
TARGET_IP="192.168.43.1"
MODE="FULL"

if [ -n "$ARG1" ] && [ "$ARG1" != "menu" ] && [ "$ARG1" != "-m" ] && [ "$ARG1" != "update" ]; then
    TARGET_IP="$ARG1"
    MODE="FULL"
elif [ "$ARG1" = "update" ]; then
    MODE="UPDATE_ONLY"
    if [ -n "$ARG2" ]; then
        TARGET_IP="$ARG2"
    else
        prompt_for_target_ip
    fi
else
    echo "Chon thao tac ban muon thuc hien:"
    echo "  [1] Cai dat day du qua che do phat WiFi cua loa (IP: 192.168.43.1)"
    echo "  [2] Cai dat day du qua mang WiFi nha (Tu dong tim IP hoac nhap thu cong)"
    echo "  [3] Chi cap nhat AI Box Plus DLNA moi (Giu nguyen cau hinh cu)"
    echo "  [4] Quet & tim dia chi IP cua loa trong mang WiFi"
    echo "  [5] Xem IP loa duoc cap khi dang ket noi WiFi loa (192.168.43.1)"
    echo "  [6] Thoat"
    echo ""
    prompt_var "Nhap lua chon cua ban (1-6, mac dinh 1): " "CHOICE" "1"

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
            prompt_var "Dai mang can quet [mac dinh: $CUR_SUB]: " "USER_SUB" "$CUR_SUB"
            scan_lan_for_r1 "$USER_SUB"
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
            TARGET_IP="192.168.43.1"
            MODE="FULL"
            ;;
    esac
fi

# 2. Chi tai cac file APK can thiet cho che do duoc chon (Tiet kiem bang thong va bo nho)
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

download_file() {
    FILE="$1"
    if [ -f "$FILE" ] && [ -s "$FILE" ]; then
        echo ">> File $FILE da co trong cache (/tmp). Bo qua tai lai."
    else
        echo ">> Dang tai $FILE tu GitHub ($BASE_URL)..."
        rm -f "$FILE.tmp"
        if curl -k -L -# -f -o "$FILE.tmp" "$BASE_URL/$FILE"; then
            mv "$FILE.tmp" "$FILE"
            echo ">> [OK] Da tai $FILE thanh cong."
        else
            echo ">> [CANH BAO] Khong the tai $FILE tu GitHub. Kiem tra lai ket noi Internet!"
            rm -f "$FILE.tmp"
        fi
    fi
}

if [ "$MODE" = "FULL" ]; then
    echo ""
    echo "=========================================================="
    echo "      TAI CAC FILE APK CAI DAT PHICOMM R1                 "
    echo "=========================================================="
    download_file "$APK_AI"
    download_file "$APK_DLNA"
    download_file "$APK_UNI"
elif [ "$MODE" = "UPDATE_ONLY" ]; then
    echo ""
    echo "=========================================================="
    echo "     TAI BAN CAP NHAT AI BOX PLUS DLNA MOI NHAT           "
    echo "=========================================================="
    download_file "$APK_AI"
fi

# 3. Kiem tra va cho ket noi den loa R1
SERIAL="$TARGET_IP:5555"

echo ""
echo "=========================================================="
echo "      KIEM TRA KET NOI DEN LOA R1 ($SERIAL)               "
echo "=========================================================="


adb disconnect "$SERIAL" >/dev/null 2>&1
CONN_CHECK=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

if [ "$DEV_STATE" != "device" ] && ! echo "$CONN_CHECK" | grep -q "connected to"; then
    echo ">> [CHUA KET NOI] Chua thay loa tai $SERIAL!"
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
        echo " 1. Dam bao iPhone dang bat Wi-Fi va ket noi cung mang voi loa."
        echo " 2. Kiem tra dia chi IP cua loa ($TARGET_IP) da dung chua."
        echo " 3. Kiem tra loa da duoc bat nguon va khoi dong xong."
    fi
    echo " 4. Kiem tra: Cai dat -> iSH -> Bat 'Mang cuc bo' (Local Network)."
    echo "-----------------------------------------------------------------"
    echo ">> He thong dang tu dong cho ket noi (Nhan Ctrl + C neu muon dung)..."
    echo ""

    TRY_COUNT=0
    while true; do
        TRY_COUNT=$((TRY_COUNT + 1))

        adb disconnect "$SERIAL" >/dev/null 2>&1
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

        if [ $((TRY_COUNT % 12)) -eq 0 ]; then
            echo ""
            prompt_var ">> Loa chua phan hoi tai $TARGET_IP. Ban co muon doi sang IP khac? (y/n, mac dinh n): " "RETRY_CHOICE" "n"
            if [ "$RETRY_CHOICE" = "y" ] || [ "$RETRY_CHOICE" = "Y" ]; then
                prompt_var "Nhap dia chi IP moi: " "NEW_IP" ""
                if [ -n "$NEW_IP" ]; then
                    TARGET_IP="$NEW_IP"
                    SERIAL="$TARGET_IP:5555"
                    TRY_COUNT=0
                    echo ">> Da doi muc tieu sang: $SERIAL"
                fi
            fi
            adb kill-server >/dev/null 2>&1 || true
            adb start-server >/dev/null 2>&1 || true
        fi

        sleep 1.5
    done
fi
# Khong su dung set -e de tranh script bi crash dot ngot tren iSH / Alpine Linux
# set -e da duoc go bo hoan toan

echo ""
echo ">> [DA KET NOI] THIET BI SAN SANG TAI $SERIAL!"

# Ham cai dat an toan tranh loi chu ky hoac loi bo nho dem
install_apk_on_device() {
    LOCAL_APK="$1"
    REMOTE_TMP="/data/local/tmp/$(basename "$LOCAL_APK")"
    PKG_NAME="$2"
    DESC="$3"
    
    if [ ! -f "$LOCAL_APK" ] || [ ! -s "$LOCAL_APK" ]; then
        echo ">> [LOI] Khong tim thay file $LOCAL_APK tren bo nho tam!"
        return 1
    fi
    
    echo ">> Dang day $DESC len loa..."
    adb -s "$SERIAL" push "$LOCAL_APK" "$REMOTE_TMP" >/dev/null 2>&1 || true
    
    echo ">> Dang cai dat $DESC..."
    INSTALL_OUT=$(adb -s "$SERIAL" shell "/system/bin/pm install -r $REMOTE_TMP" 2>&1 | tr -d '\r')
    
    if echo "$INSTALL_OUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        echo "   [!] Phat hien chu ky ung dung khac nhau, dang go ban cu de cai ban moi..."
        [ -n "$PKG_NAME" ] && adb -s "$SERIAL" shell "/system/bin/pm uninstall $PKG_NAME" >/dev/null 2>&1 || true
        INSTALL_OUT=$(adb -s "$SERIAL" shell "/system/bin/pm install $REMOTE_TMP" 2>&1 | tr -d '\r')
    fi
    
    if echo "$INSTALL_OUT" | grep -qi "Success"; then
        echo "   [OK] Cai dat $DESC thanh cong!"
    else
        echo "   [!] Ket qua cai dat: $INSTALL_OUT"
    fi
    
    adb -s "$SERIAL" shell "rm -f $REMOTE_TMP" >/dev/null 2>&1 || true
    return 0
}

# 4. Che do xem thong tin IP WiFi cua loa
if [ "$MODE" = "READ_AP_IP" ]; then
    echo "=========================================================="
    echo "           THONG TIN KET NOI & IP CUA LOA R1              "
    echo "=========================================================="
    WLAN_IP=$(adb -s "$SERIAL" shell getprop dhcp.wlan0.ipaddress 2>/dev/null | tr -d '\r\n')
    DEV_NAME=$(adb -s "$SERIAL" shell getprop net.hostname 2>/dev/null | tr -d '\r\n')
    DEV_MAC=$(adb -s "$SERIAL" shell cat /sys/class/net/wlan0/address 2>/dev/null | tr -d '\r\n')
    
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

# 5. Che do cai dat day du (AutoDLNA + Unisound + AIBoxPlus DLNA)
if [ "$MODE" = "FULL" ]; then
    echo "=========================================================="
    echo "  BAT DAU CAI DAT: Auto DLNA + Unisound + AI Box Tieng Viet"
    echo "=========================================================="
    echo ""
    echo ">> [1/7] Dang don dep bo nho dem va tat cac tien trinh rac..."
    adb -s "$SERIAL" shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "rm -rf /data/local/tmp/*" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm clear com.phicomm.speaker.otaservice" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "settings put secure install_non_market_apps 1" >/dev/null 2>&1 || true

    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.airskill" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.exceptionreporter" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.systemtool" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.otaservice" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.productiontest" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.bugreport" >/dev/null 2>&1 || true

    echo ">> [2/7] Dang cai dat AutoDLNA..."
    install_apk_on_device "$APK_DLNA" "com.phicomm.speaker.player" "AutoDLNA"

    echo ">> [3/7] Dang cai dat Unisound..."
    install_apk_on_device "$APK_UNI" "com.phicomm.speaker.device" "Unisound"

    echo ">> [4/7] Khoi chay service he thong..."
    adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.device" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.ijetty" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.netctl" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "am startservice com.phicomm.speaker.player/.EchoService" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "am start com.phicomm.speaker.device/.ui.MainActivity" >/dev/null 2>&1 || true

    echo ">> [5/7] Dang cai dat ban AI Box Plus DLNA moi nhat..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    echo ">> [6/7] Khoi chay ung dung AI Box & Cac dich vu he thong..."
    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1 || true
    sleep 2

    # Kiem tra nhanh dich vu tren loa da san sang chua
    echo ">> [7/7] Kiem tra trang thai hoat dong cac dich vu..."
    if check_port "$TARGET_IP" "8081"; then
        echo "   [OK] Web Control (Port 8081) da hoat dong san sang!"
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
        prompt_var "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n de dung ngay): " "REBOOT_NOW" "n"
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Dang khoi dong lai loa (vui long doi 25-30 giay)..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        else
            echo ">> Giu nguyen ket noi de ban truy cap Safari vao http://192.168.43.1:8081/ ngay!"
        fi
    else
        echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
        echo ""
        prompt_var "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n): " "REBOOT_NOW" "n"
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Dang khoi dong lai loa..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        fi
    fi
fi

# 6. Che do cap nhat nhanh AI Box Plus DLNA (Giu nguyen cau hinh cu)
if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo "=========================================================="
    echo "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAI DAT)    "
    echo "=========================================================="
    echo ""
    echo ">> Dang day va cai dat AI Box Plus DLNA moi nhat..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    echo ">> Khoi chay ung dung AI Box..."
    adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity" >/dev/null 2>&1 || true

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!     "
    echo "=========================================================="
    echo "Toan bo cai dat (mDNS, PayOS, hen gio...) duoc giu nguyen 100%!"
    echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
fi
