# PHICOMM R1 INSTALLER V2 (ALL-IN-ONE)

Bộ công cụ cài đặt, cập nhật, sao lưu và quản trị tự động cho loa **Phicomm R1** lấy nguồn trực tiếp từ GitHub (`vdt34/vdt34.github.io/r1`).

Hỗ trợ đầy đủ:
- 💻 **Máy tính (Windows 7 / 8 / 10 / 11)**: PowerShell 5.1 & PowerShell 7+
- 📱 **Điện thoại iPhone / iPad**: Ứng dụng **iSH Shell** (App Store)
- 🐧 **Android / Linux / macOS**: Termux, Bash, Zsh, macOS Terminal

---

## 🚀 HƯỚNG DẪN NHANH

### Cách 1: Sử dụng máy tính Windows (Khuyên dùng)
1. Tải bộ cài hoặc clone repository về máy tính.
2. Nhấp đúp vào file `install.cmd` (hoặc mở PowerShell gõ `.\install.ps1`).
3. Làm theo bảng menu điều khiển hiển thị trên màn hình.

> **Cài đặt siêu tốc 1 dòng lệnh (không cần tải trước):**
> ```powershell
> powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://vdt34.github.io/r1/install.ps1)))"
> ```

---

### Cách 2: Sử dụng điện thoại iPhone (qua iSH Shell)
1. Vào **App Store** trên iPhone, tìm và cài đặt ứng dụng miễn phí: **iSH Shell**.
2. Mở ứng dụng **Cài đặt** trên iPhone -> cuộn xuống tìm **iSH** -> Bật quyền **Mạng cục bộ (Local Network)**.
3. Mở ứng dụng **iSH Shell**, dán lệnh sau và nhấn **Enter**:
   ```sh
   curl -fsSL https://vdt34.github.io/r1/install.sh -o r1.sh && sh r1.sh
   ```
4. Làm theo hướng dẫn trên màn hình để kết nối và cài đặt cho loa!

---

## 📋 CÁC TÍNH NĂNG CHÍNH

1. **Cài đặt siêu tốc qua WiFi của loa (192.168.43.1)**:
   - Ấn giữ nút tròn đỉnh loa 6 giây để bật chế độ phát WiFi (`Phicomm_R1_xxxx`).
   - Kết nối máy tính/iPhone vào WiFi của loa -> Bộ cài tự động phát hiện, đánh thức ADB qua WebSocket port 8080 và cài đặt siêu tốc.
2. **Cài đặt qua WiFi nhà (LAN)**:
   - Tự động quét dải mạng tìm địa chỉ IP của loa hoặc nhập IP thủ công.
3. **Cập nhật nhanh AI Box Plus**:
   - Nâng cấp phiên bản trợ lý tiếng Việt mới nhất, giữ nguyên 100% cấu hình cũ (mDNS, PayOS, hẹn giờ...).
4. **An toàn & Quản trị**:
   - **Tự động sao lưu (Auto-backup)**: Tự động sao lưu ứng dụng gốc và cấu hình loa trước khi can thiệp.
   - **Khôi phục (Restore)**: Đưa loa về trạng thái sao lưu trước đó một cách an toàn.
   - **Sửa lỗi (Repair)**: Dọn dẹp ứng dụng xung đột, giải phóng âm thanh/micro, kích hoạt lại các tiến trình chạy ngầm.
   - **Gỡ bỏ (Uninstall)**: Gỡ trợ lý tiếng Việt và khôi phục nguyên trạng loa ban đầu.
5. **Kiểm tra Checksum SHA256**:
   - Mọi file APK đều được kiểm tra mã băm SHA256 trước khi truyền vào loa, loại bỏ hoàn toàn nguy cơ cài file hỏng.
6. **Hỗ trợ cài đặt hàng loạt (Multi-speaker)**:
   - Cài đặt hoặc cập nhật cho nhiều loa Phicomm R1 trong mạng cùng một lúc.
7. **Chế độ kiểm thử an toàn (Dry-Run)**:
   - Thêm tham số `-DryRun` (Windows) hoặc `--dry-run` (iPhone) để chạy thử nghiệm toàn bộ luồng mà không cần kết nối loa thật.

---

## 🛠 DANH MỤC FILE TRONG BỘ CÀI

- `install.cmd`: Trình khởi chạy nhanh trên Windows (tự động chỉnh UTF-8, bypass policy).
- `install.ps1`: Bộ cài đặt chính cho Windows (PowerShell 5.1 & 7+).
- `install.sh`: Bộ cài đặt cho iPhone (iSH), Android (Termux), Linux, macOS.
- `manifest.txt`: Bảng kê danh mục gói, phiên bản versionCode, kích thước và mã băm SHA256.
- `packages.conf`: File cấu hình định nghĩa gói cài đặt.
- `tools/Build-Manifest.ps1`: Công cụ tự động cập nhật `manifest.txt` và `SHA256SUMS`.
- `tools/Package-Release.ps1`: Đóng gói bộ phát hành `.zip`.
- `tools/Test-Suite.ps1`: Kịch bản kiểm thử tự động toàn diện.

---

## 🌐 GIAO DIỆN CẤU HÌNH LOA SAU KHI CÀI

- **Cấu hình WiFi nhà cho loa**: `http://192.168.43.1:8081/wifi.html`
- **Giao diện điều khiển Web Control**: `http://<IP_LOA>:8081/`
