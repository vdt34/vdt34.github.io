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
        [0-9]*.[0-9]*.[0-9]*.[0-9]*:[0-9]*)
            USER_IP="$arg"
            CLI_MODE="install"
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*)
            USER_IP="$arg"
            CLI_MODE="install"
            ;;
    esac
done

UI_RESET=""
UI_BOLD=""
UI_CYAN=""
UI_GREEN=""
UI_YELLOW=""
UI_RED=""
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    UI_RESET=$(printf '\033[0m')
    UI_BOLD=$(printf '\033[1m')
    UI_CYAN=$(printf '\033[36m')
    UI_GREEN=$(printf '\033[32m')
    UI_YELLOW=$(printf '\033[33m')
    UI_RED=$(printf '\033[31m')
fi

ui_header() {
    printf '\n%s%sPHICOMM R1%s\n' "$UI_BOLD" "$UI_CYAN" "$UI_RESET"
    printf '%s\n' "────────────────────────────────────────────────────────────"
    printf '%s%s%s\n' "$UI_BOLD" "$1" "$UI_RESET"
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '%s\n\n' "────────────────────────────────────────────────────────────"
}

ui_section() {
    printf '\n%s%s%s%s\n' "$UI_BOLD" "$UI_CYAN" "$1" "$UI_RESET"
}

ui_status() {
    level="$1"
    shift
    case "$level" in
        success) color="$UI_GREEN"; tag="OK" ;;
        warning) color="$UI_YELLOW"; tag="WARN" ;;
        error) color="$UI_RED"; tag="ERR" ;;
        *) color="$UI_CYAN"; tag="INFO" ;;
    esac
    printf '%s[%s]%s %s\n' "$color" "$tag" "$UI_RESET" "$*"
}

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÔNG CỤ CẦN THIẾT (TỰ ĐỘNG MỞ KHO CHO ALPINE / iSH)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true
    [ "$R1_DRYRUN" = "1" ] && return 0

    # Đảm bảo có curl để tải file và gửi API cấu hình WiFi
    if ! command -v curl >/dev/null 2>&1; then
        ui_status info "Đang cài đặt curl..."
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
    val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$val" ] && val="$def"
    echo "$val"
}

