#!/bin/sh
# =================================================================
# BỘ CÀI ĐẶT PHICOMM R1 SIÊU TỐC - iSH (iPHONE) / LINUX / ANDROID / MACOS
# Đồng bộ chuẩn xác 100% theo install.ps1 (install_src.ps1)
# Hỗ trợ WiFi AP, Cài đặt qua AP Mode, Cài đặt qua LAN, Quét loa, ADB ổn định
# =================================================================

USER_IP=""
ASSUME_YES=""
R1_DRYRUN="${R1_DRYRUN:-0}"
RUN_WIFI_CLI=""
RUN_SCAN_CLI=""
RUN_AIONLY_CLI=""
RUN_CLEAN_CLI=""

SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="."
CACHE_DIR="/tmp/r1_cache"
BASE_URL="${NABU_R1_BASE:-https://vdt34.github.io/r1}"

while [ $# -gt 0 ]; do
    case "$1" in
        192.168.43.1|192.168.43.1:*)
            USER_IP="192.168.43.1"
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
        -Clean|--clean|-clean)
            RUN_CLEAN_CLI=1
            ;;
        -Update|--update|-update|-AiOnly|--ai-only|-aionly|-ai)
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
# TIỆN ÍCH GIAO DIỆN & THANH TIẾN TRÌNH
# ------------------------------------------------------------------------------
C_RESET=""
C_CYAN=""
C_GREEN=""
C_YELLOW=""
C_RED=""
C_GRAY=""
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    C_RESET=$(printf '[0m')
    C_CYAN=$(printf '[36m')
    C_GREEN=$(printf '[32m')
    C_YELLOW=$(printf '[33m')
    C_RED=$(printf '[31m')
    C_GRAY=$(printf '[90m')
fi

read_r1_input() {
    prompt="$1"
    default_val="$2"
    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        echo "$default_val"
        return
    fi
    if [ -w /dev/tty ]; then
        printf "%s" "$prompt" > /dev/tty
    else
        printf "%s" "$prompt" >&2
    fi
    val=""
    if [ -r /dev/tty ]; then
        read -r val < /dev/tty 2>/dev/null || val=""
    elif [ -t 0 ]; then
        read -r val 2>/dev/null || val=""
    else
        read -r val 2>/dev/null || val=""
    fi
    val=$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$val" ] && val="$default_val"
    echo "$val"
}

