#!/bin/sh
# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - iSH (iPHONE) / LINUX / ANDROID / MACOS
# Đồng bộ luồng kết nối linh động & cài đặt chuẩn xác theo install.ps1
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, đánh thức ADB, cài đặt AI
# ==============================================================================

BASE_URL="https://vdt34.github.io/r1"
CACHE_DIR="/tmp/r1_cache"
SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="."

USER_IP=""
ASSUME_YES=""
CLI_MODE=""
[ "${R1_DRYRUN:-0}" = "1" ] || R1_DRYRUN=0

for arg in "$@"; do
    case "$arg" in
        -y|--yes|-Yes) ASSUME_YES="1" ;;
        -DryRun|--dry-run|-dryrun) R1_DRYRUN=1; export R1_DRYRUN ;;
        -Wifi|--wifi|-wifi) CLI_MODE="wifi" ;;
        -Scan|--scan|-scan) CLI_MODE="scan" ;;
        192.168.43.1|192.168.43.1:*)
            USER_IP="192.168.43.1"
            CLI_MODE="wifi"
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*:[0-9]*|[0-9]*.[0-9]*.[0-9]*.[0-9]*)
            USER_IP="$arg"
            CLI_MODE="install"
            ;;
    esac
done

# ------------------------------------------------------------------------------
# TIỆN ÍCH GIAO DIỆN & THANH TIẾN TRÌNH (TƯƠNG ĐỒNG INSTALL.PS1)
# ------------------------------------------------------------------------------
C_RESET=""
C_CYAN=""
C_GREEN=""
C_YELLOW=""
C_RED=""
C_GRAY=""
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    C_RESET=$(printf '\033[0m')
    C_CYAN=$(printf '\033[36m')
    C_GREEN=$(printf '\033[32m')
    C_YELLOW=$(printf '\033[33m')
    C_RED=$(printf '\033[31m')
    C_GRAY=$(printf '\033[90m')
fi

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
    case "$percent" in
        ''|*[!0-9]*) percent=0 ;;
    esac
    [ "$percent" -gt 100 ] && percent=100
    [ "$percent" -lt 0 ] && percent=0

    cols="${COLUMNS:-}"
    if [ -z "$cols" ] && command -v tput >/dev/null 2>&1; then
        cols=$(tput cols 2>/dev/null)
    fi
    case "$cols" in
        ''|*[!0-9]*) cols=60 ;;
    esac
    bar_width=$((cols - 16))
    [ "$bar_width" -gt 36 ] && bar_width=36
    [ "$bar_width" -lt 12 ] && bar_width=12

    filled=$((percent * bar_width / 100))
    empty=$((bar_width - filled))
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
        printf '\033[2A\r\033[J'
    fi
    printf '\033[?7l%s   %s%s\n' "$C_CYAN" "$label" "$C_RESET"
    printf '%s   [%s] %3s%%%s\033[?7h\n' "$C_CYAN" "$bar" "$percent" "$C_RESET"
    R1_PROGRESS_ACTIVE=1
}

progress_finish() {
    if [ -t 1 ] && [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '\033[2A\r\033[J'
        R1_PROGRESS_ACTIVE=""
    fi
}

# ------------------------------------------------------------------------------
# 1. ĐẢM BẢO CÔNG CỤ CẦN THIẾT (CURL / NC / ADB)
# ------------------------------------------------------------------------------
setup_tools() {
    mkdir -p "$HOME/.android" "$CACHE_DIR" 2>/dev/null || true
    [ "$R1_DRYRUN" = "1" ] && return 0

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

    if ! command -v adb >/dev/null 2>&1 || ! command -v nc >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            if [ -f /etc/apk/repositories ]; then
                sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null || true
            fi
            apk add --no-cache android-tools netcat-openbsd >/dev/null 2>&1 || \
            apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y android-tools-adb netcat-openbsd >/dev/null 2>&1 || true
        fi
    fi
}
setup_tools

ensure_adb() {
    [ "$R1_DRYRUN" = "1" ] && return 0
    if command -v adb >/dev/null 2>&1; then
        return 0
    fi
    if [ -x "$SCRIPT_DIR/adb" ]; then
        PATH="$SCRIPT_DIR:$PATH"
        export PATH
        return 0
    fi
    if [ -x "$CACHE_DIR/platform-tools/adb" ]; then
        PATH="$CACHE_DIR/platform-tools:$PATH"
        export PATH
        return 0
    fi

    setup_tools
    command -v adb >/dev/null 2>&1 && return 0
    return 1
}

# ------------------------------------------------------------------------------
# 2. KIỂM TRA CỔNG TCP & ĐÁNH THỨC LOA (TƯƠNG ĐỒNG Test-R1TcpPort & Revive-Speaker)
# ------------------------------------------------------------------------------
find_python() {
    if command -v python3 >/dev/null 2>&1 && python3 -c "import socket" >/dev/null 2>&1; then
        echo "python3"
    elif command -v python >/dev/null 2>&1 && python -c "import socket" >/dev/null 2>&1; then
        echo "python"
    else
        echo ""
    fi
}
PY_BIN=$(find_python)

# Kiểm tra cổng TCP mở (hỗ trợ cả cổng không phải HTTP như ADB 5555)
test_tcp_port() {
    host="$1"
    port="$2"
    timeout_sec="${3:-1}"
    [ -z "$host" ] || [ -z "$port" ] && return 1

    if [ -n "$PY_BIN" ]; then
        "$PY_BIN" - "$host" "$port" "$timeout_sec" << 'EOF' >/dev/null 2>&1
import socket, sys
h = sys.argv[1]
p = int(sys.argv[2])
t = float(sys.argv[3])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(t)
try:
    rc = s.connect_ex((h, p))
    s.close()
    sys.exit(0 if rc == 0 else 1)
except Exception:
    sys.exit(1)
EOF
        return $?
    fi

    if command -v nc >/dev/null 2>&1; then
        nc -z -w "$timeout_sec" "$host" "$port" </dev/null >/dev/null 2>&1 && return 0
        nc -w "$timeout_sec" "$host" "$port" </dev/null >/dev/null 2>&1 && return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        # Với curl: mã 0 (HTTP OK), 52 (Empty reply - như cổng ADB 5555), 56 (Recv failure sau khi đã TCP connect),
        # hoặc 1 (Unsupported protocol từ banner ADB) đều chứng tỏ cổng TCP đang MỞ!
        curl -s -m "$timeout_sec" --connect-timeout "$timeout_sec" -o /dev/null "http://$host:$port/" 2>/dev/null
        rc=$?
        case "$rc" in
            0|1|52|56) return 0 ;;
        esac
    fi

    return 1
}

