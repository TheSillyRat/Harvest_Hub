# HarvestHub Farmer App

[![Flutter](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter)](https://flutter.dev)
[![Application ID](https://img.shields.io/badge/Application%20ID-com.harvesthub.farmer-green)](#)

The **Farmer App** serves as the digital farm-gate management platform for agricultural producers, enabling them to showcase their harvest, control stock levels, fulfill customer pickup orders, and track store performance.

---

## 🚜 Features

- **Produce Catalog Management (CRUD)**: Create, edit, and soft-delete product listings with high-resolution image uploads.
- **Automated Content Moderation**: Built-in safety pre-checks preventing policy-violating text and validating semantic category matching.
- **Inventory & Stock Ceiling Protection**: Zero-stock prevention guards and category ceiling alerts to maintain reliable fulfillment.
- **Order Fulfillment Pipeline**: Receive pending pickup orders, verify customer arrival, mark orders `Ready for Pickup`, and finalize pickup handovers.
- **Pickup Scheduling & Slot Preparation**: Define farm operating hours and collection windows for seamless customer visits.
- **Store & Profile Customization**: Update farm location coordinates, contact information, descriptions, and cover banners.
- **Business Performance Analytics**: Visual reports detailing daily revenue, order volumes, best-selling produce, and customer ratings.

---

## 🚀 Running the App

```powershell
cd apps/farmer_app
flutter pub get
flutter run
```

### Static Analysis & Testing
```powershell
flutter analyze
flutter test
```
