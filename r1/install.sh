#!/bin/sh
# ==============================================================================
# BỘ CÀI PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, cài đặt AutoDLNA + Unisound + AI
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)

USER_IP=""
ASSUME_YES=""
CLI_MODE=""

for arg in "$@"; do
    case "$arg" in
        -y|--yes|-Yes) ASSUME_YES="1" ;;
        -DryRun|--dry-run) export R1_DRYRUN=1 ;;
        -Wifi|--wifi|-wifi) CLI_MODE="wifi" ;;
        -Scan|--scan|-scan) CLI_MODE="scan" ;;
        192.168.43.1)
            USER_IP="$arg"
            CLI_MODE="wifi"
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*)
            USER_IP="$arg"
            CLI_MODE="install"
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÔNG CỤ CẦN THIẾT (TỰ ĐỘNG MỞ KHO CHO ALPINE / iSH)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true

    # Đảm bảo có curl để tải file và gửi API cấu hình WiFi
    if ! command -v curl >/dev/null 2>&1; then
        echo ">> Đang cài đặt curl..."
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache curl >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y curl >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1 || true
        fi
    fi

    # Thử cài đặt adb và netcat nếu chưa có
    if ! command -v adb >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            if [ -f /etc/apk/repositories ]; then
                sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true
            fi
            apk add --no-cache android-tools netcat-openbsd >/dev/null 2>&1 || \
            apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get install -y android-tools-adb netcat-openbsd >/dev/null 2>&1 || true
        fi
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
# 2. HÀM DÒ TÌM DẢI MẠNG LAN & QUÉT TỰ ĐỘNG TÌM LOA PHICOMM R1
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
    echo ">> Đang quét tự động dải mạng LAN ($sub.1 -> 254) tìm loa Phicomm R1..."

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
                    if command -v curl >/dev/null 2>&1; then
                        if curl -s -m 0.35 -o /dev/null "http://$target:5555/" 2>/dev/null; then
                            found="5555"
                        elif curl -s -m 0.35 -o /dev/null "http://$target:8081/" 2>/dev/null; then
                            found="8081"
                        elif curl -s -m 0.35 -o /dev/null "http://$target:8080/" 2>/dev/null; then
                            found="8080"
                        fi
                    fi
                    if [ -z "$found" ] && command -v nc >/dev/null 2>&1; then
                        if nc -w 1 "$target" 5555 </dev/null >/dev/null 2>&1; then
                            found="5555"
                        elif nc -w 1 "$target" 8081 </dev/null >/dev/null 2>&1; then
                            found="8081"
                        elif nc -w 1 "$target" 8080 </dev/null >/dev/null 2>&1; then
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
            line=$(printf '%s' "$line" | tr -d '\r\n')
            [ -z "$line" ] && continue
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
            ip_val=$(printf '%s' "$line" | awk '{print $1}')
            echo "$ip_val" >> "$scan_tmp/ips.txt"
            echo "   [$TOTAL_FOUND] $line"
        done < "$scan_tmp/result.txt"
    fi
}

# ------------------------------------------------------------------------------
# 3. HÀM KÍCH HOẠT CỔNG ADB & KIỂM TRA KẾT NỐI
# ------------------------------------------------------------------------------
revive_speaker() {
    tip="$1"
    [ -z "$tip" ] && tip="192.168.43.1"
    [ "$R1_DRYRUN" = "1" ] && return 0

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 1.5 "http://$tip:8080/" >/dev/null 2>&1 || true
        curl -s -m 1.5 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=1 "http://$tip:8080/" >/dev/null 2>&1 || true
        wget -q -O- --timeout=1 "http://$tip:8081/" >/dev/null 2>&1 || true
    fi
}

check_connected() {
    state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
    if [ "$state" = "device" ]; then
        adb -s "$SERIAL" shell ls /data >/dev/null 2>&1
        return $?
    fi
    return 1
}

