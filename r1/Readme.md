# PHICOMM R1 - AI BOX PLUS (BẢN CẬP NHẬT 4 TẦNG & DLNA LOSSLESS)

Phiên bản nâng cấp giao diện 4 tầng chuyên nghiệp, tối ưu toàn diện cụm điều khiển nhạc, âm lượng và tích hợp dịch vụ truyền phát nhạc không dây DLNA DMR chất lượng cao cho loa thông minh **Phicomm R1**.

---

## 🎵 DỊCH VỤ DLNA DMR (DIGITAL MEDIA RENDERER)

> **Truyền nhạc Lossless chất lượng cao từ điện thoại / máy tính trực tiếp đến loa Phicomm R1 qua mạng Wi-Fi LAN.**

- **Tên thiết bị DLNA**: `Phicomm R1 (AIBox Plus)`
- **Trạng thái**: Sẵn sàng nhận kết nối (Hoạt động liên tục trong mạng nội bộ)
- **Chuẩn truyền tải**: DLNA / UPnP Audio Streaming (hỗ trợ MP3, AAC, FLAC, WAV Lossless)

### 📱 Hướng Dẫn Phát Nhạc DLNA Chi Tiết

1. **Kết nối mạng Wi-Fi**:
   - Đảm bảo điện thoại hoặc máy tính kết nối cùng mạng Wi-Fi với loa Phicomm R1.
2. **Mở ứng dụng âm nhạc**:
   - **Android / iOS**: Zing MP3, BubbleUPnP, Spotify, Samsung Music, mConnect, Apple Music, VLC, v.v.
   - **Windows / Mac**: Windows Media Player, MusicBee, Foobar2000, Audirvana.
3. **Phát nhạc tới loa**:
   - Nhấn biểu tượng **Cast / DLNA / AirPlay / Thiết bị phát** trên ứng dụng nhạc.
   - Chọn thiết bị: **`Phicomm R1 (AIBox Plus)`**.
   - Âm thanh sẽ được truyền tải trực tiếp và giải mã với chất lượng nguyên bản (lossless) trên loa Phicomm R1!

---

## 🎛️ BỐ CỤC GIAO DIỆN 4 TẦNG TRÊN WEB UI (`http://<IP-LOA>:8081`)

Toàn bộ giao diện Music Player đã được tái cấu trúc thành 4 tầng rõ ràng, khoa học:

```
┌────────────────────────────────────────────────────────┐
│  TẦNG 1: THÔNG TIN BÀI HÁT (TRACK INFO)                │
│  [Ảnh đĩa than quay]  Tên bài hát - Nghệ sĩ            │
│  [IDLE/YOUTUBE/ZING/DLNA] - Sóng nhạc Waveform động   │
│  0:00 ───●──────────────────────────── 3:45 (Tua nhạc) │
├────────────────────────────────────────────────────────┤
│  TẦNG 2: CỤM ĐIỀU KHIỂN PLAYER (6 NÚT)                 │
│   [Repeat]  [Prev]  【 PLAY / PAUSE 】  [Stop]  [Next] [Shuffle]│
├────────────────────────────────────────────────────────┤
│  TẦNG 3: THANH ÂM LƯỢNG (VOLUME SLIDER - 2 CHIỀU)       │
│  [-] ═══════════════════●════ 15  [+] (Mức 5)          │
├────────────────────────────────────────────────────────┤
│  TẦNG 4: KHU VỰC NGUỒN NHẠC (MUSIC SOURCES & DLNA)     │
│  [Songs] [Playlist] [Zing MP3] [Playlists] │
│  Khung tìm kiếm bài hát / Bật tắt DLNA / Quản lý danh sách│
└────────────────────────────────────────────────────────┘
```

1. **Tầng 1 - Track Info**:
   - Ảnh bìa dạng đĩa than xoay tròn khi phát nhạc.
   - Tên bài hát, ca sĩ, huy hiệu nguồn phát nổi bật.
   - Waveform sóng nhạc chuyển động theo giai điệu.
   - Thanh tiến trình kèm thời gian hiện tại / tổng thời gian, hỗ trợ click để tua nhanh.
2. **Tầng 2 - Player Controls**:
   - Cụm 6 nút điều khiển ngang hàng, cân đối.
   - Nút **Play/Pause** to tròn nổi bật ở chính giữa.
   - Nút **Stop** dừng hẳn nhạc và giải phóng tiến trình phát, không bị zombie playback.
   - Nút **Repeat** và **Shuffle** đổi màu trạng thái Active/Inactive rõ ràng.
3. **Tầng 3 - Volume Slider**:
   - Đặt ngay dưới Player và ngay trên các tab nguồn nhạc.
   - Kèm 2 nút bấm nhanh **`-`** và **`+`** tiện lợi cho màn hình cảm ứng.
   - **Đồng bộ 2 chiều**: Thay đổi trên web thì loa đổi âm lượng; bấm nút cứng trên loa hoặc ra lệnh giọng nói thì thanh trượt trên web lập tức nhảy về đúng mức.
4. **Tầng 4 - Nguồn nhạc & DLNA**:
   - Tích hợp đầy đủ các nguồn: YouTube, Zing MP3, DLNA và Playlists cá nhân.
   - Quản lý trạng thái Bật/Tắt dịch vụ DLNA ngay trong tab DLNA.

---

## 📦 THÔNG TIN BẢN APK

- **Tên file**: `AIBoxPlus_DLNA_VOV_Patched.apk`
- **Gói ứng dụng**: `info.dourok.voicebot`
- **Mã SHA-256**:
  ```
  11199640E03E90E9983F44E41429C63D8E65F5C07650C91DE9C3D95921EFDBA4
  ```
- **Các tính năng bảo toàn**:
  - Hệ thống 4 Microphone độ nhạy cao.
  - Wake Word: "Ô Kê Na Bu".
  - Kết nối trợ lý Xiaozhi / Home Assistant.
  - Tự động chạy nền cùng hệ thống khi khởi động loa.

---

## 🚀 HƯỚNG DẪN CÀI ĐẶT NHANH QUA ADB

Chạy lệnh cài đặt trực tiếp qua mạng Wi-Fi:

```bat
adb connect <IP_CỦA_LOA>:5555
adb install -r AIBoxPlus_DLNA_VOV_Patched.apk
```

Hoặc chạy file `install.bat` và chọn mục **3. Chi cai dat / cap nhat AIBoxPlus**.
