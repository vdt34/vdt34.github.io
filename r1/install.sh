#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Chuẩn hóa 100% theo new.bat: Kết nối 1-2s, đẩy lên /data/local/tmp/
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
mkdir -p "$CACHE_DIR"

clear
echo "=========================================================="
echo "     CÀI ĐẶT AUTODLNA + UNISOUND + AI TIẾNG VIỆT (R1)"
echo "=========================================================="
echo ""

# 1. Cài nhanh công cụ cần thiết nếu thiếu
if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo ">> Đang chuẩn bị công cụ adb & curl..."
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
    printf "%s" "$prompt" >&2
    val=""
    read -r val 2>/dev/null || val=""
    val=$(printf '%s' "$val" | tr -d ' \r\n')
    [ -z "$val" ] && val="$def"
    echo "$val"
}

# 2. Nhập IP của loa (Chuẩn new.bat)
echo "----------------------------------------------------------"
echo "                     NHẬP IP CỦA LOA                      "
echo "----------------------------------------------------------"
echo " - Nếu đang kết nối WiFi của loa: Nhấn [Enter] để lấy 192.168.43.1"
echo " - Nếu loa đã nối WiFi nhà: Nhập địa chỉ IP của loa (VD: 192.168.1.94)"
echo ""
USER_IP=$(read_val "Nhập IP của loa (Enter để dùng mặc định 192.168.43.1): " "192.168.43.1")
TARGET_IP=$(echo "$USER_IP" | tr -d ' ' | sed 's/:5555$//')
[ -z "$TARGET_IP" ] && TARGET_IP="192.168.43.1"
SERIAL="$TARGET_IP:5555"

echo ""
echo ">> Sẽ kết nối tới IP: $TARGET_IP"

# 3. Chuẩn bị 3 file APK
echo ""
echo ">> [1/4] Chuẩn bị 3 file APK..."
for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    if [ -f "$SCRIPT_DIR/$f" ] && [ "$(wc -c < "$SCRIPT_DIR/$f" 2>/dev/null)" -gt 1000000 ]; then
        cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
        echo "   [OK] Có sẵn $f trong thư mục."
    elif [ -f "$CACHE_DIR/$f" ] && [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -gt 1000000 ]; then
        echo "   [OK] Có sẵn $f trong bộ nhớ tạm."
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

# 4. Kết nối ADB tới loa (Chuẩn xác 100% theo :connect và :connect_retry của new.bat)
echo ""
echo ">> [2/4] Bắt đầu kết nối thiết bị [$SERIAL]..."

if [ "$R1_DRYRUN" != "1" ]; then
    killall -9 adb 2>/dev/null || true
    adb kill-server >/dev/null 2>&1 || true
    adb start-server >/dev/null 2>&1 || true
    sleep 1

    CONNECTED=0
    for try in 1 2 3 4 5; do
        echo "   [Kết nối] Thử lần $try/5 tới $SERIAL..."
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        sleep 0.6
        DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')
        if [ "$DEV_STATE" = "device" ]; then
            if adb -s "$SERIAL" shell ls >/dev/null 2>&1; then
                CONNECTED=1
                break
            fi
        fi
        sleep 1
    done

    if [ "$CONNECTED" != "1" ]; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI $SERIAL"
        echo "=========================================================="
        echo "Vui lòng kiểm tra:"
        echo " 1. Loa đã cắm nguồn và đang bật."
        echo " 2. Thiết bị và loa đang kết nối CÙNG MẠNG WiFi."
        echo " 3. Địa chỉ IP của loa ($TARGET_IP) có đúng không."
        echo "=========================================================="
        exit 1
    fi
fi
echo ">> [OK] Kết nối thành công tới loa ($SERIAL)!"

# 5. ĐẨY CẢ 3 FILE APK LÊN /data/local/tmp/ CỦA LOA TRƯỚC
echo ""
echo ">> [3/4] Đang đẩy toàn bộ file APK lên bộ nhớ tạm (/data/local/tmp/)..."
for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    echo "   -> Nạp $f..."
    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" push "$CACHE_DIR/$f" "/data/local/tmp/$f" >/dev/null 2>&1
    fi
