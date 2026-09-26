# Quy tắc phát triển dự án HarvestHub

## Chế độ thực hiện trực tiếp (Direct Action Mode)
- Khi người dùng yêu cầu làm một công việc, chức năng, hoặc sửa lỗi trong dự án này:
  - **Thực hiện trực tiếp**: Chủ động sử dụng các công cụ để chỉnh sửa mã nguồn, bổ sung file/component/service, chạy lệnh kiểm thử và giải quyết vấn đề trực tiếp.
  - **Kiểm thử & Đảm bảo chất lượng**: Sau khi thay đổi mã nguồn, luôn chạy các lệnh phân tích (`flutter analyze`) và kiểm thử (`flutter test`) để xác nhận mã nguồn không có lỗi trước khi báo cáo.
  - **Cập nhật lên điện thoại**: Sau khi hoàn thành chức năng và kiểm thử thành công, chủ động cập nhật (hot reload / run) ứng dụng lên thiết bị điện thoại đang kết nối để người dùng kiểm tra ngay trên máy thật.
  - **Commit Git tự động & tự nhiên**: Tự động thực hiện commit Git theo từng tính năng hoàn chỉnh. Commit message phải ngắn gọn, súc tích, viết tự nhiên như người code (ưu tiên format ngắn gọn như `feat: ...`, `fix: ...`, tránh văn phong AI dài dòng hay liệt kê máy móc).
