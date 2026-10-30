#!/bin/sh
# ==============================================================================
# Script Cai Dat & Cap Nhat Phicomm R1 tren iPhone qua iSH / Android / Linux
# Nguon APK: https://vdt34.github.io/r1/
# Phien ban: 2026 Sieu Ket Noi (On dinh - Bat tay ngay lap tuc)
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
TEMP_DIR="/tmp/r1_install"
APK_DLNA="autodlna.apk"
APK_UNI="unisound.apk"
APK_AI="AIBoxPlus_DLNA.apk"

# Tu dong luu script thanh file cuc bo de khong bi dut doan khi chuyen mang WiFi loa (192.168.43.1)
if [ "$R1_EXEC_LOCAL" != "1" ]; then
    SELF_TMP="/tmp/r1_install_exec.sh"
    case "$0" in
        sh|-sh|bash|-bash|*/sh|*/bash|"")
            if command -v curl >/dev/null 2>&1; then
                curl -k -sL "$BASE_URL/install.sh" -o "$SELF_TMP" 2>/dev/null || true
                if [ -f "$SELF_TMP" ] && [ -s "$SELF_TMP" ]; then
                    export R1_EXEC_LOCAL=1
                    exec sh "$SELF_TMP" "$@"
                    exit 0
                fi
            fi
            ;;
    esac
fi

clear
echo "=========================================================="
echo "    KHOI TAO MOI TRUONG CAI DAT PHICOMM R1 TU DONG"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. TU DONG KIEM TRA VA CAI DAT CONG CU NEN
# ------------------------------------------------------------------------------
NEED_INSTALL=""
if ! command -v adb >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL adb"
fi
if ! command -v curl >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL curl"
fi

if [ -n "$NEED_INSTALL" ]; then
    echo ">> Phat hien thieu:$NEED_INSTALL. Dang tu dong cai dat..."
    if command -v apk >/dev/null 2>&1; then
        apk update >/dev/null 2>&1 || true
        apk add --no-cache android-tools curl >/dev/null 2>&1 || true
    elif command -v pkg >/dev/null 2>&1; then
        pkg update -y >/dev/null 2>&1 || true
        pkg install -y android-tools curl >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y android-tools-adb curl >/dev/null 2>&1 || true
    fi
fi

if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo ">> [CANH BAO] Khong the tu dong cai adb hoac curl."
    echo "   Vui long cai dat adb truoc khi tiep tuc."
else
    echo ">> [OK] Cac cong cu (adb, curl) da san sang tren may."
fi

# ------------------------------------------------------------------------------
# 2. HAM NHAP LIEU AN TOAN
# ------------------------------------------------------------------------------
read_input() {
    PROMPT_MSG="$1"
    DEF_VAL="$2"
    printf "%s" "$PROMPT_MSG" >&2
    INPUT_VAL=""
    if [ -t 0 ]; then
        read INPUT_VAL 2>/dev/null || INPUT_VAL=""
    elif [ -e /dev/tty ]; then
        read INPUT_VAL </dev/tty 2>/dev/null || INPUT_VAL=""
    else
        read INPUT_VAL 2>/dev/null || INPUT_VAL=""
    fi
    INPUT_VAL=$(echo "$INPUT_VAL" | tr -d '\r\n')
    [ -z "$INPUT_VAL" ] && INPUT_VAL="$DEF_VAL"
    echo "$INPUT_VAL"
}