done
echo ">> [OK] Đã đưa trọn vẹn 3 file lên loa!"

# 6. THỰC THI CHUỖI LỆNH CÀI ĐẶT CHUẨN XÁC THEO NEW.BAT
echo ""
echo ">> [4/4] Bắt đầu cài đặt hệ thống..."

if [ "$R1_DRYRUN" != "1" ]; then
    # 6.1 Xóa bộ nhớ đệm trước khi cài đặt & cho phép cài app ngoài
    echo "   -> Đang dọn dẹp bộ nhớ đệm..."
    adb -s "$SERIAL" shell "
        rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null
        /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null
        settings put secure install_non_market_apps 1 2>/dev/null
    " >/dev/null 2>&1

    # 6.2 Tắt các ứng dụng không cần thiết trên loa
    echo "   -> Tắt các ứng dụng chiếm quyền..."
    adb -s "$SERIAL" shell "
        /system/bin/pm hide com.phicomm.speaker.airskill 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.device 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null
        /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null
    " >/dev/null 2>&1

    # 6.3 Cài đặt AutoDLNA + Unisound
    echo "   -> Cài đặt AutoDLNA + Unisound..."
    adb -s "$SERIAL" shell "
        /system/bin/pm install -r /data/local/tmp/autodlna.apk
        /system/bin/pm install -r /data/local/tmp/unisound.apk
        rm -f /data/local/tmp/autodlna.apk /data/local/tmp/unisound.apk
    " >/dev/null 2>&1

    # 6.4 Khởi động AutoDLNA + Unisound
    echo "   -> Khởi động AutoDLNA + Unisound..."
    adb -s "$SERIAL" shell "
        am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null
        am start com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null
    " >/dev/null 2>&1
    sleep 2

    # 6.5 Khôi phục ứng dụng cần thiết & Cài đặt AI Trợ lý ảo Tiếng Việt
    echo "   -> Khôi phục ijetty & netctl..."
    adb -s "$SERIAL" shell "
        /system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null
        /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null
    " >/dev/null 2>&1

    echo "   -> Gỡ bản AI cũ và cài đặt AI Tiếng Việt mới..."
    adb -s "$SERIAL" shell "
        /system/bin/pm uninstall info.dourok.voicebot 2>/dev/null
        /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk
        rm -f /data/local/tmp/AIBoxPlus_DLNA.apk
    " >/dev/null 2>&1

    # 6.6 Khởi động AI Trợ lý ảo Tiếng Việt & cấu hình Bluetooth, LED
    echo "   -> Khởi động AI Box Plus..."
    adb -s "$SERIAL" shell "
        am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null
        settings put global bluetooth_on 1 2>/dev/null
        service call bluetooth_manager 6 2>/dev/null
        setprop persist.sys.r1_led 0 2>/dev/null
        lights_test set 7fffff8000 0 2>/dev/null
        lights_test set 7fffff0000 ffffff 2>/dev/null
    " >/dev/null 2>&1

    # Lấy IP WiFi nhà của loa nếu có
    LAN_IP=$(adb -s "$SERIAL" shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null | tr -d '\r\n')
else
    echo "   -> [DRY-RUN] Đã thực thi chuỗi lệnh new.bat chuẩn xác!"
    LAN_IP=""
fi

echo ""
echo "=========================================================="
echo "                    CÀI ĐẶT HOÀN TẤT!                     "
echo "=========================================================="

if [ -n "$LAN_IP" ]; then
    echo ">> IP của loa trong mạng WiFi nhà: $LAN_IP"
    echo ">> Truy cập bảng điều khiển loa tại: http://$LAN_IP:8081/"
elif [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo ">> BƯỚC TIẾP THEO: CẤU HÌNH WIFI CHO LOA"
    echo " 1. Mở Safari trên iPhone vào:"
    echo "    👉 http://192.168.43.1:8081/wifi.html"
    echo " 2. Chọn WiFi nhà bạn, nhập mật khẩu để loa kết nối Internet."
    echo " 3. Đổi iPhone về WiFi nhà và trải nghiệm!"
else
    echo ">> Truy cập bảng điều khiển loa tại: http://$TARGET_IP:8081/"
fi

echo "=========================================================="