progress_update() {
    [ -t 1 ] || return
    percent="$1"
    label="$2"
    filled=$((percent / 2))
    empty=$((50 - filled))
    bar=""
    idx=0
    while [ "$idx" -lt "$filled" ]; do
        bar="${bar}█"
        idx=$((idx + 1))
    done
    idx=0
    while [ "$idx" -lt "$empty" ]; do
        bar="${bar}░"
        idx=$((idx + 1))
    done

    if [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '\033[2A\033[2K'
    fi
    printf '   %s\n' "$label"
    printf '   [%s] %3s%%\n' "$bar" "$percent"
    R1_PROGRESS_ACTIVE=1
}

progress_finish() {
    if [ -t 1 ] && [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '\033[2A\033[2K\033[1B\033[2K'
        R1_PROGRESS_ACTIVE=""
    fi
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
    ui_header "QUÉT MẠNG LAN" "Đang tìm loa Phicomm R1 trong $sub.1 - $sub.254"

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
        ui_section "THIẾT BỊ TÌM THẤY"
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
    ADB_LAST_STATE=$(adb -s "$SERIAL" get-state 2>&1)
    state_status=$?
    state=$(printf '%s' "$ADB_LAST_STATE" | tr -d ' \r\n')
    if [ "$state_status" -eq 0 ] && [ "$state" = "device" ]; then
        ADB_LAST_SHELL=$(adb -s "$SERIAL" shell echo R1_ADB_READY 2>&1)
        shell_status=$?
        if [ "$shell_status" -eq 0 ] && printf '%s\n' "$ADB_LAST_SHELL" | grep -q 'R1_ADB_READY'; then
            return 0
        fi
    fi
    return 1
}

wait_for_speaker_boot() {
    try=1
    while [ "$try" -le 45 ]; do
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        if check_connected; then
            boot_state=$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')
            [ "$boot_state" = "1" ] && return 0
        fi
        progress_update 98 "Đang chờ loa khởi động lại ($try/45)"
        sleep 2
        try=$((try + 1))
    done
    return 1
}

wait_for_webui() {
    try=1
    while [ "$try" -le 15 ]; do
        if command -v curl >/dev/null 2>&1 && curl -sS -m 1 -o /dev/null "http://$TARGET_IP:8081/" 2>/dev/null; then
            return 0
        fi
        progress_update 99 "Đang chờ WebUI khởi động ($try/15)"
        sleep 1
        try=$((try + 1))
    done
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
    ui_header "CẤU HÌNH WI-FI CHO LOA" "Kết nối vào điểm truy cập Phicomm_R1_xxxx"
    echo "Trước khi tiếp tục:"
    echo "  1. Kết nối điện thoại hoặc máy tính với Wi-Fi Phicomm_R1_xxxx."
    echo "  2. Trên điện thoại, tạm tắt dữ liệu di động."

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_val "Nhấn Enter khi đã kết nối vào WiFi của loa: " "" >/dev/null 2>&1 || true
    fi

    ui_section "KIỂM TRA ĐIỂM TRUY CẬP"
    echo "Đang kiểm tra 192.168.43.1:8989..."
    api_ok=0
    if [ "$R1_DRYRUN" = "1" ]; then
        api_ok=1
    elif command -v curl >/dev/null 2>&1; then
        if curl -s -m 2 "http://192.168.43.1:8989/" >/dev/null 2>&1 || curl -s -m 2 "http://192.168.43.1:8989/api/configwifi" >/dev/null 2>&1; then
            api_ok=1
        fi
    fi

    if [ "$api_ok" = "1" ]; then
        ui_status success "Đã kết nối tới loa."
    else
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            ui_status warning "Chưa kết nối được 192.168.43.1:8989."
            echo "Kiểm tra Wi-Fi đang kết nối và thử lại."
            ans=$(read_val "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: " "y")
            case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                "y"|"yes") ;;
                *) return 1 ;;
            esac
        fi
    fi

    ui_section "THÔNG TIN WI-FI NHÀ"
    echo "Nhập mạng Wi-Fi mà loa sẽ kết nối."
    ssid_default=""
    pass_default=""
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        ssid_default="MyWiFi"
        pass_default="12345678"
    fi
    ssid=""
    while [ -z "$ssid" ]; do
        ssid=$(read_val "Tên Wi-Fi nhà (SSID, phân biệt HOA/thường): " "$ssid_default")
        if [ -z "$ssid" ]; then
            ui_status warning "Tên Wi-Fi không được để trống."
        fi
    done

    pass=$(read_val "Mật khẩu Wi-Fi (Enter nếu mạng không có mật khẩu): " "$pass_default")

    secure="WPA"
    if [ -z "$pass" ]; then
        secure="INSECURE"
        ui_status info "Mạng Wi-Fi không mật khẩu."
    else
        pass_len=$(printf '%s' "$pass" | wc -c)
        if [ "$pass_len" -lt 8 ]; then
            ui_status warning "Mật khẩu Wi-Fi thông thường cần ít nhất 8 ký tự."
        fi
    fi

    ui_section "GỬI CẤU HÌNH"
    echo "Đang gửi thông tin Wi-Fi tới loa..."
    send_wifi_config "192.168.43.1" "$ssid" "$pass" "$secure"

    ui_status success "Đã gửi cấu hình Wi-Fi."
    echo "Đợi khoảng 20 giây để loa kết nối mạng, sau đó chọn mục 2 để quét IP và cài APK."

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
        ui_header "CÀI ĐẶT LOA" "Nhập IP hoặc quét tự động trong mạng LAN"
        echo "Nhập IP theo dạng 192.168.1.94 hoặc 192.168.1.94:5555."

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
                        ui_status warning "Không tìm thấy loa trong mạng LAN."
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
                    ui_status warning "Không thể cài APK qua điểm truy cập 192.168.43.1."
                    echo "Hãy cấu hình Wi-Fi cho loa trước; điểm truy cập có thể tự tắt."
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
        ui_status warning "Không thể cài APK qua điểm truy cập 192.168.43.1."
        echo "Hãy cấu hình Wi-Fi cho loa trước; điểm truy cập có thể tự tắt."
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d '[:space:]')
    TARGET_PORT=5555
    case "$TARGET_IP" in
        *:*)
            TARGET_PORT=${TARGET_IP##*:}
            TARGET_IP=${TARGET_IP%:*}
            case "$TARGET_PORT" in
                ''|*[!0-9]*)
                    ui_status error "Cổng ADB không hợp lệ."
                    return 1
                    ;;
            esac
            if [ "$TARGET_PORT" -lt 1 ] || [ "$TARGET_PORT" -gt 65535 ]; then
                ui_status error "Cổng ADB phải nằm trong khoảng 1-65535."
                return 1
            fi
            ;;
    esac
    SERIAL="$TARGET_IP:$TARGET_PORT"

    ui_section "THIẾT BỊ ĐÍCH"
    echo "Địa chỉ ADB: $SERIAL"

    # [1/4] Chuẩn bị bộ 3 file APK cài đặt từ GitHub
    ui_section "1/4  |  CHUẨN BỊ GÓI CÀI ĐẶT"
    rm -rf "$CACHE_DIR" 2>/dev/null || true
    mkdir -p "$CACHE_DIR"

    TS=$(date +%s 2>/dev/null || echo "1")
    download_percent=0
    for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
        if [ "$R1_DRYRUN" = "1" ] && [ -f "$SCRIPT_DIR/$f" ]; then
            cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
        else
            if command -v curl >/dev/null 2>&1; then
                curl -k -fsSL --connect-timeout 20 -o "$CACHE_DIR/$f.tmp" "$BASE_URL/$f?t=$TS" && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
            elif command -v wget >/dev/null 2>&1; then
                wget -q --no-check-certificate -O "$CACHE_DIR/$f" "$BASE_URL/$f?t=$TS"
            fi
        fi

        if [ ! -f "$CACHE_DIR/$f" ] || [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null)" -lt 1000000 ]; then
            progress_finish
            ui_status error "Không tải được gói $f."
            echo "Kiểm tra kết nối Internet rồi thử lại."
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        download_percent=$((download_percent + 20))
        progress_update "$download_percent" "Đã chuẩn bị $f"
    done
    progress_finish

    # [2/4] Bắt đầu kết nối thiết bị ADB
    ui_section "2/4  |  KẾT NỐI ADB"
    progress_update 62 "Đang kết nối với loa"

    if [ "$R1_DRYRUN" != "1" ] && ! command -v adb >/dev/null 2>&1; then
        ui_status error "Không tìm thấy ADB."
        echo "Cài đặt bằng lệnh: apk add android-tools"
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    CONNECTED=0
    if [ "$R1_DRYRUN" != "1" ]; then
        ADB_LAST_CONNECT=""
        ADB_LAST_STATE=""
        ADB_LAST_SHELL=""
        adb kill-server >/dev/null 2>&1 || true
        ADB_SERVER_OUTPUT=$(adb start-server 2>&1)
        if [ $? -ne 0 ]; then
            ui_status error "Không khởi động được ADB server."
            [ -n "$ADB_SERVER_OUTPUT" ] && printf '%s\n' "$ADB_SERVER_OUTPUT"
            return 1
        fi

        ui_status info "Đang đánh thức dịch vụ loa và kết nối ADB..."
        revive_speaker "$TARGET_IP"
        for try in 1 2 3 4 5 6 7 8 9 10 11 12; do
            progress_update 62 "Đang thử ADB $SERIAL ($try/12)"
            ADB_LAST_CONNECT=$(adb connect "$SERIAL" 2>&1)
            if check_connected; then
                CONNECTED=1
                break
            fi
            if [ "$try" -eq 4 ] || [ "$try" -eq 8 ]; then
                revive_speaker "$TARGET_IP"
            fi
            sleep 2
        done

        if [ "$CONNECTED" != "1" ]; then
            progress_finish
            ui_status error "Không thể kết nối ADB tới $SERIAL."
            echo "adb connect: ${ADB_LAST_CONNECT:-không có phản hồi}"
            echo "Trạng thái: ${ADB_LAST_STATE:-không có phản hồi}"
            [ -n "$ADB_LAST_SHELL" ] && echo "Lệnh shell: $ADB_LAST_SHELL"
            echo "Kiểm tra:"
            echo " 1. Loa và thiết bị cài đặt đang cùng mạng WiFi; IP hiện tại là $TARGET_IP."
            echo " 2. Cổng ADB TCP $TARGET_PORT đang mở. Quét thấy cổng 8080/8081 không đồng nghĩa ADB đã mở."
            echo " 3. Nếu loa vừa reset, cấu hình WiFi trước rồi đợi loa vào mạng LAN."
            echo " 4. Nếu ADB dùng cổng khác, nhập IP theo dạng IP:PORT."
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
    fi
    progress_update 68 "Đã kết nối với loa"
    progress_finish
    if [ "$R1_DRYRUN" = "1" ]; then
        ui_status info "Đã mô phỏng kết nối ADB tới $SERIAL."
    else
        ui_status success "ADB đã kết nối tới $SERIAL."
    fi

    # [3/4] Dọn loa, tắt ứng dụng cũ và nạp AutoDLNA + Unisound
    ui_section "3/4  |  CHUẨN BỊ THIẾT BỊ"

    if [ "$R1_DRYRUN" != "1" ]; then
        progress_update 70 "Đang dọn dẹp và chuẩn bị loa"
        adb -s "$SERIAL" shell rm /sdcard/otaprop.txt >/dev/null 2>&1
        adb -s "$SERIAL" shell rm /sdcard/incremental\*.zip >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm clear com.phicomm.speaker.otaservice >/dev/null 2>&1
        adb -s "$SERIAL" shell rm -rf "/data/local/tmp/*" >/dev/null 2>&1
        adb -s "$SERIAL" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1

        progress_update 74 "Đang tắt ứng dụng xung đột"
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.airskill >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.systemtool >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.device >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.otaservice >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.productiontest >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.bugreport >/dev/null 2>&1

        push_percent=76
        for f in autodlna.apk unisound.apk; do
            progress_update "$push_percent" "Đang chuyển $f vào loa"
            push_output=$(adb -s "$SERIAL" push "$CACHE_DIR/$f" "/data/local/tmp/$f" 2>&1)
            if [ $? -ne 0 ]; then
                progress_finish
                ui_status error "Không thể chuyển $f tới loa."
                [ -n "$push_output" ] && printf '%s\n' "$push_output"
                read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                return 1
            fi
            push_percent=$((push_percent + 4))
        done
    else
        progress_update 84 "[DRY-RUN] Đã mô phỏng chuẩn bị loa"
    fi

    # [4/4] Cài APK theo đúng trình tự của new.bat
    progress_finish
    ui_section "4/4  |  CÀI ĐẶT ỨNG DỤNG"

    if [ "$R1_DRYRUN" != "1" ]; then
        POST_REBOOT_AI_OK=0
        WEBUI_READY=0
        install_percent=84
        for f in autodlna.apk unisound.apk; do
            progress_update "$install_percent" "Đang cài $f"
            install_output=$(adb -s "$SERIAL" shell /system/bin/pm install -r "/data/local/tmp/$f" 2>&1)
            if [ $? -ne 0 ] || ! printf '%s\n' "$install_output" | grep -q '^Success'; then
                progress_finish
                ui_status error "Không thể cài đặt $f."
                [ -n "$install_output" ] && printf '%s\n' "$install_output"
                read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                return 1
            fi
            adb -s "$SERIAL" shell rm "/data/local/tmp/$f" >/dev/null 2>&1
            install_percent=$((install_percent + 3))
        done

        progress_update 90 "Đang khởi chạy dịch vụ loa"
        adb -s "$SERIAL" shell am startservice com.phicomm.speaker.player/.EchoService >/dev/null 2>&1
        adb -s "$SERIAL" shell am start com.phicomm.speaker.device/.ui.MainActivity >/dev/null 2>&1
        sleep 3

        progress_update 91 "Đang khôi phục dịch vụ hệ thống"
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.ijetty >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.netctl >/dev/null 2>&1

        progress_update 92 "Đang gỡ phiên bản AI cũ"
        adb -s "$SERIAL" shell /system/bin/pm uninstall info.dourok.voicebot >/dev/null 2>&1

        progress_update 93 "Đang chuyển AI Box vào loa"
        push_output=$(adb -s "$SERIAL" push "$CACHE_DIR/AIBoxPlus_DLNA.apk" "/data/local/tmp/AIBoxPlus_DLNA.apk" 2>&1)
        if [ $? -ne 0 ]; then
            progress_finish
            ui_status error "Không thể chuyển AIBoxPlus_DLNA.apk tới loa."
            [ -n "$push_output" ] && printf '%s\n' "$push_output"
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        progress_update 95 "Đang cài AI Box Plus"
        install_output=$(adb -s "$SERIAL" shell /system/bin/pm install -r /data/local/tmp/AIBoxPlus_DLNA.apk 2>&1)
        if [ $? -ne 0 ] || ! printf '%s\n' "$install_output" | grep -q '^Success'; then
            progress_finish
            ui_status error "Không thể cài đặt AIBoxPlus_DLNA.apk."
            [ -n "$install_output" ] && printf '%s\n' "$install_output"
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        adb -s "$SERIAL" shell rm /data/local/tmp/AIBoxPlus_DLNA.apk >/dev/null 2>&1

        progress_update 97 "Đang khởi chạy AI Box Plus"
        adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1
        sleep 5

        progress_finish
        echo ""
        ui_section "THIẾT LẬP AI"
        echo "Truy cập Xiaozhi.me để nhập mã 6 số và cấu hình AI."
        echo "Nếu AI đã được cấu hình trước đó, có thể bỏ qua bước này."
        sleep 2

        adb -s "$SERIAL" shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" >/dev/null 2>&1

        ui_status success "Cài đặt xong; loa sẽ khởi động lại."
        progress_update 98 "Đang khởi động lại loa"
        LAN_IP=$(adb -s "$SERIAL" shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null | tr -d '\r\n')

        adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        if wait_for_speaker_boot; then
            progress_update 99 "Đang khởi chạy AI sau reboot"
            launch_output=$(adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity 2>&1)
            launch_status=$?
            if [ "$launch_status" -eq 0 ] && ! printf '%s\n' "$launch_output" | grep -Eqi '(^|[[:space:]])(Error:|Exception|does not exist)'; then
                POST_REBOOT_AI_OK=1
                sleep 5
                if wait_for_webui; then
                    WEBUI_READY=1
                fi
            else
                progress_finish
                ui_status warning "Không khởi chạy được AI sau reboot."
                [ -n "$launch_output" ] && printf '%s\n' "$launch_output"
            fi
        else
            progress_finish
            ui_status warning "Loa chưa kết nối lại; không xác minh được AI hoặc WebUI."
        fi
        progress_update 100 "Hoàn tất"
    else
        POST_REBOOT_AI_OK=0
        WEBUI_READY=0
        progress_update 100 "[DRY-RUN] Hoàn tất, loa chưa reboot"
        LAN_IP=""
    fi

    # Dọn dẹp cache
    rm -rf "$CACHE_DIR" 2>/dev/null || true
    for tmp_sh in ./r1.sh ./r1*.sh /tmp/r1*.sh /tmp/install*.sh; do
        [ -f "$tmp_sh" ] && rm -f "$tmp_sh" 2>/dev/null || true
    done

    ui_header "HOÀN TẤT" "Kết quả cài đặt Phicomm R1"
    if [ "$R1_DRYRUN" = "1" ]; then
        ui_status info "Chạy thử hoàn tất; loa chưa được reboot."
    else
        ui_status success "Đã gửi lệnh khởi động lại loa."
        echo "Loa thường cần 30-45 giây để khởi động."
        if [ "$POST_REBOOT_AI_OK" = "1" ]; then
            ui_status success "AI đã khởi chạy sau reboot."
        else
            ui_status warning "Chưa xác minh được AI sau reboot."
        fi
        if [ "$WEBUI_READY" = "1" ]; then
            ui_status success "WebUI đã phản hồi trên cổng 8081."
        else
            ui_status warning "WebUI chưa phản hồi trên cổng 8081."
        fi
    fi
    echo ""
    if [ "$R1_DRYRUN" = "1" ]; then
        echo "Khi cài thật, mở bảng điều khiển:"
        echo "  http://$TARGET_IP:8081/"
    elif [ -n "$LAN_IP" ]; then
        echo "Bảng điều khiển:"
        echo "  http://$LAN_IP:8081/"
    else
        echo "Bảng điều khiển:"
        echo "  http://$TARGET_IP:8081/"
    fi

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# 6. MENU CHÍNH
# ------------------------------------------------------------------------------
show_menu() {
    clear 2>/dev/null || true
    ui_header "BỘ CÀI ĐẶT PHICOMM R1" "Linux / Android / iSH"
    printf '  %s1%s  Cấu hình Wi-Fi cho loa sau khi reset\n' "$UI_BOLD" "$UI_RESET"
    printf '     Kết nối trước với mạng Phicomm_R1_xxxx\n\n'
    printf '  %s2%s  Quét mạng và cài đặt ứng dụng\n' "$UI_BOLD" "$UI_RESET"
    printf '     AutoDLNA, Unisound và AI Box\n\n'
    printf '  %s3%s  Chỉ quét tìm loa trong mạng LAN\n\n' "$UI_BOLD" "$UI_RESET"
    printf '  %s4%s  Thoát\n\n' "$UI_BOLD" "$UI_RESET"
    printf '%sChọn mục [1-4]: %s' "$UI_CYAN" "$UI_RESET"
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
