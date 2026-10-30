#!/bin/sh
# ==============================================================================
#  PHICOMM R1 INSTALLER V2 - iPhone (iSH) / macOS / Linux / Android (Termux)
#  Nguon goi cai dat: GitHub (vdt34/vdt34.github.io -> thu muc /r1)
#
#  iPhone (app iSH Shell tren App Store):
#     curl -fsSL https://vdt34.github.io/r1/install.sh -o r1.sh && sh r1.sh
#
#  Dong lenh (khong hoi):
#     sh install.sh full 192.168.43.1 -y
#     sh install.sh update 192.168.1.94 -y
#     sh install.sh multi 192.168.1.94 192.168.1.95 --mode=full -y
#     sh install.sh backup|restore|repair|uninstall|info 192.168.1.94
#     sh install.sh prefetch | verify | scan [192.168.1]
#  Tuy chon: -y/--yes  --dry-run  --offline  --no-backup  --mode=full|update|repair
#            --backup=<thu muc ban sao luu>
#  Bien moi truong: R1_HOME R1_BASE_URL R1_DRYRUN=1 R1_YES=1 R1_CONNECT_TIMEOUT=90
# ==============================================================================

VERSION="2.0.0"
SELF_URL="https://vdt34.github.io/r1/install.sh"
MIRRORS="https://vdt34.github.io/r1 https://raw.githubusercontent.com/vdt34/vdt34.github.io/main/r1 https://github.com/vdt34/vdt34.github.io/releases/latest/download"
[ -n "$R1_BASE_URL" ] && MIRRORS="${R1_BASE_URL%/} $MIRRORS"

R1_HOME="${R1_HOME:-$HOME/.r1_installer}"
CACHE_DIR="$R1_HOME/cache"
LOG_DIR="$R1_HOME/logs"
BACKUP_ROOT="$R1_HOME/backups"

# --- Chay qua "curl | sh": luu script ra file roi chay lai (tranh dut khi doi WiFi) ---
case "$(basename -- "$0" 2>/dev/null)" in
    sh|-sh|bash|-bash|ash|-ash|dash|zsh)
        if [ "$R1_EXEC_LOCAL" != "1" ] && command -v curl >/dev/null 2>&1; then
            mkdir -p "$R1_HOME"
            if curl -fsSL "$SELF_URL" -o "$R1_HOME/install.sh" 2>/dev/null && [ -s "$R1_HOME/install.sh" ]; then
                R1_EXEC_LOCAL=1 exec sh "$R1_HOME/install.sh" "$@" </dev/tty
            fi
        fi
        ;;
esac

SCRIPT_DIR=$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)
mkdir -p "$CACHE_DIR" "$LOG_DIR" "$BACKUP_ROOT"
LOG_FILE="$LOG_DIR/r1_$(date +%Y%m%d_%H%M%S).log"
: > "$LOG_FILE"

AP_IP="192.168.43.1"
REMOTE_TMP="/sdcard/r1_tmp.apk"
DRYRUN="${R1_DRYRUN:-0}"
YES="${R1_YES:-0}"
OFFLINE="${R1_OFFLINE:-0}"
NO_BACKUP="${R1_NO_BACKUP:-0}"
CONNECT_TIMEOUT="${R1_CONNECT_TIMEOUT:-90}"
RUN_MODE="${R1_MODE:-}"
BACKUP_ARG="${R1_BACKUP:-}"
INTERACTIVE=1
SERIAL=""
TARGET_IP=""
MANIFEST=""
PKG_PATH=""

PKG_AIBOX="info.dourok.voicebot"
CONFLICT_PKGS="com.phicomm.speaker.airskill com.phicomm.speaker.otaservice com.phicomm.speaker.exceptionreporter com.phicomm.speaker.systemtool com.phicomm.speaker.productiontest com.phicomm.speaker.bugreport com.phicomm.speaker.remote com.tencent.qqmusic"
CORE_PKGS="com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl info.dourok.voicebot"
MANAGED_PKGS="$CORE_PKGS $CONFLICT_PKGS"

CMD_REVIVE='stop adbd; setprop service.adb.tcp.port 5555; start adbd; svc power stayon true; am force-stop com.phicomm.speaker.airskill; am force-stop com.phicomm.speaker.otaservice'
CMD_CLEAN="svc power stayon true 2>/dev/null; for p in info.dourok.voicebot com.phicomm.speaker.player com.phicomm.speaker.device $CONFLICT_PKGS; do am force-stop \$p 2>/dev/null; done; killall -9 shairport dlna mpd 2>/dev/null; for p in $CONFLICT_PKGS; do pm hide \$p 2>/dev/null; pm disable \$p 2>/dev/null; done; rm -f /sdcard/otaprop.txt /sdcard/incremental*.zip /sdcard/r1_tmp.apk /sdcard/app.apk 2>/dev/null; rm -rf /data/local/tmp/* 2>/dev/null; pm clear com.phicomm.speaker.otaservice 2>/dev/null; settings put secure install_non_market_apps 1 2>/dev/null"
CMD_POST='settings put global bluetooth_on 1 2>/dev/null; service call bluetooth_manager 6 2>/dev/null; setprop persist.sys.r1_led 0 2>/dev/null; lights_test set 7fffff8000 0 2>/dev/null; lights_test set 7fffff0000 ffffff 2>/dev/null'
CMD_START="for p in $CORE_PKGS; do pm unhide \$p 2>/dev/null; pm enable \$p 2>/dev/null; done; am startservice com.phicomm.speaker.player/.EchoService 2>/dev/null; am start -n com.phicomm.speaker.device/.ui.MainActivity 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; $CMD_POST"
CMD_START_AIBOX="pm unhide info.dourok.voicebot 2>/dev/null; pm enable info.dourok.voicebot 2>/dev/null; am start -n info.dourok.voicebot/.java.activities.MainActivity 2>/dev/null; $CMD_POST"
CMD_UNHIDE_STOCK="for p in $CONFLICT_PKGS com.phicomm.speaker.player com.phicomm.speaker.device com.phicomm.speaker.ijetty com.phicomm.speaker.netctl; do pm unhide \$p 2>/dev/null; pm enable \$p 2>/dev/null; done; svc power stayon false 2>/dev/null"

# ------------------------------------------------------------------------------
# 1. TIEN ICH
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    C_OK='\033[32m'; C_WARN='\033[33m'; C_ERR='\033[31m'; C_STEP='\033[36m'; C_HI='\033[1m'; C_END='\033[0m'
else
    C_OK=''; C_WARN=''; C_ERR=''; C_STEP=''; C_HI=''; C_END=''
fi

logf() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG_FILE"; }
log()  { lvl="$1"; shift
    case "$lvl" in OK) c="$C_OK";; WARN) c="$C_WARN";; ERR) c="$C_ERR";; STEP|TITLE) c="$C_STEP";; HI) c="$C_HI";; *) c="";; esac
    printf "%b%s%b\n" "$c" "$*" "$C_END"
    logf "[$lvl] $*"
}
title() { echo ""; echo "=========================================================="; log TITLE "  $*"; echo "=========================================================="; }