# ------------------------------------------------------------------------------
# 4. [MỤC 1] CẤU HÌNH WIFI CHO LOA QUA CHẾ ĐỘ AP 192.168.43.1
# ------------------------------------------------------------------------------
send_wifi_config() {
    target_ip="$1"
    ssid="$2"
    pass="$3"
    secure="$4"
    [ -z "$secure" ] && secure="WPA"

    esc_ssid=$(printf '%s' "$ssid" | sed 's/\\/\\\\/g; s/"/\\"/g')
    esc_pass=$(printf '%s' "$pass" | sed 's/\\/\\\\/g; s/"/\\"/g')
    payload="{\"ssid\":\"$esc_ssid\",\"secure\":\"$secure\",\"password\":\"$esc_pass\",\"mac\":\"\"}"

    if [ "$R1_DRYRUN" = "1" ]; then
        echo "   [DRY-RUN] Đã gửi cấu hình WiFi SSID='$ssid' tới http://$target_ip:8989/api/configwifi"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 5 -X POST "http://$target_ip:8989/api/configwifi" \
             -H "Content-Type: application/json" \
             -d "$payload" >/dev/null 2>&1 || true
        return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=5 --header="Content-Type: application/json" \
             --post-data="$payload" "http://$target_ip:8989/api/configwifi" >/dev/null 2>&1 || true
        return 0
    fi
    return 1
}

