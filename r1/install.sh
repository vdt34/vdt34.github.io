#!/bin/sh
# ==============================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - iSH (iPHONE) / LINUX / ANDROID / MACOS
# Đồng bộ chuẩn xác 100% theo install.ps1 (install_src.ps1)
# Tự động cấu hình WiFi AP, quét tìm loa trong LAN, dọn sạch file cũ, giao diện UTF-8
# ==============================================================================

USER_IP=""
ASSUME_YES=""
R1_DRYRUN="${R1_DRYRUN:-0}"
RUN_WIFI_CLI=""
RUN_SCAN_CLI=""
RUN_AIONLY_CLI=""

SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="."
CACHE_DIR="/tmp/r1_cache"
BASE_URL="${NABU_R1_BASE:-https://vdt34.github.io/r1}"

while [ $# -gt 0 ]; do
    case "$1" in
        192.168.43.1|192.168.43.1:*)
            USER_IP="192.168.43.1"
            RUN_WIFI_CLI=1
            ;;
        -Ip|--ip|-ip)
            shift
            [ $# -gt 0 ] && USER_IP="$1"
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*:[0-9]*|[0-9]*.[0-9]*.[0-9]*.[0-9]*)
            USER_IP="$1"
            ;;
        -Yes|-y|--yes|-yes)
            ASSUME_YES=1
            ;;
        -DryRun|--dry-run|-dryrun)
            R1_DRYRUN=1
            ;;
        -Wifi|--wifi|-wifi)
            RUN_WIFI_CLI=1
            ;;
        -Scan|--scan|-scan)
            RUN_SCAN_CLI=1
            ;;
        -AiOnly|--ai-only|-aionly|-ai)
            RUN_AIONLY_CLI=1
            ;;
        -LocalDir|--local-dir)
            shift
            [ $# -gt 0 ] && SCRIPT_DIR="$1"
            ;;
        -ApkBase|--apk-base)
            shift
            [ $# -gt 0 ] && BASE_URL="$1"
            ;;
    esac
    shift
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

read_r1_input() {
    prompt="$1"
    default_val="$2"
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        echo "$default_val"
        return
    fi
    printf "%s" "$prompt" >&2
    val=""
    read -r val 2>/dev/null || val=""
    val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$val" ] && val="$default_val"
    echo "$val"
}

set_r1_install_progress() {
    percent="$1"
    status="$2"
    [ -t 1 ] || return

    case "$percent" in
        ''|*[!0-9]*) percent=0 ;;
    esac
    [ "$percent" -gt 100 ] && percent=100
    [ "$percent" -lt 0 ] && percent=0

    bar_width=50
    filled=$((percent * bar_width / 100))
    empty=$((bar_width - filled))
    bar=""
    idx=0
    while [ "$idx" -lt "$filled" ]; do bar="${bar}█"; idx=$((idx + 1)); done
    idx=0
    while [ "$idx" -lt "$empty" ]; do bar="${bar}░"; idx=$((idx + 1)); done

    if [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '\033[2A\r\033[J'
    fi
    printf '\033[?7l%s   %s%s\n' "$C_CYAN" "$status" "$C_RESET"
    printf '%s   [%s] %3s%%%s\033[?7h\n' "$C_CYAN" "$bar" "$percent" "$C_RESET"
    R1_PROGRESS_ACTIVE=1
}

complete_r1_install_progress() {
    if [ -t 1 ] && [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '\033[2A\r\033[J'
        R1_PROGRESS_ACTIVE=""
    fi
}

wait_r1_speaker_boot() {
    serial="$1"
    attempts="${2:-45}"
    try=1
    while [ "$try" -le "$attempts" ]; do
        adb connect "$serial" >/dev/null 2>&1 || true
        state=$(adb -s "$serial" get-state 2>/dev/null | tr -d ' \r\n')
        if [ "$state" = "device" ]; then
            boot_state=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d ' \r\n')
            if [ "$boot_state" = "1" ]; then
                return 0
            fi
        fi
        set_r1_install_progress 98 "Đang chờ loa khởi động lại ($try/$attempts)"
        sleep 2
        try=$((try + 1))
    done
    return 1
}

# ------------------------------------------------------------------------------
# KIỂM TRA CỔNG TCP & ĐÁNH THỨC LOA (TƯƠNG ĐỒNG Test-R1TcpPort & Revive-Speaker)
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

test_r1_tcp_port() {
    thost="$1"
    tport="$2"
    tsec="${3:-1}"
    if [ -n "$PY_BIN" ]; then
        "$PY_BIN" - "$thost" "$tport" "$tsec" << 'EOF' >/dev/null 2>&1
import socket, sys
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(float(sys.argv[3]))
    rc = s.connect_ex((sys.argv[1], int(sys.argv[2])))
    s.close()
    sys.exit(0 if rc == 0 else 1)
except Exception:
    sys.exit(1)
EOF
        return $?
    fi
    if command -v nc >/dev/null 2>&1; then
        nc -z -w "$tsec" "$thost" "$tport" </dev/null >/dev/null 2>&1
        return $?
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -s -m "$tsec" --connect-timeout "$tsec" -o /dev/null "http://$thost:$tport/" </dev/null 2>/dev/null
        rc=$?
        case "$rc" in 0|1|52|56) return 0 ;; esac
    fi
    return 1
}

# ------------------------------------------------------------------------------
# 1. ĐẢM BẢO CÔNG CỤ CẦN THIẾT (CURL / NC / ADB) - (TƯƠNG ĐỒNG Ensure-Adb)
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
            apk add --no-cache android-tools netcat-openbsd psmisc >/dev/null 2>&1 || \
            apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community android-tools netcat-openbsd psmisc >/dev/null 2>&1 || true
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
    if command -v adb >/dev/null 2>&1; then return 0; fi
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
# 2. HÀM ĐÁNH THỨC & XÁC THỰC LOA R1 QUA WEBSOCKET 8080 (TƯƠNG ĐỒNG Revive-Speaker)
# ------------------------------------------------------------------------------
revive_speaker() {
    tip="$1"
    [ -z "$tip" ] && return 1
    [ "$R1_DRYRUN" = "1" ] && return 0

    if [ -n "$PY_BIN" ]; then
        "$PY_BIN" - "$tip" << 'EOF' >/dev/null 2>&1 || true
import sys, socket, base64, os, time
ip = sys.argv[1]
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1.2)
    if s.connect_ex((ip, 8080)) == 0:
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET / HTTP/1.1\r\n"
            f"Host: {ip}:8080\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        s.sendall(req.encode())
        resp = s.recv(1024)
        if b"101" in resp:
            payload = b'{"type":"shell","type_id":"myshell","shell":"setprop service.adb.tcp.port 5555; stop adbd; start adbd"}'
            mask = os.urandom(4)
            length = len(payload)
            header = bytearray([0x81, 0x80 | length]) + mask
            masked = bytearray(payload[i] ^ mask[i % 4] for i in range(length))
            s.sendall(header + masked)
            time.sleep(0.2)
    s.close()
