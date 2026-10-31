#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Tự động dọn file cũ, tải toàn bộ APK mới từ GitHub, kết nối cực nhạy
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)

USER_IP=""
ASSUME_YES=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes|-Yes) ASSUME_YES="1" ;;
        -DryRun|--dry-run) export R1_DRYRUN=1 ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*) USER_IP="$arg" ;;
    esac
done

clear
echo "=========================================================="
echo "     CÀI ĐẶT AUTODLNA + UNISOUND + AI TIẾNG VIỆT (R1)"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÔNG CỤ CẦN THIẾT (TỰ ĐỘNG MỞ KHO CHO ALPINE / iSH)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true

    if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v nc >/dev/null 2>&1; then
        echo ">> Đang kiểm tra & chuẩn bị công cụ adb, curl, nc..."
        if command -v apk >/dev/null 2>&1; then
            # Mở khóa repository community trong Alpine/iSH nếu đang bị khóa
            if [ -f /etc/apk/repositories ]; then
                sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true
            fi
            apk update >/dev/null 2>&1

            # Thử cài từ kho mặc định/community
            apk add --no-cache android-tools curl netcat-openbsd >/dev/null 2>&1 || true

            # Nếu vẫn thiếu adb, thử kéo trực tiếp từ kho edge/community hoặc testing
            if ! command -v adb >/dev/null 2>&1; then
                apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community android-tools curl netcat-openbsd >/dev/null 2>&1 || \
                apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing android-tools curl netcat-openbsd >/dev/null 2>&1 || true
            fi
        elif command -v pkg >/dev/null 2>&1; then
            pkg update -y >/dev/null 2>&1
            pkg install -y android-tools curl netcat-openbsd >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null 2>&1
            apt-get install -y android-tools-adb curl netcat-openbsd >/dev/null 2>&1 || true
        fi
    fi

    if [ "$R1_DRYRUN" != "1" ] && ! command -v adb >/dev/null 2>&1; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] KHÔNG THỂ CÀI ĐẶT LỆNH 'adb' TRÊN THIẾT BỊ NÀY!"
        echo "=========================================================="
        echo "Vui lòng chạy thủ công lệnh sau trong iSH để cài đặt adb:"
        echo "  apk add android-tools --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community"
        echo "=========================================================="
        exit 1
    fi
}
setup_tools

# Hàm đọc dữ liệu an toàn
read_val() {
    prompt="$1"
    def="$2"
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        echo "$def"
        return
    fi
    printf "%s" "$prompt" >&2
    val=""
    read -r val 2>/dev/null || val=""
    val=$(printf '%s' "$val" | tr -d ' \r\n')
    [ -z "$val" ] && val="$def"
    echo "$val"
}

# ------------------------------------------------------------------------------
# 2. XÓA FILE CŨ & TẢI 3 FILE APK MỚI NHẤT TỪ GITHUB (KHI CÒN ĐANG CÓ MẠNG)
# ------------------------------------------------------------------------------
echo ">> [1/4] Đang dọn sạch toàn bộ file .sh cũ, cache & tải APK mới nhất..."
# Quét & xóa sạch các file script .sh cũ từng tải về (tránh chạy nhầm bản cũ)
CUR_SCRIPT=$(basename "$0" 2>/dev/null || echo "")
for old_sh in ./r1.sh ./r1*.sh ./install.sh /tmp/r1*.sh /tmp/install*.sh; do
    if [ -f "$old_sh" ] && [ "$(basename "$old_sh")" != "$CUR_SCRIPT" ]; then
        rm -f "$old_sh" 2>/dev/null || true
    fi
done
rm -rf "$CACHE_DIR" 2>/dev/null || true
mkdir -p "$CACHE_DIR"