# ------------------------------------------------------------------------------
# 3. HAM TU DONG TIM SUB-NET MANG
# ------------------------------------------------------------------------------
detect_subnet() {
    SUB=""
    if command -v ip >/dev/null 2>&1; then
        SUB=$(ip route 2>/dev/null | grep -E 'default|src' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -z "$SUB" ] && command -v ifconfig >/dev/null 2>&1; then
        SUB=$(ifconfig 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -z "$SUB" ] && command -v route >/dev/null 2>&1; then
        SUB=$(route -n get default 2>/dev/null | grep 'gateway' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    [ -z "$SUB" ] && SUB="192.168.1"
    echo "$SUB"
}

# ------------------------------------------------------------------------------
# 4. HAM QUET MANG LAN TIM LOA R1
# ------------------------------------------------------------------------------
scan_lan_for_r1() {
    PREFIX="$1"
    [ -z "$PREFIX" ] && PREFIX=$(detect_subnet)
    
    echo ""
    echo ">> Dang quet nhanh dai mang ${PREFIX}.1 -> 254 de tim loa Phicomm R1..."
    
    SCAN_TMP="/tmp/r1_scan_$$"
    mkdir -p "$SCAN_TMP"
    
    IDX=1
    while [ $IDX -le 254 ]; do
        BATCH_END=$((IDX + 29))
        [ $BATCH_END -gt 254 ] && BATCH_END=254
        
        i=$IDX
        while [ $i -le $BATCH_END ]; do
            (
                TARGET="${PREFIX}.${i}"
                if command -v nc >/dev/null 2>&1; then
                    if nc -w 1 -z "$TARGET" 5555 >/dev/null 2>&1; then
                        echo "$TARGET" > "$SCAN_TMP/$i"
                    fi
                fi
            ) &
            i=$((i + 1))
        done
        wait
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
        echo "   (Hay dam bao loa da cam nguon va thiet bi dang bat Wi-Fi cung lop mang)."
    fi
}

prompt_for_target_ip() {
    SUGGESTED=""
    echo ""
    echo "----------------------------------------------------------"
    echo "           TIM KIEM & XAC DINH IP CUA LOA R1              "
    echo "----------------------------------------------------------"
    echo "  [1] Tu dong quet mang WiFi de tim IP loa (Khuyen dung)"
    echo "  [2] Nhap truc tiep dia chi IP loa thu cong"
    echo ""
    IP_OPT=$(read_input "Chon phuong thuc tim IP (1-2, mac dinh 1): " "1")

    if [ "$IP_OPT" = "1" ]; then
        CUR_SUB=$(detect_subnet)
        USER_SUB=$(read_input "Dai mang can quet [mac dinh: $CUR_SUB]: " "$CUR_SUB")
        scan_lan_for_r1 "$USER_SUB"
        if [ -n "$FIRST_FOUND_IP" ]; then
            SUGGESTED="$FIRST_FOUND_IP"
        fi
    fi

    echo ""
    if [ -n "$SUGGESTED" ]; then
        TARGET_IP=$(read_input "Nhap dia chi IP cua loa [Enter de chon $SUGGESTED]: " "$SUGGESTED")
    else
        TARGET_IP=$(read_input "Nhap dia chi IP cua loa (VD: 192.168.1.15): " "192.168.43.1")
    fi
    TARGET_IP=$(echo "$TARGET_IP" | sed 's/:5555$//')
    echo ">> [XAC NHAN] Dia chi IP lua chon: $TARGET_IP"
}

# ------------------------------------------------------------------------------
# 5. XU LY THAM SO HOAC HIEN THI MENU DIEU KHIEN
# ------------------------------------------------------------------------------
ARG1="$1"
ARG2="$2"
TARGET_IP="192.168.43.1"
MODE="FULL"

if [ -n "$ARG1" ] && [ "$ARG1" != "menu" ] && [ "$ARG1" != "-m" ] && [ "$ARG1" != "update" ]; then
    TARGET_IP=$(echo "$ARG1" | sed 's/:5555$//')
    MODE="FULL"
elif [ "$ARG1" = "update" ]; then
    MODE="UPDATE_ONLY"
    if [ -n "$ARG2" ]; then
        TARGET_IP=$(echo "$ARG2" | sed 's/:5555$//')
    else
        prompt_for_target_ip
    fi
else
    echo "Chon thao tac ban muon thuc hien:"
    echo "  [1] Cai dat SIEU TOC qua WiFi loa phat ra (IP: 192.168.43.1) [Khuyen dung]"
    echo "  [2] Cai dat day du qua mang WiFi nha (Tu tim hoac nhap IP thu cong)"
    echo "  [3] Chi cap nhat ban AI Box Plus DLNA moi nhat (Giu nguyen cai dat cu)"
    echo "  [4] Quet & tim dia chi IP cua loa R1 trong mang WiFi nha"
    echo "  [5] Xem IP WiFi loa nhan duoc khi dang ket noi WiFi loa (192.168.43.1)"
    echo "  [6] Thoat"
    echo ""
    CHOICE=$(read_input "Nhap lua chon cua ban (1-6, mac dinh 1): " "1")

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
            USER_SUB=$(read_input "Dai mang can quet [mac dinh: $CUR_SUB]: " "$CUR_SUB")
            scan_lan_for_r1 "$USER_SUB"
            exit 0
            ;;
        5)
            TARGET_IP="192.168.43.1"
            MODE="READ_AP_IP"
            ;;
        6)
            echo "Thoat chuong trinh. Tam biet!"
            exit 0
            ;;
        *)
            TARGET_IP="192.168.43.1"
            MODE="FULL"
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# 6. QUAN LY BO NHO DEM & TAI FILE APK TU GITHUB
# ------------------------------------------------------------------------------
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