set_r1_install_progress() {
    percent="$1"
    status="$2"
    [ -t 1 ] || return 0
    filled=$((percent / 4))
    empty=$((25 - filled))
    bar=""
    i=0
    while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i + 1)); done
    i=0
    while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i + 1)); done
    if [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '[2A
[J'
    fi
    printf '[?7l%s   %s%s\n' "$C_CYAN" "$status" "$C_RESET"
    printf '%s   [%s] %3s%%%s[?7h\n' "$C_CYAN" "$bar" "$percent" "$C_RESET"
    R1_PROGRESS_ACTIVE=1
}

complete_r1_install_progress() {
    if [ -t 1 ] && [ "$R1_PROGRESS_ACTIVE" = "1" ]; then
        printf '[2A
[J'
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
# 1. ĐẢM BẢO CÔNG CỤ (CURL / ADB)
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
            apk update >/dev/null 2>&1 || true
            apk add --no-cache android-tools netcat-openbsd >/dev/null 2>&1 || apk add --no-cache android-tools >/dev/null 2>&1 || true
        elif command -v pkg >/dev/null 2>&1; then
            pkg install -y android-tools netcat-openbsd >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y adb netcat >/dev/null 2>&1 || true
        fi
    fi
}

ensure_adb() {
    [ "$R1_DRYRUN" = "1" ] && return 0
    if command -v adb >/dev/null 2>&1; then
        return 0
    fi
    setup_tools
    if command -v adb >/dev/null 2>&1; then
        return 0
    fi
    printf '%s>> [LỖI] Không tìm thấy công cụ adb trên hệ thống.%s\n' "$C_RED" "$C_RESET"
    return 1
}

# ------------------------------------------------------------------------------
# 2. ĐÁNH THỨC ADB LOA R1
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
            f"GET / HTTP/1.1
"
            f"Host: {ip}:8080
"
            f"Upgrade: websocket
"
            f"Connection: Upgrade
"
            f"Sec-WebSocket-Key: {key}
"
            f"Sec-WebSocket-Version: 13

"
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
            printf 'GET / HTTP/1.1
Host: %s:8080
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13

' "$tip"
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
# 3. CẤU HÌNH WIFI (HỖ TRỢ CỔNG 8081 VÀ 8089)
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
        printf '%s   [DRY-RUN] Đã gửi cấu hình WiFi SSID='\''%s'\'' tới http://%s:8081 & 8089%s\n' "$C_YELLOW" "$ssid" "$target_ip" "$C_RESET"
        return 0
    fi

    target_ports=""
    if test_r1_tcp_port "$target_ip" 8081 2; then
        target_ports="8081"
    fi
    if test_r1_tcp_port "$target_ip" 8089 2; then
        target_ports="$target_ports 8089"
    fi
    [ -z "$target_ports" ] && target_ports="8081 8089"

    for p in $target_ports; do
        printf '%s>> Đang gửi cấu hình tới http://%s:%s/api/configwifi...%s\n' "$C_CYAN" "$target_ip" "$p" "$C_RESET"
        resp=""
        if command -v curl >/dev/null 2>&1; then
            resp=$(curl -s -m 6 -X POST "http://$target_ip:$p/api/configwifi" \
                 -H "Content-Type: application/json" \
                 -d "$payload" 2>/dev/null || true)
        elif command -v wget >/dev/null 2>&1; then
            resp=$(wget -q -O- --timeout=6 --header="Content-Type: application/json" \
                 --post-data="$payload" "http://$target_ip:$p/api/configwifi" 2>/dev/null || true)
        fi
        if printf '%s' "$resp" | grep -qi 'success.*true'; then
            printf '%s   [OK] Loa đã xác nhận lưu cấu hình WiFi qua cổng %s!%s\n' "$C_GREEN" "$p" "$C_RESET"
            break
        fi
    done
    return 0
}

run_wifi_config() {
    echo ""
    printf '%s=============================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s  CẤU HÌNH WIFI CHO LOA (CHẾ ĐỘ AP 192.168.43.1)%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s=============================================%s\n' "$C_CYAN" "$C_RESET"
    echo " Hướng dẫn chuẩn bị:"
    echo "  1. Loa vừa reset sẽ phát mạng WiFi 'Phicomm_R1_xxxx'."
    echo "  2. Trên Điện thoại / Máy tính: Vào Cài đặt WiFi -> Kết nối 'Phicomm_R1_xxxx'."
    printf '%s=============================================%s\n' "$C_CYAN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        read_r1_input "Nhấn Enter khi đã kết nối WiFi của loa: " "" >/dev/null || true
    fi

    echo ""
    printf '%s>> Đang kiểm tra kết nối tới loa (192.168.43.1:8081 / 8089)...%s\n' "$C_CYAN" "$C_RESET"
    port_8081_open=0
    port_8089_open=0
    if test_r1_tcp_port "192.168.43.1" 8081 2; then
        port_8081_open=1
    fi
    if test_r1_tcp_port "192.168.43.1" 8089 2; then
        port_8089_open=1
    fi

    if [ "$port_8081_open" = "1" ]; then
        printf '%s   [OK] Đã kết nối API loa qua cổng 8081 (AIBoxPlus).%s\n' "$C_GREEN" "$C_RESET"
    elif [ "$port_8089_open" = "1" ]; then
        printf '%s   [OK] Đã kết nối API loa qua cổng 8089 (Daemon gốc).%s\n' "$C_GREEN" "$C_RESET"
    else
        if [ "$R1_DRYRUN" != "1" ]; then
            printf '%s   [CẢNH BÁO] Chưa kết nối được cổng 8081/8089 trên 192.168.43.1.%s\n' "$C_YELLOW" "$C_RESET"
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

    ssid=""
    pass=""
    secure="WPA"

    if [ "$ASSUME_YES" = "1" ] || [ "$R1_DRYRUN" = "1" ]; then
        ssid="MyWiFi"
        pass="12345678"
    else
        scanned_count=0
        scan_file="/tmp/r1_cache/scanned_wifi.txt"
        mkdir -p "/tmp/r1_cache" 2>/dev/null || true
        rm -f "$scan_file" 2>/dev/null || true

        if [ "$port_8081_open" = "1" ]; then
            printf '\n%s>> Đang quét các mạng WiFi xung quanh loa...%s\n' "$C_CYAN" "$C_RESET"
            raw_scan=""
            scan_attempt=1
            while [ "$scan_attempt" -le 3 ]; do
                if command -v curl >/dev/null 2>&1; then
                    raw_scan=$(curl -s -m 4 "http://192.168.43.1:8081/api/getwifilist" 2>/dev/null || true)
                elif command -v wget >/dev/null 2>&1; then
                    raw_scan=$(wget -q -O- --timeout=4 "http://192.168.43.1:8081/api/getwifilist" 2>/dev/null || true)
                fi
                # Nếu đã có dữ liệu mạng (chứa "ssid":)
                case "$raw_scan" in
                    *'"ssid":'*) break ;;
                esac
                sleep 1
                scan_attempt=$((scan_attempt + 1))
            done

            if [ -n "$raw_scan" ]; then
                py_cmd=$(find_python)
                if [ -n "$py_cmd" ]; then
                    "$py_cmd" -c '
import sys, json
try:
    data = json.loads(sys.argv[1])
    nets = data.get("networks", [])
    seen = set()
    uniq = []
    for n in nets:
        s = (n.get("ssid") or "").strip()
        if s and s not in seen:
            seen.add(s)
            uniq.append((s, n.get("level", -100), bool(n.get("is_secure", True))))
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        for s, lvl, sec in uniq[:15]:
            f.write(f"{s}\t{lvl}\t{sec}\n")
except Exception:
    pass
' "$raw_scan" "$scan_file" 2>/dev/null || true
                fi

                # Fallback AWK thuần POSIX nếu máy không có Python hoặc Python chưa ghi được file
                if [ ! -s "$scan_file" ] && command -v awk >/dev/null 2>&1; then
                    printf '%s\n' "$raw_scan" | awk -F'"ssid":"' '
{
    for (i = 2; i <= NF; i++) {
        split($i, a, "\"");
        s = a[1];
        if (s == "") continue;
        lvl = -100;
        if (match($i, /"level":-?[0-9]+/)) {
            substr_lvl = substr($i, RSTART, RLENGTH);
            split(substr_lvl, b, ":");
            lvl = b[2] + 0;
        }
        sec = "True";
        if (match($i, /"is_secure":(true|false)/)) {
            substr_sec = substr($i, RSTART, RLENGTH);
            split(substr_sec, c, ":");
            if (c[2] == "false") sec = "False";
        }
        if (!(s in seen)) {
            seen[s] = 1;
            order[++count] = s;
            levels[s] = lvl;
            secures[s] = sec;
        } else if (lvl > levels[s]) {
            levels[s] = lvl;
        }
    }
}
END {
    for (j = 1; j <= count && j <= 15; j++) {
        name = order[j];
        print name "\t" levels[name] "\t" secures[name];
    }
}
' > "$scan_file" 2>/dev/null || true
                fi
            fi
        fi

        if [ -s "$scan_file" ]; then
            scanned_count=$(wc -l < "$scan_file" | tr -d ' ')
            printf '%s>> Tìm thấy %s mạng WiFi xung quanh loa:%s\n' "$C_GREEN" "$scanned_count" "$C_RESET"
            printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
            idx=1
            while IFS="$(printf '\t')" read -r net_ssid net_level net_sec || [ -n "$net_ssid" ]; do
                [ -z "$net_ssid" ] && continue
                sec_text="Khóa"
                [ "$net_sec" = "False" ] && sec_text="Mở"
                printf '  [%2d] %-28s (%s dBm) [%s]\n' "$idx" "$net_ssid" "$net_level" "$sec_text"
                idx=$((idx + 1))
            done < "$scan_file"
            printf '  [ 0] Nhập tên WiFi thủ công (nếu WiFi bị ẩn)\n'
            printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"

            pick=$(read_r1_input ">> Chọn số thứ tự WiFi (1-$scanned_count) hoặc 0 để tự nhập [Mặc định: 1]: " "1")
            pick=$(printf '%s' "$pick" | tr -d ' ')
            if [ "$pick" -ge 1 ] 2>/dev/null && [ "$pick" -le "$scanned_count" ] 2>/dev/null; then
                line_picked=$(sed -n "${pick}p" "$scan_file")
                ssid=$(printf '%s' "$line_picked" | cut -f1)
                sec_val=$(printf '%s' "$line_picked" | cut -f3)
                if [ "$sec_val" = "False" ]; then
                    secure="INSECURE"
                else
                    secure="WPA"
                fi
                printf '%s   -> Đã chọn mạng: %s (%s)%s\n' "$C_GREEN" "$ssid" "$secure" "$C_RESET"
            fi
        fi

        while [ -z "$ssid" ]; do
            echo ""
            echo "Nhập thông tin mạng WiFi nhà để loa kết nối:"
            printf '%s----------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
            ssid=$(read_r1_input ">> Tên WiFi nhà (SSID, phân biệt HOA/thường): " "")
            if [ -z "$ssid" ]; then
                printf '%s   [!] Tên WiFi không được để trống!%s\n' "$C_YELLOW" "$C_RESET"
            fi
        done

        if [ "$secure" = "INSECURE" ]; then
            echo "   -> Mạng không có mật khẩu (INSECURE)"
            pass=""
        else
            pass=$(read_r1_input ">> Mật khẩu WiFi (nhấn Enter nếu WiFi không có pass): " "")
            if [ -z "$pass" ]; then
                secure="INSECURE"
                echo "   -> Chế độ WiFi không mật khẩu (INSECURE)"
            else
                pass_len=$(printf '%s' "$pass" | wc -c)
                if [ "$pass_len" -lt 8 ]; then
                    printf '%s   [!] CẢNH BÁO: Mật khẩu WiFi thông thường từ 8 ký tự trở lên!%s\n' "$C_YELLOW" "$C_RESET"
                fi
            fi
        fi
    fi

    echo ""
    send_wifi_config "192.168.43.1" "$ssid" "$pass" "$secure"

    echo ""
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s            ĐÃ GỬI CẤU HÌNH WIFI CHO LOA!                 %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
    echo " THÔNG BÁO QUAN TRỌNG:"
    printf '  1. Loa đang chuyển sang kết nối WiFi '\''%s'\''.\n' "$ssid"
    printf '  2. Hãy chuyển Điện thoại / Máy tính về lại mạng WiFi nhà '\''%s'\''.\n' "$ssid"
    echo "  3. Chờ loa khởi động lại và nhận IP mới (khoảng 15-20s)."
    printf '%s  4. Sau đó bạn có thể chọn mục [4] trong menu để quét tìm IP mới của loa.%s\n' "$C_CYAN" "$C_RESET"
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        read_r1_input "Nhấn Enter để quay lại menu chính" "" >/dev/null || true
    fi
    return 0
}
# ------------------------------------------------------------------------------
# 4. DÒ MẠNG & QUÉT TÌM IP LOA (CỔNG 5555 / 8080)
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
    for port in (5555, 8080, 8081):
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

    # Xác thực thông tin thiết bị qua ADB getprop
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
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    printf '%s         TÌM KIẾM LOA PHICOMM R1             %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    printf '  Mạng: %s.0/24\n' "$sub"
    printf '%s  Thời gian: khoảng 15-30 giây...%s\n' "$C_GRAY" "$C_RESET"
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
        printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        printf '%s              KẾT QUẢ TÌM KIẾM               %s\n' "$C_YELLOW" "$C_RESET"
        printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        printf '%s  Tìm thấy: %s loa Phicomm R1%s\n\n' "$C_GREEN" "$TOTAL_FOUND" "$C_RESET"
        d_idx=1
        while IFS='|' read -r s_ip s_ports h_name m_name a_ver || [ -n "$s_ip" ]; do
            s_ip=$(printf '%s' "$s_ip" | tr -d ' \r\n')
            [ -z "$s_ip" ] && continue
            printf '%s  [%d] Loa Phicomm R1%s\n' "$d_idx" "$C_RESET"
            printf '%s      IP:       %s%s\n' "$C_YELLOW" "$s_ip" "$C_RESET"
            [ -n "$h_name" ] && printf '      Hostname: %s\n' "$h_name"
            [ -n "$m_name" ] && printf '      Model:    %s\n' "$m_name"
            [ -n "$a_ver" ] && printf '      Android:  %s\n' "$a_ver"
            echo ""
            d_idx=$((d_idx + 1))
        done < "$scan_tmp/result.txt"

        if [ -s "$scan_tmp/other.txt" ]; then
            other_cnt=$(grep -c '[0-9]' "$scan_tmp/other.txt" 2>/dev/null || echo 0)
            printf '%s  Thiết bị khác có ADB (%s):%s\n' "$C_YELLOW" "$other_cnt" "$C_RESET"
            while IFS='|' read -r o_ip o_model || [ -n "$o_ip" ]; do
                printf '%s    - %s (%s)%s\n' "$C_GRAY" "$o_ip" "$o_model" "$C_RESET"
            done < "$scan_tmp/other.txt"
            echo ""
        fi

        printf '%s---------------------------------------------%s\n' "$C_GRAY" "$C_RESET"
        printf '%s  Quét hoàn tất!%s\n' "$C_GREEN" "$C_RESET"
        printf '%s---------------------------------------------%s\n' "$C_GRAY" "$C_RESET"
    else
        echo ""
        printf '%s  Không tìm thấy loa Phicomm R1 trong mạng.%s\n' "$C_YELLOW" "$C_RESET"
    fi
}