TS=$(date +%s 2>/dev/null || echo "1")
for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    if [ "$R1_DRYRUN" = "1" ] && [ -f "$SCRIPT_DIR/$f" ]; then
        cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
        echo "   [OK] (DryRun) Dùng file $f có sẵn."
    else
        echo "   -> Đang tải bản mới nhất: $f..."
        if command -v curl >/dev/null 2>&1; then
            curl -k -fL --connect-timeout 20 -# -o "$CACHE_DIR/$f.tmp" "$BASE_URL/$f?t=$TS" && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
        elif command -v wget >/dev/null 2>&1; then
            wget -q --no-check-certificate -O "$CACHE_DIR/$f" "$BASE_URL/$f?t=$TS"
        fi
    fi

    if [ ! -f "$CACHE_DIR/$f" ] || [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -lt 1000000 ]; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] KHÔNG THỂ TẢI FILE $f TỪ GITHUB!"
        echo "=========================================================="
        echo "Nguyên nhân: Điện thoại hiện không có kết nối Internet."
        echo "Nếu bạn đang kết nối WiFi của loa (Phicomm_R1), hãy:"
        echo " 1. Chuyển điện thoại về WiFi nhà (hoặc bật 4G) có mạng."
        echo " 2. Chạy lại lệnh cài đặt để tải trọn vẹn 3 file APK vào máy."
        echo " 3. Khi tải xong, bạn có thể chuyển về WiFi loa để cài siêu tốc."
        echo "=========================================================="
        exit 1
    fi
    echo "   [OK] Đã tải bản mới nhất $f thành công."
done

# ------------------------------------------------------------------------------
# 3. XÁC ĐỊNH IP CỦA LOA (HỖ TRỢ TỰ ĐỘNG QUÉT LAN & NHẬP THỦ CÔNG)
# ------------------------------------------------------------------------------
detect_subnet() {
    sub=""
    if command -v ip >/dev/null 2>&1; then
        sub=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | awk -F'.' '{print $1"."$2"."$3}')
        [ -z "$sub" ] && sub=$(ip -4 addr show 2>/dev/null | grep -v '127.0.0.1' | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | awk '{print $2}')
    fi
    if [ -z "$sub" ] && command -v ifconfig >/dev/null 2>&1; then
        sub=$(ifconfig 2>/dev/null | grep -v '127.0.0.1' | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
    if [ -z "$sub" ] && command -v route >/dev/null 2>&1; then
        sub=$(route -n 2>/dev/null | grep -E '^0\.0\.0\.0' | awk '{print $2}' | awk -F'.' '{print $1"."$2"."$3}')
    fi
    [ -z "$sub" ] && sub="192.168.1"
    echo "$sub"
}