echo ""
echo "=========================================================="
echo "    QUAN LY TAI VE & CAP NHAT FILE APK TU GITHUB          "
echo "=========================================================="

download_apk() {
    FILE="$1"
    MIN_SZ="$2"
    DESC="$3"
    
    # 1. Kiem tra neu trong cache da co file day du dung luong
    if [ -f "$FILE" ]; then
        SZ=$(wc -c < "$FILE" 2>/dev/null | tr -d ' \r\n\t')
        if [ -n "$SZ" ] && [ "$SZ" -ge "$MIN_SZ" ]; then
            echo ">> [DA CO SAN] $DESC ($FILE) - Kich thuoc: ${SZ} bytes."
            return 0
        fi
    fi
    
    # 2. Neu chua co, thu tai tu GitHub
    echo ">> Dang tai $DESC tu GitHub ($BASE_URL/$FILE)..."
    if curl -k -L -f --connect-timeout 10 -# -o "$FILE.tmp" "$BASE_URL/$FILE"; then
        mv -f "$FILE.tmp" "$FILE"
        echo ">> [OK] Da tai xong $DESC thanh cong."
        return 0
    else
        rm -f "$FILE.tmp"
        if [ -f "$FILE" ] && [ -s "$FILE" ]; then
            echo ">> [LUU Y] Khong the tai ban moi tu GitHub, su dung ban hien co trong may."
            return 0
        fi
        echo ">> [LOI] Khong the tai $DESC! Vui long kiem tra ket noi Internet."
        return 1
    fi
}

DOWNLOAD_ERR=0
if [ "$MODE" = "FULL" ]; then
    download_apk "$APK_DLNA" 5000000 "AutoDLNA" || DOWNLOAD_ERR=1
    download_apk "$APK_UNI" 25000000 "Unisound" || DOWNLOAD_ERR=1
    download_apk "$APK_AI" 10000000 "AI Box Plus DLNA" || DOWNLOAD_ERR=1
elif [ "$MODE" = "UPDATE_ONLY" ]; then
    download_apk "$APK_AI" 10000000 "AI Box Plus DLNA" || DOWNLOAD_ERR=1
fi

