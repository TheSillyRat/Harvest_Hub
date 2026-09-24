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

Lệnh này tạo 4 tài khoản thật trong Auth Emulator, 6 danh mục và 8 sản phẩm trong Firestore Emulator.
Nếu `categories/fruits` đã tồn tại thì seed bỏ qua, không reset tồn kho hoặc mật khẩu.
Tắt các Emulator đang chạy trước khi dùng `npm run test:rules`, vì bộ test tự khởi động instance riêng và xóa dữ liệu test.
Với Android emulator, host mặc định `10.0.2.2`:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
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