# ------------------------------------------------------------------------------
# 5. CHUẨN BỊ FILE APK DUY NHẤT (AIBOXPLUS ALL-IN-ONE)
# ------------------------------------------------------------------------------
get_local_ai_apk() {
    for check_dir in "$SCRIPT_DIR" "." "$HOME" "/tmp"; do
        [ -n "$check_dir" ] && [ -d "$check_dir" ] || continue

        # 1. Tìm bản có phiên bản theo dạng ai-box-plus-X-Y-Z.apk
        best_file=""
        for f in "$check_dir"/ai-box-plus-*-*-*.apk; do
            [ -f "$f" ] || continue
            best_file="$f"
        done
        if [ -n "$best_file" ]; then
            echo "$best_file"
            return 0
        fi

        # 2. Tìm bất kỳ file apk nào có tên bắt đầu bằng ai-box hoặc aiboxplus
        for f in "$check_dir"/[aA][iI]-[bB][oO][xX]*.apk "$check_dir"/[aA][iI][bB][oO][xX]*.apk; do
            if [ -f "$f" ]; then
                echo "$f"
                return 0
            fi
        done
    done

    return 1
}

ensure_apk() {
    target_apk_name="ai-box-plus-app.apk"
    cache_file="$CACHE_DIR/$target_apk_name"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true

    # 1. Ưu tiên kiểm tra file đã tải sẵn trong CACHE (đã tải ở Bước 1 của Cài đặt AP Mode hoặc lần chạy trước)
    if [ -f "$cache_file" ] && [ "$(wc -c < "$cache_file" 2>/dev/null || echo 0)" -ge 1000000 ]; then
        apk_bytes=$(wc -c < "$cache_file" 2>/dev/null | tr -d ' ')
        apk_mb=$((apk_bytes / 1048576))
        printf '%s>> [CACHE] Đã có sẵn file APK đã tải: %s (~%s MB). Bỏ qua bước tải lại!%s\n' "$C_GREEN" "$target_apk_name" "$apk_mb" "$C_RESET"
        return 0
    fi

    # 2. Ưu tiên tìm file local trước
    local_ai=$(get_local_ai_apk)
    if [ -n "$local_ai" ] && [ -f "$local_ai" ]; then
        printf '%s>> [LOCAL] Đã tìm thấy file APK cục bộ: %s%s\n' "$C_GREEN" "$(basename "$local_ai")" "$C_RESET"
        if [ "$local_ai" != "$cache_file" ]; then
            cp -f "$local_ai" "$cache_file"
        fi
        return 0
    fi

    # 3. Nếu local và cache đều chưa có, tìm và tải trên server
    printf '%s>> [ONLINE] Đang kiểm tra phiên bản mới nhất từ máy chủ (%s/version.json)...%s\n' "$C_CYAN" "$BASE_URL" "$C_RESET"

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
        printf '%s>> [LỖI] Không tìm thấy file APK cục bộ và không thể tải APK từ máy chủ.%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null || true
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
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null || true
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 6. THỰC THI LỆNH ADB CÀI ĐẶT
# ------------------------------------------------------------------------------
invoke_adb_install_step() {
    require_success="$1"
    shift

    output=$(adb "$@" 2>&1)
    exit_code=$?
    pkg_failed=0
    if [ "$require_success" = "1" ]; then
        case "$output" in
            *Success*) pkg_failed=0 ;;
            *)
                if printf '%s\n' "$output" | grep -qi "success"; then
                    pkg_failed=0
                else
                    pkg_failed=1
                fi
                ;;
        esac
    fi

    # Xử lý khi rớt stream ADB (iSH / WiFi AP timeout khi chạy dex2oat 30-45s)
    if [ "$exit_code" -ne 0 ] || [ "$pkg_failed" -ne 0 ]; then
        if [ "$require_success" = "1" ]; then
            chk_try=1
            while [ "$chk_try" -le 10 ]; do
                sleep 3
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
# 7. KẾT NỐI ADB CHẮC CHẮN VÀ TỰ ĐỘNG ĐÁNH THỨC CỔNG 5555
# ------------------------------------------------------------------------------
robust_adb_connect() {
    serial="$1"
    tip="$2"

    [ "$R1_DRYRUN" = "1" ] && return 0

    adb start-server >/dev/null 2>&1 || true

    # Bước 1: Thử nhanh nếu cổng 5555 đã mở sẵn
    if test_r1_tcp_port "$tip" 5555 1; then
        adb disconnect "$serial" >/dev/null 2>&1 || true
        adb connect "$serial" >/dev/null 2>&1 || true
        sleep 0.5
        state=$(adb -s "$serial" get-state 2>/dev/null | tr -d ' \r\n')
        if [ "$state" = "device" ]; then
            if adb -s "$serial" shell echo 1 >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi

    # Bước 2: Cổng 5555 chưa mở -> Đánh thức qua WebSocket cổng 8080
    printf '%s>> Cổng ADB 5555 chưa mở. Đang kích hoạt ADB qua WebSocket 8080...%s\n' "$C_YELLOW" "$C_RESET"
    revive_speaker "$tip"
    sleep 2

    # Bước 3: Vòng lặp chờ cổng 5555 sẵn sàng và kết nối
    try=1
    while [ "$try" -le 8 ]; do
        if test_r1_tcp_port "$tip" 5555 1; then
            adb disconnect "$serial" >/dev/null 2>&1 || true
            adb connect "$serial" >/dev/null 2>&1 || true
            sleep 0.5
            state=$(adb -s "$serial" get-state 2>/dev/null | tr -d ' \r\n')
            if [ "$state" = "device" ]; then
                if adb -s "$serial" shell echo 1 >/dev/null 2>&1; then
                    return 0
                fi
            fi
        fi
        sleep 1
        try=$((try + 1))
    done

    return 1
}

