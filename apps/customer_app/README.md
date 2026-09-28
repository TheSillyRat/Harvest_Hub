# HarvestHub Customer App

[![Flutter](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter)](https://flutter.dev)
[![Application ID](https://img.shields.io/badge/Application%20ID-com.harvesthub.customer-green)](#)
[![Orientation](https://img.shields.io/badge/Orientation-Portrait%20Only-orange)](#)

The **Customer App** is the direct-to-consumer mobile marketplace of the HarvestHub ecosystem. It enables customers to discover nearby organic farms, explore fresh crop listings, schedule in-person self-pickups, chat with the AI Farm Assistant, and manage their orders.

---

## 📱 Features

- **Storefront & Discovery**: Browse seasonal fruits, vegetables, mushrooms, grains, and herbs by category with live availability indicators.
- **Search & Filter**: Keyword search with price range sliders, distance filters, and sorting by rating, distance, or price.
- **Interactive Farm Map**: View local farm pickup points on an interactive map with real-time Haversine distance calculations.
- **Multi-Shop Shopping Basket**: Consolidated cart grouping items by farm vendor with individual selection checkboxes and quantity steppers.
- **Atomic Order Placement**: Automatically partitions checkout into individual order records per farm with required pickup window selection.
- **AI Sprout Assistant**: Integrated Google Gemini conversational assistant providing produce tips, nutrition advice, and catalog recommendations.
- **Order Lifecycle Tracking**: Live status stream: `Pending` → `Confirmed` → `Ready for Pickup` → `Completed`.
- **Wishlist & Farm Follows**: Save preferred items and follow local growers with real-time status updates.
- **Product & Farm Reviews**: Rate and review completed orders with star ratings and feedback tags.

---

## 🚀 Running the App

```powershell
cd apps/customer_app
flutter pub get
flutter run
```

### Static Analysis & Testing
```powershell
flutter analyze
flutter test
```
