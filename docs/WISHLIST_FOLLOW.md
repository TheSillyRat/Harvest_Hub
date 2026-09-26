# Wishlist & Farmer Follow

Đã triển khai cho `customer_app`; giao diện dùng tiếng Anh theo các màn hiện có.

## Cách sử dụng

- Chạm tim trên thẻ sản phẩm hoặc trang chi tiết để lưu/bỏ lưu. Sản phẩm hết hàng vẫn lưu được.
- Mở **Saved** bằng biểu tượng tim ở thanh tìm kiếm, hoặc **Profile → My wishlist**.
- Chạm **Follow / Following** trên thẻ nông dân hoặc phần **About the farm** trong chi tiết sản phẩm.
- Mở tab **Following** ở trang Saved, từ nút Following trên màn Farmers, hoặc **Profile → Following**.
- Danh sách sắp xếp theo lần lưu gần nhất. Chạm sản phẩm để xem chi tiết, hoặc **View products** để xem sản phẩm của trang trại.
- Mục bị ẩn/xóa vẫn có thể gỡ khỏi danh sách. Lỗi tải có nút thử lại; lỗi ghi có thông báo. Nút bị khóa khi thao tác đang chờ xác nhận.

## Dữ liệu và quyền

| Đường dẫn Firestore | Trường |
| --- | --- |
| `wishlists/{uid}/items/{productId}` | `productId`, `savedAt` |
| `farmerFollows/{uid}/items/{farmerId}` | `farmerId`, `savedAt` |

`savedAt` dùng server timestamp. ID tài liệu theo sản phẩm/nông dân nên không tạo bản ghi trùng. Chỉ customer đang hoạt động được thêm vào danh sách riêng; mục tiêu phải tồn tại và đang hoạt động. Chủ tài khoản đang hoạt động được đọc/xóa mục riêng, kể cả mục tiêu đã ngừng hoạt động. Không cho tài khoản khác đọc/ghi danh sách.

`SavedItemsController` nhận UID từ AuthController, lắng nghe hai collection và xóa trạng thái khi đổi tài khoản/đăng xuất. Callback của phiên cũ không cập nhật phiên mới. Firestore cung cấp cập nhật trực tiếp và hoàn tác ghi cục bộ khi server từ chối. Khi offline, thao tác ghi có thể chờ kết nối trở lại để được xác nhận.

## Kiểm chứng

```powershell
# Từ apps/customer_app
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub

# Từ packages/harvesthub_core
flutter test --no-pub test/saved_items_service_test.dart

# Từ firebase; cần Java và các cổng emulator trống
npm run test:rules
```

Test bao gồm đồng bộ giữa các nút, lưu/bỏ lưu, cập nhật từ thiết bị khác, thứ tự lưu, lỗi stream/ghi, chống nhấn trùng, đổi tài khoản khi đang ghi, điều hướng chi tiết, mục hết hàng/bị xóa, bố cục 320px với chữ lớn, và quyền Firestore.

## Đưa lên Firebase thật

Source rules và APK cần được cập nhật cùng nhau. Các test emulator không triển khai rules lên project thật. Từ thư mục gốc dự án, chọn đúng project rồi chạy:

```powershell
./firebase/node_modules/.bin/firebase deploy --only firestore:rules --project <project-id>
```

Không cần composite index mới. Tính năng thông báo push là nhiệm vụ riêng; Follow hiện lưu quan hệ và cung cấp lối quay lại sản phẩm của trang trại.