scan_speaker_ip() {
    sub=$(detect_subnet)
    echo ""
    echo ">> Đang quét tự động dải mạng $sub.1 -> 254 để tìm loa Phicomm R1..."

    scan_tmp="/tmp/r1_scan_$$"
    rm -rf "$scan_tmp" 2>/dev/null || true
    mkdir -p "$scan_tmp"

    PY_CMD=""
    if python3 -c "import sys" >/dev/null 2>&1; then
        PY_CMD="python3"
    elif python -c "import sys" >/dev/null 2>&1; then
        PY_CMD="python"
    fi

    if [ -n "$PY_CMD" ]; then
        "$PY_CMD" - "$sub" << 'EOF' > "$scan_tmp/result.txt" 2>/dev/null || true
import sys, socket
from concurrent.futures import ThreadPoolExecutor

prefix = sys.argv[1]
def probe(i):
    ip = f"{prefix}.{i}"
    ports = []
    for p in (5555, 8081, 8080):
        try:
            s = socket.socket()
            s.settimeout(0.35)
            if s.connect_ex((ip, p)) == 0:
                ports.append(str(p))
            s.close()
        except Exception:
            pass
    if '5555' in ports or ('8080' in ports and '8081' in ports):
        p_str = ', '.join(ports)
        print(f"{ip} (Ports: {p_str})")

with ThreadPoolExecutor(max_workers=50) as ex:
    list(ex.map(probe, range(1, 255)))
EOF
    fi

    if [ ! -s "$scan_tmp/result.txt" ]; then
        idx=1
        while [ $idx -le 254 ]; do
            bend=$((idx + 31))
            [ $bend -gt 254 ] && bend=254
            i=$idx
            while [ $i -le $bend ]; do
                (
                    target="${sub}.${i}"
                    found=""
                    if command -v nc >/dev/null 2>&1; then
                        if nc -w 1 -z "$target" 5555 >/dev/null 2>&1; then
                            found="5555"
                        elif nc -w 1 -z "$target" 8081 >/dev/null 2>&1; then
                            found="8081"
                        elif nc -w 1 -z "$target" 8080 >/dev/null 2>&1; then
                            found="8080"
                        fi
                    elif command -v curl >/dev/null 2>&1; then
                        if curl -s -m 0.4 -o /dev/null "http://$target:8081/" 2>/dev/null; then
                            found="8081"
                        elif curl -s -m 0.4 -o /dev/null "http://$target:8080/" 2>/dev/null; then
                            found="8080"
                        fi
                    fi
                    if [ -n "$found" ]; then
                        echo "$target (Port: $found)" >> "$scan_tmp/result.txt"
                    fi
                ) &
                i=$((i + 1))
            done
            wait
            idx=$((bend + 1))
        done
    fi

    TOTAL_FOUND=0
    if [ -f "$scan_tmp/result.txt" ]; then
        echo ""
        echo ">> Kết quả phát hiện loa trong mạng LAN:"
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | tr -d '\r\n')
            [ -z "$line" ] && continue
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
            ip_val=$(echo "$line" | awk '{print $1}')
            echo "$ip_val" >> "$scan_tmp/ips.txt"
            echo "   [$TOTAL_FOUND] $line"
        done < "$scan_tmp/result.txt"
    fi
}

echo ""
echo "----------------------------------------------------------"
echo "                     XÁC ĐỊNH IP CỦA LOA                  "
echo "----------------------------------------------------------"
echo " [Enter] Dùng 192.168.43.1 (Khi đang nối trực tiếp WiFi loa)"
echo " [S]     Tự động QUÉT tìm IP loa trong mạng WiFi nhà (LAN)"
echo " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)"
echo "----------------------------------------------------------"
echo ""

TARGET_IP="$USER_IP"
while [ -z "$TARGET_IP" ]; do
    USER_INPUT=$(read_val "Nhập IP hoặc gõ 'S' để quét [Mặc định: 192.168.43.1]: " "192.168.43.1")
    USER_INPUT=$(echo "$USER_INPUT" | tr -d ' ')

    case "$USER_INPUT" in
        "1"|"192.168.43.1"|"")
            TARGET_IP="192.168.43.1"
            ;;
        "s"|"S"|"2"|"scan"|"SCAN")
            scan_speaker_ip
            if [ "$TOTAL_FOUND" -gt 0 ]; then
                echo ""
                PICK=$(read_val "Chọn số thứ tự loa (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
                PICK=$(echo "$PICK" | tr -d ' ')
                if [ "$PICK" -ge 1 ] 2>/dev/null && [ "$PICK" -le "$TOTAL_FOUND" ] 2>/dev/null; then
                    TARGET_IP=$(sed -n "${PICK}p" "$scan_tmp/ips.txt")
                elif echo "$PICK" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
                    TARGET_IP="$PICK"
                else
                    TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
                fi
            else
                echo ""
                echo ">> Không tìm thấy loa tự động trong mạng."
                MANUAL=$(read_val "Vui lòng nhập IP loa thủ công (VD: 192.168.1.94): " "")
                if [ -n "$MANUAL" ]; then
                    TARGET_IP="$MANUAL"
                else
                    TARGET_IP="192.168.43.1"
                fi
            fi
            rm -rf "$scan_tmp" 2>/dev/null || true
            ;;
        *)
            TARGET_IP=$(echo "$USER_INPUT" | sed 's/:5555$//')
            ;;
    esac
done