# ------------------------------------------------------------------------------
# 8. HÀM THỰC THI NẠP APK (DO_EXECUTE_INSTALL)
# ------------------------------------------------------------------------------
do_execute_install() {
    target_ip="$1"
    clean_mode="$2"   # 1 = Clean Install, 0 = Update

    target_ip=$(printf '%s' "$target_ip" | tr -d '[:space:]')
    case "$target_ip" in
        *:5555) target_ip="${target_ip%:5555}" ;;
    esac
    SERIAL="$target_ip:5555"

    mode_title="CẬP NHẬT / NÂNG CẤP (GIỮ DỮ LIỆU)"
    if [ "$clean_mode" = "1" ]; then
        mode_title="CÀI ĐẶT MỚI HOÀN TOÀN (CLEAN INSTALL)"
    fi

    echo ""
    printf '%s=============================================%s\n' "$C_CYAN" "$C_RESET"
    printf '%s  BẮT ĐẦU: %s%s\n' "$C_YELLOW" "$mode_title" "$C_RESET"
    printf '%s  Mục tiêu: %s%s\n' "$C_CYAN" "$SERIAL" "$C_RESET"
    printf '%s=============================================%s\n' "$C_CYAN" "$C_RESET"

    if ! ensure_adb; then return 1; fi

    set_r1_install_progress 15 "Đang chuẩn bị file APK AIBoxPlus"
    if ! ensure_apk; then
        complete_r1_install_progress
        return 1
    fi

    set_r1_install_progress 30 "Đang kết nối ADB tới $SERIAL"
    if ! robust_adb_connect "$SERIAL" "$target_ip"; then
        complete_r1_install_progress
        echo ""
        printf '%s=============================================%s\n' "$C_RED" "$C_RESET"
        printf '%s  [LỖI] KẾT NỐI THẤT BẠI TỚI LOA TẠI %s%s\n' "$C_RED" "$SERIAL" "$C_RESET"
        printf '%s=============================================%s\n' "$C_RED" "$C_RESET"
        printf '%sVui lòng kiểm tra:%s\n' "$C_YELLOW" "$C_RESET"
        echo " 1. Loa đã cắm nguồn và đang bật."
        echo " 2. Máy tính/Điện thoại đang kết nối ĐÚNG mạng (WiFi AP hoặc WiFi nhà)."
        echo " 3. Địa chỉ IP của loa ($target_ip) đã chính xác."
        printf '%s=============================================%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null || true
        return 1
    fi

    set_r1_install_progress 45 "Đang cấu hình quyền cài đặt hệ thống"
    adb -s "$SERIAL" shell settings put secure install_non_market_apps 1 >/dev/null 2>&1 || true

    if [ "$clean_mode" = "1" ]; then
        set_r1_install_progress 50 "Đang dọn dẹp hệ thống và ứng dụng rác"
        adb -s "$SERIAL" shell rm /sdcard/otaprop.txt >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell rm /sdcard/incremental\*.zip >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm clear com.phicomm.speaker.otaservice >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell "rm -rf /data/local/tmp/* 2>/dev/null" >/dev/null 2>&1 || true

        # Ẩn các app rác gây crash / xung đột mic
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.airskill >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.exceptionreporter >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.systemtool >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.device >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.otaservice >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.productiontest >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm hide com.phicomm.speaker.bugreport >/dev/null 2>&1 || true

        # Gỡ sạch các app cũ nếu còn sót lại (AutoDLNA và Unisound cũ)
        adb -s "$SERIAL" shell "am force-stop com.phicomm.speaker.player 2>/dev/null; /system/bin/pm uninstall com.phicomm.speaker.player 2>/dev/null; /system/bin/pm uninstall --user 0 com.phicomm.speaker.player 2>/dev/null" >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell "am force-stop com.phicomm.speaker.device 2>/dev/null; /system/bin/pm uninstall com.phicomm.speaker.device 2>/dev/null; /system/bin/pm uninstall --user 0 com.phicomm.speaker.device 2>/dev/null" >/dev/null 2>&1 || true

        # Đảm bảo dịch vụ hệ thống cần thiết hoạt động
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.ijetty >/dev/null 2>&1 || true
        adb -s "$SERIAL" shell /system/bin/pm unhide com.phicomm.speaker.netctl >/dev/null 2>&1 || true

        set_r1_install_progress 60 "Đang gỡ bỏ bản AI cũ"
        adb -s "$SERIAL" shell /system/bin/pm uninstall info.dourok.voicebot >/dev/null 2>&1 || true
    fi

    # Đẩy APK vào /data/local/tmp
    local_apk="$CACHE_DIR/ai-box-plus-app.apk"
    remote_apk="/data/local/tmp/ai-box-plus-app.apk"

    set_r1_install_progress 70 "Đang truyền file APK vào loa"
    if ! invoke_adb_install_step 0 -s "$SERIAL" push "$local_apk" "$remote_apk"; then
        complete_r1_install_progress
        printf '%s>> [LỖI] Không thể truyền file APK lên loa tại %s.%s\n' "$C_RED" "$SERIAL" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null || true
        return 1
    fi

    set_r1_install_progress 80 "Đang cài đặt APK (pm install -r)..."
    if ! invoke_adb_install_step 1 -s "$SERIAL" shell /system/bin/pm install -r "$remote_apk"; then
        complete_r1_install_progress
        printf '%s>> [LỖI] Cài đặt APK thất bại.%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu: " "" >/dev/null || true
        return 1
    fi
    adb -s "$SERIAL" shell rm "$remote_apk" >/dev/null 2>&1 || true

    set_r1_install_progress 90 "Đang khởi động dịch vụ AI & WebUI (8081)"
    adb -s "$SERIAL" shell "tinymix -D 2 0 5; tinymix -D 2 1 5; tinymix -D 2 6 207; tinymix -D 2 7 207; tinymix -D 2 8 207; tinymix -D 2 9 207; tinymix -D 2 17 1; tinymix -D 2 18 1; tinymix -D 2 46 1; tinymix -D 2 47 1" >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell "settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null" >/dev/null 2>&1 || true

    # Khởi động app bằng nhiều phương thức đồng thời (MainActivity, Broadcast, BootService)
    adb -s "$SERIAL" shell am start -n info.dourok.voicebot/.java.activities.MainActivity >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n info.dourok.voicebot/info.dourok.voicebot.java.activities.MainActivity >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell am broadcast -a info.dourok.voicebot.START >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell am broadcast -a android.intent.action.BOOT_COMPLETED >/dev/null 2>&1 || true
    adb -s "$SERIAL" shell am startservice -n info.dourok.voicebot/info.dourok.voicebot.java.services.BootStartService >/dev/null 2>&1 || true

    # Chờ WebUI cổng 8081 sẵn sàng (thử tối đa 10 giây)
    w_try=1
    while [ "$w_try" -le 5 ]; do
        sleep 2
        if test_r1_tcp_port "$target_ip" 8081 1; then
            break
        fi
        adb -s "$SERIAL" shell am start -n info.dourok.voicebot/info.dourok.voicebot.java.activities.MainActivity >/dev/null 2>&1 || true
        w_try=$((w_try + 1))
    done

    set_r1_install_progress 100 "Hoàn tất cài đặt!"
    complete_r1_install_progress

    # 1. Trường hợp cài đặt trực tiếp qua WiFi của Loa (AP Mode: 192.168.43.1)
    if [ "$target_ip" = "192.168.43.1" ]; then
        echo ""
        printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
        printf '%s        CÀI ĐẶT THÀNH CÔNG QUA AP MODE!            %s\n' "$C_YELLOW" "$C_RESET"
        printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
        echo ">> Đã cài sạch và kích hoạt AIBoxPlus All-in-One."
        echo ">> Dịch vụ AI & WebUI (8081) của loa đang chạy!"
        echo ""
        printf '%s>> BƯỚC TIẾP THEO: CẤU HÌNH WIFI CHO LOA%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        echo "  1. Giữ nguyên kết nối vào WiFi 'Phicomm_R1_xxxx'."
        echo "  2. Mở trình duyệt (Safari / Chrome), truy cập:"
        printf '%s     👉 http://192.168.43.1:8081%s\n' "$C_GREEN" "$C_RESET"
        echo "  3. Chọn mạng WiFi nhà bạn, nhập mật khẩu và bấm Kết nối."
        echo "  4. Loa sẽ tự kết nối WiFi nhà và tự động thoát AP."
        printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"

        # Thử mở trình duyệt nếu hệ thống có hỗ trợ GUI
        if command -v termux-open-url >/dev/null 2>&1; then
            termux-open-url "http://192.168.43.1:8081" >/dev/null 2>&1 || true
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "http://192.168.43.1:8081" >/dev/null 2>&1 || true
        elif command -v open >/dev/null 2>&1; then
            open "http://192.168.43.1:8081" >/dev/null 2>&1 || true
        fi

        if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
            echo ""
            read_r1_input "Nhấn Enter để quay lại menu chính..." "" >/dev/null || true
        fi
        return 0
    fi

    # 2. Trường hợp cài đặt qua mạng LAN (giữ nguyên hỏi Reboot)
    echo ""
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
    printf '%s                 CÀI ĐẶT THÀNH CÔNG!                      %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"
    if [ "$clean_mode" = "1" ]; then
        echo ">> Đã cài mới hoàn toàn AIBoxPlus All-in-One."
        echo ">> Truy cập Xiaozhi.me để nhập mã kích hoạt 6 số nếu cần."
    else
        echo ">> Đã cập nhật thành công AIBoxPlus (giữ nguyên dữ liệu & token)."
    fi
    printf '%s>> Bảng điều khiển WebUI: http://%s:8081/%s\n' "$C_CYAN" "$target_ip" "$C_RESET"
    printf '%s=============================================%s\n' "$C_GREEN" "$C_RESET"

    if [ "$ASSUME_YES" != "1" ] && [ "$R1_DRYRUN" != "1" ]; then
        echo ""
        rb=$(read_r1_input "Khởi động lại loa ngay bây giờ? [y/N]: " "n")
        case "$(printf '%s' "$rb" | tr '[:upper:]' '[:lower:]')" in
            "y"|"yes")
                adb -s "$SERIAL" reboot >/dev/null 2>&1 || true
                printf '%s>> Đã gửi lệnh khởi động lại loa.%s\n' "$C_GREEN" "$C_RESET"
                ;;
        esac
        echo ""
        read_r1_input "Nhấn Enter để quay lại menu chính..." "" >/dev/null || true
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 9. GIAO DIỆN MENU CHÍNH & CHỌN LOA
# ------------------------------------------------------------------------------
select_target_speaker() {
    TARGET_IP=""
    scan_speaker_ip
    if [ "$TOTAL_FOUND" -gt 0 ]; then
        echo ""
        pick=$(read_r1_input "   Chọn số thứ tự loa (1-$TOTAL_FOUND) hoặc nhập IP khác [Mặc định: 1]: " "1")
        pick=$(printf '%s' "$pick" | tr -d ' ')
        if [ "$pick" -ge 1 ] 2>/dev/null && [ "$pick" -le "$TOTAL_FOUND" ] 2>/dev/null; then
            TARGET_IP=$(sed -n "${pick}p" "$scan_tmp/ips.txt" 2>/dev/null)
        elif printf '%s' "$pick" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; then
            TARGET_IP="$pick"
        else
            TARGET_IP=$(head -n 1 "$scan_tmp/ips.txt" 2>/dev/null)
        fi
    else
        echo ""
        manual=$(read_r1_input "   Không tìm thấy loa tự động. Nhập IP loa thủ công (Enter để quay lại): " "")
        manual=$(printf '%s' "$manual" | tr -d ' ')
        [ -n "$manual" ] && TARGET_IP="$manual"
    fi
    rm -rf "$scan_tmp" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# 8B. CÀI ĐẶT TRỰC TIẾP QUA CHẾ ĐỘ AP MODE (192.168.43.1)
# ------------------------------------------------------------------------------
run_ap_install() {
    echo ""
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    printf '%s   CÀI ĐẶT TRỰC TIẾP QUA WIFI CỦA LOA (AP)   %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    echo ""
    printf '%s>> BƯỚC 1: Tải sẵn file APK trước khi ngắt mạng Internet...%s\n' "$C_CYAN" "$C_RESET"

    if ! ensure_apk; then
        printf '%s>> [LỖI] Không thể tải trước file APK. Vui lòng kiểm tra mạng Internet.%s\n' "$C_RED" "$C_RESET"
        read_r1_input "Nhấn Enter để quay lại menu chính..." "" >/dev/null || true
        return 1
    fi

    echo ""
    printf '%s>> BƯỚC 2: Kết nối thiết bị vào WiFi của Loa R1%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s---------------------------------------------%s\n' "$C_GRAY" "$C_RESET"
    echo "  1. Nếu loa chưa phát WiFi AP:"
    echo "     -> Nhấn giữ nút [||] (Play/Pause) trên đỉnh loa khoảng 5-6 giây."
    echo "     -> Đèn loa nhấp nháy tím/xanh và phát WiFi: Phicomm_R1_xxxx."
    echo "  2. Trên Điện thoại / Máy tính:"
    echo "     -> Vào Cài đặt WiFi -> Kết nối vào mạng 'Phicomm_R1_xxxx'."
    echo "     -> (Nếu điện thoại hỏi 'WiFi không có internet, giữ kết nối?': Chọn CÓ)."
    printf '%s---------------------------------------------%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    read_r1_input "Nhấn Enter khi ĐÃ KẾT NỐI vào WiFi của Loa: " "" >/dev/null || true

    echo ""
    printf '%s>> Đang kiểm tra kết nối tới loa (192.168.43.1)...%s\n' "$C_CYAN" "$C_RESET"
    ap_ok=0
    ap_try=1
    while [ "$ap_try" -le 5 ]; do
        if test_r1_tcp_port "192.168.43.1" 5555 1 || test_r1_tcp_port "192.168.43.1" 8080 1 || test_r1_tcp_port "192.168.43.1" 8081 1; then
            ap_ok=1
            break
        fi
        sleep 1
        ap_try=$((ap_try + 1))
    done

    if [ "$ap_ok" != "1" ]; then
        printf '%s>> [CẢNH BÁO] Chưa kết nối được IP 192.168.43.1 của loa.%s\n' "$C_YELLOW" "$C_RESET"
        printf '%s   Hãy kiểm tra: Bạn đã kết nối đúng WiFi Phicomm_R1 chưa?%s\n' "$C_GRAY" "$C_RESET"
        cont=$(read_r1_input "   Bạn vẫn muốn thử kết nối và cài đặt? [y/N]: " "n")
        case "$(printf '%s' "$cont" | tr '[:upper:]' '[:lower:]')" in
            "y"|"yes") ;;
            *) return 1 ;;
        esac
    else
        printf '%s   [OK] Đã kết nối thành công tới loa tại 192.168.43.1!%s\n' "$C_GREEN" "$C_RESET"
    fi

    # Thực hiện cài đặt sạch vào IP 192.168.43.1 (Clean Install = 1)
    do_execute_install "192.168.43.1" 1
    return $?
}