# Đánh thức loa R1 qua cổng 8080/8081 (TCP + HTTP giống Revive-Speaker trong install.ps1)
revive_speaker() {
    tip="$1"
    [ -z "$tip" ] && tip="192.168.43.1"
    [ "$R1_DRYRUN" = "1" ] && return 0

    # Mở kết nối TCP trực tiếp tới 8080 và 8081 như TcpClient.BeginConnect trong install.ps1
    test_tcp_port "$tip" 8080 1 >/dev/null 2>&1 || true
    test_tcp_port "$tip" 8081 1 >/dev/null 2>&1 || true

    # Gửi thêm HTTP request đánh thức dịch vụ trên loa
    if command -v curl >/dev/null 2>&1; then
        curl -s -m 1 --connect-timeout 1 "http://$tip:8080/" >/dev/null 2>&1 || true
        curl -s -m 1 --connect-timeout 1 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=1 "http://$tip:8080/" >/dev/null 2>&1 || true
        wget -q -O- --timeout=1 "http://$tip:8081/" >/dev/null 2>&1 || true
    fi
}

# ------------------------------------------------------------------------------
# 3. HÀM DÒ TÌM DẢI MẠNG LAN & QUÉT LOA PHICOMM R1 (TƯƠNG ĐỒNG Scan-SpeakerIp)
# ------------------------------------------------------------------------------
detect_subnet() {
    sub=""
    if command -v ip >/dev/null 2>&1; then
        sub=$(ip -4 addr show 2>/dev/null | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | grep -vE '^(127\.|169\.254\.)' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
        if [ -z "$sub" ]; then
            sub=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
        fi
    fi
    if [ -z "$sub" ] && command -v ifconfig >/dev/null 2>&1; then
        sub=$(ifconfig 2>/dev/null | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -vE '^(127\.|169\.254\.)' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
    fi
    if [ -z "$sub" ] && command -v route >/dev/null 2>&1; then
        sub=$(route -n 2>/dev/null | grep -E '^0\.0\.0\.0' | awk '{print $2}' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
    fi
    [ -z "$sub" ] && sub="192.168.1"
    echo "$sub"
}

scan_speaker_ip() {
    sub="$1"
    [ -z "$sub" ] && sub=$(detect_subnet)
    echo ""
    printf '%s>> Đang quét tự động dải mạng LAN (%s.1 -> 254) tìm loa Phicomm R1...%s\n' "$C_CYAN" "$sub" "$C_RESET"

    scan_tmp="/tmp/r1_scan_$$"
    rm -rf "$scan_tmp" 2>/dev/null || true
    mkdir -p "$scan_tmp"

    # Nếu có mạng ARP cache sẵn trên máy, đọc nhanh để ưu tiên kiểm tra trước
    if [ -n "$PY_BIN" ]; then
        "$PY_BIN" - "$sub" << 'EOF' > "$scan_tmp/result.txt" 2>/dev/null || true
import sys, socket
from concurrent.futures import ThreadPoolExecutor

prefix = sys.argv[1]

def check_port(ip, port, timeout=0.45):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        return s.connect_ex((ip, port)) == 0
    except Exception:
        return False
    finally:
        try:
            s.close()
        except Exception:
            pass

def probe_candidate(i):
    ip = f"{prefix}.{i}"
    if check_port(ip, 5555, 0.5) or check_port(ip, 8080, 0.5) or check_port(ip, 8081, 0.5):
        return ip
    return None

candidates = []
with ThreadPoolExecutor(max_workers=64) as ex:
    for res in ex.map(probe_candidate, range(1, 255)):
        if res:
            candidates.append(res)

for cand in candidates:
    has5555 = check_port(cand, 5555, 0.4)
    has8080 = check_port(cand, 8080, 0.4)
    has8081 = check_port(cand, 8081, 0.4)
    if not has5555 and (has8080 or has8081):
        # Đánh thức cổng ADB nếu loa đang mở 8080/8081
        for p in (8080, 8081):
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(0.5)
                if s.connect_ex((cand, p)) == 0:
                    s.sendall(b"GET / HTTP/1.0\r\n\r\n")
                s.close()
            except Exception:
                pass
        has5555 = check_port(cand, 5555, 0.5)
    if has5555 or (has8080 and has8081) or has8080:
        ports = []
        if has5555:
            ports.append("ADB: 5555")
        if has8081:
            ports.append("Web AI Box: 8081")
        if has8080:
            ports.append("R1: 8080")
        print(f"{cand}|({', '.join(ports)})")
EOF
    fi

    # Fallback thuần shell (dành cho iSH / Alpine không có Python)
    if [ ! -s "$scan_tmp/result.txt" ]; then
        idx=1
        while [ "$idx" -le 254 ]; do
            bend=$((idx + 42))
            [ "$bend" -gt 254 ] && bend=254
            i="$idx"
            while [ "$i" -le "$bend" ]; do
                (
                    target="${sub}.${i}"
                    has5555=0
                    has8080=0
                    has8081=0

                    if test_tcp_port "$target" 5555 1; then
                        has5555=1
                    fi
                    if test_tcp_port "$target" 8080 1; then
                        has8080=1
                    fi
                    if [ "$has5555" = "1" ] || [ "$has8080" = "1" ]; then
                        if test_tcp_port "$target" 8081 1; then
                            has8081=1
                        fi
                        if [ "$has5555" = "0" ] && [ "$has8080" = "1" ]; then
                            revive_speaker "$target"
                            if test_tcp_port "$target" 5555 1; then
                                has5555=1
                            fi
                        fi
                        ports=""
                        if [ "$has5555" = "1" ]; then
                            ports="ADB: 5555"
                        fi
                        if [ "$has8081" = "1" ]; then
                            [ -n "$ports" ] && ports="$ports, "
                            ports="${ports}Web AI Box: 8081"
                        fi
                        if [ "$has8080" = "1" ]; then
                            [ -n "$ports" ] && ports="$ports, "
                            ports="${ports}R1: 8080"
                        fi
                        printf '%03d|%s|(%s)\n' "$i" "$target" "$ports" >> "$scan_tmp/raw.txt"
                    fi
                ) &
                i=$((i + 1))
            done
            wait
            idx=$((bend + 1))
        done

        if [ -f "$scan_tmp/raw.txt" ]; then
            sort "$scan_tmp/raw.txt" | awk -F'|' '{print $2"|"$3}' > "$scan_tmp/result.txt"
        fi
    fi

    TOTAL_FOUND=0
    if [ -s "$scan_tmp/result.txt" ]; then
        while IFS='|' read -r ip_val port_info || [ -n "$ip_val" ]; do
            ip_val=$(printf '%s' "$ip_val" | tr -d ' \r\n')
            port_info=$(printf '%s' "$port_info" | tr -d '\r\n')
            [ -z "$ip_val" ] && continue
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
            echo "$ip_val" >> "$scan_tmp/ips.txt"
            echo "$ip_val $port_info" >> "$scan_tmp/display.txt"
        done < "$scan_tmp/result.txt"
    fi

    if [ "$TOTAL_FOUND" -gt 0 ]; then
        echo ""
        printf '%s>> Phát hiện %s loa Phicomm R1 trong mạng LAN:%s\n' "$C_GREEN" "$TOTAL_FOUND" "$C_RESET"
        d_idx=1
        while IFS= read -r d_line || [ -n "$d_line" ]; do
            [ -z "$d_line" ] && continue
            printf '%s   [%s] %s%s\n' "$C_YELLOW" "$d_idx" "$d_line" "$C_RESET"
            d_idx=$((d_idx + 1))
        done < "$scan_tmp/display.txt"
    fi
}

# ------------------------------------------------------------------------------
# 4. KIỂM TRA & KẾT NỐI ADB LINH ĐỘNG (ĐẢM BẢO KẾT NỐI CHẮC CHẮN)
# ------------------------------------------------------------------------------
check_connected() {
    target_serial="${1:-$SERIAL}"
    state=$(adb -s "$target_serial" get-state 2>/dev/null | tr -d ' \r\n')
    if [ "$state" = "device" ]; then
        adb -s "$target_serial" shell ls /data >/dev/null 2>&1
        return $?
    fi
    return 1
}

reset_adb_daemon() {
    if command -v killall >/dev/null 2>&1; then
        killall -9 adb >/dev/null 2>&1 || true
    elif command -v pkill >/dev/null 2>&1; then
        pkill -9 adb >/dev/null 2>&1 || true
    fi
    adb kill-server >/dev/null 2>&1 || true
    adb start-server >/dev/null 2>&1 || true
    sleep 1
}

# Kết nối ADB linh động theo chuẩn install.ps1 + tự động phục hồi khi rớt/offline
connect_speaker_adb() {
    target_ip="$1"
    target_port="${2:-5555}"
    SERIAL="${target_ip}:${target_port}"

    [ "$R1_DRYRUN" = "1" ] && return 0

    reset_adb_daemon

    # Thử kết nối trực tiếp lần 1 (như install.ps1)
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    sleep 1

    if check_connected "$SERIAL"; then
        return 0
    fi

    # Đánh thức loa qua cổng 8080/8081 và thử lại nhiều chu kỳ
    progress_update 40 "Đang đánh thức loa"
    revive_speaker "$target_ip"
    sleep 2

    try=1
    max_tries=8
    while [ "$try" -le "$max_tries" ]; do
        pct=$((40 + try))
        [ "$pct" -gt 50 ] && pct=50
        progress_update "$pct" "Đang chờ loa phản hồi ($try/$max_tries)"

        # Nếu thiết bị bị kẹt trạng thái offline, ngắt kết nối cũ trước khi connect lại
        cur_state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
        if [ "$cur_state" = "offline" ] || [ "$cur_state" = "connecting" ]; then
            adb disconnect "$SERIAL" >/dev/null 2>&1 || true
        fi

        # Giữa chừng nếu daemon ADB bị treo (hay gặp trên iSH), khởi động lại server
        if [ "$try" -eq 5 ]; then
            reset_adb_daemon
            revive_speaker "$target_ip"
            sleep 1
        fi

        adb connect "$SERIAL" >/dev/null 2>&1 || true
        sleep 1

        if check_connected "$SERIAL"; then
            return 0
        fi

        revive_speaker "$target_ip"
        sleep 1
        try=$((try + 1))
    done

    return 1
}

# Đảm bảo kết nối ADB vẫn sống trước mỗi bước quan trọng (tự kết nối lại nếu vừa rớt)
ensure_adb_alive() {
    [ "$R1_DRYRUN" = "1" ] && return 0
    if check_connected "$SERIAL"; then
        return 0
    fi
    revive_speaker "$TARGET_IP"
    adb disconnect "$SERIAL" >/dev/null 2>&1 || true
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    sleep 1
    check_connected "$SERIAL" && return 0

    reset_adb_daemon
    revive_speaker "$TARGET_IP"
    sleep 1
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    sleep 1
    check_connected "$SERIAL"
}

# Thực thi bước ADB (push / install) có tự động thử lại nếu kết nối chập chờn
invoke_adb_step() {
    require_success="$1"
    shift

    attempt=1
    while [ "$attempt" -le 2 ]; do
        ensure_adb_alive >/dev/null 2>&1 || true
        output=$(adb "$@" 2>&1)
        exit_code=$?

        pkg_failed=0
        if [ "$require_success" = "1" ]; then
            if ! printf '%s\n' "$output" | tr -d '\r' | grep -Eq '^[[:space:]]*Success[[:space:]]*$'; then
                pkg_failed=1
            fi
        fi

        if [ "$exit_code" -eq 0 ] && [ "$pkg_failed" -eq 0 ]; then
            return 0
        fi

        if [ "$attempt" -lt 2 ]; then
            revive_speaker "$TARGET_IP"
            adb disconnect "$SERIAL" >/dev/null 2>&1 || true
            adb connect "$SERIAL" >/dev/null 2>&1 || true
            sleep 1
        fi
        attempt=$((attempt + 1))
    done

    progress_finish
    [ -n "$output" ] && printf '%s\n' "$output"
    if [ "$exit_code" -ne 0 ]; then
        printf '%s>> [LỖI] ADB kết thúc với mã lỗi %s.%s\n' "$C_RED" "$exit_code" "$C_RESET"
    elif [ "$pkg_failed" -eq 1 ]; then
        printf '%s>> [LỖI] ADB không xác nhận cài đặt thành công.%s\n' "$C_RED" "$C_RESET"
    fi
    return 1
}

wait_for_speaker_boot() {
    try=1
    while [ "$try" -le 45 ]; do
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        if check_connected "$SERIAL"; then
            boot_state=$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d ' \r\n')
            [ "$boot_state" = "1" ] && return 0
        fi
        progress_update 98 "Đang chờ loa khởi động lại ($try/45)"
        sleep 2
        try=$((try + 1))
    done
    return 1
}

wait_for_webui() {
    check_ip="${1:-$TARGET_IP}"
    max_wait="${2:-15}"
    pct="${3:-99}"
    label_prefix="${4:-Đang chờ WebUI khởi động}"
    try=1
    while [ "$try" -le "$max_wait" ]; do
        if test_tcp_port "$check_ip" 8081 1; then
            return 0
        fi
        if command -v curl >/dev/null 2>&1 && curl -sS -m 1 -o /dev/null "http://$check_ip:8081/" 2>/dev/null; then
            return 0
        fi
        progress_update "$pct" "$label_prefix ($try/$max_wait)"
        sleep 1
        try=$((try + 1))
    done
    return 1
}

# Khởi chạy AI Box Plus và xác minh tiến trình info.dourok.voicebot đã thực sự chạy
start_ai_box() {
    [ "$R1_DRYRUN" = "1" ] && return 0
    try_ai=1
    while [ "$try_ai" -le 3 ]; do
        ensure_adb_alive >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell am start -W -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1 || \
        adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell monkey -p info.dourok.voicebot -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
        sleep 2
        ai_running=$(adb -s "$SERIAL" shell "ps 2>/dev/null | grep info.dourok.voicebot" 2>/dev/null | tr -d '\r\n')
        if [ -n "$ai_running" ]; then
            return 0
        fi
        try_ai=$((try_ai + 1))
    done
    return 1
}

# ------------------------------------------------------------------------------
# 5. [MỤC 1] CẤU HÌNH WIFI CHO LOA QUA AP API (192.168.43.1:8989)
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
        printf '%s   [DRY-RUN] Đã gửi cấu hình WiFi SSID='\''%s'\'' tới http://%s:8989/api/configwifi%s\n' "$C_YELLOW" "$ssid" "$target_ip" "$C_RESET"
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
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s  CẤU HÌNH WIFI CHO LOA VỪA RESET (CHẾ ĐỘ AP 192.168.43.1)%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    echo " Hướng dẫn chuẩn bị:"
    echo "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'."
    echo "  2. Trên Điện thoại / Máy tính: Vào Cài đặt WiFi -> Kết nối 'Phicomm_R1_xxxx'."
    echo "  3. TẮT 4G/5G (Dữ liệu di động) nếu đang dùng điện thoại."
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_val "Nhấn Enter khi đã kết nối WiFi của loa: " "" >/dev/null 2>&1 || true
    fi

    echo ""
    printf '%s>> Đang kiểm tra kết nối tới loa (192.168.43.1:8989)...%s\n' "$C_CYAN" "$C_RESET"
    api_ok=0
    if [ "$R1_DRYRUN" = "1" ]; then
        api_ok=1
    elif test_tcp_port "192.168.43.1" 8989 2; then
        api_ok=1
    elif command -v curl >/dev/null 2>&1; then
        if curl -s -m 2 "http://192.168.43.1:8989/" >/dev/null 2>&1 || curl -s -m 2 "http://192.168.43.1:8989/api/configwifi" >/dev/null 2>&1; then
            api_ok=1
        fi
    fi

    if [ "$api_ok" = "1" ]; then
        printf '%s   [OK] Đã kết nối được API của loa.%s\n' "$C_GREEN" "$C_RESET"
    else
        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            printf '%s   [CẢNH BÁO] Chưa kết nối được 192.168.43.1:8989.%s\n' "$C_YELLOW" "$C_RESET"
            echo "   Kiểm tra: Thiết bị đã chọn WiFi Phicomm_R1 chưa? Đã tắt 4G chưa?"
            ans=$(read_val "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: " "n")
            case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
                "y"|"yes") ;;
                *) return 1 ;;
            esac
        fi
    fi

    echo ""
    echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
    printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    ssid_default=""
    pass_default=""
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        ssid_default="MyWiFi"
        pass_default="12345678"
    fi
    ssid=""
    while [ -z "$ssid" ]; do
        ssid=$(read_val ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): " "$ssid_default")
        if [ -z "$ssid" ]; then
            printf '%s   [!] Tên WiFi không được để trống!%s\n' "$C_YELLOW" "$C_RESET"
        fi
    done

    pass=$(read_val ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): " "$pass_default")

    secure="WPA"
    if [ -z "$pass" ]; then
        secure="INSECURE"
        echo "   -> Chế độ WiFi không mật khẩu (INSECURE)"
    else
        pass_len=$(printf '%s' "$pass" | wc -c)
        if [ "$pass_len" -lt 8 ]; then
            printf '%s   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!%s\n' "$C_YELLOW" "$C_RESET"
        fi
    fi

    echo ""
    printf '%s>> Đang gửi cấu hình tới loa (192.168.43.1:8989)...%s\n' "$C_CYAN" "$C_RESET"
    send_wifi_config "192.168.43.1" "$ssid" "$pass" "$secure"

    echo ""
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s            ĐÃ GỬI CẤU HÌNH WIFI THÀNH CÔNG!              %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    echo " THÔNG BÁO QUAN TRỌNG:"
    echo "  1. Loa đang kết nối WiFi nhà, chờ khoảng 20 giây sẽ có IP."
    echo "  2. Hãy chuyển Điện thoại / Máy tính về lại mạng WiFi nhà."
    printf '%s  3. Sau đó quay lại menu chọn [2] để tìm IP và cài APK.%s\n' "$C_CYAN" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 6. TẢI VÀ CHUẨN BỊ 3 FILE APK (TƯƠNG ĐỒNG Ensure-Apks TRONG INSTALL.PS1)