TARGET_IP=$(echo "$TARGET_IP" | tr -d ' ' | sed 's/:5555$//')
SERIAL="$TARGET_IP:5555"

echo ""
echo ">> Sẽ kết nối tới IP: $TARGET_IP"

# Cảnh báo hướng dẫn đặc biệt cho iPhone khi cài qua WiFi loa (192.168.43.1)
if [ "$TARGET_IP" = "192.168.43.1" ]; then
    echo ""
    echo "----------------------------------------------------------"
    echo "  LƯU Ý QUAN TRỌNG TRÊN iPHONE KHI NỐI WIFI LOA (192.168.43.1):"
    echo "----------------------------------------------------------"
    echo " 1. HÃY TẮT 4G/5G (Dữ liệu di động) TRÊN iPHONE NGAY BÂY GIỜ!"
    echo "    (Vì WiFi loa không có Internet, nếu bật 4G thì iOS sẽ tự động"
    echo "     đẩy mạng sang 4G khiến iSH không gửi được lệnh tới loa)."
    echo " 2. Đảm bảo iPhone đang kết nối WiFi 'Phicomm_R1_xxxx'."
    echo " 3. Nếu loa chưa phát WiFi: Nhấn giữ nút tròn đỉnh loa 6 giây."
    echo "----------------------------------------------------------"
    printf "Sau khi đã tắt 4G và nối WiFi loa, nhấn [Enter] để tiếp tục: "
    read -r _ 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. KẾT NỐI THIẾT BỊ LOA (CHẾ ĐỘ KÉP THÔNG MINH: TRỰC TIẾP + KÍCH HOẠT 8080)
# ------------------------------------------------------------------------------
echo ""
echo ">> [2/4] Bắt đầu kết nối thiết bị [$SERIAL]..."