read_input() { # $1 prompt, $2 default
    if [ "$INTERACTIVE" != "1" ]; then echo "$2"; return; fi
    printf "%s" "$1" >&2
    _v=""
    if [ -t 0 ]; then read -r _v 2>/dev/null || _v=""
    elif [ -e /dev/tty ]; then read -r _v </dev/tty 2>/dev/null || _v=""
    fi
    _v=$(printf '%s' "$_v" | tr -d '\r\n')
    [ -z "$_v" ] && _v="$2"
    echo "$_v"
}

confirm() { # $1 prompt, $2 default y/n
    [ "$YES" = "1" ] && return 0
    if [ "$INTERACTIVE" != "1" ]; then [ "$2" = "y" ]; return; fi
    _a=$(read_input "$1 (y/n, mac dinh $2): " "$2")
    case "$_a" in y|Y|yes|c|C|co) return 0;; *) return 1;; esac
}

pause_enter() { [ "$INTERACTIVE" = "1" ] && read_input "Nhan Enter de tiep tuc..." "" >/dev/null; }

norm_ip() { # in ra IP hop le hoac rong
    _ip=$(printf '%s' "$1" | tr -d ' \r\n' | sed 's/:5555$//')
    if printf '%s' "$_ip" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        if printf '%s' "$_ip" | awk -F. '{ for(i=1;i<=4;i++) if ($i>255) exit 1 }'; then echo "$_ip"; return; fi
    fi
    echo ""
}

file_size() { wc -c < "$1" 2>/dev/null | tr -d ' \t\r\n'; }

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
    else echo "no-sha256-tool"; fi
}

if timeout 1 true >/dev/null 2>&1; then TIMEOUT_BIN="timeout"; else TIMEOUT_BIN=""; fi

# ------------------------------------------------------------------------------
# 2. CHUAN BI CONG CU (adb, curl, nc)
# ------------------------------------------------------------------------------
ensure_tools() {
    [ "$DRYRUN" = "1" ] && { log WARN ">> [DRY-RUN] Gia lap ADB - khong ket noi loa that."; return 0; }
    NEED=""
    command -v adb  >/dev/null 2>&1 || NEED="$NEED adb"
    command -v curl >/dev/null 2>&1 || NEED="$NEED curl"
    command -v nc   >/dev/null 2>&1 || NEED="$NEED nc"
    [ -z "$NEED" ] && return 0
    log WARN ">> Thieu:$NEED. Dang tu dong cai dat..."
    if command -v apk >/dev/null 2>&1; then          # iSH / Alpine
        apk update >/dev/null 2>&1
        apk add --no-cache android-tools curl netcat-openbsd >/dev/null 2>&1 || apk add --no-cache android-tools curl >/dev/null 2>&1
    elif command -v pkg >/dev/null 2>&1; then        # Termux
        pkg install -y android-tools curl netcat-openbsd >/dev/null 2>&1
    elif command -v apt-get >/dev/null 2>&1; then    # Debian/Ubuntu
        sudo apt-get update -y >/dev/null 2>&1; sudo apt-get install -y adb curl netcat-openbsd >/dev/null 2>&1
    elif command -v brew >/dev/null 2>&1; then       # macOS
        brew install android-platform-tools >/dev/null 2>&1
    fi
    if ! command -v adb >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        log ERR ">> [LOI] Khong cai duoc adb/curl. iSH: chay 'apk add android-tools curl'. macOS: 'brew install android-platform-tools'."
        return 1
    fi
    log OK ">> [OK] Da cai xong cong cu."
}

# ------------------------------------------------------------------------------
# 3. ADB CO TIMEOUT + GIA LAP
# ------------------------------------------------------------------------------
fake_adb() {
    _l="$*"
    case "$_l" in
        connect\ *)            echo "connected to ${_l#connect }";;
        disconnect*)           echo "disconnected";;
        *get-state*)           echo "device";;
        *" push "*)            echo "1 file pushed. 4.1 MB/s";;
        *" pull "*)            eval "_dst=\${$#}"; [ -e "$_dst" ] || echo dryrun > "$_dst"; echo "1 file pulled.";;
        *"pm install"*)        echo "Success";;
        *"pm uninstall"*)      echo "Success";;
        *"pm path "*)          _p=${_l##*pm path }; echo "package:/system/app/$_p/base.apk";;
        *"pm list packages -d"*) echo "package:com.phicomm.speaker.otaservice";;
        *"pm list packages"*)  for p in $MANAGED_PKGS; do echo "package:/system/app/$p/base.apk=$p"; done;;
        *"dumpsys package"*)   echo "    versionCode=4 targetSdk=33";;
        *"ls -ld"*)            echo "drwxr-x--x u0_a45   u0_a45            2026-10-30 10:00 info.dourok.voicebot";;
        *"echo MODEL"*)        printf 'MODEL=R1\nANDROID=5.1.1\nSERIAL=DRYRUN0001\nWIFIIP=192.168.1.94\nMAC=00:11:22:33:44:55\nUID=uid=0(root)\n';;
        *" shell ps")          printf 'u0_a45 1234 1 info.dourok.voicebot\nsystem 999 1 com.phicomm.speaker.player\nsystem 998 1 com.phicomm.speaker.device\n';;
        *"echo 1")             echo "1";;
        *) echo "";;
    esac
}

adb_run() { # $1 = timeout (giay), con lai = tham so adb. In ra output (da bo \r)
    _to="$1"; shift
    logf "ADB> $*"
    if [ "$DRYRUN" = "1" ]; then _o=$(fake_adb "$@")
    elif [ -n "$TIMEOUT_BIN" ]; then _o=$($TIMEOUT_BIN "$_to" adb "$@" 2>&1 </dev/null); [ $? -eq 124 ] && _o="R1_TIMEOUT"
    else _o=$(adb "$@" 2>&1 </dev/null); fi
    _o=$(printf '%s' "$_o" | tr -d '\r')
    logf "<< $(printf '%s' "$_o" | head -c 1500)"
    printf '%s' "$_o"
}

ashell() { adb_run "${2:-60}" -s "$SERIAL" shell "$1"; }

start_adb_server() { [ "$DRYRUN" = "1" ] || adb start-server >/dev/null 2>&1 </dev/null; }

# ------------------------------------------------------------------------------
# 4. TAI FILE / MANIFEST / CHECKSUM
# ------------------------------------------------------------------------------
fetch_url() { # $1 url, $2 dest
    logf "GET $1"
    rm -f "$2.part"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 --connect-timeout 15 -# -o "$2.part" "$1" || { rm -f "$2.part"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2.part" "$1" || { rm -f "$2.part"; return 1; }
    else return 1; fi
    mv -f "$2.part" "$2"
}

fetch_text() { # $1 url -> stdout
    if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 "$1" 2>/dev/null
    else wget -q -O - "$1" 2>/dev/null; fi
}

get_manifest() {
    [ -n "$MANIFEST" ] && [ -f "$MANIFEST" ] && return 0
    _src=""
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/manifest.txt" ]; then
        MANIFEST="$CACHE_DIR/manifest.active"; tr -d '\r' < "$SCRIPT_DIR/manifest.txt" > "$MANIFEST"; _src="thu muc bo cai"
    fi
    if [ -z "$_src" ] && [ "$OFFLINE" != "1" ]; then
        for m in $MIRRORS; do
            _t=$(fetch_text "$m/manifest.txt?t=$(date +%s)")
            if printf '%s' "$_t" | grep -q '|'; then
                printf '%s\n' "$_t" | tr -d '\r' > "$CACHE_DIR/manifest.txt"; _src="$m"; break
            fi
        done
    fi
    if [ -z "$_src" ] && [ -f "$CACHE_DIR/manifest.txt" ]; then _src="cache trong may (offline)"; fi
    if [ -z "$_src" ]; then log ERR ">> [LOI] Khong lay duoc manifest.txt (chua co Internet va chua co cache)."; return 1; fi
    [ -z "$MANIFEST" ] && MANIFEST="$CACHE_DIR/manifest.txt"
    log INFO ">> Manifest: $_src ($(mf_ids | wc -l | tr -d ' ') goi)"
}

