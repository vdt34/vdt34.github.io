# Hệ Thống Gia Phả Dòng Họ (GiaPha Edition)

Ứng dụng Cây Gia Phả trực quan tương tác, tích hợp máy tính danh xưng xưng hô họ hàng, lịch giỗ tổ tiên âm lịch và bản đồ định vị mộ phần, chạy tĩnh hoàn toàn trên nền tảng GitHub Pages.

## Các tính năng chính

1. **Cây Gia Phả Trực Quan (Interactive Tree View)**:
   - Thu phóng và kéo rê canvas (Zoom & Pan mượt mà trên desktop và cảm ứng mobile).
   - Phân biệt trực quan: Nam (xanh dương), Nữ (hồng), Người đã khuất (viền vàng gold kèm biểu tượng ngọn nến 🕯️).
   - Hiển thị theo từng tầng thế hệ (Đời 1, Đời 2, Đời 3...).

2. **Máy Tính Danh Xưng Họ Hàng (Kinship Resolver)**:
   - Cho phép chọn bất kỳ ai trong gia tộc làm mốc "Tôi".
   - Tự động phân tích cây phả hệ theo thuật toán đồ thị LCA (Lowest Common Ancestor) để đưa ra chính xác:
     - Quan hệ huyết thống (Bác họ, Chú họ, Anh họ, Cháu...).
     - Lời xưng hô chuẩn xác hai chiều ("Bạn gọi người đó là...", "Người đó gọi bạn là...").

3. **Lịch Giỗ Tổ Tiên & Xuất Feed iCalendar (.ics)**:
   - Tự động bốc tách ngày mất âm lịch của tất cả các cụ trong dòng họ.
   - Chuyển đổi sang ngày dương lịch chính xác cho 10 năm liên tiếp theo thuật toán thiên văn âm lịch Việt Nam (UTC+7).
   - Nút xuất file `.ics` một chạm: Đăng ký trực tiếp vào Apple Calendar trên iPhone hoặc Google Calendar để tự động nhận thông báo nhắc giỗ trước 1 ngày.

4. **Sách Phả Ký (Chronicle Book View)**:
   - Trình bày dạng văn bản truyền thống theo từng đời (Đời I, Đời II, Đời III...).
   - Hỗ trợ in ấn hoàn hảo qua lệnh Print (`Ctrl+P`).

5. **Bản Đồ Mộ Phần (Gravesite Locator)**:
   - Lưu trữ vị trí an táng, chỉ dẫn lối vào và tọa độ GPS của từng phần mộ gia tộc.
   - Nút liên kết mở trực tiếp chỉ đường trên Google Maps.

## Đường dẫn truy cập

- Địa chỉ web: `https://vdt34.github.io/giapha/`
- Kết nối chéo với Lịch Âm: `https://vdt34.github.io/amlich/`