if [ $DOWNLOAD_ERR -ne 0 ]; then
    echo ""
    echo "=========================================================="
    echo "  [LOI THIEU FILE CAI DAT DO CHUA CO INTERNET]"
    echo "=========================================================="
    echo "Ban dang ket noi vao WiFi cua loa (192.168.43.1 khong co mang)"
    echo "hoac mang bi gian doan, nen chua co file APK trong may."
    echo ""
    echo "CACH XU LY:"
    echo " 1. Chuyen dien thoai ve WiFi nha (hoac bat 4G/5G)."
    echo " 2. Chay lai script nay de tai tron ven 3 file APK vao may."
    echo " 3. Khi da co file trong may, ket noi WiFi loa de FLASH SIEU TOC!"
    echo "=========================================================="
    exit 1
fi

echo ">> [HOAN TAT TAI FILE] Toan bo file cai dat da san sang trong may!"

# ------------------------------------------------------------------------------
# 7. KET NOI TOI LOA R1 (CHUAN XAC, ON DINH - BAT TAY NGAY LAP TUC)
# ------------------------------------------------------------------------------
SERIAL="$TARGET_IP:5555"

echo ""
echo "=========================================================="
echo "      KIEM TRA KET NOI DEN LOA R1 ($SERIAL)               "
echo "=========================================================="

# Khoi dong adb server tren may
adb start-server >/dev/null 2>&1 || true