show_menu() {
    echo ""
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    printf '%s     BỘ CÀI ĐẶT PHICOMM R1 (AI-BOX PLUS)     %s\n' "$C_YELLOW" "$C_RESET"
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    echo "  1) Cài đặt trực tiếp qua WiFi Loa (AP Mode)"
    printf '%s     -> Tải sẵn APK, kết nối WiFi loa và cài sạch ngay%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  2) Cài đặt mới hoàn toàn (Clean Install qua mạng LAN)"
    printf '%s     -> Gỡ sạch app rác cũ, cài đặt bản mới nhất%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  3) Cập nhật / Nâng cấp (Update qua mạng LAN)"
    printf '%s     -> Nâng cấp app, giữ nguyên cấu hình và token/license%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  4) Cấu hình WiFi cho loa (chế độ AP 192.168.43.1)"
    printf '%s     -> Kết nối loa vào WiFi nhà sau khi reset%s\n' "$C_GRAY" "$C_RESET"
    echo ""
    echo "  5) Quét tìm IP loa Phicomm R1 trong mạng LAN"
    echo "  6) Thoát"
    printf '%s---------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
    CHOICE=$(read_r1_input "Chọn [1-6]: " "6")
    CHOICE=$(printf '%s' "$CHOICE" | tr -d ' ')
    [ -z "$CHOICE" ] && CHOICE="6"
}

