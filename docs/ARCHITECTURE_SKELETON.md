# HarvestHub - Core Architecture & Scaffold (SangHuynh Branch)

## 🏗️ Tổng quan Sườn Kiến trúc Project

Dự án **HarvestHub** được tổ chức theo mô hình **Monorepo (Multi-app)** gồm 3 ứng dụng Flutter độc lập và 1 package dùng chung, sử dụng chung 1 project Firebase:

```text
HarvestHub/
├── apps/
│   ├── customer_app/      # 📱 Ứng dụng Khách hàng (com.harvesthub.customer)
│   ├── farmer_app/        # 🚜 Ứng dụng Nông dân (com.harvesthub.farmer)
│   └── admin_app/         # 🛡️ Ứng dụng Quản trị (com.harvesthub.admin)
├── packages/
│   └── harvesthub_core/   # 📦 Package dùng chung (Models, Services, State Management, UI Theme)
└── firebase/
    ├── firestore.rules    # 🔒 Quy tắc bảo mật Firestore
    ├── storage.rules      # 🔒 Quy tắc bảo mật Firebase Storage
    ├── seed.mjs           # 🚀 Script nạp dữ liệu mẫu vào Firebase
    └── firebase.json      # ⚙️ Cấu hình Firebase Emulators
```

---

## 🎯 Cấu trúc các Module chính (Sườn Core)

1. **Khách hàng (`customer_app`)**:
   - Xem danh mục sản phẩm, tìm kiếm nông sản.
   - Thêm giỏ hàng, chọn khung giờ nhận hàng tại điểm bán.
   - Theo dõi trạng thái đơn hàng (Pending -> Confirmed -> ReadyForPickup -> Completed).

2. **Nông dân (`farmer_app`)**:
   - Quản lý danh mục sản phẩm của trang trại.
   - Cập nhật tồn kho, giá bán sản phẩm.
   - Tiếp nhận và xác nhận đơn hàng của khách hàng.

3. **Quản trị (`admin_app`)**:
   - Quản lý người dùng (Nông dân, Khách hàng).
   - Quản lý danh mục sản phẩm hệ thống.
   - Theo dõi hoạt động và báo cáo tổng quan.

4. **Core Package (`harvesthub_core`)**:
   - Data models: `User`, `Farmer`, `Category`, `Product`, `Order`, `OrderItem`.
   - Firebase Services: `AuthService`, `FirestoreService`, `StorageService`.
   - Shared Providers & Custom Widgets.
