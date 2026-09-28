# HarvestHub Core Package

[![Dart](https://img.shields.io/badge/Dart-3.13%2B-0175C2?logo=dart)](https://dart.dev)
[![Package](https://img.shields.io/badge/Package-harvesthub__core-blue)](#)

The **`harvesthub_core`** package encapsulates the shared business logic, immutable domain models, backend service clients, state management controllers, and UI design primitives across all three HarvestHub Flutter applications.

---

## 📦 Package Architecture

- **`lib/src/models.dart`**: Immutable entity models (`Product`, `Order`, `OrderItem`, `User`, `Farmer`, `Review`, `Category`, `NotificationItem`).
- **`lib/src/services.dart`**: Firebase client abstractions:
  - `OrderService`: Concurrency-safe atomic transaction checkout and stock restoration.
  - `InventoryService`: Zero-stock enforcement and category purchase limit validation.
  - `ProductModerationService`: Automated content inspection and category matching algorithms.
  - `FarmerReviewService`: Real-time rating aggregation and review submission.
  - `SavedItemsService`: Account-scoped reactive wishlist and farm following streams.
  - `NotificationService`: In-app broadcast and targeted transaction notifications.
- **`lib/src/faq.dart`**: Google Gemini AI Sprout assistant integration with offline fallback intelligence.
- **`lib/src/theme.dart`**: Curated color tokens (`HhColors`), modern typography styling, and consistent widget geometry.
- **`lib/src/ui_components.dart` & `widgets.dart`**: Production-grade shared components (product cards, badges, status chips, loading states).

---

## 🧪 Testing

```powershell
cd packages/harvesthub_core
flutter test
```
