#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Cách dùng trên iPhone: Mở app iSH, dán lệnh:
# curl -fsSL https://vdt34.github.io/r1/install.sh -o r1.sh && sh r1.sh
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
mkdir -p "$CACHE_DIR"

clear
echo "=========================================================="
echo "    BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC CHO iPHONE & LINUX"
echo "=========================================================="
echo ""

# 1. Cài nhanh công cụ cần thiết nếu thiếu
if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo ">> Đang cài công cụ adb & curl..."
    if command -v apk >/dev/null 2>&1; then
        apk update >/dev/null 2>&1
        apk add --no-cache android-tools curl netcat-openbsd >/dev/null 2>&1
    elif command -v pkg >/dev/null 2>&1; then
        pkg install -y android-tools curl netcat-openbsd >/dev/null 2>&1
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y android-tools-adb curl netcat-openbsd >/dev/null 2>&1
    fi
fi

# Hàm nhập liệu an toàn
read_val() {
    prompt="$1"
    def="$2"
    printf "%s" "$prompt"
    val=""
    read -r val 2>/dev/null || val=""
    val=$(printf '%s' "$val" | tr -d '\r\n')
    [ -z "$val" ] && val="$def"
    echo "$val"
}

# 2. Chọn chế độ cài đặt
echo "Chọn cách kết nối:"
echo "  [1] Cài qua WiFi loa phát ra (192.168.43.1) [Khuyên dùng]"
echo "  [2] Cài qua WiFi nhà (Nhập IP của loa)"
echo ""
CHOICE=$(read_val "Lựa chọn của bạn [1-2, mặc định 1]: " "1")

TARGET_IP="192.168.43.1"
if [ "$CHOICE" = "2" ]; then
    USER_IP=$(read_val "Nhập IP của loa (Ví dụ: 192.168.1.94): " "192.168.1.94")
    TARGET_IP=$(echo "$USER_IP" | tr -d ' ' | sed 's/:5555$//')
    [ -z "$TARGET_IP" ] && TARGET_IP="192.168.1.94"
fi
SERIAL="$TARGET_IP:5555"

# 3. Chuẩn bị 3 file APK (ưu tiên thư mục có sẵn, nếu thiếu mới tải)
echo ""
echo ">> [1/4] Chuẩn bị 3 file APK..."
for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    # Nếu file đã có ở thư mục hiện tại
    if [ -f "$SCRIPT_DIR/$f" ] && [ "$(wc -c < "$SCRIPT_DIR/$f" 2>/dev/null)" -gt 1000000 ]; then
        cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
        echo "   [OK] Dùng $f có sẵn trong thư mục."
    elif [ -f "$CACHE_DIR/$f" ] && [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -gt 1000000 ]; then
        echo "   [OK] Đã có sẵn $f trong bộ nhớ tạm."
    else
        echo "   -> Đang tải $f từ GitHub..."
        curl -k -fL --connect-timeout 10 -# -o "$CACHE_DIR/$f.tmp" "$BASE_URL/$f" && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
    fi

    if [ ! -f "$CACHE_DIR/$f" ] || [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -lt 1000000 ]; then
        echo ""
        echo "[LỖI] Không tìm thấy file $f!"
        echo "Nếu đang nối WiFi loa (không có mạng), hãy chuyển về WiFi nhà tải xong rồi chạy lại."
        exit 1
    fi
done