except Exception:
    pass
EOF
        return 0
    fi

    if command -v nc >/dev/null 2>&1; then
        (
            printf 'GET / HTTP/1.1\r\nHost: %s:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' "$tip"
            sleep 0.2
            printf '\201\347\000\000\000\000{"type":"shell","type_id":"myshell","shell":"setprop service.adb.tcp.port 5555; stop adbd; start adbd"}'
            sleep 0.2
        ) | nc -w 1 "$tip" 8080 >/dev/null 2>&1 || true
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -s -m 1 --connect-timeout 1 "http://$tip:8080/" >/dev/null 2>&1 || true
        curl -s -m 1 --connect-timeout 1 "http://$tip:8081/" >/dev/null 2>&1 || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O- --timeout=1 "http://$tip:8080/" >/dev/null 2>&1 || true
        wget -q -O- --timeout=1 "http://$tip:8081/" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 3. [MỤC 1] CẤU HÌNH WIFI CHO LOA QUA AP API (TƯƠNG ĐỒNG Run-WifiConfig)
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
    return 0
}

run_wifi_config() {
    echo ""
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s  CẤU HÌNH WIFI CHO LOA VỪA RESET (CHẾ ĐỘ AP 192.168.43.1)%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    echo " Hướng dẫn chuẩn bị:"
    echo "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'."
    echo "  2. Trên Điện thoại / Máy tính: Vào Cài đặt WiFi -> Kết nối 'Phicomm_R1_xxxx'."
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_r1_input "Nhấn Enter khi đã kết nối WiFi của loa: " "" >/dev/null 2>&1 || true
    fi

    echo ""
    printf '%s>> Đang kiểm tra kết nối tới loa (192.168.43.1:8989)...%s\n' "$C_CYAN" "$C_RESET"
    connected_api=0
    if test_r1_tcp_port "192.168.43.1" 8989 2; then
        connected_api=1
    fi

    if [ "$connected_api" = "1" ]; then
        printf '%s   [OK] Đã kết nối được API của loa.%s\n' "$C_GREEN" "$C_RESET"
    else
        if [ "$R1_DRYRUN" != "1" ]; then
            printf '%s   [CẢNH BÁO] Chưa kết nối được 192.168.43.1:8989.%s\n' "$C_YELLOW" "$C_RESET"
            printf '%s   Kiểm tra: Thiết bị đã chọn WiFi Phicomm_R1 chưa? Loa còn phát AP không?%s\n' "$C_GRAY" "$C_RESET"
            if [ "$ASSUME_YES" != "1" ]; then
                cont=$(read_r1_input "   Vẫn tiếp tục gửi cấu hình WiFi? [y/N]: " "n")
                case "$(printf '%s' "$cont" | tr '[:upper:]' '[:lower:]')" in
                    "y"|"yes") ;;
                    *) return 1 ;;
                esac
            fi
        fi
    fi

    echo ""
    echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
    printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    ssid=""
    pass=""
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        ssid="MyWiFi"
        pass="12345678"
    else
        while [ -z "$ssid" ]; do
            ssid=$(read_r1_input ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): " "")
            if [ -z "$ssid" ]; then
                printf '%s   [!] Tên WiFi không được để trống!%s\n' "$C_YELLOW" "$C_RESET"
            fi
        done
        pass=$(read_r1_input ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): " "")
    fi

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
        read_r1_input "Nhấn Enter để quay lại menu chính" "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 4. HÀM DÒ TÌM DẢI MẠNG LAN & QUÉT LOA (TƯƠNG ĐỒNG Get-LocalSubnet & Scan-SpeakerIp)
# ------------------------------------------------------------------------------
decode_proc_hex_ip() {
    hex_ip="$1"
    [ "${#hex_ip}" -eq 8 ] || return 1
    b1=$(printf '%d' "0x$(printf '%s' "$hex_ip" | cut -c 7-8)" 2>/dev/null)
    b2=$(printf '%d' "0x$(printf '%s' "$hex_ip" | cut -c 5-6)" 2>/dev/null)
    b3=$(printf '%d' "0x$(printf '%s' "$hex_ip" | cut -c 3-4)" 2>/dev/null)
    if [ -n "$b1" ] && [ -n "$b2" ] && [ -n "$b3" ] && [ "$b1" != "127" ] && [ "$b1" != "0" ] && [ "$b1" != "169" ]; then
        echo "${b1}.${b2}.${b3}"
        return 0
    fi
    return 1
}