mf_ids()   { grep -v '^#' "$MANIFEST" | grep '|' | sort -t'|' -k8,8n | cut -d'|' -f1; }
mf_field() { awk -F'|' -v id="$1" -v n="$2" '$1==id {print $n; exit}' "$MANIFEST"; }
mf_id_by_pkg() { awk -F'|' -v p="$1" '$0 !~ /^#/ && $3==p {print $1; exit}' "$MANIFEST"; }

get_pkg_file() { # $1 id -> PKG_PATH
    PKG_PATH=""
    _f=$(mf_field "$1" 2); _sha=$(mf_field "$1" 5); _d=$(mf_field "$1" 9)
    for c in "$SCRIPT_DIR/$_f" "$CACHE_DIR/$_f"; do
        [ -f "$c" ] || continue
        if [ "$(sha256_of "$c")" = "$_sha" ]; then log OK "   [OK] $_d: checksum dung ($c)"; PKG_PATH="$c"; return 0; fi
        log WARN "   [!] $_f tai $c sai checksum -> bo qua."
    done
    [ "$OFFLINE" = "1" ] && { log ERR "   [LOI] Thieu $_f (che do offline)."; return 1; }
    for m in $MIRRORS; do
        log HI "   -> Tai $_d tu $m ..."
        if fetch_url "$m/$_f" "$CACHE_DIR/$_f.download"; then
            if [ "$(sha256_of "$CACHE_DIR/$_f.download")" = "$_sha" ]; then
                mv -f "$CACHE_DIR/$_f.download" "$CACHE_DIR/$_f"; PKG_PATH="$CACHE_DIR/$_f"
                log OK "   [OK] Da tai va xac minh SHA256 $_f."; return 0
            fi
            log WARN "   [!] Sai checksum khi tai tu $m. Thu nguon khac..."
            rm -f "$CACHE_DIR/$_f.download"
        fi
    done
    log ERR "   [LOI] Khong the tai $_f tu bat ky nguon nao."
    return 1
}

prepare_files() { # $@ = danh sach id
    title "KIEM TRA & CHUAN BI FILE CAI DAT (SHA256)"
    _err=0
    for id in "$@"; do
        get_pkg_file "$id" || _err=1
        [ "$(mf_field "$id" 7)" != "apk" ] && log WARN "   [CANH BAO] $(mf_field "$id" 2) khong phai APK hop le (loai: $(mf_field "$id" 7)) - se bo qua khi cai."
    done
    if [ "$_err" -ne 0 ]; then
        log ERR ">> [LOI] Thieu file cai dat. Neu dang noi WiFi loa (khong co Internet):"
        log WARN "   1. Chuyen ve WiFi nha / bat 4G, chay muc [11] 'Tai truoc' de luu file vao may."
        log WARN "   2. Sau do ket noi WiFi loa va cai (file da co trong cache)."
        return 1
    fi
}

do_prefetch() {
    get_manifest || return 1
    # shellcheck disable=SC2046
    prepare_files $(mf_ids) || return 1
    log OK ">> [OK] Tat ca file da san sang trong cache: $CACHE_DIR"
}

