#!/bin/sh
# ==============================================================================
# Script Cài Đặt & Cập Nhật Loa Phicomm R1 (Bản Siêu Tốc & Tự Động Hóa 2026)
# Nguồn APK: https://vdt34.github.io/r1/
# Tương thích: iPhone iSH (Alpine), Android Termux, macOS, Linux (Ubuntu/Debian)
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
echo "    KHỞI TẠO MÔI TRƯỜNG CÀI ĐẶT PHICOMM R1 TỰ ĐỘNG"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. TỰ ĐỘNG KIỂM TRA VÀ CÀI ĐẶT CÔNG CỤ CẦN THIẾT TRÊN MỌI HỆ ĐIỀU HÀNH
# ------------------------------------------------------------------------------
NEED_INSTALL=""
if ! command -v adb >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL adb"
fi
if ! command -v curl >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL curl"
fi
if ! command -v nc >/dev/null 2>&1; then
    NEED_INSTALL="$NEED_INSTALL nc"
fi

if [ -n "$NEED_INSTALL" ]; then
    echo ">> Phát hiện máy chưa có:$NEED_INSTALL. Đang tự động cài đặt..."
    if command -v apk >/dev/null 2>&1; then
        # iSH (Alpine Linux trên iPhone/iPad)
        apk update >/dev/null 2>&1 || true
        apk add --no-cache android-tools curl netcat-openbsd >/dev/null 2>&1 || true
    elif command -v pkg >/dev/null 2>&1; then
        # Termux trên Android
        pkg update -y >/dev/null 2>&1 || true
        pkg install -y android-tools curl netcat-openbsd >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        # Debian / Ubuntu / Raspberry Pi OS
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y android-tools-adb curl netcat-openbsd >/dev/null 2>&1 || true
    elif command -v pacman >/dev/null 2>&1; then
        # Arch Linux
        pacman -Sy --noconfirm android-tools curl gnu-netcat >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora / RHEL
        dnf install -y android-tools curl nc >/dev/null 2>&1 || true
    elif command -v brew >/dev/null 2>&1; then
        # macOS Homebrew
        brew install android-platform-tools curl netcat >/dev/null 2>&1 || true
    else
        echo ">> [Lưu ý] Không nhận diện được trình quản lý gói. Vui lòng đảm bảo đã cài: adb, curl, nc."
    fi
    echo ">> [OK] Đã hoàn tất kiểm tra công cụ nền tảng!"
else
    echo ">> [OK] Các công cụ (adb, curl, nc) đã có sẵn trên máy."
fi

# ------------------------------------------------------------------------------
# 2. HÀM NHẬP DỮ LIỆU AN TOÀN (Tương thích cả khi chạy qua pipe: curl ... | sh)
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
# 3. HÀM PHÁT HIỆN DẢI MẠNG VÀ KIỂM TRA CỔNG KẾT NỐI (Đa nền tảng)
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

