#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mini Web Server & API Proxy siêu tốc cho loa Phicomm R1 trên iPhone (iSH) / Linux / macOS
Phục vụ giao diện wifi.html và chuyển tiếp API quét/cài Wi-Fi tới 192.168.43.1:8989 trong tích tắc
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

def schedule_shutdown(delay=1.0):
    def _shutdown():
        time.sleep(delay)
        if server_instance:
            try:
                server_instance.shutdown()
            except Exception:
                pass
    t = threading.Thread(target=_shutdown)
    t.daemon = True
    t.start()

class WifiPortalHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Tắt log rác HTTP để terminal gọn gàng
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
            # Proxy request quét Wi-Fi với timeout ngắn để không làm đơ Safari
            data = None
            try:
                req = urllib.request.Request(f"{TARGET_AP}/api/getwifilist", headers={"User-Agent": "iSH-WifiPortal/1.0"})
                with urllib.request.urlopen(req, timeout=2.0) as response:
                    data = response.read()
            except Exception:
                pass

            if not data:
                try:
                    req = urllib.request.Request(f"{TARGET_AP}/api/wifilist", headers={"User-Agent": "iSH-WifiPortal/1.0"})
                    with urllib.request.urlopen(req, timeout=1.5) as response:
                        data = response.read()
                except Exception:
                    pass

            if not data:
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

            # 1. PHẢN HỒI NGAY LẬP TỨC CHO SAFARI (TRONG 0.05 GIÂY)
            # Người dùng không phải chờ loa ngắt kết nối hay treo socket
            res_body = json.dumps({"success": True, "message": "OK"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_cors_headers()
            self.end_headers()
            try:
                self.wfile.write(res_body)
                self.wfile.flush()
            except Exception:
                pass

            # 2. CHUYỂN TIẾP TỚI LOA BẤT ĐỒNG BỘ (Loa nhận lệnh là ngắt AP ngay)
            def _forward_to_speaker():
                try:
                    req = urllib.request.Request(
                        f"{TARGET_AP}/api/configwifi",
                        data=body,
                        headers={"Content-Type": "application/json"}
                    )
                    urllib.request.urlopen(req, timeout=1.5)
                except Exception:
                    # Loa Phicomm R1 luôn ngắt Wi-Fi chip ngay khi nhận được gói tin, ngoại lệ là bình thường
                    pass
                print(">> Đã gửi cấu hình tới loa thành công!")
                schedule_shutdown(0.8)

            t = threading.Thread(target=_forward_to_speaker)
            t.daemon = True
            t.start()
            return

        self.send_response(404)
        self.end_headers()

def run():
    global server_instance
    server_address = ("127.0.0.1", PORT)
    try:
        server_instance = HTTPServer(server_address, WifiPortalHandler)
    except Exception:
        time.sleep(0.5)
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
        try:
            server_instance.server_close()
        except Exception:
            pass
        print("\n>> Đã hoàn tất và đóng Web Portal.")

if __name__ == "__main__":
    run()