# 4. Kết nối tới loa (WebSocket revive + ADB)
echo ""
echo ">> [2/4] Đang kết nối tới loa tại $SERIAL..."
if [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo "--------------------------------------------------------"
    echo " LƯU Ý CHO iPHONE:"
    echo " 1. TẮT 4G/5G trên iPhone để không bị nhiễu mạng."
    echo " 2. Ấn giữ nút tròn đỉnh loa 6 giây cho đổi sang đèn cam."
    echo " 3. Vào Wi-Fi iPhone kết nối mạng: Phicomm_R1_xxxx"
    echo " 4. Bật 'Mạng cục bộ' (Local Network) cho iSH trong Cài đặt iPhone."
    echo "--------------------------------------------------------"
fi

revive_speaker() {
    [ "$R1_DRYRUN" = "1" ] && return 0
    cmd="stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice"
    payload="{\"type\":\"shell\",\"type_id\":\"revive\",\"shell\":\"$cmd\"}"
    len=${#payload}
    hdr="\\201$(printf '\\%03o' $((128 + len)))\\000\\000\\000\\000"
    if command -v nc >/dev/null 2>&1; then
        {
            printf 'GET / HTTP/1.1\r\nHost: %s:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' "$TARGET_IP"
            sleep 0.5
            printf "%b%s" "$hdr" "$payload"
            sleep 0.5
        } | nc -w 2 "$TARGET_IP" 8080 >/dev/null 2>&1 || true
    fi
}

[ "$R1_DRYRUN" != "1" ] && adb start-server >/dev/null 2>&1 || true
revive_speaker
sleep 0.6

TRY=0
while true; do
    TRY=$((TRY + 1))
    [ "$R1_DRYRUN" = "1" ] && break
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')
    if [ "$DEV_STATE" = "device" ]; then break; fi
    printf "\r[*] Đang chờ kết nối loa %s (thử lần %d)... " "$SERIAL" "$TRY"
    if [ $((TRY % 3)) -eq 0 ]; then
        adb disconnect "$SERIAL" >/dev/null 2>&1 || true
        revive_speaker
    fi
    sleep 1
done
echo ""
echo ">> [OK] Đã kết nối thành công tới loa ($SERIAL)!"

# 5. ĐẨY HẾT 3 FILE LÊN BỘ NHỚ TẠM CỦA LOA TRƯỚC (/sdcard/)
echo ""
echo ">> [3/4] Đang đẩy toàn bộ 3 file APK lên loa..."
for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    echo "   -> Nạp $f..."
    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" push "$CACHE_DIR/$f" "/sdcard/$f" >/dev/null 2>&1
    fi
done
echo ">> [OK] Đã đưa trọn vẹn 3 file lên bộ nhớ loa!"

# 6. Dọn dẹp, cài đặt lần lượt 3 file và khởi chạy hệ thống
echo ""
echo ">> [4/4] Bắt đầu cài đặt và kích hoạt hệ thống..."

if [ "$R1_DRYRUN" != "1" ]; then
    # Dọn dẹp tiến trình xung đột
    adb -s "$SERIAL" shell "
        svc power stayon true 2>/dev/null
        am force-stop info.dourok.voicebot 2>/dev/null
        am force-stop com.phicomm.speaker.player 2>/dev/null
        am force-stop com.phicomm.speaker.device 2>/dev/null
        for p in com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic; do
            pm hide \$p 2>/dev/null
            pm disable \$p 2>/dev/null
        done
        killall -9 shairport dlna mpd 2>/dev/null
        settings put secure install_non_market_apps 1 2>/dev/null
    " >/dev/null 2>&1

    # Cài đặt từng app từ /sdcard/
    for item in "autodlna.apk:com.phicomm.speaker.player:AutoDLNA" \
                "unisound.apk:com.phicomm.speaker.device:Unisound" \
                "AIBoxPlus_DLNA.apk:info.dourok.voicebot:AI Box Plus"; do
        apk_file=$(echo "$item" | cut -d: -f1)
        pkg_name=$(echo "$item" | cut -d: -f2)
        desc=$(echo "$item" | cut -d: -f3)

        echo "   -> Đang cài đặt $desc..."
        out=$(adb -s "$SERIAL" shell "pm install -r /sdcard/$apk_file" 2>&1 | tr -d '\r')
        if echo "$out" | grep -Eq 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match'; then
            adb -s "$SERIAL" shell "pm uninstall $pkg_name; pm install /sdcard/$apk_file" >/dev/null 2>&1
        fi
        adb -s "$SERIAL" shell "rm -f /sdcard/$apk_file" >/dev/null 2>&1
    done

    # Mở khóa và khởi chạy toàn bộ dịch vụ
    adb -s "$SERIAL" shell "
        for p in com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot; do
            pm unhide \$p 2>/dev/null
            pm enable \$p 2>/dev/null
        done
        am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null
        am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null
        am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null
        settings put global bluetooth_on 1 2>/dev/null
        service call bluetooth_manager 6 2>/dev/null
        setprop persist.sys.r1_led 0 2>/dev/null
        lights_test set 7fffff8000 0 2>/dev/null
        lights_test set 7fffff0000 ffffff 2>/dev/null
    " >/dev/null 2>&1
else
    echo "   -> [DRY-RUN] Cài đặt hoàn tất AutoDLNA, Unisound, AI Box Plus!"
fi

echo ""
echo "=========================================================="
echo "    [HOÀN TẤT] ĐÃ CÀI ĐẶT LOA PHICOMM R1 THÀNH CÔNG!"
echo "=========================================================="
if [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo ">> CÀI ĐẶT WIFI CHO LOA:"
    echo " 1. Mở Safari trên iPhone, vào: http://192.168.43.1:8081/wifi.html"
    echo " 2. Chọn WiFi nhà bạn, nhập mật khẩu để loa kết nối mạng."
    echo " 3. Đổi iPhone về WiFi nhà và thưởng thức âm nhạc!"
else
    echo ">> Giao diện điều khiển loa: http://$TARGET_IP:8081/"
fi
echo "=========================================================="