# ------------------------------------------------------------------------------
# 5. KET NOI LOA
# ------------------------------------------------------------------------------
send_revive() { # Gui lenh danh thuc adbd qua WebSocket cong 8080 (mask = 0, khong can python)
    _ip="$1"
    [ "$DRYRUN" = "1" ] || [ -z "$_ip" ] && return 0
    _payload="{\"type\":\"shell\",\"type_id\":\"revive\",\"shell\":\"$CMD_REVIVE\"}"
    _len=${#_payload}
    if [ "$_len" -lt 126 ]; then _hdr="\\201$(printf '\\%03o' $((128 + _len)))\\000\\000\\000\\000"
    else _hdr="\\201\\376$(printf '\\%03o' $((_len / 256)))$(printf '\\%03o' $((_len % 256)))\\000\\000\\000\\000"; fi
    if command -v nc >/dev/null 2>&1; then
        {
            printf 'GET / HTTP/1.1\r\nHost: %s:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' "$_ip"
            sleep 1
            # shellcheck disable=SC2059
            printf "$_hdr"
            printf '%s' "$_payload"
            sleep 1
        } | nc -w 3 "$_ip" 8080 >/dev/null 2>&1
    fi
    logf "Revive -> $_ip"
}

is_ready() {
    [ "$(adb_run 10 -s "$SERIAL" get-state)" = "device" ] && return 0
    [ "$(ashell 'echo 1' 10)" = "1" ] && return 0
    return 1
}

connect_hint() {
    if [ "$1" = "$AP_IP" ]; then
        echo "------------------ HUONG DAN KET NOI WIFI LOA (AP) ------------------"
        echo " 1. TAT 4G/5G (Du lieu di dong) - WiFi loa khong co Internet."
        echo " 2. An giu nut tron tren dinh loa ~6 giay den khi keu bip & doi den."
        echo " 3. Cai dat -> Wi-Fi -> chon Phicomm_R1_xxxx ('Khong co Internet' -> van dung)."
        echo " 4. iPhone: Cai dat -> iSH -> bat 'Mang cuc bo' (Local Network)."
        echo " 5. Quay lai iSH va GIU MAN HINH iSH MO trong luc cai."
        echo "---------------------------------------------------------------------"
    else
        echo " - Dien thoai/may tinh phai cung mang WiFi voi loa ($1)."
        echo " - iPhone: Cai dat -> iSH -> bat 'Mang cuc bo' (Local Network)."
    fi
}

connect_speaker() { # $1 ip, $2 timeout
    TARGET_IP=$(norm_ip "$1")
    [ -z "$TARGET_IP" ] && { log ERR ">> [LOI] IP khong hop le: $1"; return 1; }
    _limit="${2:-$CONNECT_TIMEOUT}"
    SERIAL="$TARGET_IP:5555"
    ensure_tools || return 1
    title "KET NOI DEN LOA R1 ($SERIAL)"
    connect_hint "$TARGET_IP"
    start_adb_server
    log STEP ">> Dang danh thuc loa tai $TARGET_IP (cong 8080)..."
    send_revive "$TARGET_IP"
    _t0=$(date +%s); _try=0
    while true; do
        _try=$((_try + 1))
        _res=$(adb_run 15 connect "$SERIAL")
        if is_ready; then echo ""; log OK ">> [KET NOI THANH CONG] $SERIAL"; return 0; fi
        _el=$(( $(date +%s) - _t0 ))
        printf "\r[*] Dang ket noi %s (lan %d, %ds/%ds)...   " "$SERIAL" "$_try" "$_el" "$_limit"
        if printf '%s' "$_res" | grep -Eq 'already connected|offline|R1_TIMEOUT' || [ $((_try % 3)) -eq 0 ]; then
            adb_run 10 disconnect "$SERIAL" >/dev/null
            send_revive "$TARGET_IP"
        fi
        if [ "$_el" -ge "$_limit" ]; then
            echo ""
            [ "$INTERACTIVE" != "1" ] && { log ERR ">> [LOI] Het ${_limit}s ma khong ket noi duoc $SERIAL."; return 1; }
            _a=$(read_input ">> Chua ket noi duoc. [Enter]=cho tiep, nhap IP moi, hoac 'q' de huy: " "")
            [ "$_a" = "q" ] || [ "$_a" = "Q" ] && return 1
            _n=$(norm_ip "$_a")
            if [ -n "$_n" ]; then TARGET_IP="$_n"; SERIAL="$_n:5555"; log STEP ">> Doi muc tieu sang $SERIAL"; send_revive "$_n"; fi
            _t0=$(date +%s); _try=0
        fi
        sleep 1
    done
}

ensure_connected() {
    is_ready && return 0
    log WARN "   [!] Mat ket noi voi loa - dang ket noi lai..."
    _si="$INTERACTIVE"; INTERACTIVE=0
    connect_speaker "$TARGET_IP" 60; _r=$?
    INTERACTIVE="$_si"
    return $_r
}

# ------------------------------------------------------------------------------
# 6. THONG TIN / SUC KHOE
# ------------------------------------------------------------------------------
load_devinfo() {
    DEVINFO=$(ashell 'echo MODEL=$(getprop ro.product.model); echo ANDROID=$(getprop ro.build.version.release); echo SERIAL=$(getprop ro.serialno); echo WIFIIP=$(getprop dhcp.wlan0.ipaddress); echo MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null); echo UID=$(id)')
    DEV_ID=$(info_get SERIAL); [ -z "$DEV_ID" ] && DEV_ID=$(info_get MAC); [ -z "$DEV_ID" ] && DEV_ID="$TARGET_IP"
    DEV_ID=$(printf '%s' "$DEV_ID" | tr -c 'A-Za-z0-9_.\n-' '_')
}
info_get() { printf '%s\n' "$DEVINFO" | sed -n "s/^$1=//p" | head -n 1; }

show_devinfo() {
    load_devinfo
    log HI "   Model: $(info_get MODEL) | Android: $(info_get ANDROID) | Serial: $(info_get SERIAL)"
    log HI "   MAC: $(info_get MAC) | IP WiFi nha: $(info_get WIFIIP) | Quyen: $(info_get UID | cut -d' ' -f1)"
}

remote_path() { ashell "pm path $1" 30 | sed -n 's/^package://p' | head -n 1; }

remote_vc() {
    [ -z "$(remote_path "$1")" ] && { echo -1; return; }
    _v=$(ashell "dumpsys package $1" 30 | grep -o 'versionCode=[0-9]*' | head -n 1 | cut -d= -f2)
    echo "${_v:-0}"
}

check_health() {
    title "KIEM TRA SUC KHOE LOA"
    sleep 2
    _ps=$(ashell 'ps' 30)
    _dis=$(ashell 'pm list packages -d' 30)
    _ok=0
    for p in $CORE_PKGS; do
        _path=$(remote_path "$p")
        if [ -n "$_path" ]; then
            _st="Da cai"; _lv=OK
            printf '%s\n' "$_dis" | grep -qx "package:$p" && { _st="$_st | BI TAT"; _lv=WARN; }
            if printf '%s' "$_ps" | grep -q "$p"; then _st="$_st | dang chay"; else _st="$_st | khong chay"; fi
        else
            _st="CHUA CAI"; _lv=WARN
            [ "$p" = "$PKG_AIBOX" ] && { _lv=ERR; _ok=1; }
        fi
        log "$_lv" "$(printf '   %-32s %s' "$p" "$_st")"
    done
    log HI "   AI Box Plus versionCode tren loa: $(remote_vc "$PKG_AIBOX")"
    if [ "$DRYRUN" = "1" ] || nc -z -w 2 "$TARGET_IP" 8081 >/dev/null 2>&1; then log OK "   Web Control: http://$TARGET_IP:8081/ [MO]"
    else log WARN "   Web Control: http://$TARGET_IP:8081/ [chua phan hoi - co the can vai giay]"; fi
    return $_ok
}

# ------------------------------------------------------------------------------
# 7. CAI DAT APK AN TOAN
# ------------------------------------------------------------------------------
install_apk() { # $1 file, $2 package, $3 mo ta, $4 kich thuoc -> 0 OK / 1 FAIL
    _f="$1"; _pkg="$2"; _desc="$3"; _sz="${4:-$(file_size "$1")}"
    _a=1
    while [ $_a -le 3 ]; do
        ensure_connected || break
        log INFO "   -> [$_a/3] Chuyen $_desc sang loa ($((_sz / 1048576)) MB)..."
        adb_run 900 -s "$SERIAL" push "$_f" "$REMOTE_TMP" >/dev/null
        _ls=$(ashell "ls -l $REMOTE_TMP" 20)
        if [ "$DRYRUN" != "1" ] && ! printf '%s' "$_ls" | grep -q "[[:space:]]$_sz[[:space:]]"; then
            log WARN "   [!] File tren loa chua du dung luong (mat ket noi?) - thu lai..."
            _a=$((_a + 1)); sleep 2; continue
        fi
        log INFO "   -> Dang cai dat (pm install)..."
        _out=$(ashell "pm install -r $REMOTE_TMP" 600)
        if printf '%s' "$_out" | grep -Eq 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match|INSTALL_FAILED_SHARED_USER_INCOMPATIBLE'; then
            log WARN "   [!] Khac chu ky ban cu -> go ban cu roi cai lai..."
            ashell "pm uninstall $_pkg" 120 >/dev/null
            _out=$(ashell "pm install $REMOTE_TMP" 600)
        elif printf '%s' "$_out" | grep -q 'INSTALL_FAILED_VERSION_DOWNGRADE'; then
            log WARN "   [!] Ban tren loa moi hon -> cai de (downgrade)..."
            _out=$(ashell "pm install -r -d $REMOTE_TMP" 600)
        fi
        if printf '%s' "$_out" | grep -q 'Success'; then
            ashell "rm -f $REMOTE_TMP" 20 >/dev/null
            log OK "   [THANH CONG] Da cai $_desc."
            return 0
        fi
        if [ -z "$_out" ] || printf '%s' "$_out" | grep -Eqi 'R1_TIMEOUT|closed|offline|no devices|not found|protocol fault|broken pipe'; then
            log WARN "   [!] Mat ket noi trong luc cai - se ket noi lai va thu tiep..."
            _a=$((_a + 1)); sleep 2; continue
        fi
        log ERR "   [LOI] $_out"
        break
    done
    ashell "rm -f $REMOTE_TMP; pm unhide $_pkg 2>/dev/null; pm enable $_pkg 2>/dev/null" 30 >/dev/null
    log ERR "   [THAT BAI] Khong cai duoc $_desc (log: $LOG_FILE)"
    return 1
}

install_item() { # $1 id -> RESULT = OK / SKIP / FAIL
    _type=$(mf_field "$1" 7)
    if [ "$_type" != "apk" ]; then
        log WARN "   [BO QUA] $(mf_field "$1" 2) khong phai APK hop le (loai '$_type'). Can thay bang APK day du tren GitHub."
        RESULT="SKIP"; return 0
    fi
    get_pkg_file "$1" >/dev/null 2>&1 || { RESULT="FAIL"; return 1; }
    if install_apk "$PKG_PATH" "$(mf_field "$1" 3)" "$(mf_field "$1" 9)" "$(mf_field "$1" 6)"; then RESULT="OK"; else RESULT="FAIL"; fi
}

# ------------------------------------------------------------------------------
# 8. SAO LUU / KHOI PHUC
# ------------------------------------------------------------------------------
list_backups() { # $1 dev id (tuy chon) -> danh sach thu muc, moi nhat truoc
    _root="$BACKUP_ROOT"; [ -n "$1" ] && _root="$BACKUP_ROOT/$1"
    [ -d "$_root" ] || return 0
    find "$_root" -name backup.txt 2>/dev/null | while read -r f; do d=$(dirname "$f"); echo "$(basename "$d")|$d"; done | sort -r | cut -d'|' -f2
}

do_backup() { # $1 tag -> BACKUP_DIR
    title "SAO LUU TRANG THAI LOA (BACKUP)"
    load_devinfo
    BACKUP_DIR="$BACKUP_ROOT/$DEV_ID/$(date +%Y%m%d-%H%M%S)_${1:-manual}"
    mkdir -p "$BACKUP_DIR/apk" "$BACKUP_DIR/data"
    log STEP ">> Luu thong tin he thong, danh sach goi va trang thai..."
    ashell 'getprop' 30 > "$BACKUP_DIR/getprop.txt"
    ashell 'pm list packages -f' 60 > "$BACKUP_DIR/packages_all.txt"
    ashell 'pm list packages -u' 60 > "$BACKUP_DIR/packages_u.txt"
    ashell 'pm list packages -d' 60 > "$BACKUP_DIR/packages_disabled.txt"
    log STEP ">> Sao luu file APK cua cac goi lien quan..."
    : > "$BACKUP_DIR/apk_paths.txt"
    for p in $MANAGED_PKGS; do
        _rp=$(remote_path "$p"); [ -z "$_rp" ] && continue
        echo "$p|$_rp" >> "$BACKUP_DIR/apk_paths.txt"
        adb_run 600 -s "$SERIAL" pull "$_rp" "$BACKUP_DIR/apk/$p.apk" >/dev/null
        log INFO "$(printf '   %-36s %s' "$p" "$_rp")"
    done
    log STEP ">> Sao luu cau hinh AI Box Plus (shared_prefs)..."
    if ashell "ls -ld /data/data/$PKG_AIBOX" 20 | grep -q "$PKG_AIBOX"; then
        adb_run 120 -s "$SERIAL" pull "/data/data/$PKG_AIBOX/shared_prefs" "$BACKUP_DIR/data" >/dev/null
        _n=$(find "$BACKUP_DIR/data" -name '*.xml' 2>/dev/null | wc -l | tr -d ' ')
        if [ "$_n" -gt 0 ]; then log OK "   [OK] Da luu $_n file cau hinh."; else log WARN "   [!] Khong doc duoc cau hinh (thieu quyen root?) - bo qua."; fi
    else log INFO "   (AI Box Plus chua cai - khong co cau hinh de luu)"; fi
    {
        echo "installer=$VERSION"; echo "date=$(date +%Y-%m-%dT%H:%M:%S)"; echo "tag=${1:-manual}"; echo "ip=$TARGET_IP"
        echo "model=$(info_get MODEL)"; echo "android=$(info_get ANDROID)"; echo "serial=$(info_get SERIAL)"; echo "mac=$(info_get MAC)"
        echo "aibox_version=$(remote_vc "$PKG_AIBOX")"
    } > "$BACKUP_DIR/backup.txt"
    log OK ">> [OK] Da sao luu tai: $BACKUP_DIR"
}

select_backup() { # $1 dev id -> SELECTED_BACKUP
    SELECTED_BACKUP=""
    _list=$(list_backups "$1"); [ -z "$_list" ] && _list=$(list_backups "")
    [ -z "$_list" ] && { log WARN ">> Chua co ban sao luu nao."; return 1; }
    echo ""
    printf '%s\n' "$_list" | awk '{ printf "  [%d] %s\n", NR, $0 }'
    _cnt=$(printf '%s\n' "$_list" | wc -l | tr -d ' ')
    _s=$(read_input "Chon ban sao luu (1-$_cnt, mac dinh 1 = moi nhat): " "1")
    case "$_s" in ''|*[!0-9]*) _s=1;; esac
    [ "$_s" -lt 1 ] || [ "$_s" -gt "$_cnt" ] && _s=1
    SELECTED_BACKUP=$(printf '%s\n' "$_list" | sed -n "${_s}p")
}