# Xử lý tham số dòng lệnh trực tiếp (Automation / Scripts)
if [ -n "$RUN_WIFI_CLI" ]; then
    run_wifi_config
    exit $?
fi

if [ -n "$RUN_SCAN_CLI" ]; then
    scan_speaker_ip
    exit 0
fi

if [ -n "$RUN_CLEAN_CLI" ] && [ -n "$USER_IP" ]; then
    do_execute_install "$USER_IP" 1
    exit $?
fi

if [ -n "$RUN_AIONLY_CLI" ] && [ -n "$USER_IP" ]; then
    do_execute_install "$USER_IP" 0
    exit $?
fi

if [ -n "$USER_IP" ]; then
    do_execute_install "$USER_IP" 0
    exit $?
fi

# Tự động đảm bảo công cụ cần thiết (ADB, Netcat, v.v.) ngay khi khởi chạy
setup_tools

# Vòng lặp Menu chính
while :; do
    show_menu
    case "$CHOICE" in
        1)
            run_ap_install
            ;;
        2)
            select_target_speaker
            if [ -n "$TARGET_IP" ]; then
                do_execute_install "$TARGET_IP" 1
            fi
            ;;
        3)
            select_target_speaker
            if [ -n "$TARGET_IP" ]; then
                do_execute_install "$TARGET_IP" 0
            fi
            ;;
        4)
            run_wifi_config
            ;;
        5)
            scan_speaker_ip
            echo ""
            read_r1_input "   Nhấn Enter để quay lại menu chính: " "" >/dev/null || true
            ;;
        6|q|Q|exit)
            echo "Thoát chương trình."
            break
            ;;
        *)
            printf '%sLựa chọn không hợp lệ. Vui lòng nhập số từ 1 đến 6.%s\n' "$C_YELLOW" "$C_RESET"
            sleep 1
            ;;
    esac
done