detect_subnet() {
    sub=""
    if command -v curl >/dev/null 2>&1; then
        lip=$(curl -s -w "%{local_ip}" -o /dev/null --connect-timeout 2 --max-time 3 "http://1.1.1.1/" 2>/dev/null || true)
        if [ -n "$lip" ]; then
            sub=$(printf '%s' "$lip" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -vE '^(127\.|0\.|169\.254\.)' | awk -F'.' '{print $1"."$2"."$3}')
        fi
    fi
    if [ -z "$sub" ] && [ -n "$PY_BIN" ]; then
        sub=$("$PY_BIN" - << 'EOF' 2>/dev/null
import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    ip = s.getsockname()[0]
    s.close()
    p = ip.split(".")
    if len(p) == 4 and p[0] not in ("127", "0", "169"):
        print(f"{p[0]}.{p[1]}.{p[2]}")
except Exception:
    pass
EOF
)
    fi
    if [ -z "$sub" ] && command -v ip >/dev/null 2>&1; then
        sub=$(ip -4 route get 8.8.8.8 2>/dev/null | grep -oE 'src [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
    fi
    if [ -z "$sub" ] && command -v ifconfig >/dev/null 2>&1; then
        sub=$(ifconfig 2>/dev/null | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -vE '^(127\.|169\.254\.)' | head -n 1 | awk -F'.' '{print $1"."$2"."$3}')
    fi
    if [ -z "$sub" ] && [ -r /proc/net/tcp ]; then
        for hex_candidate in $(awk 'NR>1 {split($2,a,":"); print a[1]}' /proc/net/tcp /proc/net/udp 2>/dev/null); do
            decoded=$(decode_proc_hex_ip "$hex_candidate")
            if [ -n "$decoded" ]; then
                sub="$decoded"
                break
            fi
        done
    fi
    [ -z "$sub" ] && sub="192.168.1"
    echo "$sub"
}

scan_single_subnet() {
    sub="$1"
    scan_tmp="$2"

    if [ -n "$PY_BIN" ]; then
        "$PY_BIN" - "$sub" << 'EOF' >> "$scan_tmp/adb_ips.txt" 2>/dev/null || true
import sys, socket
from concurrent.futures import ThreadPoolExecutor
prefix = sys.argv[1]
def probe_cand(i):
    ip = f"{prefix}.{i}"
    for port in (5555, 8080):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.6)
        try:
            if s.connect_ex((ip, port)) == 0:
                return (ip, port)
        except Exception:
            pass
        finally:
            try: s.close()
            except Exception: pass
    return None

with ThreadPoolExecutor(max_workers=64) as ex:
    for res in ex.map(probe_cand, range(1, 255)):
        if res:
            print(f"{res[0]}|{res[1]}")
EOF
    else
        idx=1
        while [ "$idx" -le 254 ]; do
            bend=$((idx + 19))
            [ "$bend" -gt 254 ] && bend=254
            i="$idx"
            while [ "$i" -le "$bend" ]; do
                (
                    target="${sub}.${i}"
                    if test_r1_tcp_port "$target" 5555 1; then
                        printf '%03d|%s|5555\n' "$i" "$target" >> "$scan_tmp/raw.txt"
                    elif test_r1_tcp_port "$target" 8080 1; then
                        printf '%03d|%s|8080\n' "$i" "$target" >> "$scan_tmp/raw.txt"
                    fi
                ) &
                i=$((i + 1))
            done
            wait
            idx=$((bend + 1))
        done
        if [ -f "$scan_tmp/raw.txt" ]; then
            sort -u "$scan_tmp/raw.txt" | awk -F'|' '{print $2 "|" $3}' >> "$scan_tmp/adb_ips.txt"
        fi
    fi

    # Xác thực thông tin thiết bị qua ADB getprop (chuẩn Scan-SpeakerIp)
    if [ -s "$scan_tmp/adb_ips.txt" ]; then
        while IFS='|' read -r cand_ip cand_port || [ -n "$cand_ip" ]; do
            cand_ip=$(printf '%s' "$cand_ip" | tr -d ' \r\n')
            cand_port=$(printf '%s' "$cand_port" | tr -d ' \r\n')
            [ -z "$cand_ip" ] && continue

            if [ "$cand_port" = "8080" ]; then
                if ! test_r1_tcp_port "$cand_ip" 5555 1; then
                    revive_speaker "$cand_ip" </dev/null >/dev/null 2>&1 || true
                    sleep 1
                fi
            fi

            test_r1_tcp_port "$cand_ip" 5555 1 || continue

            adb connect "$cand_ip:5555" </dev/null >/dev/null 2>&1 || true
            model=$(adb -s "$cand_ip:5555" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r\n')
            hostname=$(adb -s "$cand_ip:5555" shell getprop net.hostname </dev/null 2>/dev/null | tr -d '\r\n')
            aver=$(adb -s "$cand_ip:5555" shell getprop ro.build.version.release </dev/null 2>/dev/null | tr -d '\r\n')
            adb disconnect "$cand_ip:5555" </dev/null >/dev/null 2>&1 || true

            [ -z "$model" ] && model="Phicomm R1"
            [ -z "$hostname" ] && hostname="Phicomm_R1"
            [ -z "$aver" ] && aver="5.1.1"

            is_r1=0
            case "$model" in *[Rr]1*|*[Rr][Kk]322*) is_r1=1 ;; esac
            case "$hostname" in *[Pp][Hh][Ii][Cc][Oo][Mm][Mm]*|*[Rr]1*) is_r1=1 ;; esac

            if [ "$is_r1" = "1" ]; then
                printf '%s|(ADB: 5555)|%s|%s|%s\n' "$cand_ip" "$hostname" "$model" "$aver" >> "$scan_tmp/result.txt"
            else
                printf '%s|%s\n' "$cand_ip" "$model" >> "$scan_tmp/other.txt"
            fi
        done < "$scan_tmp/adb_ips.txt"
    fi
}

