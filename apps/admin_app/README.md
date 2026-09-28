# HarvestHub Admin App

[![Flutter](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter)](https://flutter.dev)
[![Application ID](https://img.shields.io/badge/Application%20ID-com.harvesthub.admin-green)](#)

The **Admin App** provides executive platform oversight, catalog governance, merchant verification, content moderation, and ecosystem analytics across the entire HarvestHub network.

---

## 🛡️ Features

- **Merchant Verification & User Governance**: Inspect and approve new farmer registrations, oversee customer accounts, and issue policy-violation suspensions.
- **Product Safety & Moderation Hub**: Automated logging of flagged listings with review workflows to resolve category mismatches or content violations.
- **Platform Category Hierarchy**: Manage standard agricultural produce categories with image icons and localized descriptions.
- **Executive Analytics Dashboard**: High-level platform KPIs including Gross Merchandise Value (GMV), order throughput, top-performing farms, and regional density charts.
- **Strict Role-Based Security**: Administrative actions are protected by Firestore security rules, disallowing non-admin access.

---

## 🚀 Running the App

```powershell
cd apps/admin_app
flutter pub get
flutter run
```

### Static Analysis & Testing
```powershell
flutter analyze
flutter test
```
