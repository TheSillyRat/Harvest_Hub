# Flutter Monorepo & Emulator Troubleshooting Rules

## 1. Monorepo Build & Dart Analysis Failures
- Khi gặp lỗi `Gradle task assembleDebug failed with exit code 1` hoặc thông báo `Analysis issues may affect the execution`:
  - Luôn kiểm tra phân tích tĩnh toàn bộ workspace bằng `flutter analyze`.
  - Ưu tiên kiểm tra các package dùng chung (`packages/harvesthub_core`) vì lỗi biên dịch tại đây sẽ chặn bước `compileFlutterBuildDebug` của mọi ứng dụng con (`apps/*`).
  - Đảm bảo các directive `export` trong file library chính không trỏ đến các file bị thiếu hoặc chứa các symbol bị trùng lặp.

## 2. Android Emulator Network & DNS Issues
- Khi máy ảo không kết nối được mạng để tải ảnh từ Internet (như Unsplash/Firebase Storage):
  - Kiểm tra xem máy ảo có bị nghẽn DNS hay không bằng cách so sánh ping IP (`8.8.8.8`) và ping tên miền.
  - Giải pháp tức thì: Cấu hình Private DNS của máy ảo thành `dns.google` (Settings > Network & Internet > Private DNS).
  - Khởi động lại máy ảo bằng **Cold Boot Now** khi cần xóa trạng thái snapshot mạng cũ.
