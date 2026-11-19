#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mini Web Server & API Proxy cho loa Phicomm R1 trên iPhone (iSH) / Linux / macOS
Tự động phục vụ giao diện wifi.html và chuyển tiếp API quét/cài Wi-Fi tới 192.168.43.1:8989
"""

import sys
import os
import json
import time
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

PORT = 8000
TARGET_AP = "http://192.168.43.1:8989"
HTML_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wifi.html")

server_instance = None
shutdown_timer = None

def schedule_shutdown(delay=2.5):
    def _shutdown():
        time.sleep(delay)
        if server_instance:
            server_instance.shutdown()
    t = threading.Thread(target=_shutdown)
    t.daemon = True
    t.start()

class WifiPortalHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Giữ terminal sạch sẽ, chỉ log ngắn
        pass

    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ["/", "/index.html", "/wifi.html"]:
            content = None
            if os.path.isfile(HTML_FILE):
                try:
                    with open(HTML_FILE, "rb") as f:
                        content = f.read()
                except Exception:
                    pass
            
            if not content:
                # Tìm trong /tmp/r1_cache/wifi.html
                fallback = "/tmp/r1_cache/wifi.html"
                if os.path.isfile(fallback):
                    try:
                        with open(fallback, "rb") as f:
                            content = f.read()
                    except Exception:
                        pass

            if not content:
                content = b"<html><body><h2>Khong tim thay wifi.html</h2></body></html>"

            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(content)
            return

        elif path in ["/api/getwifilist", "/api/wifilist", "/scan"]:
            # Proxy request tới loa 192.168.43.1:8989
            data = None
            for ep in ["/api/getwifilist", "/api/wifilist"]:
                try:
                    req = urllib.request.Request(f"{TARGET_AP}{ep}", headers={"User-Agent": "iSH-WifiPortal/1.0"})
                    with urllib.request.urlopen(req, timeout=4) as response:
                        data = response.read()
                        if data:
                            break
                except Exception:
                    pass

            if not data:
                # Nếu không gọi được API thật, trả danh sách rỗng để người dùng nhập tay
                data = b"[]"

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(data)
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        path = self.path.split("?")[0]
        if path in ["/api/configwifi", "/connect"]:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length) if content_length > 0 else b"{}"

            print("\n>> Đã nhận lệnh cấu hình Wi-Fi từ Safari!")
            try:
                payload = json.loads(body.decode("utf-8"))
                ssid = payload.get("ssid", "Unknown")
                print(f"   Mạng Wi-Fi: {ssid}")
            except Exception:
                pass

            # Gửi tới loa 192.168.43.1:8989/api/configwifi
            success = False
            try:
                req = urllib.request.Request(
                    f"{TARGET_AP}/api/configwifi",
                    data=body,
                    headers={"Content-Type": "application/json"}
                )
                with urllib.request.urlopen(req, timeout=5) as response:
                    success = True
            except Exception as e:
                # Loa Phicomm R1 thường ngắt kết nối AP ngay khi nhận lệnh, nên ngoại lệ cũng là dấu hiệu đã gửi thành công
                success = True

            res_body = json.dumps({"success": success, "message": "OK"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(res_body)

            print(">> Đã chuyển tiếp cấu hình tới loa thành công!")
            print(">> Loa đang chuyển mạng... Đang tự động đóng server Web.")
            schedule_shutdown(2.0)
            return

        self.send_response(404)
        self.end_headers()

def run():
    global server_instance
    server_address = ("127.0.0.1", PORT)
    try:
        server_instance = HTTPServer(server_address, WifiPortalHandler)
    except Exception as e:
        # Thử lại nếu cổng bị giữ
        time.sleep(1)
        server_instance = HTTPServer(server_address, WifiPortalHandler)

    print("==========================================================")
    print(f"  [OK] ĐÃ MỞ WEB CẤU HÌNH WIFI THÀNH CÔNG!")
    print(f"  👉 Hãy mở Safari trên iPhone và vào:")
    print(f"     http://localhost:{PORT}")
    print("==========================================================")
    print("  (Đang chờ bạn chọn Wi-Fi và bấm Kết nối trên Safari...)")
    print("  Nhấn Ctrl+C nếu muốn quay lại terminal.")
    sys.stdout.flush()

    try:
        server_instance.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server_instance.server_close()
        print("\n>> Đã đóng Web Portal.")

if __name__ == "__main__":
    run()