configure_wifi_ap() {
    echo ""
    echo "=========================================================="
    echo "  CẤU HÌNH WIFI CHO LOA VỪA RESET (CHẾ ĐỘ AP 192.168.43.1)"
    echo "=========================================================="
    echo " Hướng dẫn chuẩn bị:"
    echo "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'."
    echo "  2. Trên iPhone / Máy tính: Vào Cài đặt WiFi -> Kết nối 'Phicomm_R1_xxxx'."
    echo "  3. TẮT 4G/5G (Dữ liệu di động) trên điện thoại."
    echo "=========================================================="

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_val "Nhấn Enter khi đã kết nối vào WiFi của loa: " "" >/dev/null 2>&1 || true
    fi

    echo ""
    echo ">> Đang kiểm tra kết nối tới loa (192.168.43.1:8989)..."
    api_ok=0
    if [ "$R1_DRYRUN" = "1" ]; then
        api_ok=1
    elif command -v curl >/dev/null 2>&1; then
        if curl -s -m 2 "http://192.168.43.1:8989/" >/dev/null 2>&1 || curl -s -m 2 "http://192.168.43.1:8989/api/configwifi" >/dev/null 2>&1; then
            api_ok=1
        fi
    fi

    if [ "$api_ok" = "1" ]; then
        echo "   [OK] Đã kết nối được tới loa R1."
    else
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            echo "   [CẢNH BÁO] Chưa kết nối được 192.168.43.1:8989."
            echo "   Kiểm tra: Điện thoại đã chọn WiFi Phicomm_R1 chưa? Đã tắt 4G chưa?"
            ans=$(read_val "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: " "y")
            case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                "y"|"yes") ;;
                *) return 1 ;;
            esac
        fi
    fi

    echo ""
    echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
    echo "----------------------------------------------------------"
    ssid=""
    while [ -z "$ssid" ]; do
        ssid=$(read_val ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): " "")
        if [ "$R1_DRYRUN" = "1" ] && [ -z "$ssid" ]; then
            ssid="MyWiFi"
        fi
        if [ -z "$ssid" ]; then
            echo "   [!] Tên WiFi không được để trống!"
        fi
    done

    pass=$(read_val ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): " "")
    if [ "$R1_DRYRUN" = "1" ] && [ -z "$pass" ]; then
        pass="12345678"
    fi

    secure="WPA"
    if [ -z "$pass" ]; then
        secure="INSECURE"
        echo "   -> Chế độ WiFi không mật khẩu (INSECURE)"
    else
        pass_len=$(printf '%s' "$pass" | wc -c)
        if [ "$pass_len" -lt 8 ]; then
            echo "   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!"
        fi
    fi

    echo ""
    echo ">> Đang gửi cấu hình tới loa (192.168.43.1:8989)..."
    send_wifi_config "192.168.43.1" "$ssid" "$pass" "$secure"

    echo ""
    echo "=========================================================="
    echo "            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG!              "
    echo "=========================================================="
    echo " THÔNG BÁO QUAN TRỌNG:"
    echo "  1. Loa đang kết nối WiFi nhà, chờ khoảng 20 giây sẽ có IP."
    echo "  2. Hãy chuyển iPhone / Máy tính về lại mạng WiFi nhà."
    echo "  3. Sau đó quay lại menu chọn [2] để tìm IP và cài APK."
    echo "=========================================================="

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 5. [MỤC 2] CÀI ĐẶT APK CHO LOA TRONG MẠNG LAN (GIỮ NGUYÊN CODE CHUẨN)
# ------------------------------------------------------------------------------
run_install_lan() {
    target_param="$1"
    TARGET_IP="$target_param"

    if [ -z "$TARGET_IP" ]; then
        echo ""
        echo "----------------------------------------------------------"
        echo "                    TÌM IP CỦA LOA TRONG LAN              "
        echo "----------------------------------------------------------"
        echo " [S] hoặc [Enter]: Tự động QUÉT tìm IP loa trong WiFi nhà (LAN)"
        echo " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)"
        echo "----------------------------------------------------------"
        echo ""

        while [ -z "$TARGET_IP" ]; do
            USER_INPUT=$(read_val "Nhập IP hoặc gõ 'S' để quét [Mặc định: S]: " "S")
            USER_INPUT=$(printf '%s' "$USER_INPUT" | tr -d ' ')

            case "$USER_INPUT" in
                "s"|"S"|"scan"|"SCAN"|"")
                    scan_speaker_ip
                    if [ "$TOTAL_FOUND" -gt 0 ]; then
                        echo ""
                        PICK=$(read_val "Chọn số thứ tự loa (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
                        PICK=$(printf '%s' "$PICK" | tr -d ' ')
                        if [ "$PICK" -ge 1 ] 2>/dev/null && [ "$PICK" -le "$TOTAL_FOUND" ] 2>/dev/null; then
                            TARGET_IP=$(sed -n "${PICK}p" "$scan_tmp/ips.txt")
                        elif printf '%s' "$PICK" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
                            TARGET_IP="$PICK"
                        else
                            TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
                        fi
                    else
                        echo ""
                        echo ">> Không tìm thấy loa tự động trong mạng LAN."
                        MANUAL=$(read_val "Vui lòng nhập IP loa thủ công (hoặc Enter về menu): " "")
                        if [ -n "$MANUAL" ]; then
                            TARGET_IP="$MANUAL"
                        else
                            rm -rf "$scan_tmp" 2>/dev/null || true
                            return 1
                        fi
                    fi
                    rm -rf "$scan_tmp" 2>/dev/null || true
                    ;;
                "1"|"192.168.43.1")
                    echo ""
                    echo "=========================================================="
                    echo "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!"
                    echo "=========================================================="
                    echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
                    echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
                    echo "=========================================================="
                    read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                    return 1
                    ;;
                *)
                    TARGET_IP=$(printf '%s' "$USER_INPUT" | sed 's/:5555$//')
                    ;;
            esac
        done
    fi

    # Kiểm tra lại nếu người dùng nhập nhầm 192.168.43.1
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo ""
        echo "=========================================================="
        echo "  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!"
        echo "=========================================================="
        echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
        echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
        echo "=========================================================="
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d ' ' | sed 's/:5555$//')
    SERIAL="$TARGET_IP:5555"

    echo ""
    echo ">> Sẽ kết nối tới IP: $TARGET_IP"

    # [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub
    echo ""
    echo ">> [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub..."
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
            echo "Vui lòng kiểm tra lại kết nối mạng WiFi/4G của thiết bị."
            echo "=========================================================="
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        echo "   [OK] Đã chuẩn bị file $f thành công."
    done

    # [2/4] Bắt đầu kết nối thiết bị ADB
    echo ""
    echo ">> [2/4] Bắt đầu kết nối thiết bị [$SERIAL]..."

    if [ "$R1_DRYRUN" != "1" ] && ! command -v adb >/dev/null 2>&1; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] THIẾU CÔNG CỤ ADB TRÊN THIẾT BỊ!"
        echo "=========================================================="
        echo "Vui lòng chạy lệnh sau trong iSH để cài đặt adb:"
        echo "  apk add android-tools"
        echo "=========================================================="
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    CONNECTED=0
    if [ "$R1_DRYRUN" != "1" ]; then
        adb kill-server >/dev/null 2>&1 || true
        adb start-server >/dev/null 2>&1 || true

        echo "   [Kết nối] Thử kết nối trực tiếp..."
        OUT_CONN=$(adb connect "$SERIAL" 2>&1 | tr -d '\r\n')
        echo "   -> $OUT_CONN"
        sleep 1.2

        if check_connected; then
            CONNECTED=1
        else
            echo "   -> Loa chưa phản hồi, đang gửi tín hiệu kích hoạt ADB qua cổng 8080..."
            revive_speaker "$TARGET_IP"
            sleep 1.8

            for try in 1 2 3 4 5; do
                echo "   [Thử lại] Lần $try/5 tới $SERIAL..."
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
            echo "Vui lòng kiểm tra:"
            echo " 1. Loa đã cắm nguồn và đang bật."
            echo " 2. Điện thoại và loa đang cùng kết nối vào một mạng WiFi."
            echo " 3. Địa chỉ IP của loa ($TARGET_IP) đã đúng chưa."
            echo " 4. Nếu loa vừa reset, hãy chọn mục 1 để cấu hình WiFi trước."
            echo "=========================================================="
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
    fi
    echo ">> [OK] Kết nối thành công tới loa ($SERIAL)!"

    # [3/4] Đẩy 3 file APK lên bộ nhớ tạm của loa
    echo ""
    echo ">> [3/4] Đang dọn sạch bộ nhớ tạm của loa & nạp 3 file APK mới lên (/data/local/tmp/)..."

    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" shell rm -rf "/data/local/tmp/*" >/dev/null 2>&1
        for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
            echo "   -> Nạp $f..."
            adb -s "$SERIAL" push "$CACHE_DIR/$f" "/data/local/tmp/$f" >/dev/null 2>&1
        done
    else
        echo "   -> Nạp autodlna.apk..."
        echo "   -> Nạp unisound.apk..."
        echo "   -> Nạp AIBoxPlus_DLNA.apk..."
    fi
    echo ">> [OK] Đã đưa trọn vẹn 3 file mới lên loa!"

    # [4/4] Bắt đầu cài đặt hệ thống chuẩn xác theo new.bat
    echo ""
    echo ">> [4/4] Bắt đầu cài đặt hệ thống..."

    if [ "$R1_DRYRUN" != "1" ]; then
        echo "   -> Đang dọn dẹp bộ nhớ đệm..."
        adb -s "$SERIAL" shell "rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip 2>/dev/null; /system/bin/pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null" >/dev/null 2>&1

        echo "   -> Tắt các ứng dụng chiếm quyền..."
        adb -s "$SERIAL" shell "/system/bin/pm hide com.phicomm.speaker.airskill 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.exceptionreporter 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.systemtool 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.device 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.otaservice 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.productiontest 2>/dev/null; /system/bin/pm hide com.phicomm.speaker.bugreport 2>/dev/null" >/dev/null 2>&1

        echo "   -> Cài đặt AutoDLNA + Unisound..."
        adb -s "$SERIAL" shell "/system/bin/pm install -r /data/local/tmp/autodlna.apk; /system/bin/pm install -r /data/local/tmp/unisound.apk; rm -f /data/local/tmp/autodlna.apk /data/local/tmp/unisound.apk" >/dev/null 2>&1

        echo "   -> Khởi động AutoDLNA + Unisound..."
        adb -s "$SERIAL" shell "am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null" >/dev/null 2>&1
        sleep 2

        echo "   -> Khôi phục ijetty & netctl..."
        adb -s "$SERIAL" shell "/system/bin/pm unhide com.phicomm.speaker.ijetty 2>/dev/null; /system/bin/pm unhide com.phicomm.speaker.netctl 2>/dev/null" >/dev/null 2>&1

        echo "   -> Gỡ bản AI cũ và cài đặt AI Tiếng Việt mới..."
        adb -s "$SERIAL" shell "/system/bin/pm uninstall info.dourok.voicebot 2>/dev/null; /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk; rm -f /data/local/tmp/AIBoxPlus_DLNA.apk" >/dev/null 2>&1

        echo "   -> Khởi động AI Box Plus & cấu hình đèn LED..."
        adb -s "$SERIAL" shell "am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" >/dev/null 2>&1

        LAN_IP=$(adb -s "$SERIAL" shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null | tr -d '\r\n')

        echo "   -> Đang khởi động lại loa (Reboot)..."
        adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
    else
        echo "   -> [DRY-RUN] Đã thực thi chuỗi lệnh new.bat chuẩn xác!"
        echo "   -> [DRY-RUN] Đã gửi lệnh khởi động lại (Reboot) loa!"
        LAN_IP=""
    fi

    # Dọn dẹp cache
    rm -rf "$CACHE_DIR" 2>/dev/null || true
    for tmp_sh in ./r1.sh ./r1*.sh /tmp/r1*.sh /tmp/install*.sh; do
        [ -f "$tmp_sh" ] && rm -f "$tmp_sh" 2>/dev/null || true
    done

    echo ""
    echo "=========================================================="
    echo "                    CÀI ĐẶT HOÀN TẤT!                     "
    echo "=========================================================="
    echo ">> Đã gửi lệnh khởi động lại (Reboot) loa thành công!"
    echo ">> Loa đang khởi động lại (thường mất khoảng 30 - 45 giây)."
    echo ""
    if [ -n "$LAN_IP" ]; then
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
        echo "   👉 http://$LAN_IP:8081/"
    else
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
        echo "   👉 http://$TARGET_IP:8081/"
    fi

    echo "=========================================================="
    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 6. MENU CHÍNH
# ------------------------------------------------------------------------------
show_menu() {
    clear 2>/dev/null || true
    echo "=========================================================="
    echo "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX"
    echo "=========================================================="
    echo "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)"
    echo "     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx"
    echo ""
    echo "  2) Quét IP LAN & Cài đặt APK (AutoDLNA + Unisound + AI)"
    echo "     -> Dùng khi loa ĐÃ vào WiFi nhà (có IP LAN)"
    echo ""
    echo "  3) Chỉ quét tìm IP loa trong LAN (không cài đặt)"
    echo "  4) Thoát"
    echo "=========================================================="
    printf "Chọn [1-4]: "
    CHOICE=""
    if ! read -r CHOICE 2>/dev/null; then
        CHOICE="4"
    fi
    CHOICE=$(printf '%s' "$CHOICE" | tr -d ' \r\n')
}

# Xử lý tham số CLI trực tiếp (nếu có)
if [ "$CLI_MODE" = "wifi" ]; then
    configure_wifi_ap
    exit 0
elif [ "$CLI_MODE" = "install" ]; then
    run_install_lan "$USER_IP"
    exit 0
elif [ "$CLI_MODE" = "scan" ]; then
    scan_speaker_ip
    exit 0
fi

# Vòng lặp menu
while :; do
    show_menu
    case "$CHOICE" in
        1)
            configure_wifi_ap
            ;;
        2)
            run_install_lan ""
            ;;
        3)
            scan_speaker_ip
            echo ""
            read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
            ;;
        4|"q"|"Q"|"exit")
            echo "Thoát chương trình."
            break
            ;;
        "")
            continue
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 4."
            sleep 1
            ;;
    esac
done
