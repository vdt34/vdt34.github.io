#!/bin/sh
# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - TỐI ƯU CHO iPHONE (iSH) & LINUX / ANDROID
# Tự động cấu hình WiFi, quét tìm loa trong LAN, dọn file cũ, tải APK từ GitHub
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)

USER_IP=""
ASSUME_YES=""
RUN_WIFI_CLI=""
RUN_SCAN_CLI=""

for arg in "$@"; do
    case "$arg" in
        -y|--yes|-Yes) ASSUME_YES="1" ;;
        -DryRun|--dry-run) export R1_DRYRUN=1 ;;
        --wifi|-wifi|-Wifi) RUN_WIFI_CLI="1" ;;
        --scan|-scan|-Scan) RUN_SCAN_CLI="1" ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*) USER_IP="$arg" ;;
    esac
done

clear 2>/dev/null || true
echo "=========================================================="
echo "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÔNG CỤ CẦN THIẾT (TỰ ĐỘNG MỞ KHO CHO ALPINE / iSH)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true

    # Kiểm tra và cài đặt curl nếu thiếu (cần cho tải file và gửi WiFi)
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

    # Thử cài đặt adb và netcat nếu chưa có (nếu có Internet)
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
# 2. CẤU HÌNH WIFI CHO LOA QUA API AP (192.168.43.1:8989)
# ------------------------------------------------------------------------------
send_wifi_config() {
    target_ip="$1"
    [ -z "$target_ip" ] && target_ip="192.168.43.1"
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
    else
        echo "   [LỖI] Cần lệnh curl hoặc wget để gửi cấu hình."
        return 1
    fi
}

ask_wifi_and_send() {
    target_ip="$1"
    [ -z "$target_ip" ] && target_ip="192.168.43.1"

    echo ""
    echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
    echo "----------------------------------------------------------"
    ssid=""
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        ssid="MyWiFi"
        pass="12345678"
    else
        while [ -z "$ssid" ]; do
            printf ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): "
            read -r ssid 2>/dev/null || ssid=""
            ssid=$(printf '%s' "$ssid" | tr -d '\r\n')
            [ -z "$ssid" ] && echo "   [!] Tên WiFi không được để trống!"
        done

        printf ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): "
        pass=""
        read -r pass 2>/dev/null || pass=""
        pass=$(printf '%s' "$pass" | tr -d '\r\n')
    fi

    secure="WPA"
    if [ -z "$pass" ]; then
        secure="INSECURE"
        echo "   -> Chế độ WiFi không mật khẩu (INSECURE)"
    else
        if [ ${#pass} -lt 8 ]; then
            echo "   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!"
        fi
    fi

    echo ""
    echo ">> Đang gửi cấu hình tới loa ($target_ip:8989)..."
    send_wifi_config "$target_ip" "$ssid" "$pass" "$secure"
    return $?
}

run_wifi_config() {
    echo ""
    echo "----------------------------------------------------------"
    echo "        CẤU HÌNH WIFI CHO LOA QUA CHẾ ĐỘ AP               "
    echo "----------------------------------------------------------"
    echo " LƯU Ý: Loa chỉ phát WiFi AP ~60-90 giây sau khi reset."
    echo "  -> Bước này CHỈ gửi WiFi (1 request HTTP nhỏ, xong <5s)."
    echo "  -> KHÔNG push APK ở đây vì sẽ bị timeout."
    echo ""
    echo " Các bước chuẩn bị:"
    echo "  1. Giữ nút tròn đỉnh loa 5-6 giây cho đến khi đèn đổi màu/nhấp nháy."
    echo "  2. Trên iPhone / Máy tính: Cài đặt WiFi -> chọn mạng 'Phicomm_R1_xxxx'."
    echo "  3. TẮT 4G/5G (Dữ liệu di động trên điện thoại)."
    echo "  4. Nhấn Enter để tiếp tục."
    echo "----------------------------------------------------------"
    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        printf "Nhấn Enter khi đã kết nối WiFi loa: "
        read -r _ 2>/dev/null || true
    fi

    echo ""
    echo ">> Kiểm tra kết nối tới 192.168.43.1:8989..."
    connected_api=0
    if [ "$R1_DRYRUN" = "1" ]; then
        connected_api=1
    else
        # Kiểm tra cổng 8989 bằng curl hoặc nc (không dùng nc -z để tránh lỗi busybox)
        if command -v curl >/dev/null 2>&1; then
            if curl -s -m 2 -o /dev/null "http://192.168.43.1:8989/" 2>/dev/null; then
                connected_api=1
            fi
        fi
        if [ "$connected_api" = "0" ] && command -v nc >/dev/null 2>&1; then
            if nc -w 2 192.168.43.1 8989 </dev/null >/dev/null 2>&1; then
                connected_api=1
            fi
        fi
    fi

    if [ "$connected_api" = "1" ]; then
        echo "   [OK] Đã kết nối được tới loa R1."
    else
        echo "   [!] Chưa thấy phản hồi từ 192.168.43.1:8989."
        echo "   (Hãy chắc chắn điện thoại đã kết nối WiFi Phicomm_R1 và đã TẮT 4G)."
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            printf "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: "
            ans=""
            read -r ans 2>/dev/null || true
            case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                "y"|"yes") ;;
                *) return 1 ;;
            esac
        fi
    fi

    ask_wifi_and_send "192.168.43.1"
    rc=$?

    if [ "$rc" = "0" ]; then
        echo ""
        echo "=========================================================="
        echo "            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG               "
        echo "=========================================================="
        echo " BƯỚC TIẾP THEO:"
        echo "  1. Nghe loa báo 'kết nối thành công' (nếu có)."
        echo "  2. Đợi 20 giây để loa kết nối WiFi nhà và nhận IP LAN."
        echo "  3. Chuyển thiết bị về lại mạng WiFi nhà."
        echo "  4. Quay lại menu, chọn mục 2 để quét IP LAN & cài APK."
        echo "=========================================================="
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            printf "Đợi 20s và tự động quay lại menu? [Enter]: "
            read -r _ 2>/dev/null || true
            sleep 20
        fi
    fi
    return $rc
}

