# Quy tắc phát triển dự án HarvestHub

## Chế độ thực hiện trực tiếp (Direct Action Mode)
- Khi người dùng yêu cầu làm một công việc, chức năng, hoặc sửa lỗi trong dự án này:
  - **Thực hiện trực tiếp**: Chủ động sử dụng các công cụ để chỉnh sửa mã nguồn, bổ sung file/component/service, chạy lệnh kiểm thử và giải quyết vấn đề trực tiếp.
  - **Kiểm thử & Đảm bảo chất lượng**: Sau khi thay đổi mã nguồn, luôn chạy các lệnh phân tích (`flutter analyze`) và kiểm thử (`flutter test`) để xác nhận mã nguồn không có lỗi trước khi báo cáo.
  - **Cập nhật lên điện thoại**: Sau khi hoàn thành chức năng và kiểm thử thành công, chủ động cập nhật (hot reload / run) ứng dụng lên thiết bị điện thoại đang kết nối để người dùng kiểm tra ngay trên máy thật.
  - **Commit Git tự động & tự nhiên**: Tự động thực hiện commit Git theo từng tính năng hoàn chỉnh. Commit message phải ngắn gọn, súc tích, viết tự nhiên như người code (ưu tiên format ngắn gọn như `feat: ...`, `fix: ...`, tránh văn phong AI dài dòng hay liệt kê máy móc).

## Quy chuẩn chất lượng TechWiz 7 (Production Standards)
Áp dụng bắt buộc từ [standards.md](file:///e:/Techwiz7/HarvestHub/standards.md) cho tất cả các tính năng và tác vụ lập trình:
1. **Cấu trúc & Kiến trúc**:
   - Tách biệt rõ ràng Presentation (UI), Business Logic / State Management và Data Service.
   - Tránh monolithic code: chia nhỏ các widget, logic phức tạp thành các helper/component dễ tái sử dụng.
   - Tuyệt đối tránh các giải pháp tạm bợ, logic lạ, lồng ghép quá nhiều vòng lặp hoặc điều kiện phức tạp khó đọc, khó bảo trì.
2. **Quy ước đặt tên (Naming Conventions)**:
   - Classes, Widgets, Enums: `PascalCase` rõ nghĩa (ví dụ: `OrderProgressCard`, `NotificationPayload`).
   - Functions, Methods, Variables: `camelCase` (ví dụ: `highlightOrderCard()`, `targetOrderId`).
   - Constants: `SCREAMING_SNAKE_CASE` hoặc chữ hoa nhất quán.
3. **Hiệu năng & Tối ưu hóa**:
   - Tránh tìm kiếm lặp $O(N^2)$ trong UI build; lập chỉ mục Map/Set khi tra cứu dữ liệu.
   - Tránh gọi lặp Firestore / Network trong vòng lặp.
   - Tối ưu hóa render danh sách với `ListView.builder` và `GlobalKey` / `Scrollable.ensureVisible` khi điều hướng đến phần tử cụ thể.
4. **Trải nghiệm & Tính tin cậy (Reliability & Clean UI)**:
   - Xử lý mượt mà animation hiệu ứng (ví dụ: viền highlight đổi màu mờ dần).
   - Đảm bảo `flutter analyze` 0 warnings, 0 errors và tất cả unit/widget tests đều pass trước khi hoàn thành task.