if [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo "------------------ HUONG DAN KET NOI WIFI LOA (AP) ------------------"
    echo " 1. TAT 4G/5G (Du lieu di dong) tren dien thoai:"
    echo "    * WiFi loa KHONG CO INTERNET, neu bat 4G thi dien thoai se ban"
    echo "      goi tin qua 4G khien iSH/Termux khong the ket noi toi loa duoc!"
    echo " 2. An giu nut tron tren dinh loa 6 giay den khi loa keu bip & doi den cam."
    echo " 3. Vao Cai dat -> Wi-Fi tren dien thoai, chon mang: Phicomm_R1_xxxx"
    echo " 4. Neu dien thoai bao 'Wi-Fi khong co Internet' -> Chon 'Tiep tuc dung'!"
    echo " 5. iPhone: Vao Cai dat may -> iSH -> Bat 'Mang cuc bo' (Local Network)."
    echo "---------------------------------------------------------------------"
else
    echo " 1. Dam bao dien thoai dang bat Wi-Fi va ket noi cung lop mang voi loa."
    echo " 2. Dia chi IP muc tieu cua loa: $TARGET_IP"
    echo " 3. iPhone: Vao Cai dat may -> iSH -> Bat 'Mang cuc bo' (Local Network)."
fi

echo ">> He thong dang tu dong cho ket noi (Nhan Ctrl + C neu muon dung)..."
echo ""

# Ham kiem tra loa da ket noi va san sang chua
is_r1_ready() {
    # 1. Kiem tra trang thai thiet bi tren adb
    DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')
    if [ "$DEV_STATE" = "device" ]; then
        return 0
    fi
    # 2. Hoac kiem tra qua lenh adb devices
    if adb devices 2>/dev/null | grep "$SERIAL" | grep -v "offline" | grep -q "device"; then
        return 0
    fi
    # 3. Hoac kiem tra thu thi shell nhanh
    if adb -s "$SERIAL" shell "echo 1" 2>/dev/null | grep -q "1"; then
        return 0
    fi
    return 1
}

# Ket noi thu lan dau
CONN_INIT=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
sleep 1

if ! is_r1_ready; then
    # Neu bao already connected ma get-state khong phai device (socket ma tren adb daemon)
    if echo "$CONN_INIT" | grep -q "already connected"; then
        echo ">> Phat hien socket cu dang giu, dang lam sach ket noi..."
        adb disconnect "$SERIAL" >/dev/null 2>&1 || true
        adb kill-server >/dev/null 2>&1 || true
        sleep 1
        adb start-server >/dev/null 2>&1 || true
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        sleep 1
    fi

    TRY_COUNT=0
    while true; do
        TRY_COUNT=$((TRY_COUNT + 1))

        if is_r1_ready; then
            echo ""
            echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
            break
        fi

        CONN_RES=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
        DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

        if is_r1_ready; then
            echo ""
            echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
            break
        fi

        printf "\r[*] Dang cho ket noi [%s] (Thu %d) | Trang thai: %s   " "$SERIAL" "$TRY_COUNT" "$CONN_RES"

        # Neu bi ket 'already connected' hoac sau moi 6 lan thu (~7s), lam sach adb server de bat tay lai
        if echo "$CONN_RES" | grep -q "already connected" || [ $((TRY_COUNT % 6)) -eq 0 ]; then
            adb disconnect "$SERIAL" >/dev/null 2>&1 || true
            adb kill-server >/dev/null 2>&1 || true
            sleep 0.8
            adb start-server >/dev/null 2>&1 || true
        fi

        # Sau 18 lan thu (~20s) o che do WiFi nha ma chua duoc, hoi nguoi dung
        if [ $((TRY_COUNT % 18)) -eq 0 ]; then
            if [ "$TARGET_IP" != "192.168.43.1" ]; then
                echo ""
                RETRY_CHOICE=$(read_input ">> Chua thay loa tai $TARGET_IP. Ban co muon doi IP khac? (y/n, mac dinh n): " "n")
                if [ "$RETRY_CHOICE" = "y" ] || [ "$RETRY_CHOICE" = "Y" ]; then
                    NEW_IP=$(read_input "Nhap dia chi IP moi: " "")
                    if [ -n "$NEW_IP" ]; then
                        TARGET_IP=$(echo "$NEW_IP" | sed 's/:5555$//')
                        SERIAL="$TARGET_IP:5555"
                        TRY_COUNT=0
                        echo ">> Da doi muc tieu sang: $SERIAL"
                    fi
                fi
            fi
        fi

        sleep 1.2
    done
else
    echo ">> [THANH CONG] Da ket noi duoc den loa tai $SERIAL!"
fi

echo ""
echo ">> [SAN SANG] BAT DAU QUA TRINH CAI DAT CHO LOA R1..."

# ------------------------------------------------------------------------------
# 8. HAM CAI DAT APK AN TOAN, XU LY XUNG DOT CHU KY
# ------------------------------------------------------------------------------
install_apk_on_device() {
    LOCAL_APK="$1"
    REMOTE_TMP="/data/local/tmp/$(basename "$LOCAL_APK")"
    PKG_NAME="$2"
    DESC="$3"
    
    printf "   -> Dang truyen %s sang loa... " "$DESC"
    adb -s "$SERIAL" push "$LOCAL_APK" "$REMOTE_TMP" >/dev/null 2>&1
    printf "Dang cai dat... "
    INSTALL_OUT=$(adb -s "$SERIAL" shell "pm install -r $REMOTE_TMP" 2>&1 | tr -d '\r')
    
    # Neu bi loi khac biet chu ky ung dung cu
    if echo "$INSTALL_OUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        printf "\n   [!] Khac chu ky cu, dang go ban cu de cai moi... "
        [ -n "$PKG_NAME" ] && adb -s "$SERIAL" shell "pm uninstall $PKG_NAME" >/dev/null 2>&1 || true
        INSTALL_OUT=$(adb -s "$SERIAL" shell "pm install $REMOTE_TMP" 2>&1 | tr -d '\r')
    fi
    
    if echo "$INSTALL_OUT" | grep -qi "Success"; then
        echo "[THANG CONG]"
    else
        echo "[LOI]: $INSTALL_OUT"
    fi
    
    adb -s "$SERIAL" shell "rm -f $REMOTE_TMP" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# 9. CHE DO XEM THONG TIN IP WIFI CUA LOA (192.168.43.1)
# ------------------------------------------------------------------------------
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
        echo "   (Ban co the vao Web Control dieu khien tai: http://$WLAN_IP:8081/)"
    else
        echo ">> Loa chua co IP mang WiFi nha (hoac chua cai dat WiFi)."
        echo "   Vao http://192.168.43.1:8081/wifi.html de ket noi WiFi nha cho loa."
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# 10. CHE DO CAI DAT DAY DU: AUTODLNA + UNISOUND + AI BOX PLUS
# ------------------------------------------------------------------------------
if [ "$MODE" = "FULL" ]; then
    echo "=========================================================="
    echo "  BAT DAU CAI DAT: AutoDLNA + Unisound + AI Box Plus DLNA"
    echo "=========================================================="
    echo ""
    
    # 10.1 Tat toan bo tien trinh chiem quyen & xung dot
    echo ">> [1/5] Tat toan bo tien trinh chiem quyen, xung dot am thanh & micro..."
    adb -s "$SERIAL" shell "
        # 1. Giu loa luon thuc (chong sleep lam dut AP)
        svc power stayon true 2>/dev/null

        # 2. Force-stop cac tien trinh cu dang chiem am thanh/micro/cong mang
        am force-stop info.dourok.voicebot 2>/dev/null
        am force-stop com.phicomm.speaker.player 2>/dev/null
        am force-stop com.phicomm.speaker.device 2>/dev/null
        am force-stop com.phicomm.speaker.airskill 2>/dev/null
        am force-stop com.phicomm.speaker.otaservice 2>/dev/null
        am force-stop com.phicomm.speaker.exceptionreporter 2>/dev/null
        am force-stop com.phicomm.speaker.systemtool 2>/dev/null
        am force-stop com.phicomm.speaker.productiontest 2>/dev/null
        am force-stop com.phicomm.speaker.bugreport 2>/dev/null
        am force-stop com.phicomm.speaker.remote 2>/dev/null
        am force-stop com.tencent.qqmusic 2>/dev/null

        # 3. Dung cac daemon media chay ngam neu co
        killall -9 shairport dlna mpd 2>/dev/null

        # 4. Vo hieu hoa cac app gay chiem quyen/tu tat WiFi AP cua Phicomm
        for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do
            pm hide \$p 2>/dev/null
            pm disable \$p 2>/dev/null
        done

        # 5. Don sach cache OTA va bat quyen cai dat ngoai
        rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null
        rm -rf /data/local/tmp/* 2>/dev/null
        pm clear com.phicomm.speaker.otaservice 2>/dev/null
        settings put secure install_non_market_apps 1 2>/dev/null
    " >/dev/null 2>&1
    echo "   [OK] Da giai phong hoan toan am thanh, micro va cac cong mang!"

    # 10.2 Cai dat AutoDLNA
    echo ">> [2/5] Cai dat AutoDLNA (Dieu khien nhac & Web Control)..."
    install_apk_on_device "$APK_DLNA" "com.phicomm.speaker.player" "AutoDLNA"

    # 10.3 Cai dat Unisound
    echo ">> [3/5] Cai dat Unisound (Dieu khien phan cung & he thong)..."
    install_apk_on_device "$APK_UNI" "com.phicomm.speaker.device" "Unisound"

    # 10.4 Cai dat AI Box Plus DLNA
    echo ">> [4/5] Cai dat AI Box Plus DLNA (Tro ly Tieng Viet & DLNA)..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    # 10.5 Mo khoa va khoi chay toan bo dich vu
    echo ">> [5/5] Mo khoa va khoi chay toan bo dich vu he thong..."
    adb -s "$SERIAL" shell "
        for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do
            pm unhide \$p 2>/dev/null
            pm enable \$p 2>/dev/null
        done
        am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null
        am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null
        am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null

        # Tu dong cau hinh ngay sau khi cai: BAT DLNA, AirPlay, Bluetooth & Den RGB; TAT Den vien & Den cho
        settings put global bluetooth_on 1 2>/dev/null
        service call bluetooth_manager 6 2>/dev/null
        mkdir -p /data/data/info.dourok.voicebot/shared_prefs 2>/dev/null
        setprop persist.sys.r1_led 0 2>/dev/null
        lights_test set 7fffff8000 0 2>/dev/null
        lights_test set 7fffff0000 ffffff 2>/dev/null
    " >/dev/null 2>&1

    sleep 1

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!        "
    echo "=========================================================="
    echo "Toan bo ung dung & dich vu da duoc kich hoat SAN SANG DUNG NGAY!"
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo "Ket noi WiFi giua may ban va loa duoc GIU NGUYEN (khong bi ngat)."
        echo ""
        echo ">>> CAC BUOC CAU HINH WIFI NHA (HAY THUC HIEN NGAY):"
        echo " 1. Mo trinh duyet Safari hoac Chrome tren may, truy cap:"
        echo "    👉 http://192.168.43.1:8081/wifi.html (de cai WiFi nha cho loa)"
        echo "    hoac: http://192.168.43.1:8081/ (giao dien dieu khien Web)"
        echo " 2. Chon ten WiFi nha ban, nhap mat khau -> Loa se phat am thong bao."
        echo " 3. Sau khi loa da noi WiFi nha, chuyen may ban ve WiFi nha va tan huong!"
        echo "=========================================================="
        echo ""
        REBOOT_NOW=$(read_input "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n de vao web ngay): " "n")
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Dang khoi dong lai loa (vui long doi 25-30 giay)..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        else
            echo ">> Giu nguyen ket noi de ban vao http://192.168.43.1:8081/wifi.html ngay!"
        fi
    else
        echo "Truy cap giao dien web dieu khien loa tai: http://$TARGET_IP:8081/"
        echo "=========================================================="
        echo ""
        REBOOT_NOW=$(read_input "Ban co muon khoi dong lai loa bay gio khong? (y/n, mac dinh n): " "n")
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Dang khoi dong lai loa..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 11. CHE DO CAP NHAT NHANH AI BOX PLUS DLNA
# ------------------------------------------------------------------------------
if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo "=========================================================="
    echo "  CAP NHAT NHANH AI BOX PLUS DLNA (GIU NGUYEN CAU HINH)   "
    echo "=========================================================="
    echo ""
    
    echo ">> [1/3] Tat tien trinh cu & don dep cac app xung dot..."
    adb -s "$SERIAL" shell "
        am force-stop info.dourok.voicebot 2>/dev/null
        for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport; do
            pm hide \$p 2>/dev/null
            pm disable \$p 2>/dev/null
        done
        rm -rf /data/local/tmp/* 2>/dev/null
    " >/dev/null 2>&1

    echo ">> [2/3] Dang chuyen va cai dat AI Box Plus DLNA moi nhat..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    echo ">> [3/3] Khoi chay ung dung AI Box Plus..."
    adb -s "$SERIAL" shell "
        pm unhide info.dourok.voicebot 2>/dev/null
        pm enable info.dourok.voicebot 2>/dev/null
        am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null

        # Tu dong cau hinh ngay sau khi cap nhat: BAT DLNA, AirPlay, Bluetooth & Den RGB; TAT Den vien & Den cho
        settings put global bluetooth_on 1 2>/dev/null
        service call bluetooth_manager 6 2>/dev/null
        mkdir -p /data/data/info.dourok.voicebot/shared_prefs 2>/dev/null
        setprop persist.sys.r1_led 0 2>/dev/null
        lights_test set 7fffff8000 0 2>/dev/null
        lights_test set 7fffff0000 ffffff 2>/dev/null
    " >/dev/null 2>&1

    echo ""
    echo "=========================================================="
    echo "     [HOAN TAT] CAP NHAT AI BOX PLUS DLNA THANH CONG!     "
    echo "=========================================================="
    echo "Toan bo cai dat (mDNS, PayOS, hen gio...) duoc giu nguyen 100%!"
    echo "Truy cap giao dien web dieu khien tai: http://$TARGET_IP:8081/"
fi