# ------------------------------------------------------------------------------
ensure_apks() {
    echo ""
    printf '%s>> Đang chuẩn bị và tự động cài AI...%s\n' "$C_CYAN" "$C_RESET"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true

    for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
        rm -f "$CACHE_DIR/$f" "$CACHE_DIR/$f.tmp" 2>/dev/null || true
    done

    TS=$(date +%s 2>/dev/null || echo "1")
    idx=0
    missing=0
    for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
        p_start=$((5 + idx * 10))
        progress_update "$p_start" "Đang chuẩn bị $f"

        if [ "$R1_DRYRUN" = "1" ] && [ -f "$SCRIPT_DIR/$f" ]; then
            cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
        else
            if command -v curl >/dev/null 2>&1; then
                curl -k -fsSL --connect-timeout 20 --max-time 45 -o "$CACHE_DIR/$f.tmp" "$BASE_URL/$f?t=$TS" 2>/dev/null && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
            elif command -v wget >/dev/null 2>&1; then
                wget -q --no-check-certificate --timeout=45 -O "$CACHE_DIR/$f.tmp" "$BASE_URL/$f?t=$TS" 2>/dev/null && mv -f "$CACHE_DIR/$f.tmp" "$CACHE_DIR/$f"
            fi
            # Fallback sang file APK cục bộ nếu đang có sẵn trong cùng thư mục script
            if [ ! -f "$CACHE_DIR/$f" ] && [ -f "$SCRIPT_DIR/$f" ]; then
                cp -f "$SCRIPT_DIR/$f" "$CACHE_DIR/$f" 2>/dev/null || true
            fi
        fi

        if [ ! -f "$CACHE_DIR/$f" ] || [ "$(wc -c < "$CACHE_DIR/$f" 2>/dev/null || echo 0)" -lt 1000000 ]; then
            missing=1
            break
        fi

        p_done=$((15 + idx * 10))
        progress_update "$p_done" "Đã xử lý $f"
        idx=$((idx + 1))
    done

    if [ "$missing" = "1" ]; then
        progress_finish
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI THIẾU FILE CÀI ĐẶT DO CHƯA CÓ INTERNET]%s\n' "$C_RED" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%sVui lòng kiểm tra kết nối mạng để tải đủ 3 file APK.%s\n' "$C_YELLOW" "$C_RESET"
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 7. [MỤC 2] QUÉT IP LAN & CÀI ĐẶT APK (ĐỒNG BỘ VỚI Run-Install TRONG INSTALL.PS1)
# ------------------------------------------------------------------------------
run_install_lan() {
    target_param="$1"
    TARGET_IP="$target_param"

    if [ -z "$TARGET_IP" ]; then
        echo ""
        printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        printf '%s                  TÌM IP CỦA LOA TRONG LAN                %s\n' "$C_YELLOW" "$C_RESET"
        printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        printf '%s [S] hoặc [Enter]: Tự động QUÉT tìm IP loa trong WiFi nhà (LAN)%s\n' "$C_CYAN" "$C_RESET"
        echo " Hoặc gõ trực tiếp IP của loa (Ví dụ: 192.168.1.94)"
        printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"

        while [ -z "$TARGET_IP" ]; do
            USER_INPUT=$(read_val "Nhập IP hoặc 'S' để quét [Mặc định: S]: " "S")
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
                        elif printf '%s' "$PICK" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$'; then
                            TARGET_IP="$PICK"
                        else
                            TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
                        fi
                    else
                        echo ""
                        printf '%s>> Không tìm thấy loa trong mạng LAN.%s\n' "$C_YELLOW" "$C_RESET"
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
                    printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
                    printf '%s  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!%s\n' "$C_YELLOW" "$C_RESET"
                    printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
                    echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
                    echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
                    printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
                    read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                    return 1
                    ;;
                *)
                    TARGET_IP="$USER_INPUT"
                    ;;
            esac
        done
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d '[:space:]')
    TARGET_PORT="5555"
    case "$TARGET_IP" in
        *:*)
            TARGET_PORT="${TARGET_IP##*:}"
            TARGET_IP="${TARGET_IP%:*}"
            case "$TARGET_PORT" in
                ''|*[!0-9]*) TARGET_PORT="5555" ;;
            esac
            ;;
    esac

    # Kiểm tra lại nếu người dùng nhập nhầm 192.168.43.1
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
        echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    SERIAL="$TARGET_IP:$TARGET_PORT"

    echo ""
    printf '%s>> Sẽ kết nối tới IP: %s%s\n' "$C_CYAN" "$TARGET_IP" "$C_RESET"

    # Đảm bảo có ADB trước khi cài đặt (như Ensure-Adb trong install.ps1)
    if ! ensure_adb; then
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI] KHÔNG THỂ KHỞI TẠO CÔNG CỤ ADB!%s\n' "$C_RED" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%sVui lòng cài đặt android-tools (ví dụ: apk add android-tools).%s\n' "$C_YELLOW" "$C_RESET"
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    # [1/4] Tải và chuẩn bị 3 file APK
    if ! ensure_apks; then
        return 1
    fi

    # [2/4] Bắt đầu kết nối thiết bị ADB
    progress_update 38 "Đang kết nối với loa"

    if ! connect_speaker_adb "$TARGET_IP" "$TARGET_PORT"; then
        progress_finish
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI %s%s\n' "$C_RED" "$SERIAL" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%sVui lòng kiểm tra:%s\n' "$C_YELLOW" "$C_RESET"
        echo " 1. Loa đã cắm nguồn và đang bật."
        echo " 2. Thiết bị và loa đang kết nối CÙNG MẠNG WiFi."
        echo " 3. Địa chỉ IP của loa ($TARGET_IP) đã đúng chưa."
        echo " 4. Nếu loa vừa reset -> hãy chọn mục 1 để cấu hình WiFi trước."
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi
    progress_update 52 "Đã kết nối với loa"

    # [3/4] Đẩy APK lên bộ nhớ tạm của loa
    progress_update 54 "Đang dọn dẹp và chuẩn bị loa"
    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" shell rm /sdcard/otaprop.txt >/dev/null 2>&1
        adb -s "$SERIAL" shell rm /sdcard/incremental\*.zip >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm clear com.phicomm.speaker.otaservice >/dev/null 2>&1
        adb -s "$SERIAL" shell "rm -rf /data/local/tmp/* 2>/dev/null" >/dev/null 2>&1
        adb -s "$SERIAL" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1

        progress_update 58 "Đang tắt ứng dụng xung đột"
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.airskill >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.systemtool >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.device >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.otaservice >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.productiontest >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.bugreport >/dev/null 2>&1

        push_percent=60
        for f in autodlna.apk unisound.apk; do
            progress_update "$push_percent" "Đang chuyển $f vào loa"
            local_apk="$CACHE_DIR/$f"
            if [ ! -f "$local_apk" ]; then
                progress_finish
                printf '%s>> [LỖI] Không tìm thấy file APK trên máy: %s%s\n' "$C_RED" "$local_apk" "$C_RESET"
                read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                return 1
            fi
            if ! invoke_adb_step 0 -s "$SERIAL" push "$local_apk" "/data/local/tmp/$f"; then
                printf '%s>> [LỖI] Tải file lên loa thất bại: %s%s\n' "$C_RED" "$f" "$C_RESET"
                read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                return 1
            fi
            push_percent=$((push_percent + 4))
        done
    else
        progress_update 68 "[DRY-RUN] Đã mô phỏng chuẩn bị loa"
    fi

    # [4/4] Thực thi chuỗi lệnh cài đặt hệ thống chuẩn theo new.bat / install.ps1
    if [ "$R1_DRYRUN" != "1" ]; then
        POST_REBOOT_AI_OK=0
        WEBUI_READY=0
        install_percent=70
        for f in autodlna.apk unisound.apk; do
            progress_update "$install_percent" "Đang cài $f"
            if ! invoke_adb_step 1 -s "$SERIAL" shell /system/bin/pm install -r "/data/local/tmp/$f"; then
                printf '%s>> [LỖI] Cài đặt thất bại: %s%s\n' "$C_RED" "$f" "$C_RESET"
                read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
                return 1
            fi
            install_percent=$((install_percent + 5))
        done

        for f in autodlna.apk unisound.apk; do
            adb -s "$SERIAL" shell rm "/data/local/tmp/$f" >/dev/null 2>&1
        done

        progress_update 80 "Đang khởi chạy dịch vụ loa"
        ensure_adb_alive >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell am startservice com.phicomm.speaker.player/.EchoService >/dev/null 2>&1
        adb -s "$SERIAL" shell am start -n com.phicomm.speaker.device/.ui.MainActivity >/dev/null 2>&1
        adb -s "$SERIAL" shell am start com.phicomm.speaker.device/.ui.MainActivity >/dev/null 2>&1
        sleep 3

        progress_update 83 "Đang khôi phục dịch vụ hệ thống"
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.ijetty >/dev/null 2>&1
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.netctl >/dev/null 2>&1

        progress_update 85 "Đang gỡ phiên bản AI cũ"
        adb -s "$SERIAL" shell /system/bin/pm uninstall info.dourok.voicebot >/dev/null 2>&1

        ai_apk="AIBoxPlus_DLNA.apk"
        local_ai_apk="$CACHE_DIR/$ai_apk"
        if [ ! -f "$local_ai_apk" ]; then
            progress_finish
            printf '%s>> [LỖI] Không tìm thấy file APK trên máy: %s%s\n' "$C_RED" "$local_ai_apk" "$C_RESET"
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        progress_update 88 "Đang chuyển AI Box vào loa"
        if ! invoke_adb_step 0 -s "$SERIAL" push "$local_ai_apk" "/data/local/tmp/$ai_apk"; then
            printf '%s>> [LỖI] Tải file lên loa thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        progress_update 92 "Đang cài AI Box Plus"
        if ! invoke_adb_step 1 -s "$SERIAL" shell /system/bin/pm install -r "/data/local/tmp/$ai_apk"; then
            printf '%s>> [LỖI] Cài đặt thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_val "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        adb -s "$SERIAL" shell rm "/data/local/tmp/$ai_apk" >/dev/null 2>&1

        progress_update 95 "Đang khởi chạy AI Box Plus trước khi reboot"
        PRE_REBOOT_AI_OK=0
        if start_ai_box; then
            PRE_REBOOT_AI_OK=1
        fi
        sleep 3
        wait_for_webui "$TARGET_IP" 10 96 "Đang chờ AI Box khởi tạo lần đầu" >/dev/null 2>&1 || true

        progress_update 97 "Đang tối ưu cấu hình đèn & Bluetooth"
        ensure_adb_alive >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" >/dev/null 2>&1

        LAN_IP=$(adb -s "$SERIAL" shell "getprop dhcp.wlan0.ipaddress 2>/dev/null" 2>/dev/null | tr -d ' \r\n')

        progress_update 98 "Đang khởi động lại loa"
        adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        if wait_for_speaker_boot; then
            progress_update 99 "Đang khởi chạy AI sau reboot"
            if start_ai_box; then
                POST_REBOOT_AI_OK=1
                sleep 3
                if wait_for_webui "${LAN_IP:-$TARGET_IP}" 15 99 "Đang chờ WebUI khởi động"; then
                    WEBUI_READY=1
                fi
            fi
        fi
        progress_update 100 "Hoàn tất"
        progress_finish
    else
        POST_REBOOT_AI_OK=0
        WEBUI_READY=0
        progress_update 100 "[DRY-RUN] Hoàn tất, loa chưa reboot"
        progress_finish
        LAN_IP=""
    fi

    # Dọn dẹp cache
    for f in autodlna.apk unisound.apk AIBoxPlus_DLNA.apk; do
        rm -f "$CACHE_DIR/$f" "$CACHE_DIR/$f.tmp" 2>/dev/null || true
    done

    UI_IP="$TARGET_IP"
    [ -n "$LAN_IP" ] && UI_IP="$LAN_IP"

    echo ""
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s                    CÀI ĐẶT HOÀN TẤT!                     %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    if [ "$R1_DRYRUN" = "1" ]; then
        printf '%s>> Chạy thử hoàn tất; loa chưa được reboot.%s\n' "$C_YELLOW" "$C_RESET"
    else
        printf '%s>> Đã gửi lệnh khởi động lại (Reboot) loa.%s\n' "$C_GREEN" "$C_RESET"
        echo ">> Loa đang khởi động lại (thường mất khoảng 30 - 45 giây)."
        if [ "$POST_REBOOT_AI_OK" = "1" ]; then
            printf '%s>> AI đã được khởi chạy sau reboot.%s\n' "$C_GREEN" "$C_RESET"
        else
            printf '%s>> [CẢNH BÁO] Chưa xác minh được AI chạy sau reboot.%s\n' "$C_YELLOW" "$C_RESET"
        fi
        if [ "$WEBUI_READY" = "1" ]; then
            printf '%s>> WebUI đã phản hồi tại cổng 8081.%s\n' "$C_GREEN" "$C_RESET"
        else
            printf '%s>> [CẢNH BÁO] WebUI chưa phản hồi tại cổng 8081.%s\n' "$C_YELLOW" "$C_RESET"
        fi
    fi
    echo ""
    if [ "$R1_DRYRUN" = "1" ]; then
        echo ">> Khi cài thật, truy cập bảng điều khiển sau khi loa khởi động:"
    else
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
    fi
    printf '%s   👉 http://%s:8081/%s\n' "$C_CYAN" "$UI_IP" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 8. MENU CHÍNH (ĐỒNG BỘ VỚI Show-Menu TRONG INSTALL.PS1)
