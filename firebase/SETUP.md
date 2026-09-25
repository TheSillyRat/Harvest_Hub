# Firebase setup

## Project thật

1. Tạo một Firebase project HarvestHub trên Firebase Console.
2. Bật Authentication → Email/Password.
3. Tạo Firestore Database, chọn production mode; triển khai rules bên dưới.
4. Bật Storage theo yêu cầu gói dịch vụ hiện hành của Firebase.
5. Đăng ký 3 Android app với đúng applicationId:
   - com.harvesthub.customer
   - com.harvesthub.farmer
   - com.harvesthub.admin
6. Tải từng file thật về đúng vị trí:
   - apps/customer_app/android/app/google-services.json
   - apps/farmer_app/android/app/google-services.json
   - apps/admin_app/android/app/google-services.json

Không dùng file cấu hình bịa hoặc dùng chung file sai package. Source đã khai báo Google Services Gradle plugin và Internet permission, minSdk 23.
Chưa có ba file này thì build Android thông thường chưa đủ điều kiện nghiệm thu.

Từ thư mục HarvestHub:

```powershell
cd firebase
npm install
cd ..
./firebase/node_modules/.bin/firebase login
./firebase/node_modules/.bin/firebase use --add
./firebase/node_modules/.bin/firebase deploy --only firestore:rules,firestore:indexes,storage
```

Triển khai rules vào project của bạn sau khi kiểm tra đúng project đang chọn.

## Emulator cục bộ

Từ HarvestHub/firebase:

```powershell
npm install
npm run emulators
```

Auth 9099, Firestore 8180, Storage 9199, UI 4000; project ID `demo-harvesthub`.
Giữ Emulator chạy; mở terminal thứ hai trong HarvestHub/firebase:

```powershell
npm run seed:emulator
```

Lệnh này tạo 4 tài khoản thật trong Auth Emulator, 6 danh mục và 11 sản phẩm trong Firestore Emulator.
Nếu `categories/fruits` đã tồn tại thì seed bỏ qua, không reset tồn kho hoặc mật khẩu.
Tắt các Emulator đang chạy trước khi dùng `npm run test:rules`, vì bộ test tự khởi động instance riêng và xóa dữ liệu test.
Với Android emulator, host mặc định `10.0.2.2`:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Dùng `npm run seed:emulator -- --refresh` để nạp sản phẩm mẫu mới vào một emulator đã seed trước đó. Lệnh refresh giữ nguyên số lượng tồn kho hiện có và cập nhật điểm cùng số lượt đánh giá mẫu cho từng sản phẩm. Với database đã có sản phẩm mẫu, có thể chỉ cập nhật hai trường đánh giá mà không đụng vào dữ liệu khác:

```powershell
npm run seed:emulator -- --ratings-only
```

Khi chạy thiết bị thật dùng `--dart-define=FIREBASE_EMULATOR_HOST=<IP máy>`, bật truy cập LAN có kiểm soát.
Firebase init thiếu cấu hình sẽ hiển thị màn hướng dẫn thay vì crash.
Gradle chỉ cho phép thiếu google-services.json khi bật rõ chế độ Emulator.
Debug manifest cho phép HTTP đến Emulator cục bộ. APK production dùng cấu hình Firebase thật và không bật flag này.

## Seed project demo thật

Chỉ thực hiện trên project demo của bạn. Script dùng Firebase Admin SDK cục bộ, không triển khai backend/API riêng.
Tạo service account có quyền Auth/Firestore, lưu ngoài repository, rồi:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\harvesthub-service-account.json'
npm run seed:project -- --project YOUR_PROJECT_ID --confirm-demo-project
```

Với project demo đã seed, cập nhật riêng điểm và số lượt đánh giá mẫu mà không thay đổi các trường khác của sản phẩm:

```powershell
npm run seed:project -- --project YOUR_PROJECT_ID --confirm-demo-project --ratings-only
```

Lệnh này chỉ cập nhật 11 sản phẩm demo có ID `seed-*`; tất cả sản phẩm đó phải tồn tại trước khi chạy.

Tài khoản Auth đã có sẽ được tái sử dụng, không thay mật khẩu. Nếu email demo thuộc role khác, script dừng.
Không commit service account hoặc thông tin ký APK.

## Tạo admin thủ công

Tạo Auth user admin@harvesthub.app qua Console; lấy UID, tạo users/{uid}:

```text
name: Quản trị HarvestHub
email: admin@harvesthub.app
phone: 0900000000
address: HarvestHub
role: admin
isActive: true
createdAt: timestamp hiện tại
```

Role và isActive không được tự sửa qua client. Admin không được tự khóa chính mình.

## Tài liệu kỹ thuật

- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/security/rules-conditions
- https://firebase.google.com/docs/emulator-suite


## Customer nearby products

Each demo farmer has `pickupLocation` (Firestore GeoPoint) and `pickupAddress`.
These are approximate demo points in Da Lat (11.9404, 108.4583) and Ba Vi
(21.0805, 105.3956), not verified trading addresses. Set an Android emulator's
location near either point to test the distance slider. A real location elsewhere
may correctly have no results within the selected radius.

For a database already seeded, backfill just the missing pickup locations:

```powershell
npm run seed:emulator -- --locations-only
# Authorized demo project, with Admin credentials configured:
npm run seed:project -- --project YOUR_PROJECT_ID --confirm-demo-project --locations-only
```

This mode preserves existing pickup locations, stock, passwords and account status.
The normal seed includes locations for new farmers. Farmer app code is unchanged;
Customer reads the optional fields directly. Existing farmers without coordinates
remain browsable, but cannot match a distance radius. Customer GPS stays on-device.
# Customer farm and product details

Customer profile photos are stored at `avatars/{uid}/{file}` (JPEG, PNG or WebP,
up to 5 MB). The download URL is saved in Firebase Auth `photoURL`; existing
Firestore user fields and Farmer profile writes are unchanged. Deploy
`firebase deploy --only storage --project <project-id>` using an authorized
Firebase account before trying avatar uploads against a live project. The rules
restrict uploads to the active owner. Password reset uses Firebase Auth email
delivery and the project's configured email templates.

Customer reads public store information from `farmers/{id}`: `businessName`,
`farmerName`, `avatarUrl`, `coverImageUrl`, `description`, `address`, `phone`,
`rating`, `reviewCount` and `pickupLocation`. Only active farms appear in the
directory; a missing pickup location does not hide a farm.

Products may include `imageUrls`. Customer combines these with the legacy
`imageUrl`, removes duplicates and displays at most six images. Written reviews
live at `products/{id}/reviews/{reviewId}` with `authorName`, `rating`, `comment`
and `createdAt`. Current rules allow reading reviews of active products and
deny client writes. Deploy the updated Firestore rules before using this view
against a live project.

Run `node seed.mjs --details-only` with configured Admin credentials to add
sample reviews, gallery images and public contact fields to existing demo data.
Use `--emulator --details-only` for local data. Sample reviews are marked
`isDemo: true` and displayed as samples. Repeated runs use stable review IDs and
preserve existing non-demo reviews, stock and prices. `--ratings-only` now also
writes these sample review records and recalculates product aggregates.