pkg_in_list() { grep -Eq "^package:(.*=)?$1\$" "$2" 2>/dev/null; } # $1 pkg, $2 file

do_restore() { # $1 thu muc ban sao luu (tuy chon)
    title "KHOI PHUC TU BAN SAO LUU (RESTORE)"
    _dir="$1"
    if [ -z "$_dir" ]; then load_devinfo; select_backup "$DEV_ID" || return 1; _dir="$SELECTED_BACKUP"; fi
    [ -f "$_dir/backup.txt" ] || { log ERR ">> [LOI] Ban sao luu khong hop le: $_dir"; return 1; }
    log STEP ">> Dung ban sao luu: $_dir"
    confirm "Khoi phuc se thay the ung dung & trang thai hien tai. Tiep tuc?" y || return 1
    tr -d '\r' < "$_dir/packages_all.txt" > "$_dir/.all" 2>/dev/null
    tr -d '\r' < "$_dir/packages_u.txt" > "$_dir/.u" 2>/dev/null
    tr -d '\r' < "$_dir/packages_disabled.txt" > "$_dir/.dis" 2>/dev/null

    log STEP ">> [1/3] Khoi phuc ung dung..."
    for p in $MANAGED_PKGS; do
        _cur=$(remote_path "$p")
        _bp=$(awk -F'|' -v p="$p" '$1==p {print $2; exit}' "$_dir/apk_paths.txt" 2>/dev/null)
        if [ -n "$_bp" ]; then
            case "$_bp" in
                /system/*)
                    case "$_cur" in ""|/system/*) ;; *) log INFO "   $p : go ban cap nhat -> tra ve ban goc /system"; ashell "pm uninstall $p" 120 >/dev/null;; esac ;;
                *)
                    if [ -f "$_dir/apk/$p.apk" ] && [ "$(file_size "$_dir/apk/$p.apk")" -gt 1000 ]; then
                        log INFO "   $p : cai lai ban da sao luu"; install_apk "$_dir/apk/$p.apk" "$p" "$p" >/dev/null
                    fi ;;
            esac
        else
            case "$_cur" in ""|/system/*) ;; *) log INFO "   $p : khong co trong ban sao luu -> go bo"; ashell "pm uninstall $p" 120 >/dev/null;; esac
        fi
    done

    log STEP ">> [2/3] Khoi phuc trang thai bat/tat/an cua ung dung..."
    _cmds=""
    for p in $MANAGED_PKGS; do
        pkg_in_list "$p" "$_dir/.u" || continue
        if ! pkg_in_list "$p" "$_dir/.all"; then _cmds="$_cmds pm hide $p 2>/dev/null;"
        elif pkg_in_list "$p" "$_dir/.dis"; then _cmds="$_cmds pm unhide $p 2>/dev/null; pm disable $p 2>/dev/null;"
        else _cmds="$_cmds pm unhide $p 2>/dev/null; pm enable $p 2>/dev/null;"; fi
    done
    [ -n "$_cmds" ] && ashell "$_cmds" 120 >/dev/null

    log STEP ">> [3/3] Khoi phuc cau hinh AI Box Plus..."
    _own=$(ashell "ls -ld /data/data/$PKG_AIBOX" 20)
    _n=$(find "$_dir/data" -name '*.xml' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$_n" -gt 0 ] && printf '%s' "$_own" | grep -q "$PKG_AIBOX"; then
        _uid=$(printf '%s' "$_own" | awk '{print $2}'); _gid=$(printf '%s' "$_own" | awk '{print $3}')
        _sp="/data/data/$PKG_AIBOX/shared_prefs"
        ashell "am force-stop $PKG_AIBOX; mkdir -p $_sp" 20 >/dev/null
        find "$_dir/data" -name '*.xml' | while read -r x; do adb_run 60 -s "$SERIAL" push "$x" "$_sp/$(basename "$x")" >/dev/null; done
        ashell "chown -R $_uid:$_gid $_sp; chmod 771 $_sp; chmod 660 $_sp/*" 20 >/dev/null
        log OK "   [OK] Da khoi phuc $_n file cau hinh."
    else log INFO "   (Khong co cau hinh can khoi phuc)"; fi
    rm -f "$_dir/.all" "$_dir/.u" "$_dir/.dis"
    log OK ">> [OK] Khoi phuc xong. Nen khoi dong lai loa."
    confirm "Khoi dong lai loa ngay?" n && adb_run 20 -s "$SERIAL" reboot >/dev/null
    return 0
}

# ------------------------------------------------------------------------------
# 9. QUY TRINH CHINH
# ------------------------------------------------------------------------------
do_full() { # $1 ip
    title "CAI DAT DAY DU PHICOMM R1"
    get_manifest || return 1
    # shellcheck disable=SC2046
    prepare_files $(mf_ids) || return 1
    connect_speaker "$1" || return 1
    show_devinfo
    if [ "$NO_BACKUP" != "1" ]; then
        if [ -z "$(list_backups "$DEV_ID")" ]; then
            log STEP ">> [AN TOAN] Loa nay chua co ban sao luu - tu dong sao luu trang thai goc truoc khi cai..."
            do_backup goc
        else log OK ">> [AN TOAN] Da co ban sao luu cho loa nay (giu nguyen ban goc)."; fi
    fi
    _ids=$(mf_ids); _total=$(( $(printf '%s\n' "$_ids" | wc -l) + 2 )); _step=1
    log STEP ">> [$_step/$_total] Tat tien trinh chiem quyen, xung dot am thanh & micro..."
    ashell "$CMD_CLEAN" 120 >/dev/null
    log OK "   [OK] Da giai phong am thanh, micro va cong mang."
    _summary=""; _fail=0
    for id in $_ids; do
        _step=$((_step + 1))
        log STEP ">> [$_step/$_total] $(mf_field "$id" 9)..."
        install_item "$id"
        [ "$RESULT" = "FAIL" ] && _fail=1
        _summary="$_summary$(printf '   %-42s %s' "$(mf_field "$id" 9)" "$RESULT")
"
    done
    _step=$((_step + 1))
    log STEP ">> [$_step/$_total] Mo khoa & khoi chay dich vu..."
    ashell "$CMD_START" 120 >/dev/null
    check_health; _h=$?
    title "KET QUA CAI DAT"
    printf '%s' "$_summary"
    if [ "$_fail" -eq 0 ] && [ "$_h" -eq 0 ]; then log OK ">> [HOAN TAT] CAI DAT LOA PHICOMM R1 THANH CONG!"
    else log ERR ">> [CHUA HOAN TAT] Co loi - thu muc [7] Sua loi (Repair) hoac xem log."; fi
    log INFO "   Log: $LOG_FILE"
    if [ "$TARGET_IP" = "$AP_IP" ]; then
        log HI ">>> CAU HINH WIFI NHA CHO LOA: mo Safari -> http://192.168.43.1:8081/wifi.html"
        log HI "    chon WiFi nha, nhap mat khau -> loa se phat thong bao. Sau do doi dien thoai ve WiFi nha."
    else log HI ">>> Giao dien dieu khien: http://$TARGET_IP:8081/"; fi
    [ "$_fail" -eq 0 ] && [ "$_h" -eq 0 ]
}

do_update() { # $1 ip
    title "CAP NHAT AI BOX PLUS (GIU NGUYEN CAU HINH)"
    get_manifest || return 1
    _id=$(mf_id_by_pkg "$PKG_AIBOX"); [ -z "$_id" ] && { log ERR ">> [LOI] Manifest khong co AI Box Plus."; return 1; }
    prepare_files "$_id" || return 1
    connect_speaker "$1" || return 1
    _cur=$(remote_vc "$PKG_AIBOX"); _new=$(mf_field "$_id" 4)
    log HI ">> Phien ban tren loa: $_cur | Phien ban tren GitHub: $_new"
    if [ "$_cur" -gt 0 ] && [ "$_new" -gt 0 ] && [ "$_cur" -ge "$_new" ]; then
        confirm "Loa da co ban moi nhat. Van cai lai?" n || return 0
    fi
    log STEP ">> [1/3] Dung tien trinh cu & chan app xung dot..."
    ashell "am force-stop $PKG_AIBOX 2>/dev/null; for p in $CONFLICT_PKGS; do pm hide \$p 2>/dev/null; pm disable \$p 2>/dev/null; done; rm -rf /data/local/tmp/* 2>/dev/null" 60 >/dev/null
    log STEP ">> [2/3] Cai dat ban moi..."
    install_item "$_id"
    log STEP ">> [3/3] Khoi chay AI Box Plus..."
    ashell "$CMD_START_AIBOX" 60 >/dev/null
    if [ "$RESULT" = "OK" ]; then log OK ">> [HOAN TAT] Cap nhat thanh cong ($_cur -> $(remote_vc "$PKG_AIBOX")). Cau hinh cu duoc giu nguyen."
    else log ERR ">> [THAT BAI] Cap nhat khong thanh cong."; fi
    log HI ">>> Giao dien dieu khien: http://$TARGET_IP:8081/"
    [ "$RESULT" = "OK" ]
}

do_repair() { # $1 ip
    title "SUA LOI (REPAIR)"
    get_manifest; _hasm=$?
    connect_speaker "$1" || return 1
    show_devinfo
    log STEP ">> [1/4] Don file tam, chan app xung dot, bat cai dat ngoai..."
    ashell "$CMD_CLEAN" 120 >/dev/null
    log STEP ">> [2/4] Kiem tra AI Box Plus..."
    RESULT="OK"
    if [ "$_hasm" -eq 0 ]; then
        _id=$(mf_id_by_pkg "$PKG_AIBOX"); _cur=$(remote_vc "$PKG_AIBOX"); _new=$(mf_field "$_id" 4)
        if [ -n "$_id" ] && { [ "$_cur" -lt 0 ] || { [ "$_new" -gt 0 ] && [ "$_cur" -lt "$_new" ]; }; }; then
            log WARN "   AI Box Plus thieu hoac cu (versionCode $_cur) -> cai lai."
            if prepare_files "$_id"; then install_item "$_id"; else RESULT="FAIL"; fi
        else log OK "   [OK] AI Box Plus da cai (versionCode $_cur)."; fi
    else log WARN "   [!] Khong co manifest - bo qua buoc cai lai."; fi
    log STEP ">> [3/4] Mo khoa & khoi dong lai dich vu..."
    ashell "$CMD_START" 120 >/dev/null
    log STEP ">> [4/4] Kiem tra lai..."
    check_health; _h=$?
    if [ "$_h" -eq 0 ] && [ "$RESULT" != "FAIL" ]; then log OK ">> [OK] Sua loi hoan tat."; else log ERR ">> [!] Van con loi - thu Restore hoac cai lai day du."; fi
    confirm "Khoi dong lai loa de ap dung?" n && adb_run 20 -s "$SERIAL" reboot >/dev/null
    [ "$_h" -eq 0 ] && [ "$RESULT" != "FAIL" ]
}

do_uninstall() { # $1 ip
    title "GO CAI DAT / TRA LOA VE TRANG THAI GOC"
    connect_speaker "$1" || return 1
    show_devinfo
    confirm "Go AI Box Plus va mo lai cac ung dung goc Phicomm?" n || return 1
    _oldest=$(list_backups "$DEV_ID" | tail -n 1)
    if [ -n "$_oldest" ] && confirm "Co ban sao luu goc ($_oldest). Khoi phuc tu ban nay (khuyen dung)?" y; then
        ashell "am force-stop $PKG_AIBOX; pm uninstall $PKG_AIBOX" 120 >/dev/null
        do_restore "$_oldest"; return $?
    fi
    log STEP ">> [1/3] Go AI Box Plus..."
    log INFO "   $(ashell "am force-stop $PKG_AIBOX; pm uninstall $PKG_AIBOX" 120)"
    log STEP ">> [2/3] Tra ung dung he thong ve ban goc..."
    for p in com.phicomm.speaker.player com.phicomm.speaker.device; do
        _cur=$(remote_path "$p")
        case "$_cur" in ""|/system/*) ;; *) ashell "pm uninstall $p" 120 >/dev/null; log INFO "   $p -> ban goc";; esac
    done
    log STEP ">> [3/3] Mo lai ung dung goc Phicomm..."
    ashell "$CMD_UNHIDE_STOCK" 120 >/dev/null
    log OK ">> [OK] Da go cai dat."
    confirm "Khoi dong lai loa ngay?" y && adb_run 20 -s "$SERIAL" reboot >/dev/null
    return 0
}

do_info() { connect_speaker "$1" || return 1; title "THONG TIN LOA"; show_devinfo; check_health; }

# ------------------------------------------------------------------------------
# 10. QUET MANG & NHIEU LOA
# ------------------------------------------------------------------------------
detect_subnet() {
    _s=""
    command -v ip >/dev/null 2>&1 && _s=$(ip route 2>/dev/null | grep -oE 'src [0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | cut -d' ' -f2)
    [ -z "$_s" ] && command -v ipconfig >/dev/null 2>&1 && _s=$(ipconfig getifaddr en0 2>/dev/null | cut -d. -f1-3)
    [ -z "$_s" ] && command -v ifconfig >/dev/null 2>&1 && _s=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | cut -d. -f1-3)
    echo "${_s:-192.168.1}"
}

do_scan() { # $1 dai mang (tuy chon) -> FOUND_IPS
    FOUND_IPS=""
    _pre="$1"
    if [ -z "$_pre" ]; then _cur=$(detect_subnet); _pre=$(read_input "Dai mang can quet [mac dinh $_cur]: " "$_cur"); fi
    _pre=$(printf '%s' "$_pre" | cut -d. -f1-3)
    log STEP ">> Dang quet $_pre.1-254 (cong 8080 & 5555)..."
    if [ "$DRYRUN" = "1" ]; then FOUND_IPS="$_pre.94"; log OK "   [+] (gia lap) $_pre.94"; return 0; fi
    command -v nc >/dev/null 2>&1 || { log ERR ">> Can 'nc' de quet (iSH: apk add netcat-openbsd)."; return 1; }
    _tmp="$R1_HOME/scan_$$"; mkdir -p "$_tmp"
    _i=1
    while [ $_i -le 254 ]; do
        _end=$((_i + 24)); [ $_end -gt 254 ] && _end=254
        _j=$_i
        while [ $_j -le $_end ]; do
            ( if nc -z -w 1 "$_pre.$_j" 8080 >/dev/null 2>&1 || nc -z -w 1 "$_pre.$_j" 5555 >/dev/null 2>&1; then : > "$_tmp/$_j"; fi ) &
            _j=$((_j + 1))
        done
        wait
        printf "\r[*] Tien do: %d/254" "$_end"
        _i=$((_end + 1))
    done
    echo ""
    for f in $(ls "$_tmp" 2>/dev/null | sort -n); do FOUND_IPS="$FOUND_IPS $_pre.$f"; log OK "   [+] Phat hien loa R1 tai: $_pre.$f"; done
    rm -rf "$_tmp"
    FOUND_IPS=$(echo $FOUND_IPS)
    [ -z "$FOUND_IPS" ] && { log WARN ">> Khong tim thay loa trong $_pre.x"; return 1; }
    return 0
}

choose_ip() { # -> CHOSEN_IP
    CHOSEN_IP=""
    echo ""
    echo "Nhap IP loa (VD 192.168.1.94). De trong + Enter de tu dong quet."
    CHOSEN_IP=$(norm_ip "$(read_input 'IP loa: ' '')")
    [ -n "$CHOSEN_IP" ] && return 0
    if do_scan ""; then
        _k=0; for x in $FOUND_IPS; do _k=$((_k + 1)); echo "  [$_k] $x"; done
        _s=$(read_input "Chon loa (so thu tu hoac IP, mac dinh 1): " "1")
        case "$_s" in *.*) CHOSEN_IP=$(norm_ip "$_s");; *) CHOSEN_IP=$(printf '%s\n' $FOUND_IPS | sed -n "${_s}p");; esac
    else
        CHOSEN_IP=$(norm_ip "$(read_input 'Nhap IP loa thu cong: ' '')")
    fi
    [ -n "$CHOSEN_IP" ]
}

do_multi() { # $@ danh sach IP
    title "CAI DAT CHO NHIEU LOA"
    _list=""
    for x in "$@"; do for y in $(printf '%s' "$x" | tr ',;' '  '); do _v=$(norm_ip "$y"); [ -n "$_v" ] && _list="$_list $_v"; done; done
    if [ -z "$_list" ] && [ "$INTERACTIVE" = "1" ]; then
        _raw=$(read_input "Nhap danh sach IP (cach nhau dau phay). Enter = quet mang: " "")
        for y in $(printf '%s' "$_raw" | tr ',;' '  '); do _v=$(norm_ip "$y"); [ -n "$_v" ] && _list="$_list $_v"; done
        if [ -z "$_list" ] && do_scan ""; then
            confirm "Cai cho tat ca loa vua tim thay ($FOUND_IPS)?" y && _list="$FOUND_IPS"
        fi
    fi
    _list=$(printf '%s\n' $_list | awk '!seen[$0]++' | tr '\n' ' ')
    [ -z "$(echo $_list)" ] && { log ERR ">> Khong co IP nao."; return 1; }
    case " $_list " in *" $AP_IP "*) log WARN ">> [!] $AP_IP la IP WiFi phat cua loa - che do nhieu loa nen dung qua WiFi nha.";; esac
    _mode="$RUN_MODE"
    if [ -z "$_mode" ]; then
        echo "  [1] Cai day du   [2] Chi cap nhat AI Box   [3] Sua loi"
        case "$(read_input 'Chon che do (mac dinh 1): ' '1')" in 2) _mode=update;; 3) _mode=repair;; *) _mode=full;; esac
    fi
    [ "$_mode" != "repair" ] && { do_prefetch || return 1; }
    _si="$INTERACTIVE"; INTERACTIVE=0
    _rep=""; _bad=0; _n=0; _tot=$(echo $_list | wc -w | tr -d ' ')
    for ip in $_list; do
        _n=$((_n + 1)); title "LOA $_n/$_tot: $ip"
        _t0=$(date +%s)
        case "$_mode" in update) do_update "$ip";; repair) do_repair "$ip";; *) do_full "$ip";; esac
        if [ $? -eq 0 ]; then _kq="THANH CONG"; else _kq="THAT BAI"; _bad=1; fi
        adb_run 10 disconnect "$ip:5555" >/dev/null
        _rep="$_rep$(printf '   %-16s %-8s %-11s %ss' "$ip" "$_mode" "$_kq" "$(( $(date +%s) - _t0 ))")
"
    done
    INTERACTIVE="$_si"
    title "TONG KET NHIEU LOA"
    printf '%s' "$_rep" | tee -a "$LOG_FILE"
    return $_bad
}

# ------------------------------------------------------------------------------
# 11. MENU & DIEM VAO
# ------------------------------------------------------------------------------
banner() {
    echo ""
    echo "=========================================================="
    echo "   PHICOMM R1 INSTALLER V$VERSION - iPhone(iSH)/macOS/Linux"
    echo "   Nguon: github.com/vdt34/vdt34.github.io (thu muc r1)"
    [ "$DRYRUN" = "1" ] && echo "   *** CHE DO GIA LAP (DRY-RUN) ***"
    echo "=========================================================="
}

target_or_ask() { # $1 ip tu dong lenh, $2 mac dinh khi khong tuong tac
    TARGET_ARG=$(norm_ip "$1")
    [ -n "$TARGET_ARG" ] && return 0
    if [ "$INTERACTIVE" != "1" ]; then
        [ -n "$2" ] && { TARGET_ARG="$2"; return 0; }
        log ERR ">> [LOI] Can dia chi IP cua loa."; return 1
    fi
    choose_ip || return 1
    TARGET_ARG="$CHOSEN_IP"
}

run_action() { # $1 action, $2... tham so
    _act="$1"; shift
    case "$_act" in
        full)      target_or_ask "$1" "$AP_IP" && do_full "$TARGET_ARG" ;;
        update)    target_or_ask "$1" && do_update "$TARGET_ARG" ;;
        repair)    target_or_ask "$1" && do_repair "$TARGET_ARG" ;;
        uninstall) target_or_ask "$1" && do_uninstall "$TARGET_ARG" ;;
        info)      target_or_ask "$1" && do_info "$TARGET_ARG" ;;
        backup)    target_or_ask "$1" && connect_speaker "$TARGET_ARG" && do_backup manual ;;
        restore)   target_or_ask "$1" && connect_speaker "$TARGET_ARG" && do_restore "$BACKUP_ARG" ;;
        scan)      do_scan "$1" ;;
        prefetch|verify) do_prefetch ;;
        multi)     do_multi "$@" ;;
        *) log ERR "Thao tac khong hop le: $_act"; return 1 ;;
    esac
}

menu() {
    while true; do
        banner
        echo "  [1]  Cai moi day du qua WiFi loa phat ra (192.168.43.1) [Khuyen dung]"
        echo "  [2]  Cai moi day du qua WiFi nha (nhap IP / tu quet)"
        echo "  [3]  Cap nhat AI Box Plus moi nhat (giu cau hinh)"
        echo "  [4]  Cai / cap nhat cho NHIEU LOA"
        echo "  [5]  Sao luu (Backup) loa"
        echo "  [6]  Khoi phuc (Restore) tu ban sao luu"
        echo "  [7]  Sua loi (Repair)"
        echo "  [8]  Go cai dat / tra ve goc (Uninstall)"
        echo "  [9]  Quet tim loa trong mang"
        echo "  [10] Thong tin & kiem tra suc khoe loa"
        echo "  [11] Tai truoc & kiem tra checksum (lam truoc khi noi WiFi loa)"
        echo "  [0]  Thoat"
        echo "=========================================================="
        _c=$(read_input "Lua chon (mac dinh 1): " "1")
        case "$_c" in
            1)  run_action full "$AP_IP" ;;
            2)  run_action full "" ;;
            3)  run_action update "" ;;
            4)  run_action multi ;;
            5)  run_action backup "" ;;
            6)  run_action restore "" ;;
            7)  run_action repair "" ;;
            8)  run_action uninstall "" ;;
            9)  run_action scan "" ;;
            10) run_action info "" ;;
            11) run_action prefetch ;;
            0|q|Q) echo "Tam biet!"; return 0 ;;
            *) log WARN "Lua chon khong hop le." ;;
        esac
        pause_enter
    done
}

# --- Phan tich tham so ---
ACTION=""
ARGS=""
for a in "$@"; do
    case "$a" in
        -y|--yes)      YES=1 ;;
        --dry-run)     DRYRUN=1 ;;
        --offline)     OFFLINE=1 ;;
        --no-backup)   NO_BACKUP=1 ;;
        --mode=*)      RUN_MODE="${a#--mode=}" ;;
        --backup=*)    BACKUP_ARG="${a#--backup=}" ;;
        -h|--help)     sed -n '2,22p' "$0"; exit 0 ;;
        menu|-m)       ACTION="menu" ;;
        full|update|repair|backup|restore|uninstall|scan|info|prefetch|verify|multi)
                       if [ -z "$ACTION" ]; then ACTION="$a"; else ARGS="$ARGS $a"; fi ;;
        *)             ARGS="$ARGS $a" ;;
    esac
done
# Tuong thich ban cu: "sh install.sh 192.168.1.94" = cai day du toi IP do
if [ -z "$ACTION" ] && [ -n "$(echo $ARGS)" ]; then ACTION="full"; fi
[ -z "$ACTION" ] && ACTION="menu"

logf "=== R1 Installer $VERSION | action=$ACTION | dryrun=$DRYRUN | $(uname -a 2>/dev/null) ==="
if [ "$ACTION" = "menu" ]; then
    INTERACTIVE=1
    menu
    exit 0
fi
INTERACTIVE=0
banner
# shellcheck disable=SC2086
run_action "$ACTION" $ARGS
RC=$?
if [ $RC -eq 0 ]; then log INFO ">> Ket thuc: $ACTION -> OK | Log: $LOG_FILE"; else log ERR ">> Ket thuc: $ACTION -> LOI | Log: $LOG_FILE"; fi
exit $RC