# ------------------------------------------------------------------------------
# 3. HÀM TÌM KIẾM DẢI MẠNG & QUÉT LOA TRONG LAN
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

    # Nếu không có Python, quét bằng vòng lặp shell dùng curl / nc an toàn
    if [ ! -s "$scan_tmp/result.txt" ]; then
        idx=1
        while [ $idx -le 254 ]; do
            bend=$((idx + 25))
            [ $bend -gt 254 ] && bend=254
            i=$idx
            while [ $i -le $bend ]; do
                (
                    target="${sub}.${i}"
                    found=""
                    if command -v curl >/dev/null 2>&1; then
                        if curl -s -m 0.3 -o /dev/null "http://$target:8081/" 2>/dev/null; then
                            found="8081"
                        elif curl -s -m 0.3 -o /dev/null "http://$target:8080/" 2>/dev/null; then
                            found="8080"
                        fi
                    fi
                    if [ -z "$found" ] && command -v nc >/dev/null 2>&1; then
                        if nc -w 1 "$target" 5555 </dev/null >/dev/null 2>&1; then
                            found="5555"
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

# ------------------------------------------------------------------------------
# 4. HÀM KÍCH HOẠT CỔNG ADB & KIỂM TRA TRẠNG THÁI
# ------------------------------------------------------------------------------
revive_speaker() {
    tip="$1"
    [ -z "$tip" ] && return
    if command -v curl >/dev/null 2>&1; then
        curl -s -m 1.5 "http://$tip:8080/" >/dev/null 2>&1 || true
        curl -s -m 1.5 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=1 "http://$tip:8080/" >/dev/null 2>&1 || true
        wget -q -O- --timeout=1 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v nc >/dev/null 2>&1; then
        nc -w 1 "$tip" 8080 </dev/null >/dev/null 2>&1 || true
        nc -w 1 "$tip" 8081 </dev/null >/dev/null 2>&1 || true
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
# 5. TẢI VÀ CHUẨN BỊ 3 FILE APK TỪ GITHUB
# ------------------------------------------------------------------------------
ensure_apks() {
    echo ""
    echo ">> [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub..."
    mkdir -p "$CACHE_DIR"

    TS=$(date +%s 2>/dev/null || echo "1")
    for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
        cached="$CACHE_DIR/$f"

        if [ "$R1_DRYRUN" = "1" ] && [ -f "$SCRIPT_DIR/$f" ]; then
            cp -f "$SCRIPT_DIR/$f" "$cached" 2>/dev/null || true
            echo "   [OK] (DryRun) Dùng file $f có sẵn."
        elif [ -f "$cached" ] && [ "$(wc -c < "$cached" 2>/dev/null)" -ge 500000 ]; then
            echo "   [OK] Đã có sẵn $f trong bộ nhớ tạm."
        else
            echo "   -> Đang tải bản mới nhất: $f..."
            if command -v curl >/dev/null 2>&1; then
                curl -k -fL --connect-timeout 25 -# -o "$cached.tmp" "$BASE_URL/$f?t=$TS" && mv -f "$cached.tmp" "$cached"
            elif command -v wget >/dev/null 2>&1; then
                wget -q --no-check-certificate -O "$cached" "$BASE_URL/$f?t=$TS"
            fi
        fi

        if [ "$R1_DRYRUN" != "1" ] && { [ ! -f "$cached" ] || [ "$(wc -c < "$cached" 2>/dev/null)" -lt 500000 ]; }; then
            echo ""
            echo "=========================================================="
            echo "  [LỖI] KHÔNG THỂ TẢI FILE $f TỪ GITHUB!"
            echo "=========================================================="
            echo "Nguyên nhân: Thiết bị hiện không có kết nối Internet."
            echo "Vui lòng kiểm tra lại kết nối mạng WiFi/4G."
            echo "=========================================================="
            return 1
        fi
        echo "   [OK] Đã chuẩn bị file $f thành công."
    done
    return 0
}

# ------------------------------------------------------------------------------
# 6. LUỒNG QUÉT IP LAN & CÀI ĐẶT APK
# ------------------------------------------------------------------------------
run_install() {
    # Kiểm tra lệnh adb trước khi cài đặt APK
    if [ "$R1_DRYRUN" != "1" ] && ! command -v adb >/dev/null 2>&1; then
        echo ""
        echo "=========================================================="
        echo "  [LỖI] THIẾU CÔNG CỤ 'adb' ĐỂ CÀI ĐẶT APK VÀO LOA!"
        echo "=========================================================="
        echo "Vui lòng kết nối WiFi nhà (có Internet) và chạy lệnh sau trong iSH:"
        echo "  apk add android-tools"
        echo "Sau đó chạy lại script để tiến hành cài đặt."
        echo "=========================================================="
        if [ "$ASSUME_YES" != "1" ]; then
            printf "Nhấn Enter để quay lại menu: "
            read -r _ 2>/dev/null || true
        fi
        return 1
    fi

    passed_ip="$1"
    TARGET_IP="$passed_ip"
    [ -z "$TARGET_IP" ] && TARGET_IP="$USER_IP"

    if [ -z "$TARGET_IP" ]; then
        echo ""
        echo "----------------------------------------------------------"
        echo "                  XÁC ĐỊNH IP CỦA LOA                     "
        echo "----------------------------------------------------------"
        echo " [S]     Tự động QUÉT tìm IP loa trong WiFi nhà (KHUYÊN DÙNG)"
        echo " [1]     Dùng 192.168.43.1 (KHÔNG khuyến nghị — AP sẽ tắt)"
        echo " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)"
        echo "----------------------------------------------------------"

        while [ -z "$TARGET_IP" ]; do
            USER_INPUT=$(read_val "Nhập IP hoặc 'S' để quét [Mặc định: S]: " "S")
            USER_INPUT=$(echo "$USER_INPUT" | tr -d ' ')

            case "$USER_INPUT" in
                "s"|"S"|"scan"|"SCAN")
                    scan_speaker_ip
                    if [ "${TOTAL_FOUND:-0}" -gt 0 ]; then
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
                        echo ">> Không tìm thấy loa trong mạng LAN."
                        echo "   -> Nếu loa vừa reset, hãy quay lại menu chọn mục 1 để cấu hình WiFi trước."
                        MANUAL=$(read_val "Hoặc nhập IP loa thủ công (Enter=quay lại menu): " "")
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
                    echo "  [CẢNH BÁO] Chọn 192.168.43.1 (AP mode) để cài APK"
                    echo "  KHÔNG khuyến nghị vì AP sẽ tắt sau ~60-90s!"
                    echo "=========================================================="
                    echo "  Quy trình đúng:"
                    echo "   1. Chọn mục 1 cấu hình WiFi trước (mất 5s)"
                    echo "   2. Loa kết nối WiFi nhà, có IP LAN"
                    echo "   3. Chọn mục 2 quét IP LAN và cài đặt siêu tốc"
                    echo "=========================================================="
                    printf "Vẫn tiếp tục cài qua AP? [y/N]: "
                    ans=""
                    read -r ans 2>/dev/null || true
                    case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                        "y"|"yes") TARGET_IP="192.168.43.1" ;;
                        *) return 1 ;;
                    esac
                    ;;
                *)
                    TARGET_IP=$(echo "$USER_INPUT" | sed 's/:5555$//')
                    ;;
            esac
        done
    fi

    TARGET_IP=$(echo "$TARGET_IP" | tr -d ' ' | sed 's/:5555$//')
    SERIAL="$TARGET_IP:5555"

    echo ""
    echo ">> Sẽ kết nối tới IP: $TARGET_IP"

    # Tải bộ 3 file APK
    ensure_apks || return 1

    # Kết nối ADB tới loa
    echo ""
    echo ">> [2/4] Bắt đầu kết nối thiết bị [$SERIAL]..."

    CONNECTED=0
    if [ "$R1_DRYRUN" != "1" ]; then
        adb start-server >/dev/null 2>&1 || true

        echo "   [Kết nối] Thử kết nối trực tiếp tới $SERIAL..."
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
            echo " Kiểm tra:"
            echo "  - Thiết bị đã kết nối cùng mạng WiFi với loa chưa?"
            echo "  - TẮT 4G/5G trên điện thoại (để không bị định tuyến nhầm)."
            echo "  - Trên iOS: Đã bật 'Mạng cục bộ' cho iSH chưa?"
            echo "  - Nếu loa vừa reset -> hãy chọn mục 1 để cấu hình WiFi trước."
            echo "=========================================================="
            if [ "$ASSUME_YES" != "1" ]; then
                printf "Nhấn Enter để quay lại menu: "
                read -r _ 2>/dev/null || true
            fi
            return 1
        fi
    fi
    echo ">> [OK] Kết nối thành công tới loa ($SERIAL)!"

    # Nạp 3 file APK lên loa
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

    # Thực thi cài đặt chuẩn new.bat
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
        echo ">> Truy cập bảng điều khiển loa tại: http://192.168.43.1:8081/"
    else
        echo ">> Truy cập bảng điều khiển loa tại: http://$TARGET_IP:8081/"
    fi
    echo "=========================================================="

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        printf "Nhấn Enter để quay lại menu: "
        read -r _ 2>/dev/null || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 7. MENU CHÍNH & VÒNG LẶP ĐIỀU KHIỂN
