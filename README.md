# HarvestHub

[![Flutter Version](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.13%2B-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)](#)

> **TechWiz 7 Multi-Platform Application Computing Project**  
> Direct farm-to-table digital marketplace connecting conscientious customers with verified local organic growers through location-aware in-person pickup scheduling.

---

## 📖 Executive Summary

Local smallholder farmers frequently struggle with commercial visibility and high intermediary logistics costs, while everyday consumers find it difficult to source guaranteed fresh, transparently priced local produce. 

**HarvestHub** resolves this disconnect through an integrated **Multi-App Monorepo architecture** consisting of **three independent Flutter applications** operating over a unified Google Cloud Firebase backend:

| Application | Role & Purpose | Android Application ID |
| :--- | :--- | :--- |
| **`customer_app`** | Browse nearby farms, explore catalog, save items, chat with AI, and schedule farm pickups | `com.harvesthub.customer` |
| **`farmer_app`** | Manage farm inventory, monitor zero-stock limits, fulfill orders, and inspect reviews | `com.harvesthub.farmer` |
| **`admin_app`** | Platform governance, content moderation, user management, and executive analytics | `com.harvesthub.admin` |
| **`harvesthub_core`** | Shared domain entities, business logic, state controllers, UI tokens, and utilities | *(Dart Package)* |

---

## 🏛️ System Architecture

```text
HarvestHub (Monorepo)
├── apps/
│   ├── customer_app/             # Customer shopping experience
│   │   ├── lib/screens/          # Home, Marketplace, CartSheet, Checkout, Chatbot, FarmMap
│   │   └── android/              # Native Android configuration (Portrait locked)
│   ├── farmer_app/               # Farmer store & fulfillment management
│   │   ├── lib/                  # Dashboard, Inventory, Orders, Schedule, Reports
│   │   └── android/              # Native Android configuration
│   └── admin_app/                # Executive administration & moderation
│       ├── lib/                  # Analytics, Users, Products, Moderation, Categories
│       └── android/              # Native Android configuration
├── packages/
│   └── harvesthub_core/          # Reusable shared domain package
│       ├── lib/src/models.dart   # Data contracts: Product, Order, User, Farmer, Review
│       ├── lib/src/services.dart # Firestore transactions, Auth, Inventory, Notifications
│       └── lib/src/faq.dart      # Gemini AI Sprout assistant & fallback engine
└── firebase/
    ├── firestore.rules           # Declarative RBAC & atomic transaction verification
    ├── storage.rules             # Media upload authentication and size constraints
    ├── firestore.indexes.json    # Composite query indexing configuration
    └── seed_hcm_demo.mjs         # Production-grade mock catalog and farm seed data
```

---

## 🌟 Key Technical Highlights

### 1. Multi-Shop Self-Pickup & Cart Partitioning
- **Shopee-like Multi-Shop Grouping**: Customers can aggregate produce from multiple independent farms into one unified shopping basket.
- **Atomic Order Partitioning**: At checkout, the system atomically splits the transaction into distinct, self-contained order records partitioned per farmer.
- **On-Farm Pickup Slots**: Zero third-party delivery fees. Customers select explicit pickup windows (e.g., *Morning 07:00 - 10:00*) for each grower.
- **GPS Distance & Map Routing**: Real-time Haversine distance calculations and direct Google Maps navigation coordinates.

### 2. Concurrency-Safe Stock & Zero-Stock Prevention
- **Atomic Stock Deductions**: Stock decrements execute inside Firestore atomic database transactions (`runTransaction`), preventing overselling during concurrent user checkouts.
- **Zero Stock Guard**: Out-of-stock items automatically disable checkout actions and prevent purchase increments client-side and server-side.
- **Category Upper Limits**: Enforces sensible quantity ceilings per category (e.g., maximum 20 kg for heavy produce) to protect smallholder inventory.

### 3. AI Farm Assistant ("AI Sprout")
- Integrated with **Google Gemini AI** to deliver personalized produce recommendations, storage/preservation tips, nutrition advice, and harvest schedule consultations.
- Responds in **English** by default, with automatic pinned product recommendations linked directly to live in-stock inventory.
- Features resilient offline fallback intelligence when cloud API keys are temporarily unavailable.

### 4. AI-Powered Product Moderation & Content Safety
- Multi-tier automated inspection for newly listed items before or upon farmer publication.
- Identifies illicit substances, weapons, and inappropriate text.
- Validates semantic category matching (e.g., detecting if mushrooms or meats are improperly submitted under fruits).

### 5. Reactive Wishlists & Farm Following
- Instant bookmarking of favorite crops and growers with real-time Firestore reactive listeners.
- Account-scoped server timestamps and optimistic local updates with automatic error rollback.

### 6. Executive Analytics Dashboard
- Comprehensive multi-dimension charts for platform revenue, order status distribution, top-performing farms, and regional breakdowns.

---

## 👥 Demo Credentials (Post-Seed)

All seed accounts are initialized with testing credentials on Firebase:

| Role | Email | Password | Primary Permissions |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin@harvesthub.app` | `Admin@123` | Platform oversight, moderation, user bans, analytics |
| **Farmer (HCM Demo)** | `farmer_sgn_binhloi@harvesthub.app` | `Farmer@123` | Citrus orchard management, inventory & orders |
| **Farmer (Highland)** | `farmer1@harvesthub.app` | `Farmer@123` | Dalat organic farm, order confirmation & slots |
| **Farmer (Standard)** | `farmer2@harvesthub.app` | `Farmer@123` | Produce management & store profile |
| **Customer** | `customer@harvesthub.app` | `Customer@123` | Browsing, ordering, pickup scheduling, reviews |

*(Note: Admin accounts cannot be registered publicly via client applications; they are provisioned exclusively via administrative seed scripts or Firebase Console).*

---

## 🚀 Getting Started & Installation

### Prerequisites
- **Flutter SDK**: `3.47+` (Dart `3.13+`)
- **JDK**: Java 17 or higher
- **Android SDK**: API Level 34+
- **Node.js**: `v18+` (for Firebase CLI & seed scripts)

### 1. Repository Setup & Dependencies
```powershell
# Clone the repository
git clone https://github.com/TheSillyRat/Harvest_Hub.git
cd Harvest_Hub

# Install Core dependencies
cd packages/harvesthub_core
flutter pub get

# Install application dependencies
cd ../../apps/customer_app && flutter pub get
cd ../farmer_app && flutter pub get
cd ../admin_app && flutter pub get
cd ../..
```

### 2. Firebase Configuration
Before running Android apps, ensure `google-services.json` is placed in each app's `android/app/` directory:
- `apps/customer_app/android/app/google-services.json`
- `apps/farmer_app/android/app/google-services.json`
- `apps/admin_app/android/app/google-services.json`

Refer to [Firebase Setup Guide](firebase/SETUP.md) for full cloud configuration steps.

### 3. Launching Applications

#### Run Customer App:
```powershell
cd apps/customer_app
flutter run
```

#### Run Farmer App:
```powershell
cd apps/farmer_app
flutter run
```

#### Run Admin App:
```powershell
cd apps/admin_app
flutter run
```

---

## 🧪 Automated Testing & Verification

The codebase maintains strict code quality compliance with **0 warnings** on `flutter analyze` and passing automated test suites across all modules:

```powershell
# 1. Analyze Code Quality (Must return 0 errors, 0 warnings)
cd apps/customer_app && flutter analyze
cd ../farmer_app && flutter analyze
cd ../admin_app && flutter analyze
cd ../../packages/harvesthub_core && flutter analyze

# 2. Run Comprehensive Unit & Widget Test Suites
cd ../../packages/harvesthub_core && flutter test
cd ../../apps/customer_app && flutter test
cd ../farmer_app && flutter test
cd ../admin_app && flutter test
```

---

## 📋 TechWiz 7 Project Team Task Assignments

| Member Name | Core Responsibilities & Deliverables |
| :--- | :--- |
| **Phan Minh Tai** | Product Browsing, Category Navigation, Dynamic Wishlist, Farmer Follow System, Shopping Cart Management, Multi-Shop Checkout & Pickup Processing, In-App Restock & Order Notifications |
| **Nguyen Huynh Van Sang** | Customer Authentication & Profile Management, Search & Filtering Engine, AI Sprout Assistant (Gemini), Order History & Tracking, Zero-Stock Purchase Prevention |
| **Ho Hoang Sang** | Farmer Inventory Maintenance & Stock Limits, Admin Platform-Wide Product & Order Oversight, Admin Analytics Dashboard, Farmer Order Workflow & Pickup Slot Preparation |
| **Nguyen Phuoc Tuong** | ERD Database Architecture & Git Workflow, Admin User Governance (Farmers & Customers), Farmer Profile & Store Management, Product CRUD Operations, Sales & Order Reports |

---

## 📄 License & Attribution

- **License**: Released under the [MIT License](LICENSE).
- **Images**: High-resolution demonstration media curated from public domain [Unsplash](https://unsplash.com) photography collections for educational and competition purposes.