revive_speaker() {
    local tip="$1"
    [ -z "$tip" ] && tip="192.168.43.1"
    [ "$R1_DRYRUN" = "1" ] && return 0

    cmd="stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice"
    payload="{\"type\":\"shell\",\"type_id\":\"revive\",\"shell\":\"$cmd\"}"
    len=${#payload}
    hdr="\\201$(printf '\\%03o' $((128 + len)))\\000\\000\\000\\000"

    # Cách 1: Thử bằng Python nếu có sẵn
    if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        PY_BIN=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
        "$PY_BIN" -c "
import socket
try:
    s = socket.socket()
    s.settimeout(2)
    s.connect(('$tip', 8080))
    s.sendall(b'GET / HTTP/1.1\r\nHost: $tip:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n')
    s.recv(1024)
    cmd = b'stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice'
    payload = b'{\"type\":\"shell\",\"type_id\":\"revive\",\"shell\":\"' + cmd + b'\"}'
    mask = b'\x12\x34\x56\x78'
    masked = bytes([b ^ mask[i % 4] for i, b in enumerate(payload)])
    hdr = bytes([0x81, 0x80 | len(payload)]) + mask if len(payload) < 126 else bytes([0x81, 0x80 | 126, len(payload) >> 8, len(payload) & 0xff]) + mask
    s.sendall(hdr + masked)
    s.close()
except:
    pass
" 2>/dev/null || true
    # Cách 2: Dùng nc (netcat)
    elif command -v nc >/dev/null 2>&1; then
        {
            printf 'GET / HTTP/1.1\r\nHost: %s:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' "$tip"
            sleep 0.5
            printf "%b%s" "$hdr" "$payload"
            sleep 0.5
        } | nc -w 2 "$tip" 8080 >/dev/null 2>&1 || true
    fi
}

check_connected() {
    DEV_STATE=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d '\r\n')
    if [ "$DEV_STATE" = "device" ]; then
        if adb -s "$SERIAL" shell ls >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

CONNECTED=0
if [ "$R1_DRYRUN" != "1" ]; then
    # Khởi động adb daemon nếu chưa chạy
    adb start-server >/dev/null 2>&1 || true

    # BƯỚC 1: Thử kết nối trực tiếp (cực nhanh 1-2s nếu cổng 5555 đã mở sẵn)
    echo "   [Kết nối] Thử kết nối trực tiếp tới $SERIAL..."
    OUT_CONN=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
    echo "   -> $OUT_CONN"
    sleep 1.2

    if check_connected; then
        CONNECTED=1
    else
        # BƯỚC 2: Nếu chưa vào được (loa AP hoặc bản gốc ngủ đông adbd), kích hoạt qua cổng 8080
        echo "   -> Loa chưa phản hồi, đang gửi tín hiệu kích hoạt ADB qua cổng 8080..."
        revive_speaker "$TARGET_IP"
        sleep 1.8

        # Thử lại 5 lần
        for try in 1 2 3 4 5; do
            echo "   [Kết nối lại] Thử lần $try/5 tới $SERIAL..."
            OUT_CONN=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
            echo "   -> $OUT_CONN"
            sleep 1.2
            if check_connected; then
                CONNECTED=1
                break
            fi
            sleep 1
        done
    fi

    if [ "$CONNECTED" != "1" ]; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI $SERIAL"
        echo "=========================================================="
        echo "Vui lòng kiểm tra các mục sau trên iPhone:"
        echo " 1. TẮT 4G/5G (Dữ liệu di động): Bắt buộc tắt để iPhone không"
        echo "    gửi gói tin qua mạng di động."
        echo " 2. BẬT MẠNG CỤC BỘ: Vào 'Cài đặt' iPhone -> cuộn xuống tìm app"
        echo "    'iSH' -> Gạt BẬT 'Mạng cục bộ' (Local Network)."
        echo " 3. ĐÚNG MẠNG WIFI: Đang kết nối cùng WiFi với loa (nếu WiFi nhà)"
        echo "    hoặc đã kết nối vào 'Phicomm_R1_xxxx' (nếu dùng 192.168.43.1)."
        echo " 4. KIỂM TRA ĐÈN LOA: Loa đã cắm điện, nếu dùng 192.168.43.1 thì"
        echo "    ấn giữ nút tròn đỉnh loa 6 giây cho đổi màu đèn cam/trắng."
        echo "=========================================================="
        exit 1
    fi
fi
echo ">> [OK] Kết nối thành công tới loa ($SERIAL)!"

# ------------------------------------------------------------------------------
# 5. DỌN SẠCH THƯ MỤC TẠM TRÊN LOA VÀ ĐẨY CẢ 3 FILE APK MỚI LÊN
# ------------------------------------------------------------------------------
echo ""
echo ">> [3/4] Đang dọn sạch bộ nhớ tạm của loa & nạp 3 file APK mới lên (/data/local/tmp/)..."
if [ "$R1_DRYRUN" != "1" ]; then
    adb -s "$SERIAL" shell "rm -rf /data/local/tmp/* 2>/dev/null" >/dev/null 2>&1
fi

for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
    echo "   -> Nạp $f..."
    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" push "$CACHE_DIR/$f" "/data/local/tmp/$f" >/dev/null 2>&1
    fi
done
echo ">> [OK] Đã đưa trọn vẹn 3 file mới lên loa!"

# ------------------------------------------------------------------------------
# 6. THỰC THI CHUỖI LỆNH CÀI ĐẶT CHUẨN XÁC THEO NEW.BAT
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 7. DỌN SẠCH FILE TẠM & FILE SCRIPT .SH TRÊN iSH ĐỂ LẦN SAU KHÔNG BỊ DÍNH FILE CŨ
# ------------------------------------------------------------------------------
rm -rf "$CACHE_DIR" 2>/dev/null || true
for tmp_sh in ./r1.sh ./r1*.sh /tmp/r1*.sh /tmp/install*.sh; do
    [ -f "$tmp_sh" ] && rm -f "$tmp_sh" 2>/dev/null || true
done

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

if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
    echo ""
    read_val "Nhấn Enter để kết thúc: " "" >/dev/null 2>&1 || true
fi