# ------------------------------------------------------------------------------
show_menu() {
    echo ""
    echo "=========================================================="
    echo "     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX"
    echo "=========================================================="
    echo "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)"
    echo "     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx"
    echo ""
    echo "  2) Quét IP LAN & cài đặt APK (AutoDLNA + Unisound + AI)"
    echo "     -> Dùng khi loa ĐÃ vào WiFi nhà (có IP LAN)"
    echo ""
    echo "  3) Chỉ quét IP LAN (không cài đặt)"
    echo "  4) Thoát"
    echo "=========================================================="
    printf "Chọn [1-4]: "
    CHOICE=""
    if ! read -r CHOICE 2>/dev/null; then
        CHOICE="4"
    fi
    CHOICE=$(printf '%s' "$CHOICE" | tr -d ' \r\n')
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if [ -n "$USER_IP" ]; then
    run_install "$USER_IP"
    exit $?
fi

if [ "$RUN_WIFI_CLI" = "1" ]; then
    run_wifi_config
    exit $?
fi

if [ "$RUN_SCAN_CLI" = "1" ]; then
    scan_speaker_ip
    exit $?
fi

# Vòng lặp menu chính tương tác
while :; do
    show_menu
    case "$CHOICE" in
        1)
            run_wifi_config
            ;;
        2)
            run_install ""
            ;;
        3)
            scan_speaker_ip
            if [ "${TOTAL_FOUND:-0}" -gt 0 ]; then
                echo ""
                echo ">> Đã tìm thấy $TOTAL_FOUND loa trong mạng LAN."
            else
                echo ""
                echo ">> Không tìm thấy loa R1 trong dải mạng hiện tại."
            fi
            printf "Nhấn Enter để quay lại menu: "
            read -r _ 2>/dev/null || true
            ;;
        4|"q"|"Q"|"exit")
            echo "Thoát chương trình."
            break
            ;;
        "")
            # Người dùng bấm Enter mà không nhập số -> hiện lại menu
            continue
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 4."
            sleep 1
            ;;
    esac
done
