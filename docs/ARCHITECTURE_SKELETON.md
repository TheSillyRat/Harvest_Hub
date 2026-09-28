# HarvestHub - System Architecture & Monorepo Scaffold

## 🏗️ Architectural Overview

The **HarvestHub** project is organized around an enterprise **Monorepo (Multi-App)** structure containing three independent Flutter applications and a shared domain package, connected to a unified Firebase Cloud project:

```text
HarvestHub/
├── apps/
│   ├── customer_app/      # 📱 Customer Mobile App (com.harvesthub.customer)
│   ├── farmer_app/        # 🚜 Farmer Management App (com.harvesthub.farmer)
│   └── admin_app/         # 🛡️ Platform Administration App (com.harvesthub.admin)
├── packages/
│   └── harvesthub_core/   # 📦 Shared Domain Package (Models, Services, State Management, UI Theme)
└── firebase/
    ├── firestore.rules    # 🔒 Declarative Role-Based Access Control
    ├── storage.rules      # 🔒 Secure Media Storage Constraints
    ├── seed_hcm_demo.mjs  # 🚀 Comprehensive Mock Catalog Seeder
    └── firebase.json      # ⚙️ Firebase CLI & Emulator Configuration
```

---

## 🎯 Core Application Modules

### 1. Customer Application (`apps/customer_app`)
- **Product Discovery & Search**: Fast categorized catalog browsing, keyword fuzzy search, and dietary filter chips.
- **Location-Aware Farm Directory**: Interactive map and list views displaying distance to farm gates, operating hours, and pickup hubs.
- **Multi-Shop Shopping Basket**: Consolidated cart grouping items by farm vendor with individual item selection and atomic partition checkout.
- **Pickup Slot Scheduling**: Choice of convenient fulfillment windows (e.g. morning/afternoon slots) for in-person collection.
- **Order Lifecycle Tracking**: Live status stream: `Pending` → `Confirmed` → `Ready for Pickup` → `Completed`.
- **AI Sprout Assistant**: Integrated Google Gemini conversational assistant for nutrition advice and produce recommendations.
- **Wishlist & Follow System**: Instant saving of preferred produce and farms.

### 2. Farmer Application (`apps/farmer_app`)
- **Produce Management (CRUD)**: Create, update, deactivate, and remove farm listings with category-specific validation.
- **Automated Content Moderation**: Integrated inspection verifying product names, categories, and ethical listing guidelines.
- **Real-Time Inventory Controls**: Stock level maintenance with automated zero-stock checkout lockouts.
- **Order Fulfillment Pipeline**: Immediate order review, confirmation, pickup slot readiness flag, and completion logging.
- **Business Performance Analytics**: Revenue reports, best-selling produce breakdown, and customer review monitoring.

### 3. Administrator Application (`apps/admin_app`)
- **Platform Oversight & Governance**: User directory monitoring, farmer approval verification, and account deactivation controls.
- **Catalog Moderation**: Category management, violation log inspection, and enforcement of listing standards.
- **Platform Analytics**: Aggregate Gross Merchandise Value (GMV), order volume distribution, active store metrics, and geographic density.

### 4. Core Shared Package (`packages/harvesthub_core`)
- **Domain Models**: Immutable contracts for `Product`, `Order`, `OrderItem`, `User`, `Farmer`, `Review`, `Category`, and `NotificationItem`.
- **Backend Services**: Firestore transactional operations, authentication lifecycle, image uploads, and inventory checks.
- **Design System & UI Tokens**: Reusable typography, custom color palette (`HhColors`), responsive button primitives, and dialog components.
