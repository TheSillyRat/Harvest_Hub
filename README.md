# HarvestHub

Marketplace nông sản địa phương, gồm **3 app Flutter độc lập**, dùng một Firebase project:

| App | Android applicationId |
| --- | --- |
| customer_app | com.harvesthub.customer |
| farmer_app | com.harvesthub.farmer |
| admin_app | com.harvesthub.admin |

Package dùng chung: `packages/harvesthub_core` (models, services, Provider, theme và component).
UI tiếng Việt. Đơn hàng mô phỏng, không thanh toán thật. Khách tự đến nhận tại điểm bán; không có vận chuyển.

## Cài đặt

Yêu cầu Flutter stable / Dart 3.6+, Java 17+ và Android SDK. Phiên bản kiểm tra tại máy: Flutter 3.47.2 / Dart 3.13.2.
Đọc [Firebase setup](firebase/SETUP.md) trước khi chạy Android.

```powershell
cd HarvestHub/apps/customer_app
flutter pub get
flutter run

cd ../farmer_app
flutter pub get
flutter run

cd ../admin_app
flutter pub get
flutter run
```

## Tài khoản demo sau seed

| App | Email | Password |
| --- | --- | --- |
| Admin | admin@harvesthub.app | Admin@123 |
| Farmer | farmer1@harvesthub.app | Farmer@123 |
| Farmer | farmer2@harvesthub.app | Farmer@123 |
| Customer | customer@harvesthub.app | Customer@123 |

Không có chức năng đăng ký admin trong app. Tài khoản chỉ tồn tại sau khi chạy seed hoặc tạo trên Firebase Console.

## Kiểm tra

Chạy `flutter analyze`, `flutter test`, `flutter build apk` trong từng thư mục app.
Chạy `flutter test` trong package core.
Xem [trạng thái nghiệm thu](docs/ACCEPTANCE.md) để phân biệt source đã triển khai với kiểm chứng trên Firebase/thiết bị.

## Quy ước nghiệp vụ

- Đơn chỉ có Pending → Confirmed → ReadyForPickup → Completed; Pending/Confirmed có thể Cancelled.
- Mỗi đơn thuộc một nông dân. Đặt hàng dùng giá hiện tại từ Firestore, không tin giá client.
- Xóa từng nhóm giỏ trong cùng transaction tạo đơn, không xóa cả giỏ ngoài transaction.
- Nhóm đã đặt thành công không bị đặt lại khi nhóm khác thất bại.
- Giới hạn kỹ thuật: tối đa 8 loại sản phẩm mỗi nông dân mỗi lần checkout để rules kiểm tra từng dòng trong giới hạn truy cập tài liệu của Firestore.
- Field nội bộ `products.stockMutation = {orderId, itemIndex, kind}` liên kết tồn kho với đơn, chống sửa stock độc lập từ customer.
- Sản phẩm và danh mục dùng xóa mềm; giữ lịch sử đơn.

## Nguồn ảnh

Dữ liệu mẫu dùng ảnh công khai từ Unsplash (`images.unsplash.com`); URL từng ảnh nằm trong script seed.
App có placeholder khi chưa chọn ảnh hoặc ảnh mạng không tải được.

## Sườn kiến trúc dự án

Xem chi tiết sườn kiến trúc và các module tại [Sườn kiến trúc dự án (SangHuynh)](docs/ARCHITECTURE_SKELETON.md).