scan_speaker_ip() {
    sub="$1"
    [ -z "$sub" ] && sub=$(detect_subnet)
    echo ""
    printf '%s╔════════════════════════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
    printf '%s║                         🔍 ĐANG TÌM KIẾM LOA                       ║%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s╚════════════════════════════════════════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"
    echo ""
    printf '   📡 Mạng: %s.0/24\n' "$sub"
    printf '%s   ⏱️  Thời gian: khoảng 15-30 giây%s\n' "$C_GRAY" "$C_RESET"
    echo ""

    scan_tmp="/tmp/r1_scan_$$"
    rm -rf "$scan_tmp" 2>/dev/null || true
    mkdir -p "$scan_tmp"

    scan_single_subnet "$sub" "$scan_tmp"

    TOTAL_FOUND=0
    if [ -s "$scan_tmp/result.txt" ]; then
        while IFS='|' read -r ip_val port_info h_name m_name a_ver || [ -n "$ip_val" ]; do
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
        printf '%s╔════════════════════════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
        printf '%s║                            🎯 KẾT QUẢ QUÉT                         ║%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s╚════════════════════════════════════════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"
        echo ""
        printf '%s   ✅ Tìm thấy %s loa Phicomm R1:%s\n' "$C_GREEN" "$TOTAL_FOUND" "$C_RESET"
        echo ""
        d_idx=1
        while IFS='|' read -r s_ip s_ports h_name m_name a_ver || [ -n "$s_ip" ]; do
            s_ip=$(printf '%s' "$s_ip" | tr -d ' \r\n')
            [ -z "$s_ip" ] && continue
            printf '%s   ┌─── Loa #%s ──────────────────────────────────────────────────────%s\n' "$C_GREEN" "$d_idx" "$C_RESET"
            printf '%s   │  📍 IP:         %s%s\n' "$C_YELLOW" "$s_ip" "$C_RESET"
            [ -n "$h_name" ] && printf '   │  🏷️  Hostname:   %s\n' "$h_name"
            [ -n "$m_name" ] && printf '   │  📱 Model:      %s\n' "$m_name"
            [ -n "$a_ver" ] && printf '   │  🤖 Android:    %s\n' "$a_ver"
            printf '%s   └────────────────────────────────────────────────────────────────%s\n' "$C_GREEN" "$C_RESET"
            echo ""
            d_idx=$((d_idx + 1))
        done < "$scan_tmp/result.txt"

        if [ -s "$scan_tmp/other.txt" ]; then
            other_cnt=$(grep -c '[0-9]' "$scan_tmp/other.txt" 2>/dev/null || echo 0)
            printf '%s   ℹ️  Tìm thấy %s thiết bị khác có ADB:%s\n' "$C_YELLOW" "$other_cnt" "$C_RESET"
            while IFS='|' read -r o_ip o_model || [ -n "$o_ip" ]; do
                printf '%s      • %s - %s%s\n' "$C_GRAY" "$o_ip" "$o_model" "$C_RESET"
            done < "$scan_tmp/other.txt"
            echo ""
        fi

        printf '%s   ──────────────────────────────────────────────────────────────────%s\n' "$C_GRAY" "$C_RESET"
        printf '   Tổng số thiết bị:    %s\n' "$TOTAL_FOUND"
        printf '   Loa Phicomm R1:      %s\n' "$TOTAL_FOUND"
        printf '%s   ──────────────────────────────────────────────────────────────────%s\n' "$C_GRAY" "$C_RESET"
        echo ""
        printf '%s   ✓ Quét hoàn tất!%s\n' "$C_GREEN" "$C_RESET"
        echo ""
    else
        echo ""
        printf '%s   ⚠️  Không tìm thấy loa Phicomm R1.%s\n' "$C_YELLOW" "$C_RESET"
        echo ""
    fi
}