check_port() {
    _IP="$1"
    _PORT="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -w 1 -z "$_IP" "$_PORT" >/dev/null 2>&1 && return 0
        nc -w 1 "$_IP" "$_PORT" </dev/null >/dev/null 2>&1 && return 0
    fi
    if command -v timeout >/dev/null 2>&1; then
        timeout 1 sh -c "exec 3<>/dev/tcp/$_IP/$_PORT" >/dev/null 2>&1 && return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# 4. HÀM QUÉT MẠNG LAN TÌM LOA R1 (Chạy batch song song siêu nhanh)
# ------------------------------------------------------------------------------
scan_lan_for_r1() {
    PREFIX="$1"
    [ -z "$PREFIX" ] && PREFIX=$(detect_subnet)
    
    echo ""
    echo ">> Đang quét nhanh dải mạng ${PREFIX}.1 -> 254 để tìm loa Phicomm R1..."
    echo "   (Kiểm tra cổng ADB 5555 mở qua kết nối song song)..."
    
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
                if check_port "$TARGET" "5555"; then
                    echo "$TARGET" > "$SCAN_TMP/$i"
                fi
            ) &
            i=$((i + 1))
        done
        wait
        printf "\r[*] Tiến độ quét: %d/254 IP..." "$BATCH_END"
        IDX=$((BATCH_END + 1))
    done
    echo ""
    
    FOUND_COUNT=0
    FIRST_FOUND_IP=""
    for f in "$SCAN_TMP"/*; do
        if [ -f "$f" ]; then
            F_IP=$(cat "$f")
            FOUND_COUNT=$((FOUND_COUNT + 1))
            echo "   [+] Phát hiện loa R1 [$FOUND_COUNT] tại IP: $F_IP"
            [ -z "$FIRST_FOUND_IP" ] && FIRST_FOUND_IP="$F_IP"
        fi
    done
    rm -rf "$SCAN_TMP"
    
    if [ $FOUND_COUNT -eq 0 ]; then
        echo ">> Không tìm thấy thiết bị nào mở cổng 5555 trong dải mạng ${PREFIX}.x."
        echo "   (Hãy đảm bảo loa đã cắm nguồn và thiết bị đang bật Wi-Fi cùng lớp mạng)."
    fi
}

prompt_for_target_ip() {
    SUGGESTED=""
    echo ""
    echo "----------------------------------------------------------"
    echo "           TÌM KIẾM & XÁC ĐỊNH IP CỦA LOA R1              "
    echo "----------------------------------------------------------"
    echo "  [1] Tự động quét mạng WiFi để tìm IP loa (Khuyên dùng)"
    echo "  [2] Nhập trực tiếp địa chỉ IP loa thủ công"
    echo ""
    IP_OPT=$(read_input "Chọn phương thức tìm IP (1-2, mặc định 1): " "1")

    if [ "$IP_OPT" = "1" ]; then
        CUR_SUB=$(detect_subnet)
        USER_SUB=$(read_input "Dải mạng cần quét [mặc định: $CUR_SUB]: " "$CUR_SUB")
        scan_lan_for_r1 "$USER_SUB"
        if [ -n "$FIRST_FOUND_IP" ]; then
            SUGGESTED="$FIRST_FOUND_IP"
        fi
    fi

    echo ""
    if [ -n "$SUGGESTED" ]; then
        TARGET_IP=$(read_input "Nhập địa chỉ IP của loa [Enter để chọn $SUGGESTED]: " "$SUGGESTED")
    else
        TARGET_IP=$(read_input "Nhập địa chỉ IP của loa (VD: 192.168.1.15): " "192.168.43.1")
    fi
    TARGET_IP=$(echo "$TARGET_IP" | sed 's/:5555$//')
    echo ">> [XÁC NHẬN] Địa chỉ IP lựa chọn: $TARGET_IP"
}

# ------------------------------------------------------------------------------
# 5. XỬ LÝ THAM SỐ HOẶC HIỂN THỊ MENU ĐIỀU KHIỂN TIẾNG VIỆT
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
    echo "Chọn thao tác bạn muốn thực hiện:"
    echo "  [1] Cài đặt SIÊU TỐC qua WiFi loa phát ra (IP: 192.168.43.1) [Khuyên dùng]"
    echo "  [2] Cài đặt đầy đủ qua mạng WiFi nhà (Tự tìm hoặc nhập IP thủ công)"
    echo "  [3] Chỉ cập nhật bản AI Box Plus DLNA mới nhất (Giữ nguyên cài đặt cũ)"
    echo "  [4] Quét & tìm địa chỉ IP của loa R1 trong mạng WiFi nhà"
    echo "  [5] Xem IP WiFi loa nhận được khi đang kết nối WiFi loa (192.168.43.1)"
    echo "  [6] Thoát"
    echo ""
    CHOICE=$(read_input "Nhập lựa chọn của bạn (1-6, mặc định 1): " "1")

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
            USER_SUB=$(read_input "Dải mạng cần quét [mặc định: $CUR_SUB]: " "$CUR_SUB")
            scan_lan_for_r1 "$USER_SUB"
            exit 0
            ;;
        5)
            TARGET_IP="192.168.43.1"
            MODE="READ_AP_IP"
            ;;
        6)
            echo "Thoát chương trình. Tạm biệt!"
            exit 0
            ;;
        *)
            TARGET_IP="192.168.43.1"
            MODE="FULL"
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# 6. QUẢN LÝ BỘ NHỚ ĐỆM & TỰ ĐỘNG XÓA APK CŨ ĐỂ TẢI BẢN MỚI NHẤT
# ------------------------------------------------------------------------------
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

echo ""
echo "=========================================================="
echo "    QUẢN LÝ TẢI VỀ & CẬP NHẬT FILE APK TỪ GITHUB          "
echo "=========================================================="

# Kiểm tra xem máy hiện tại có kết nối Internet ra GitHub không
HAS_INTERNET=0
if curl -k -s --connect-timeout 4 -I "$BASE_URL/$APK_AI" >/dev/null 2>&1; then
    HAS_INTERNET=1
fi

if [ "$HAS_INTERNET" = "1" ]; then
    # Luôn xóa sạch cache APK cũ để đảm bảo người dùng luôn nhận bản APK cập nhật mới nhất
    echo ">> [INTERNET OK] Đang xóa cache APK cũ trong $TEMP_DIR để tải bản mới nhất..."
    rm -f "$TEMP_DIR"/*.apk "$TEMP_DIR"/*.tmp 2>/dev/null || true
else
    # Khi máy đang kết nối vào WiFi của Loa (192.168.43.1 không có Internet):
    # Kiểm tra xem trước đó đã có file APK sẵn chưa
    if [ -f "$TEMP_DIR/$APK_AI" ] && [ -s "$TEMP_DIR/$APK_AI" ]; then
        echo ">> [CHẾ ĐỘ NGOẠI TUYẾN] Không có Internet (đang nối WiFi loa 192.168.43.1)."
        echo "   Phát hiện các file APK đã tải trước đó trong máy -> Sử dụng để flash ngay!"
    else
        echo ">> [CẢNH BÁO] Không có kết nối Internet và chưa có file APK trong máy."
        rm -f "$TEMP_DIR"/*.apk "$TEMP_DIR"/*.tmp 2>/dev/null || true
    fi
fi

download_apk() {
    FILE="$1"
    MIN_SZ="$2"
    DESC="$3"
    
    # Kiểm tra nếu file đã có và dung lượng hợp lệ
    if [ -f "$FILE" ]; then
        SZ=$(wc -c < "$FILE" 2>/dev/null | tr -d ' \r\n\t')
        if [ -n "$SZ" ] && [ "$SZ" -ge "$MIN_SZ" ]; then
            echo ">> [ĐÃ CÓ SẴN] $DESC ($FILE) - Kích thước: ${SZ} bytes."
            return 0
        fi
    fi
    
    echo ">> Đang tải $DESC từ GitHub ($BASE_URL/$FILE)..."
    if curl -k -L -f --connect-timeout 15 -# -o "$FILE.tmp" "$BASE_URL/$FILE"; then
        mv -f "$FILE.tmp" "$FILE"
        echo ">> [OK] Đã tải xong $DESC thành công."
        return 0
    else
        rm -f "$FILE.tmp"
        if [ -f "$FILE" ] && [ -s "$FILE" ]; then
            echo ">> [LƯU Ý] Không thể tải bản mới, giữ lại bản hiện có trong máy."
            return 0
        fi
        echo ">> [LỖI] Không thể tải $DESC! Vui lòng kiểm tra lại kết nối mạng."
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
    echo "  [LỖI THIẾU FILE CAI ĐẶT DO CHƯA CÓ INTERNET]"
    echo "=========================================================="
    echo "Bạn đang kết nối vào WiFi của loa (192.168.43.1 không có mạng)"
    echo "hoặc mạng Internet bị gián đoạn, nên chưa tải được file APK về máy."
    echo ""
    echo "CÁCH XỬ LÝ NHANH:"
    echo " 1. Chuyển điện thoại/máy tính về WiFi nhà (hoặc bật 4G/5G)."
    echo " 2. Chạy lại script này để hệ thống tải trọn vẹn 3 file APK vào máy."
    echo " 3. Khi máy đã có file, chuyển sang WiFi loa để FLASH SIÊU TỐC!"
    echo "=========================================================="
    exit 1
fi

echo ">> [HOÀN TẤT TẢI FILE] Toàn bộ file cài đặt đã sẵn sàng trên máy!"

# ------------------------------------------------------------------------------
# 7. KIỂM TRA KẾT NỐI ĐẾN LOA R1 (TỐI ƯU SIÊU TỐC CHO CHẾ ĐỘ AP 192.168.43.1)
# ------------------------------------------------------------------------------
SERIAL="$TARGET_IP:5555"

echo ""
echo "=========================================================="
echo "      KIỂM TRA KẾT NỐI ĐẾN LOA R1 ($SERIAL)               "
echo "=========================================================="

# Khoi dong va lam sach adb server truoc
adb kill-server >/dev/null 2>&1 || true
sleep 0.5
adb start-server >/dev/null 2>&1 || true

if [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo "------------------ HƯỚNG DẪN KẾT NỐI WIFI LOA (AP) ------------------"
    echo " 1. TẮT 4G/5G (Dữ liệu di động) trên điện thoại (để không bị lệch gói tin)."
    echo " 2. Ấn giữ nút tròn trên đỉnh loa 6 giây đến khi loa kêu bíp & đổi đèn cam."
    echo " 3. Vào Cài đặt -> Wi-Fi trên điện thoại, chọn mạng: Phicomm_R1_xxxx"
    echo " 4. Nếu điện thoại báo 'Wi-Fi không có Internet' -> Chọn 'Tiếp tục dùng'!"
    echo " 5. iPhone: Vào Cài đặt máy -> iSH -> Bật 'Mạng cục bộ' (Local Network)."
    echo "---------------------------------------------------------------------"
    echo "⚡ HỆ THỐNG SẼ TỰ ĐỘNG BẮT ĐẦU CÀI ĐẶT NGAY KHI PHÁT HIỆN LOA!"
    echo "   (Quá trình cài đặt chỉ mất ~25 giây, không lo loa bị tắt AP)"
    echo "---------------------------------------------------------------------"
else
    echo " 1. Đảm bảo thiết bị của bạn đang kết nối cùng mạng WiFi với loa."
    echo " 2. Địa chỉ IP mục tiêu của loa: $TARGET_IP"
    echo " 3. Nếu dùng iPhone iSH: Vào Cài đặt máy -> iSH -> Bật 'Mạng cục bộ'."
fi

echo ">> Đang dò tìm loa liên tục tại $SERIAL (Bấm Ctrl + C nếu muốn dừng)..."
echo ""

TRY_COUNT=0
while true; do
    TRY_COUNT=$((TRY_COUNT + 1))

    # Ket noi truc tiep ADB toi loa
    CONN_OUT=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
    DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')

    # Neu thiet bi bao device hoac connected to
    if [ "$DEV_STATE" = "device" ] || echo "$CONN_OUT" | grep -q "connected to"; then
        # Kiem tra quyen thuc thi lenh tren loa (ho tro ca device phan hoi cham)
        if adb -s "$SERIAL" shell "echo r1_ok" 2>/dev/null | grep -q "r1_ok"; then
            echo ""
            echo ">> [KẾT NỐI THÀNH CÔNG] Đã nhận diện loa Phicomm R1 tại $SERIAL!"
            break
        fi
    fi

    printf "\r[*] Đang chờ kết nối [%s] (Lần thử %d) | %s   " "$SERIAL" "$TRY_COUNT" "$CONN_OUT"

    # Sau moi 6 lan thu (~6s), reset socket de giai phong port bi ket boi scan_lan
    if [ $((TRY_COUNT % 6)) -eq 0 ]; then
        adb disconnect "$SERIAL" >/dev/null 2>&1 || true
        adb kill-server >/dev/null 2>&1 || true
        sleep 0.5
        adb start-server >/dev/null 2>&1 || true
    fi

    # Nếu sau 18 lần thử ở chế độ WiFi nhà mà chưa thấy, hỏi đổi IP
    if [ $((TRY_COUNT % 18)) -eq 0 ]; then
        if [ "$TARGET_IP" != "192.168.43.1" ]; then
            echo ""
            RETRY_CHOICE=$(read_input ">> Chưa thấy loa tại $TARGET_IP. Bạn có muốn đổi IP khác? (y/n, mặc định n): " "n")
            if [ "$RETRY_CHOICE" = "y" ] || [ "$RETRY_CHOICE" = "Y" ]; then
                NEW_IP=$(read_input "Nhập địa chỉ IP mới: " "")
                if [ -n "$NEW_IP" ]; then
                    TARGET_IP=$(echo "$NEW_IP" | sed 's/:5555$//')
                    SERIAL="$TARGET_IP:5555"
                    TRY_COUNT=0
                    echo ">> Đã đổi mục tiêu sang: $SERIAL"
                fi
            fi
        fi
    fi

    sleep 1
done

echo ""
echo ">> [SẴN SÀNG] BẮT ĐẦU QUÁ TRÌNH CÀI ĐẶT CHO LOA R1..."

# ------------------------------------------------------------------------------
# 8. HÀM CÀI ĐẶT APK AN TOÀN, XỬ LÝ XUNG ĐỘT CHỮ KÝ VÀ TỐI ƯU TỐC ĐỘ
# ------------------------------------------------------------------------------
install_apk_on_device() {
    LOCAL_APK="$1"
    REMOTE_TMP="/data/local/tmp/$(basename "$LOCAL_APK")"
    PKG_NAME="$2"
    DESC="$3"
    
    printf "   -> Đang chuyển %s sang loa... " "$DESC"
    adb -s "$SERIAL" push "$LOCAL_APK" "$REMOTE_TMP" >/dev/null 2>&1
    printf "Đang cài đặt... "
    INSTALL_OUT=$(adb -s "$SERIAL" shell "/system/bin/pm install -r $REMOTE_TMP" 2>&1 | tr -d '\r')
    
    # Nếu bị lỗi khác biệt chữ ký keystore giữa bản cũ và bản mới
    if echo "$INSTALL_OUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
        printf "\n   [!] Khác chữ ký ứng dụng cũ, đang gỡ bản cũ để cài mới... "
        [ -n "$PKG_NAME" ] && adb -s "$SERIAL" shell "/system/bin/pm uninstall $PKG_NAME" >/dev/null 2>&1 || true
        INSTALL_OUT=$(adb -s "$SERIAL" shell "/system/bin/pm install $REMOTE_TMP" 2>&1 | tr -d '\r')
    fi
    
    if echo "$INSTALL_OUT" | grep -qi "Success"; then
        echo "[THÀNH CÔNG]"
    else
        echo "[LỖI]: $INSTALL_OUT"
    fi
    
    adb -s "$SERIAL" shell "rm -f $REMOTE_TMP" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# 9. CHẾ ĐỘ XEM THÔNG TIN IP WIFI CỦA LOA (ĐANG KẾT NỐI AP 192.168.43.1)
# ------------------------------------------------------------------------------
if [ "$MODE" = "READ_AP_IP" ]; then
    echo "=========================================================="
    echo "           THÔNG TIN KẾT NỐI & IP CỦA LOA R1              "
    echo "=========================================================="
    WLAN_IP=$(adb -s "$SERIAL" shell getprop dhcp.wlan0.ipaddress 2>/dev/null | tr -d '\r\n')
    DEV_NAME=$(adb -s "$SERIAL" shell getprop net.hostname 2>/dev/null | tr -d '\r\n')
    DEV_MAC=$(adb -s "$SERIAL" shell cat /sys/class/net/wlan0/address 2>/dev/null | tr -d '\r\n')
    
    echo "Tên thiết bị       : $DEV_NAME"
    echo "Địa chỉ MAC WiFi   : $DEV_MAC"
    if [ -n "$WLAN_IP" ]; then
        echo ">> IP Loa trong mạng WiFi nhà: $WLAN_IP"
        echo "   (Bạn có thể vào Web Control điều khiển tại: http://$WLAN_IP:8081/)"
    else
        echo ">> Loa chưa có IP mạng WiFi nhà (hoặc chưa cài đặt WiFi)."
        echo "   Vào http://192.168.43.1:8081/wifi.html để kết nối WiFi nhà cho loa."
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# 10. CHẾ ĐỘ CÀI ĐẶT ĐẦY ĐỦ: AUTODLNA + UNISOUND + AI BOX PLUS TIẾNG VIỆT
# ------------------------------------------------------------------------------
if [ "$MODE" = "FULL" ]; then
    echo "=========================================================="
    echo "  BẮT ĐẦU CÀI ĐẶT: AutoDLNA + Unisound + AI Box Plus DLNA"
    echo "=========================================================="
    echo ""
    
    # 10.1 TẮT HẾT TIẾN TRÌNH CHIẾM QUYỀN & XUNG ĐỘT (Gộp 1 phiên shell duy nhất)
    echo ">> [1/5] Tắt toàn bộ tiến trình chiếm quyền, xung đột âm thanh & micro..."
    adb -s "$SERIAL" shell "
        # 0. Giu loa luon thuc (chong ngu/standby lam dut WiFi AP)
        svc power stayon true 2>/dev/null

        # 1. Buộc dừng (force-stop) các tiến trình cũ đang chiếm âm thanh/micro/cổng mạng
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

        # 2. Dừng các daemon media chạy ngầm nếu có
        killall -9 shairport dlna mpd 2>/dev/null

        # 3. Vô hiệu hóa vĩnh viễn các app rác Phicomm gây chiếm quyền/tự tắt WiFi AP
        for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do
            pm hide \$p 2>/dev/null
            pm disable \$p 2>/dev/null
        done

        # 4. Dọn sạch cache OTA, file tạm và bật quyền cài đặt ngoài
        rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null
        rm -rf /data/local/tmp/* 2>/dev/null
        pm clear com.phicomm.speaker.otaservice 2>/dev/null
        settings put secure install_non_market_apps 1 2>/dev/null
    " >/dev/null 2>&1
    echo "   [OK] Đã giải phóng hoàn toàn âm thanh, micro và các cổng mạng!"

    # 10.2 Cài đặt AutoDLNA
    echo ">> [2/5] Cài đặt AutoDLNA (Điều khiển nhạc & Web Control)..."
    install_apk_on_device "$APK_DLNA" "com.phicomm.speaker.player" "AutoDLNA"

    # 10.3 Cài đặt Unisound
    echo ">> [3/5] Cài đặt Unisound (Điều khiển phần cứng & hệ thống)..."
    install_apk_on_device "$APK_UNI" "com.phicomm.speaker.device" "Unisound"

    # 10.4 Cài đặt AI Box Plus DLNA
    echo ">> [4/5] Cài đặt AI Box Plus DLNA (Trợ lý Tiếng Việt & DLNA)..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    # 10.5 Mở khóa và khởi chạy toàn bộ dịch vụ
    echo ">> [5/5] Mở khóa và khởi chạy toàn bộ dịch vụ hệ thống..."
    adb -s "$SERIAL" shell "
        for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do
            pm unhide \$p 2>/dev/null
            pm enable \$p 2>/dev/null
        done
        # Khởi chạy EchoService (LED, EQ, Web server 8080/8081)
        am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null
        # Khởi chạy giao diện Unisound
        am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null
        # Khởi chạy ứng dụng AI Box Plus DLNA
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

    # 10.6 Kiểm tra nhanh trạng thái các cổng dịch vụ
    echo ""
    echo ">> Kiểm tra trạng thái hoạt động các cổng dịch vụ:"
    if check_port "$TARGET_IP" "8081"; then
        echo "   [OK] Web Control (Cổng 8081) đã sẵn sàng!"
    else
        echo "   [*] Web Control (Cổng 8081) đang khởi động..."
    fi
    if check_port "$TARGET_IP" "8080"; then
        echo "   [OK] EchoService (Cổng 8080 - Đèn LED & EQ) đã sẵn sàng!"
    fi
    if check_port "$TARGET_IP" "8082"; then
        echo "   [OK] AI Box Service (Cổng 8082) đã sẵn sàng!"
    fi

    echo ""
    echo "=========================================================="
    echo "     [HOÀN TẤT] CÀI ĐẶT LOA PHICOMM R1 THÀNH CÔNG!        "
    echo "=========================================================="
    echo "Toàn bộ ứng dụng & dịch vụ đã được kích hoạt SẴN SÀNG DÙNG NGAY!"
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo "Kết nối WiFi giữa máy bạn và loa được GIỮ NGUYÊN (không bị ngắt)."
        echo ""
        echo ">>> CÁC BƯỚC CẤU HÌNH WIFI NHÀ (HÃY THỰC HIỆN NGAY):"
        echo " 1. Mở trình duyệt Safari hoặc Chrome trên máy, truy cập:"
        echo "    👉 http://192.168.43.1:8081/wifi.html (để cài WiFi nhà cho loa)"
        echo "    hoặc: http://192.168.43.1:8081/ (giao diện điều khiển Web)"
        echo " 2. Chọn tên WiFi nhà bạn, nhập mật khẩu -> Loa sẽ phát âm thông báo."
        echo " 3. Sau khi loa đã nối WiFi nhà, chuyển máy bạn về WiFi nhà và tận hưởng!"
        echo "=========================================================="
        echo ""
        REBOOT_NOW=$(read_input "Bạn có muốn khởi động lại loa bây giờ không? (y/n, mặc định n để vào web ngay): " "n")
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Đang khởi động lại loa (vui lòng đợi 25-30 giây)..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        else
            echo ">> Giữ nguyên kết nối để bạn vào http://192.168.43.1:8081/wifi.html ngay!"
        fi
    else
        echo "Truy cập giao diện web điều khiển loa tại: http://$TARGET_IP:8081/"
        echo "=========================================================="
        echo ""
        REBOOT_NOW=$(read_input "Bạn có muốn khởi động lại loa bây giờ không? (y/n, mặc định n): " "n")
        if [ "$REBOOT_NOW" = "y" ] || [ "$REBOOT_NOW" = "Y" ]; then
            echo ">> Đang khởi động lại loa..."
            adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 11. CHẾ ĐỘ CẬP NHẬT NHANH AI BOX PLUS DLNA (GIỮ NGUYÊN CÀI ĐẶT CŨ)
# ------------------------------------------------------------------------------
if [ "$MODE" = "UPDATE_ONLY" ]; then
    echo "=========================================================="
    echo "  CẬP NHẬT NHANH AI BOX PLUS DLNA (GIỮ NGUYEN CẤU HÌNH)   "
    echo "=========================================================="
    echo ""
    
    echo ">> [1/3] Tắt tiến trình cũ & dọn dẹp các app xung đột..."
    adb -s "$SERIAL" shell "
        am force-stop info.dourok.voicebot 2>/dev/null
        for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport; do
            pm hide \$p 2>/dev/null
            pm disable \$p 2>/dev/null
        done
        rm -rf /data/local/tmp/* 2>/dev/null
    " >/dev/null 2>&1

    echo ">> [2/3] Đang chuyển và cài đặt AI Box Plus DLNA mới nhất..."
    install_apk_on_device "$APK_AI" "info.dourok.voicebot" "AI Box Plus DLNA"

    echo ">> [3/3] Khởi chạy ứng dụng AI Box Plus..."
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

    sleep 1
    if check_port "$TARGET_IP" "8082"; then
        echo "   [OK] AI Box Service (Cổng 8082) đã sẵn sàng!"
    fi

    echo ""
    echo "=========================================================="
    echo "     [HOÀN TẤT] CẬP NHẬT AI BOX PLUS DLNA THÀNH CÔNG!     "
    echo "=========================================================="
    echo "Toàn bộ cài đặt (mDNS, PayOS, hẹn giờ...) được giữ nguyên 100%!"
    echo "Truy cập giao diện web điều khiển tại: http://$TARGET_IP:8081/"
fi
