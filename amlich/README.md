# Vietnam Lunar Calendar (GitHub Edition)

Hệ thống lịch âm dương Việt Nam chạy hoàn toàn trên nền tảng tĩnh GitHub Pages, đồng bộ dữ liệu bằng GitHub REST API và tự động sinh các feed iCalendar (.ics) qua GitHub Actions để đăng ký trên thiết bị di động (iPhone / iPad / Mac / Android).

## Tính năng nổi bật

- **Lõi tính lịch âm Việt Nam (UTC+7)**: Triển khai thuật toán thiên văn độ chính xác cao theo kinh độ 105°E (Việt Nam), phân biệt chính xác với lịch âm Trung Quốc (UTC+8, ví dụ năm 1985).
- **Xử lý ngày âm lặp hàng năm**: Tự động giải mã ngày dương tương ứng cho các sự kiện như ngày giỗ gia đình, sinh nhật âm lịch, hỗ trợ chính sách ngày 30 khi gặp tháng thiếu 29 ngày.
- **Bảo mật dữ liệu 2 lớp**:
  - Dữ liệu public (`data/public/`): Ngày lễ, sự kiện cộng đồng được công khai và sinh ra các file `.ics` công cộng.
  - Dữ liệu private (`data/private/`): Mã hóa client-side bằng Web Crypto API (chuẩn AES-GCM 256-bit kết hợp PBKDF2). Không lưu mật khẩu hoặc khóa giải mã trên GitHub.
- **Chuẩn iCalendar RFC 5545**: Hỗ trợ đầy đủ tiếng Việt UTF-8, định dạng kết thúc dòng CRLF, gấp dòng 75 octets, UID ổn định.

## Cấu trúc thư mục

```text
amlich/
├── index.html                  # Giao diện dashboard quản lý lịch
├── assets/                     # Định dạng giao diện CSS & Icons
├── engine/                     # Lõi tính toán lịch âm và Can Chi (ES Module)
│   ├── vietnam-lunar.js
│   └── can-chi.js
├── data/
│   ├── public/                 # Dữ liệu ngày lễ và sự kiện công khai (JSON)
│   └── private/                # Thư mục lưu dữ liệu riêng tư đã mã hóa
├── feeds/                      # Các file iCalendar .ics đã sinh
│   ├── holidays.ics
│   ├── lunar.ics
│   └── public-events.ics
├── scripts/                    # Scripts Python kiểm thử và sinh feed ICS
│   ├── vietnam_lunar.py
│   ├── generate_ics.py
│   └── validate_data.py
├── tests/                      # Bộ kiểm thử đơn vị tự động
│   ├── test_lunar.py
│   ├── test_ics.py
│   └── test_events.py
└── .github/workflows/          # CI/CD tự động hóa trên GitHub Actions
    ├── update-calendar.yml
    └── deploy-pages.yml
```

## Hướng dẫn đăng ký Lịch trên iPhone

1. Vào **Cài đặt (Settings)** > **Lịch (Calendar)** > **Tài khoản (Accounts)**.
2. Chọn **Thêm tài khoản (Add Account)** > **Khác (Other)** > **Thêm Lịch đã đăng ký (Add Subscribed Calendar)**.
3. Nhập đường dẫn file feed (thay `username` bằng tài khoản GitHub của bạn):
   - Ngày lễ Việt Nam: `https://username.github.io/amlich/feeds/holidays.ics`
   - Ngày Mùng 1 & Rằm: `https://username.github.io/amlich/feeds/lunar.ics`
   - Sự kiện công cộng: `https://username.github.io/amlich/feeds/public-events.ics`
4. Bật tự động làm mới và nhấn **Lưu**.
