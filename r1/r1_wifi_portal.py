#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mini Web Portal + API Proxy cho loa Phicomm R1 (chạy trên iPhone/iSH, Linux, macOS)

Phục vụ wifi.html và chuyển tiếp API quét/cài Wi-Fi tới loa (mặc định 192.168.43.1:8989).

Điểm chính:
  - ThreadingHTTPServer, mọi response đều có Content-Length + Connection: close
  - Chỉ dùng thư viện chuẩn, http.client trực tiếp (không đi qua proxy hệ thống)
  - Scan: gọi song song 2 endpoint, trả ngay khi có kết quả hợp lệ đầu tiên;
    gộp các request scan trùng nhau; cache để dự phòng khi loa trả lời chậm
  - Cấu hình Wi-Fi: gửi tới loa và báo kết quả THẬT (ok / loa ngắt AP / bị từ chối / không với tới)
    Chỉ tự tắt server khi đã gửi thành công; lỗi thật thì giữ server để bấm thử lại
  - Chống CSRF/DNS-rebinding: kiểm tra Host + Origin, không bật CORS
  - Watchdog (đồng hồ monotonic) tự thoát khi không ai dùng; /ping để giữ phiên
  - Timeout đọc socket (client gửi thiếu body không làm treo luồng)

Biến môi trường (tuỳ chọn):
  R1_PORT          cổng web (mặc định 8000; bận thì thử cổng kế tiếp)
  R1_TARGET        địa chỉ loa (mặc định http://192.168.43.1:8989)
  R1_HTML          đường dẫn wifi.html (mặc định: cạnh file này)
  R1_SCAN_TIMEOUT  timeout quét Wi-Fi, giây (mặc định 4)
  R1_IDLE          số giây không hoạt động thì tự thoát (mặc định 300)
"""

import sys
import os
import json
import time
import errno
import signal
import socket
import threading
import traceback
import http.client
from urllib.parse import urlsplit
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


# ---------------------------------------------------------------------------
# Cấu hình
# ---------------------------------------------------------------------------
def _env_float(name, default):
    try:
        return float(os.environ.get(name, default))
    except (TypeError, ValueError):
        return float(default)


def _env_int(name, default):
    try:
        return int(os.environ.get(name, default))
    except (TypeError, ValueError):
        return int(default)


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PORT = _env_int("R1_PORT", 8000)
TARGET_AP = os.environ.get("R1_TARGET", "http://192.168.43.1:8989").strip().rstrip("/")
HTML_FILE = os.environ.get("R1_HTML") or os.path.join(SCRIPT_DIR, "wifi.html")
FALLBACK_HTML = "/tmp/r1_cache/wifi.html"

SCAN_TIMEOUT = _env_float("R1_SCAN_TIMEOUT", 4.0)   # mỗi endpoint quét
CONNECT_TIMEOUT = 1.5                               # thời gian chờ nối tới loa
FORWARD_TIMEOUT = 3.0                               # chờ loa trả lời sau khi đã gửi
FORWARD_RETRIES = 2                                 # chỉ retry khi chưa nối được
WATCHDOG_IDLE = _env_float("R1_IDLE", 300.0)
SHUTDOWN_DELAY = 0.8                                # để response kịp gửi xong
STALE_SCAN_MAX_AGE = 120.0                          # tuổi tối đa của cache scan dự phòng
DUP_WINDOW = 30.0                                   # chống bấm đúp "Kết nối"
MAX_BODY = 64 * 1024
MAX_UPSTREAM = 1024 * 1024
UA = "iSH-WifiPortal/2.0"

_t = urlsplit(TARGET_AP if "://" in TARGET_AP else "http://" + TARGET_AP)
if _t.scheme != "http" or not _t.hostname:
    sys.exit("R1_TARGET không hợp lệ (cần dạng http://host:port): %r" % TARGET_AP)
T_HOST = _t.hostname
T_PORT = _t.port or 80
T_BASE = _t.path.rstrip("/")


# ---------------------------------------------------------------------------
# Trạng thái toàn cục
# ---------------------------------------------------------------------------
server_instance = None
_state_lock = threading.Lock()
_last_request_ts = time.monotonic()
_shutdown_started = False

_scan_lock = threading.Lock()
_scan_cache = None                  # {"data": bytes, "ts": float}

_forward_lock = threading.Lock()
_last_ok = None                     # {"body": bytes, "ts": float, "status": str}

_ALLOWED_HOSTS = set()
_ALLOWED_ORIGINS = set()


def _log(msg):
    print(msg, file=sys.stderr)
    sys.stderr.flush()


def _touch():
    global _last_request_ts
    with _state_lock:
        _last_request_ts = time.monotonic()


def schedule_shutdown(delay=SHUTDOWN_DELAY):
    """Hẹn giờ tắt server, chỉ chạy một lần, không block caller."""
    global _shutdown_started
    with _state_lock:
        if _shutdown_started:
            return
        _shutdown_started = True

    def _do():
        time.sleep(delay)
        srv = server_instance
        if srv is not None:
            try:
                srv.shutdown()
            except Exception:
                pass

    threading.Thread(target=_do, daemon=True).start()


def _watchdog():
    while True:
        time.sleep(5.0)
        with _state_lock:
            idle = time.monotonic() - _last_request_ts
        if idle >= WATCHDOG_IDLE:
            print("\n>> Không có hoạt động trong %ds, tự thoát Web Portal." % int(idle))
            sys.stdout.flush()
            schedule_shutdown(0.0)
            return


# ---------------------------------------------------------------------------
# Giao tiếp với loa
# ---------------------------------------------------------------------------
def _speaker_get(path, timeout):
    """GET tới loa. Trả (status, bytes). Ném OSError/HTTPException khi lỗi."""
    conn = http.client.HTTPConnection(T_HOST, T_PORT, timeout=timeout)
    try:
        conn.request("GET", T_BASE + path,
                     headers={"User-Agent": UA, "Accept": "application/json",
                              "Connection": "close"})
        r = conn.getresponse()
        return r.status, r.read(MAX_UPSTREAM)
    finally:
        conn.close()


def _scan_speaker():
    """Gọi song song 2 endpoint, trả bytes JSON hợp lệ đầu tiên (ưu tiên danh sách không rỗng)."""
    paths = ("/api/getwifilist", "/api/wifilist")
    done = threading.Event()
    lock = threading.Lock()
    box = {}
    pending = [len(paths)]

    def worker(path):
        try:
            status, data = _speaker_get(path, SCAN_TIMEOUT)
            if status != 200 or not data:
                _log("[scan:%s] HTTP %s" % (path, status))
            else:
                parsed = json.loads(data.decode("utf-8"))
                with lock:
                    if parsed in ([], {}, None):
                        box.setdefault("weak", data)    # hợp lệ nhưng rỗng: chờ bên kia
                    else:
                        box.setdefault("data", data)
                        done.set()
        except Exception as e:
            _log("[scan:%s] %r" % (path, e))
        finally:
            with lock:
                pending[0] -= 1
                if pending[0] == 0:
                    done.set()

    for p in paths:
        threading.Thread(target=worker, args=(p,), daemon=True).start()

    done.wait(SCAN_TIMEOUT + 0.5)
    with lock:
        return box.get("data") or box.get("weak")


def _forward_config(body):
    """
    Gửi cấu hình tới loa. Trả (status, detail):
      "ok"          loa trả 2xx
      "sent"        đã gửi rồi loa ngắt kết nối/không trả lời (loa ngắt AP ngay -> coi như thành công)
      "rejected"    loa trả HTTP lỗi
      "unreachable" không nối được tới loa (đã retry)
    """
    last_err = None
    for attempt in range(FORWARD_RETRIES):
        conn = http.client.HTTPConnection(T_HOST, T_PORT, timeout=CONNECT_TIMEOUT)
        try:
            try:
                conn.connect()
            except OSError as e:
                last_err = e
                _log("[forward] nối lần %d thất bại: %r" % (attempt + 1, e))
                if attempt + 1 < FORWARD_RETRIES:
                    time.sleep(0.3)
                continue

            # Đã nối được: từ đây mọi ngoại lệ đều nghĩa là "đã gửi, loa có thể đã ngắt AP"
            try:
                conn.sock.settimeout(FORWARD_TIMEOUT)
                conn.request("POST", T_BASE + "/api/configwifi", body=body,
                             headers={"Content-Type": "application/json",
                                      "User-Agent": UA, "Connection": "close"})
                r = conn.getresponse()
                r.read(65536)
                if 200 <= r.status < 300:
                    return "ok", None
                return "rejected", "HTTP %d" % r.status
            except (OSError, http.client.HTTPException) as e:
                return "sent", repr(e)
        finally:
            conn.close()
    return "unreachable", repr(last_err)


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------
class WifiPortalHandler(BaseHTTPRequestHandler):
    timeout = 10                      # timeout đọc/ghi socket: chống treo khi client gửi thiếu
    server_version = "R1Portal"
    sys_version = ""

    def log_message(self, format, *args):
        pass

    # ----- Helpers ---------------------------------------------------------
    def _send_body(self, status, content_type, body, extra_headers=None):
        if not isinstance(body, (bytes, bytearray)):
            body = bytes(body)
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            if extra_headers:
                for k, v in extra_headers.items():
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except (ConnectionError, socket.timeout):
            pass    # client đóng kết nối sớm

    def _json(self, status, obj, extra_headers=None):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self._send_body(status, "application/json; charset=utf-8", body, extra_headers)

    def _guard(self):
        """Chặn trang web lạ gọi vào portal (CSRF / DNS rebinding)."""
        host = (self.headers.get("Host") or "").strip().lower()
        if host and host not in _ALLOWED_HOSTS:
            self._json(403, {"success": False, "message": "Forbidden host"})
            return False
        origin = (self.headers.get("Origin") or "").strip().lower()
        if origin and origin not in _ALLOWED_ORIGINS:
            self._json(403, {"success": False, "message": "Forbidden origin"})
            return False
        return True

    def _read_body(self):
        """Trả (bytes, None) hoặc (None, (status, message))."""
        raw = self.headers.get("Content-Length")
        try:
            n = int(raw) if raw is not None else -1
        except (TypeError, ValueError):
            n = -1
        if n < 0:
            return None, (400, "Thiếu hoặc sai Content-Length")
        if n == 0:
            return None, (400, "Body rỗng")
        if n > MAX_BODY:
            return None, (413, "Body quá lớn")
        data = self.rfile.read(n)
        if len(data) != n:
            return None, (400, "Body không đầy đủ")
        return data, None

    def _safe(self, fn):
        _touch()
        try:
            fn()
        except (ConnectionError, socket.timeout):
            pass
        except Exception:
            _log("[handler] lỗi không mong đợi:\n" + traceback.format_exc())
            self._json(500, {"success": False, "message": "Lỗi nội bộ"})

    # ----- Dispatch --------------------------------------------------------
    def do_OPTIONS(self):
        self._safe(self._options)

    def do_GET(self):
        self._safe(self._get)

    def do_POST(self):
        self._safe(self._post)

    # ----- OPTIONS ---------------------------------------------------------
    def _options(self):
        # Không bật CORS: portal chỉ phục vụ cùng origin
        try:
            self.send_response(204)
            self.send_header("Allow", "GET, POST, OPTIONS")
            self.send_header("Connection", "close")
            self.end_headers()
        except (ConnectionError, socket.timeout):
            pass

    # ----- GET -------------------------------------------------------------
    def _get(self):
        if not self._guard():
            return
        path = self.path.split("?", 1)[0]

        if path in ("/", "/index.html", "/wifi.html"):
            self._serve_html()
        elif path in ("/api/getwifilist", "/api/wifilist", "/scan"):
            self._serve_scan()
        elif path == "/ping":
            self._json(200, {"ok": True})
        elif path == "/favicon.ico":
            try:
                self.send_response(204)
                self.send_header("Connection", "close")
                self.end_headers()
            except (ConnectionError, socket.timeout):
                pass
        else:
            self._send_body(404, "text/plain; charset=utf-8", b"Not Found")

    def _serve_html(self):
        for src in (HTML_FILE, FALLBACK_HTML):
            if src and os.path.isfile(src):
                try:
                    with open(src, "rb") as f:
                        content = f.read()
                except OSError:
                    continue
                self._send_body(200, "text/html; charset=utf-8", content)
                return
        msg = ("<!doctype html><meta charset='utf-8'>"
               "<h2>Không tìm thấy wifi.html</h2>"
               "<p>Đặt wifi.html cạnh file Python hoặc đặt biến R1_HTML.</p>")
        self._send_body(404, "text/html; charset=utf-8", msg.encode("utf-8"))

    def _serve_scan(self):
        global _scan_cache
        t0 = time.monotonic()
        stale = False
        # Gộp các request scan trùng nhau: ai đến sau dùng luôn kết quả của lượt đang chạy
        with _scan_lock:
            cache = _scan_cache
            if cache and cache["ts"] >= t0:
                data = cache["data"]
            else:
                data = _scan_speaker()
                if data:
                    _scan_cache = {"data": data, "ts": time.monotonic()}
                elif cache and time.monotonic() - cache["ts"] <= STALE_SCAN_MAX_AGE:
                    data = cache["data"]
                    stale = True

        if data:
            self._send_body(200, "application/json; charset=utf-8", data,
                            {"X-Scan-Stale": "1"} if stale else None)
        else:
            self._json(502, {"success": False, "error": "speaker_unreachable",
                             "message": "Không lấy được danh sách Wi-Fi từ loa"})

    # ----- POST ------------------------------------------------------------
    def _post(self):
        global _last_ok
        if not self._guard():
            return
        path = self.path.split("?", 1)[0]
        if path not in ("/api/configwifi", "/connect"):
            self._send_body(404, "text/plain; charset=utf-8", b"Not Found")
            return

        body, err = self._read_body()
        if err:
            self._json(err[0], {"success": False, "message": err[1]})
            return

        # Validate (không log mật khẩu)
        try:
            payload = json.loads(body.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            self._json(400, {"success": False, "message": "Body không phải JSON hợp lệ"})
            return
        ssid = payload.get("ssid") if isinstance(payload, dict) else None
        if not isinstance(ssid, str) or not ssid.strip():
            self._json(400, {"success": False, "message": "Thiếu tên Wi-Fi (ssid)"})
            return

        print("\n>> Nhận lệnh cấu hình Wi-Fi: %s" % ssid)
        sys.stdout.flush()

        with _forward_lock:
            prev = _last_ok
            if prev and prev["body"] == body and time.monotonic() - prev["ts"] < DUP_WINDOW:
                status, detail = prev["status"], None       # bấm đúp: không gửi lại
            else:
                status, detail = _forward_config(body)
                if status in ("ok", "sent"):
                    _last_ok = {"body": body, "ts": time.monotonic(), "status": status}

        if status == "ok":
            print(">> Loa đã nhận cấu hình.")
            self._json(200, {"success": True, "message": "OK"})
        elif status == "sent":
            print(">> Đã gửi cấu hình, loa ngắt AP ngay (bình thường).")
            self._json(200, {"success": True, "message": "OK", "note": "speaker_dropped_ap"})
        elif status == "rejected":
            print(">> Loa từ chối cấu hình (%s)." % detail)
            self._json(502, {"success": False,
                             "message": "Loa từ chối cấu hình (%s)" % detail})
        else:
            print(">> KHÔNG nối được tới loa — server vẫn chạy, hãy thử lại.")
            self._json(502, {"success": False,
                             "message": "Không kết nối được tới loa. "
                                        "Hãy kiểm tra iPhone đang nối Wi-Fi của loa rồi thử lại."})
        sys.stdout.flush()

        if status in ("ok", "sent"):
            schedule_shutdown(SHUTDOWN_DELAY)


# ---------------------------------------------------------------------------
# Khởi động
# ---------------------------------------------------------------------------
def _bind_server():
    """Bind 127.0.0.1; cổng bận thì thử 9 cổng kế tiếp. Trả (server, port)."""
    last = None
    for offset in range(10):
        port = PORT + offset
        try:
            return ThreadingHTTPServer(("127.0.0.1", port), WifiPortalHandler), port
        except OSError as e:
            last = e
            if e.errno != errno.EADDRINUSE:
                break
            _log("[bind] cổng %d đang bận, thử cổng kế tiếp..." % port)
    sys.exit("Không mở được cổng web (%r). Thử đặt R1_PORT khác." % (last,))


def run():
    global server_instance

    server_instance, port = _bind_server()
    server_instance.daemon_threads = True

    for h in ("127.0.0.1", "localhost"):
        _ALLOWED_HOSTS.add("%s:%d" % (h, port))
        _ALLOWED_ORIGINS.add("http://%s:%d" % (h, port))

    def _on_term(signum, frame):
        print("\n>> Nhận tín hiệu thoát, đang đóng...")
        sys.stdout.flush()
        schedule_shutdown(0.0)

    for sig in (signal.SIGTERM, getattr(signal, "SIGHUP", None)):
        if sig is not None:
            try:
                signal.signal(sig, _on_term)
            except (ValueError, OSError):
                pass

    threading.Thread(target=_watchdog, daemon=True).start()

    print("==========================================================")
    print("  [OK] ĐÃ MỞ WEB CẤU HÌNH WIFI THÀNH CÔNG!")
    print("  👉 Hãy mở Safari trên iPhone và vào:")
    print("     http://127.0.0.1:%d" % port)
    print("  (Proxy tới loa: %s)" % TARGET_AP)
    print("==========================================================")
    print("  (Đang chờ bạn chọn Wi-Fi và bấm Kết nối trên Safari...)")
    print("  Nhấn Ctrl+C nếu muốn quay lại terminal.")
    sys.stdout.flush()

    try:
        server_instance.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            server_instance.server_close()
        except Exception:
            pass
        print("\n>> Đã hoàn tất và đóng Web Portal.")
        sys.stdout.flush()


if __name__ == "__main__":
    run()