# ------------------------------------------------------------------------------
show_menu() {
    echo ""
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX / ANDROID   %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    echo "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)"
    printf '%s     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  2) Quét IP LAN & Cài đặt APK (AutoDLNA + Unisound + AI)"
    printf '%s     -> Dùng khi loa ĐÃ vào WiFi nhà (có IP LAN)%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  3) Chỉ quét tìm IP loa trong LAN (không cài đặt)"
    echo "  4) Thoát"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf "Chọn [1-4]: "
    CHOICE=""
    if ! read -r CHOICE 2>/dev/null; then
        CHOICE="4"
    fi
    CHOICE=$(printf '%s' "$CHOICE" | tr -d ' \r\n')
}

# Xử lý tham số CLI trực tiếp (Automation / Scripts)
if [ "$CLI_MODE" = "wifi" ]; then
    configure_wifi_ap
    exit 0
elif [ "$CLI_MODE" = "install" ]; then
    run_install_lan "$USER_IP"
    exit $?
elif [ "$CLI_MODE" = "scan" ]; then
    scan_speaker_ip
    if [ "$TOTAL_FOUND" -gt 0 ]; then
        printf '%s>> Tìm thấy %s loa Phicomm R1 trong mạng LAN.%s\n' "$C_GREEN" "$TOTAL_FOUND" "$C_RESET"
    else
        printf '%s>> Không tìm thấy loa R1 trong dải mạng hiện tại.%s\n' "$C_YELLOW" "$C_RESET"
    fi
    rm -rf "$scan_tmp" 2>/dev/null || true
    exit 0
fi

# Vòng lặp Menu chính
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
            if [ "$TOTAL_FOUND" -eq 0 ]; then
                echo ""
                printf '%s>> Không tìm thấy loa R1 trong dải mạng hiện tại.%s\n' "$C_YELLOW" "$C_RESET"
            fi
            rm -rf "$scan_tmp" 2>/dev/null || true
            echo ""
            read_val "Nhấn Enter để quay lại menu chính: " "" >/dev/null 2>&1 || true
            ;;
        4|"q"|"Q"|"exit")
            printf '%sThoát chương trình.%s\n' "$C_YELLOW" "$C_RESET"
            break
            ;;
        "")
            continue
            ;;
        *)
            printf '%sLựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 4.%s\n' "$C_YELLOW" "$C_RESET"
            sleep 1
            ;;
    esac
done