# ------------------------------------------------------------------------------
# 5. CHUẨN BỊ FILE CÀI ĐẶT APK (TƯƠNG ĐỒNG Get-LocalAiApk & Ensure-Apks)
# ------------------------------------------------------------------------------
get_local_ai_apk() {
    [ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR" ] && return 1

    # 1. Tìm bản có phiên bản theo dạng ai-box-plus-X-Y-Z.apk
    best_file=""
    for f in "$SCRIPT_DIR"/ai-box-plus-*-*-*.apk; do
        [ -f "$f" ] || continue
        best_file="$f"
    done
    if [ -n "$best_file" ]; then
        echo "$best_file"
        return 0
    fi

    # 2. Tìm bản vá VOV nếu có
    if [ -f "$SCRIPT_DIR/AIBoxPlus_DLNA_VOV_Patched.apk" ]; then
        echo "$SCRIPT_DIR/AIBoxPlus_DLNA_VOV_Patched.apk"
        return 0
    fi

    # 3. Tìm bản AIBoxPlus_DLNA.apk chuẩn
    if [ -f "$SCRIPT_DIR/AIBoxPlus_DLNA.apk" ]; then
        echo "$SCRIPT_DIR/AIBoxPlus_DLNA.apk"
        return 0
    fi

    # 4. Tìm bất kỳ file apk nào có tên bắt đầu bằng ai-box hoặc aiboxplus
    for f in "$SCRIPT_DIR"/[aA][iI]-[bB][oO][xX]*.apk "$SCRIPT_DIR"/[aA][iI][bB][oO][xX]*.apk; do
        if [ -f "$f" ]; then
            echo "$f"
            return 0
        fi
    done

    return 1
}

ensure_apk_ai_only() {
    f="AIBoxPlus_DLNA.apk"
    cache_file="$CACHE_DIR/$f"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    rm -f "$cache_file" "$cache_file.tmp" 2>/dev/null || true

    # 1. Ưu tiên tìm file local trước (file cùng thư mục script)
    local_ai=$(get_local_ai_apk)
    if [ -n "$local_ai" ] && [ -f "$local_ai" ]; then
        printf '%s>> [LOCAL] Đã tìm thấy file AIBoxPlus cục bộ: %s%s\n' "$C_GREEN" "$(basename "$local_ai")" "$C_RESET"
        cp -f "$local_ai" "$cache_file"
        return 0
    fi

    # 2. Nếu local không có, tìm và tải trên server
    printf '%s>> [ONLINE] Không có file APK AIBoxPlus cục bộ trong '\''%s'\''. Đang kiểm tra từ máy chủ (%s/version.json)...%s\n' "$C_CYAN" "$SCRIPT_DIR" "$BASE_URL" "$C_RESET"

    TS=$(date +%s 2>/dev/null || echo "1")
    json_raw=""
    if command -v curl >/dev/null 2>&1; then
        json_raw=$(curl -k -fsSL --connect-timeout 15 --max-time 30 "$BASE_URL/version.json?t=$TS" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        json_raw=$(wget -q --no-check-certificate --timeout=30 -O - "$BASE_URL/version.json?t=$TS" 2>/dev/null)
    fi

    ai_download_url=$(printf '%s\n' "$json_raw" | sed -n 's/.*"url": *"\([^"]*\)".*/\1/p' | head -n 1)
    ai_apk_name=$(printf '%s\n' "$json_raw" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' | head -n 1)
    ai_ver=$(printf '%s\n' "$json_raw" | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -n 1)

    if [ -z "$ai_download_url" ]; then
        printf '%s>> [LỖI] Không tìm thấy file APK cục bộ và không thể tải AIBoxPlus từ máy chủ.%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    printf '%s>> Phiên bản mới nhất trên máy chủ: %s (v%s)%s\n' "$C_GREEN" "$ai_apk_name" "$ai_ver" "$C_RESET"
    printf '%s>> Đang tải: %s...%s\n' "$C_CYAN" "$ai_download_url" "$C_RESET"

    if command -v curl >/dev/null 2>&1; then
        curl -k -fsSL --connect-timeout 20 --max-time 60 -o "$cache_file.tmp" "$ai_download_url?t=$TS" 2>/dev/null && mv -f "$cache_file.tmp" "$cache_file"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --timeout=60 -O "$cache_file.tmp" "$ai_download_url?t=$TS" 2>/dev/null && mv -f "$cache_file.tmp" "$cache_file"
    fi

    if [ ! -f "$cache_file" ] || [ "$(wc -c < "$cache_file" 2>/dev/null || echo 0)" -lt 1000000 ]; then
        printf '%s>> [LỖI] Tải %s từ máy chủ thất bại.%s\n' "$C_RED" "$ai_apk_name" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi
    return 0
}

ensure_apks() {
    echo ""
    printf '%s>> Đang chuẩn bị các gói cài đặt (ưu tiên file cục bộ, tự động tải từ máy chủ nếu thiếu)...%s\n' "$C_CYAN" "$C_RESET"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    rm -f "$CACHE_DIR/AIBoxPlus_DLNA.apk" "$CACHE_DIR/AIBoxPlus_DLNA.apk.tmp" 2>/dev/null || true

    missing=0
    set_r1_install_progress 20 "Đang kiểm tra AIBoxPlus"
    if ! ensure_apk_ai_only; then
        missing=1
    fi
    set_r1_install_progress 35 "Đã chuẩn bị xong file APK"

    if [ "$missing" = "1" ]; then
        complete_r1_install_progress
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI THIẾU FILE CÀI ĐẶT]%s\n' "$C_RED" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%sKhông tìm thấy đủ file APK trong thư mục cục bộ và tải từ máy chủ thất bại.%s\n' "$C_YELLOW" "$C_RESET"
        printf '%sVui lòng copy file APK vào cùng thư mục với script hoặc kiểm tra kết nối mạng.%s\n' "$C_YELLOW" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 6. THỰC THI BƯỚC CÀI ĐẶT ADB (TƯƠNG ĐỒNG Invoke-AdbInstallStep TRONG INSTALL.PS1)
# ------------------------------------------------------------------------------
invoke_adb_install_step() {
    require_success="$1"
    shift

    output=$(adb "$@" 2>&1)
    exit_code=$?
    pkg_failed=0
    if [ "$require_success" = "1" ]; then
        if ! printf '%s\n' "$output" | tr -d '\r' | grep -Eq '^[[:space:]]*Success[[:space:]]*$'; then
            pkg_failed=1
        fi
    fi

    # Đặc trị cho iSH (iOS) khi pm install APK lớn (11MB+):
    # dex2oat trên RK3229 (Android 5.1.1) ngốn 100% CPU trong 30-45s khiến stream adb của iSH rớt kết nối (error: closed).
    # Kiểm tra xem gói info.dourok.voicebot đã xuất hiện trên hệ thống chưa:
    if [ "$exit_code" -ne 0 ] || [ "$pkg_failed" -ne 0 ]; then
        if [ "$require_success" = "1" ]; then
            chk_try=1
            while [ "$chk_try" -le 8 ]; do
                sleep 4
                adb connect "$SERIAL" >/dev/null 2>&1 || true
                if adb -s "$SERIAL" shell pm path info.dourok.voicebot 2>/dev/null | grep -q "info.dourok.voicebot"; then
                    return 0
                fi
                chk_try=$((chk_try + 1))
            done
        fi

        complete_r1_install_progress
        [ -n "$output" ] && printf '%s\n' "$output"
        if [ "$exit_code" -ne 0 ]; then
            printf '%s>> [LỖI] ADB kết thúc với mã lỗi %s.%s\n' "$C_RED" "$exit_code" "$C_RESET"
        elif [ "$pkg_failed" -eq 1 ]; then
            printf '%s>> [LỖI] ADB không xác nhận cài đặt thành công.%s\n' "$C_RED" "$C_RESET"
        fi
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 7. [MỤC 2] LUỒNG QUÉT IP LAN & CÀI ĐẶT APK (ĐỒNG BỘ 100% THEO Run-Install PS1)
# ------------------------------------------------------------------------------
run_install() {
    target_param="$1"
    TARGET_IP="$target_param"

    if [ -z "$TARGET_IP" ]; then
        scan_speaker_ip
        if [ "$TOTAL_FOUND" -gt 0 ]; then
            echo ""
            pick=$(read_r1_input "   Chọn số thứ tự loa để cài APK (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
            pick=$(printf '%s' "$pick" | tr -d ' ')
            if [ "$pick" -ge 1 ] 2>/dev/null && [ "$pick" -le "$TOTAL_FOUND" ] 2>/dev/null; then
                TARGET_IP=$(sed -n "${pick}p" "$scan_tmp/ips.txt")
            elif printf '%s' "$pick" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$'; then
                TARGET_IP="$pick"
            else
                TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
            fi
        else
            echo ""
            manual=$(read_r1_input "   Không tìm thấy loa. Nhập IP loa thủ công (Enter để quay lại menu): " "")
            if [ -n "$manual" ]; then
                TARGET_IP="$manual"
            else
                rm -rf "$scan_tmp" 2>/dev/null || true
                return 1
            fi
        fi
        rm -rf "$scan_tmp" 2>/dev/null || true
    fi

    # Kiểm tra lại nếu người dùng nhập nhầm 192.168.43.1
    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [CẢNH BÁO] KHÔNG THỂ CÀI ĐẶT APK QUA AP 192.168.43.1!%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        echo "  WiFi AP của loa tự tắt sau ~60-90 giây, push APK sẽ rớt mạng."
        echo "  -> Hãy chọn [1] trên Menu để cấu hình WiFi cho loa trước!"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d '[:space:]')
    case "$TARGET_IP" in
        *:5555) TARGET_IP="${TARGET_IP%:5555}" ;;
    esac
    SERIAL="$TARGET_IP:5555"

    echo ""
    printf '%s>> Sẽ kết nối tới IP: %s%s\n' "$C_CYAN" "$TARGET_IP" "$C_RESET"

    # Đảm bảo có ADB trước khi cài đặt
    if ! ensure_adb; then
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI] KHÔNG THỂ KHỞI TẠO CÔNG CỤ ADB!%s\n' "$C_RED" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%sVui lòng kiểm tra kết nối Internet để tải bộ công cụ ADB.%s\n' "$C_YELLOW" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    if ! ensure_apks; then return 1; fi

    # [2/4] Bắt đầu kết nối thiết bị ADB
    complete_r1_install_progress
    echo ""
    set_r1_install_progress 38 "Đang kết nối với loa"

    if [ "$R1_DRYRUN" != "1" ]; then
        killall -9 adb 2>/dev/null || pkill -9 adb 2>/dev/null || kill -9 $(pidof adb 2>/dev/null) 2>/dev/null || true
        adb kill-server >/dev/null 2>&1 || true
        adb start-server >/dev/null 2>&1 || true
        sleep 1

        connected=0
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        sleep 1

        state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
        if [ "$state" = "device" ]; then
            if adb -s "$SERIAL" shell ls /data >/dev/null 2>&1; then
                connected=1
            fi
        fi

        if [ "$connected" = "0" ]; then
            set_r1_install_progress 40 "Đang đánh thức loa"
            revive_speaker "$TARGET_IP"
            sleep 2

            try=1
            while [ "$try" -le 5 ]; do
                pct=$((40 + try * 2))
                set_r1_install_progress "$pct" "Đang chờ loa phản hồi ($try/5)"
                adb connect "$SERIAL" >/dev/null 2>&1 || true
                sleep 1

                state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
                if [ "$state" = "device" ]; then
                    if adb -s "$SERIAL" shell ls /data >/dev/null 2>&1; then
                        connected=1
                        break
                    fi
                fi
                sleep 1
                try=$((try + 1))
            done
        fi

        if [ "$connected" = "0" ]; then
            complete_r1_install_progress
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
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
    fi
    set_r1_install_progress 52 "Đã kết nối với loa"

    # [3/4] Dọn dẹp và chuẩn bị loa
    set_r1_install_progress 54 "Đang dọn dẹp và chuẩn bị loa"
    if [ "$R1_DRYRUN" != "1" ]; then
        adb -s "$SERIAL" shell rm /sdcard/otaprop.txt >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell rm /sdcard/incremental\*.zip >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm clear com.phicomm.speaker.otaservice >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell "rm -rf /data/local/tmp/* 2>/dev/null" >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1 || true

        set_r1_install_progress 58 "Đang tắt ứng dụng xung đột"
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.airskill >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.systemtool >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.device >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.otaservice >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.productiontest >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.bugreport >/dev/null 2>&1 || true
    else
        set_r1_install_progress 68 "[DRY-RUN] Đã mô phỏng chuẩn bị loa"
    fi

    # [4/4] Thực thi chuỗi lệnh cài đặt hệ thống chuẩn theo new.bat / install.ps1
    post_reboot_ai_started=0
    webui_ready=0
    speaker_lan_ip=""

    if [ "$R1_DRYRUN" != "1" ]; then
        set_r1_install_progress 80 "Đang khởi chạy dịch vụ loa"
        adb -s "$SERIAL" shell am startservice com.phicomm.speaker.player/.EchoService >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell am startservice com.phicomm.speaker.player/.DlnaPlayerService >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm uninstall com.phicomm.speaker.device >/dev/null 2>&1 || true
        sleep 2

        set_r1_install_progress 83 "Đang khôi phục dịch vụ hệ thống"
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.ijetty >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.netctl >/dev/null 2>&1 || true

        set_r1_install_progress 85 "Đang gỡ phiên bản AI cũ"
        adb -s "$SERIAL" shell /system/bin/pm uninstall info.dourok.voicebot >/dev/null 2>&1 || true

        ai_apk="AIBoxPlus_DLNA.apk"
        local_ai_apk="$CACHE_DIR/$ai_apk"
        if [ ! -f "$local_ai_apk" ]; then
            complete_r1_install_progress
            printf '%s>> [LỖI] Không tìm thấy file APK trên máy: %s%s\n' "$C_RED" "$local_ai_apk" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        set_r1_install_progress 88 "Đang chuyển AI Box vào loa"
        if ! invoke_adb_install_step 0 -s "$SERIAL" push "$local_ai_apk" "/data/local/tmp/$ai_apk"; then
            complete_r1_install_progress
            printf '%s>> [LỖI] Tải file lên loa thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        set_r1_install_progress 92 "Đang cài AI Box Plus"
        if ! invoke_adb_install_step 1 -s "$SERIAL" shell /system/bin/pm install -r "/data/local/tmp/$ai_apk"; then
            complete_r1_install_progress
            printf '%s>> [LỖI] Cài đặt thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        adb -s "$SERIAL" shell rm "/data/local/tmp/$ai_apk" >/dev/null 2>&1 || true

        set_r1_install_progress 95 "Đang khởi chạy AI Box Plus"
        adb -s "$SERIAL" shell "tinymix -D 2 0 5; tinymix -D 2 1 5; tinymix -D 2 6 207; tinymix -D 2 7 207; tinymix -D 2 8 207; tinymix -D 2 9 207; tinymix -D 2 17 1; tinymix -D 2 18 1; tinymix -D 2 46 1; tinymix -D 2 47 1" >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1 || true
        sleep 5

        complete_r1_install_progress
        echo ""
        echo "------------------------------------------------------------------------"
        echo "Truy cập Xiaozhi.me để nhập mã 6 số và cấu hình AI."
        echo "Nếu AI đã được cấu hình trước đó, có thể bỏ qua bước này."
        echo "------------------------------------------------------------------------"
        sleep 2

        adb -s "$SERIAL" shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" >/dev/null 2>&1 || true

        printf '%s>> Cài đặt thành công, loa sẽ tự khởi động lại.%s\n' "$C_GREEN" "$C_RESET"
        speaker_lan_ip=$(adb -s "$SERIAL" shell getprop dhcp.wlan0.ipaddress 2>/dev/null | tr -d ' \r\n')

        set_r1_install_progress 98 "Đang khởi động lại loa"
        adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
        if wait_r1_speaker_boot "$SERIAL"; then
            set_r1_install_progress 99 "Đang khởi chạy AI sau reboot"
            adb -s "$SERIAL" shell "tinymix -D 2 0 5; tinymix -D 2 1 5; tinymix -D 2 6 207; tinymix -D 2 7 207; tinymix -D 2 8 207; tinymix -D 2 9 207; tinymix -D 2 17 1; tinymix -D 2 18 1; tinymix -D 2 46 1; tinymix -D 2 47 1" >/dev/null 2>&1 || true
            launch_out=$(adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity 2>&1)
            launch_code=$?
            if [ "$launch_code" -eq 0 ] && ! printf '%s\n' "$launch_out" | grep -Eq '(?i)(Error:|Exception|does not exist)'; then
                post_reboot_ai_started=1
                sleep 5
                web_try=1
                while [ "$web_try" -le 15 ]; do
                    if test_r1_tcp_port "$TARGET_IP" 8081 1; then
                        webui_ready=1
                        break
                    fi
                    set_r1_install_progress 99 "Đang chờ WebUI khởi động ($web_try/15)"
                    sleep 1
                    web_try=$((web_try + 1))
                done
            else
                complete_r1_install_progress
                printf '%s>> [CẢNH BÁO] Không khởi chạy được AI sau reboot:%s\n' "$C_YELLOW" "$C_RESET"
                [ -n "$launch_out" ] && printf '%s\n' "$launch_out"
            fi
        else
            complete_r1_install_progress
            printf '%s>> [CẢNH BÁO] Loa chưa kết nối lại sau reboot; không xác minh được AI/WebUI.%s\n' "$C_YELLOW" "$C_RESET"
        fi
        set_r1_install_progress 100 "Hoàn tất"
        complete_r1_install_progress
    else
        post_reboot_ai_started=0
        webui_ready=0
        set_r1_install_progress 100 "[DRY-RUN] Hoàn tất, loa chưa reboot"
        complete_r1_install_progress
        speaker_lan_ip=""
    fi

    # Dọn dẹp cache
    rm -f "$CACHE_DIR/AIBoxPlus_DLNA.apk" "$CACHE_DIR/AIBoxPlus_DLNA.apk.tmp" 2>/dev/null || true

    ui_ip="$TARGET_IP"
    [ -n "$speaker_lan_ip" ] && ui_ip="$speaker_lan_ip"

    echo ""
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s                    CÀI ĐẶT HOÀN TẤT!                     %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    if [ "$R1_DRYRUN" = "1" ]; then
        printf '%s>> Chạy thử hoàn tất; loa chưa được reboot.%s\n' "$C_YELLOW" "$C_RESET"
        echo ">> Khi cài thật, truy cập bảng điều khiển sau khi loa khởi động:"
    else
        printf '%s>> Đã gửi lệnh khởi động lại (Reboot) loa.%s\n' "$C_GREEN" "$C_RESET"
        echo ">> Loa đang khởi động lại (thường mất khoảng 30 - 45 giây)."
        if [ "$post_reboot_ai_started" = "1" ]; then
            printf '%s>> AI đã được khởi chạy sau reboot.%s\n' "$C_GREEN" "$C_RESET"
        else
            printf '%s>> [CẢNH BÁO] Chưa xác minh được AI chạy sau reboot.%s\n' "$C_YELLOW" "$C_RESET"
        fi
        if [ "$webui_ready" = "1" ]; then
            printf '%s>> WebUI đã phản hồi tại cổng 8081.%s\n' "$C_GREEN" "$C_RESET"
        else
            printf '%s>> [CẢNH BÁO] WebUI chưa phản hồi tại cổng 8081.%s\n' "$C_YELLOW" "$C_RESET"
        fi
        echo ""
        echo ">> Sau khi loa khởi động xong, truy cập bảng điều khiển tại:"
    fi
    printf '%s   👉 http://%s:8081/%s\n' "$C_CYAN" "$ui_ip" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    echo ""
    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_r1_input "Nhấn Enter để quay lại menu chính" "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 8. [MỤC 3] CHỈ CÀI ĐẶT / CẬP NHẬT AIBOXPLUS (ĐỒNG BỘ THEO Run-Install-AiOnly PS1)
# ------------------------------------------------------------------------------
run_install_ai_only() {
    target_param="$1"
    TARGET_IP="$target_param"

    if [ -z "$TARGET_IP" ]; then
        scan_speaker_ip
        if [ "$TOTAL_FOUND" -gt 0 ]; then
            echo ""
            pick=$(read_r1_input "   Chọn số thứ tự loa để cập nhật AIBoxPlus (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
            pick=$(printf '%s' "$pick" | tr -d ' ')
            if [ "$pick" -ge 1 ] 2>/dev/null && [ "$pick" -le "$TOTAL_FOUND" ] 2>/dev/null; then
                TARGET_IP=$(sed -n "${pick}p" "$scan_tmp/ips.txt")
            elif printf '%s' "$pick" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$'; then
                TARGET_IP="$pick"
            else
                TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt")
            fi
        else
            echo ""
            manual=$(read_r1_input "   Không tìm thấy loa. Nhập IP loa thủ công (Enter để quay lại menu): " "")
            if [ -n "$manual" ]; then
                TARGET_IP="$manual"
            else
                rm -rf "$scan_tmp" 2>/dev/null || true
                return 1
            fi
        fi
        rm -rf "$scan_tmp" 2>/dev/null || true
    fi

    if [ "$TARGET_IP" = "192.168.43.1" ]; then
        echo ""
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [CẢNH BÁO] KHÔNG THỂ CẬP NHẬT APK QUA AP 192.168.43.1!%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s==========================================================%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    TARGET_IP=$(printf '%s' "$TARGET_IP" | tr -d '[:space:]')
    case "$TARGET_IP" in
        *:5555) TARGET_IP="${TARGET_IP%:5555}" ;;
    esac
    SERIAL="$TARGET_IP:5555"

    echo ""
    printf '%s>> Sẽ kết nối tới loa: %s%s\n' "$C_CYAN" "$TARGET_IP" "$C_RESET"

    if ! ensure_adb; then
        printf '%s>> [LỖI] Không thể khởi tạo công cụ ADB.%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
        return 1
    fi

    if ! ensure_apk_ai_only; then return 1; fi

    echo ""
    printf '%s>> Đang kết nối tới loa qua ADB (%s)...%s\n' "$C_CYAN" "$SERIAL" "$C_RESET"

    if [ "$R1_DRYRUN" != "1" ]; then
        adb connect "$SERIAL" >/dev/null 2>&1 || true
        sleep 1
        state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
        if [ "$state" != "device" ]; then
            revive_speaker "$TARGET_IP"
            adb connect "$SERIAL" >/dev/null 2>&1 || true
            sleep 1
            state=$(adb -s "$SERIAL" get-state 2>/dev/null | tr -d ' \r\n')
        fi

        if [ "$state" != "device" ]; then
            echo ""
            printf '%s>> [LỖI] Không thể kết nối tới loa tại %s.%s\n' "$C_RED" "$SERIAL" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        printf '%s>> Đã kết nối thành công tới loa.%s\n' "$C_GREEN" "$C_RESET"
        printf '%s>> Đang bật quyền cài đặt ứng dụng...%s\n' "$C_CYAN" "$C_RESET"
        adb -s "$SERIAL" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1 || true

        ai_apk="AIBoxPlus_DLNA.apk"
        local_ai_apk="$CACHE_DIR/$ai_apk"

        printf '%s>> Đang tải AIBoxPlus lên loa...%s\n' "$C_CYAN" "$C_RESET"
        if ! invoke_adb_install_step 0 -s "$SERIAL" push "$local_ai_apk" "/data/local/tmp/$ai_apk"; then
            printf '%s>> [LỖI] Tải file lên loa thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi

        printf '%s>> Đang cài đặt / cập nhật AIBoxPlus (giữ nguyên token Xiaozhi)...%s\n' "$C_CYAN" "$C_RESET"
        if ! invoke_adb_install_step 1 -s "$SERIAL" shell /system/bin/pm install -r "/data/local/tmp/$ai_apk"; then
            printf '%s>> [LỖI] Cài đặt thất bại: %s%s\n' "$C_RED" "$ai_apk" "$C_RESET"
            read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null 2>&1 || true
            return 1
        fi
        adb -s "$SERIAL" shell rm "/data/local/tmp/$ai_apk" >/dev/null 2>&1 || true

        printf '%s>> Đang khởi động AIBoxPlus...%s\n' "$C_CYAN" "$C_RESET"
        adb -s "$SERIAL" shell "tinymix -D 2 0 5; tinymix -D 2 1 5; tinymix -D 2 6 207; tinymix -D 2 7 207; tinymix -D 2 8 207; tinymix -D 2 9 207; tinymix -D 2 17 1; tinymix -D 2 18 1; tinymix -D 2 46 1; tinymix -D 2 47 1" >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1 || true
        sleep 4
    fi

    echo ""
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s             CẬP NHẬT AIBOXPLUS HOÀN TẤT!                 %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s>> AIBoxPlus đã được cài đặt / cập nhật thành công (giữ nguyên dữ liệu).%s\n' "$C_GREEN" "$C_RESET"
    printf '%s>> Bảng điều khiển WebUI: http://%s:8081/%s\n' "$C_CYAN" "$TARGET_IP" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_GREEN" "$C_RESET"
    echo ""

    if [ "$ASSUME_YES" != "1" ]; then
        reboot_ans=$(read_r1_input "Khởi động lại loa ngay bây giờ? [y/N]: " "n")
        case "$(printf '%s' "$reboot_ans" | tr '[:upper:]' '[:lower:]')" in
            "y"|"yes")
                adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
                printf '%s>> Đã gửi lệnh khởi động lại loa.%s\n' "$C_GREEN" "$C_RESET"
                ;;
        esac
        echo ""
        read_r1_input "Nhấn Enter để quay lại menu chính" "" >/dev/null 2>&1 || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 9. MENU CHÍNH (ĐỒNG BỘ THEO Show-Menu TRONG INSTALL.PS1)
# ------------------------------------------------------------------------------
show_menu() {
    echo ""
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s     CÔNG CỤ CÀI ĐẶT PHICOMM R1 - iSH / LINUX / ANDROID   %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    echo "  1) Cấu hình WiFi cho loa (kết nối AP 192.168.43.1)"
    printf '%s     -> Dùng khi loa vừa reset, đang phát WiFi Phicomm_R1_xxxx%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  2) Cài đặt mới hoàn toàn (AIBox Plus All-in-One)"
    printf '%s     -> Dùng khi cài mới hoàn toàn cho loa (ưu tiên file local)%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  3) Chỉ cài đặt / cập nhật AIBoxPlus (giữ nguyên token & app cũ)"
    printf '%s     -> Nâng cấp AIBoxPlus nhanh, không ảnh hưởng DLNA (ưu tiên local)%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  4) Quét tìm IP loa Phicomm R1 trong LAN (chỉ kiểm tra)"
    echo "  5) Thoát"
    printf '%s==========================================================%s\n' "$C_CYAN" "$C_RESET"
    choice=$(read_r1_input "Chọn [1-5]: " "5")
    choice=$(printf '%s' "$choice" | tr -d ' \r\n')
    echo "$choice"
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if [ -n "$RUN_WIFI_CLI" ]; then
    run_wifi_config
    exit $?
fi

if [ -n "$RUN_AIONLY_CLI" ]; then
    run_install_ai_only "$USER_IP"
    exit $?
fi

if [ -n "$USER_IP" ]; then
    run_install "$USER_IP"
    exit $?
fi

if [ -n "$RUN_SCAN_CLI" ]; then
    scan_speaker_ip
    exit 0
fi

# Vòng lặp Menu chính
while :; do
    c=$(show_menu)
    case "$c" in
        1)
            run_wifi_config
            ;;
        2)
            run_install ""
            ;;
        3)
            run_install_ai_only ""
            ;;
        4)
            scan_speaker_ip
            read_r1_input "   Nhấn Enter để quay lại menu chính" "" >/dev/null 2>&1 || true
            ;;
        5|"q"|"Q"|"exit")
            printf '%sThoát chương trình.%s\n' "$C_YELLOW" "$C_RESET"
            break
            ;;
        "")
            continue
            ;;
        *)
            printf '%sLựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 5.%s\n' "$C_YELLOW" "$C_RESET"
            sleep 1
            ;;
    esac
done
