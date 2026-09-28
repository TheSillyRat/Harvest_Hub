# HarvestHub

HarvestHub is a farm-to-customer marketplace for ordering produce and scheduling on-farm pickup. The repository contains three Flutter applications, a shared Dart package, and Firebase configuration. The applications and AI assistant use English for their interface text; names and addresses retain the values stored in Firebase.

| Component | Purpose |
| --- | --- |
| `apps/customer_app` | Browse farms and products, search, manage a multi-farm cart, schedule pickup, track orders, review purchases, save favorites, and use AI Sprout |
| `apps/farmer_app` | Manage the farm profile, products, inventory, pickup schedule, orders, and reports |
| `apps/admin_app` | Approve farmers and manage users, categories, products, orders, and analytics |
| `packages/harvesthub_core` | Shared models, services, controllers, UI components, and image assets |
| `firebase` | Firestore and Storage rules, indexes, sample data, and seed scripts |

## Requirements

- Flutter 3.47 or later and Dart 3.13 or later.
- JDK 17 and the Android SDK for Android builds.
- On Windows, enable Developer Mode so Flutter can create symlinks for plugins.
- Node.js 20 or later for Firebase Emulator and seed scripts.
- Firebase Authentication with Email/Password, Cloud Firestore, and Cloud Storage enabled. Each Android app has its own `android/app/google-services.json`.

## Run an app

Install dependencies for the shared package, then for the app you want to run:

```powershell
cd packages/harvesthub_core
flutter pub get
cd ../../apps/customer_app
flutter pub get
flutter run
```

Replace `customer_app` with `farmer_app` or `admin_app` to run the other apps. Run `flutter analyze` and `flutter test` inside each app and `packages/harvesthub_core` to check the source.

## Sample data and its source

[`firebase/data/catalog_snapshot.json`](firebase/data/catalog_snapshot.json) was exported from the **`harvesthub-c57ec`** Cloud Firestore project on **September 29, 2026** (Bangkok time). It contains 8 categories, 15 demo farms whose account emails end in `@harvesthub.app`, 128 products belonging to those farms, and 648 reviews marked `isDemo`. The 33 farm-category links were derived from those farms' existing product categories so that the product-listing flow has sample category data. Vietnamese demo text was translated to English, and emoji were removed from review tag labels.

Accounts with personal email addresses and their products are excluded. Orders, carts, notifications, contact messages, and the Gemini API key are also excluded. The included Android configurations connect to the existing Firebase project, which already contains data. **AI Sprout and content moderation remain in the source.**

### Sample image sources

The image fields in [`firebase/data/catalog_snapshot.json`](firebase/data/catalog_snapshot.json) preserve the values from the Firestore export:

- External category, farm, and product images whose URLs begin with `https://images.unsplash.com/` are served by [Unsplash](https://unsplash.com/). The exact image URLs are stored with the corresponding records in the snapshot. See the [Unsplash License](https://unsplash.com/license) for usage terms. These images need an internet connection to load.
- Some farm and product images are embedded as `data:image/jpeg;base64` values. They were copied from the existing `harvesthub-c57ec` Firestore records and load from the seed data itself. Those records do not identify the original photographer or external source, so their origin cannot be verified from the snapshot.

The snapshot does not include photographer names for the Unsplash URLs. Use the image URLs in the JSON to trace each image; do not treat the embedded images as Unsplash images.

## Restore the sample data

From `firebase/`, install dependencies:

```powershell
cd firebase
npm ci
```

To verify the seed without changing the live Firebase project, open two terminals in `firebase/`:

```powershell
# Terminal 1
npm run emulators

# Terminal 2, after the emulators start
npm run seed:emulator
```

Only `firebase/seed_snapshot.mjs` is run for seeding. It reads `firebase/data/catalog_snapshot.json` and creates demo accounts, categories, farms, products, and reviews. Running it again skips existing records; it does not reset passwords or stock. The Android apps currently connect to the live Firebase project through `google-services.json`; the Emulator steps above verify the seed data independently.

To restore the snapshot to another Firebase project, use a service account with the required permissions. Set `GOOGLE_APPLICATION_CREDENTIALS` to its JSON file, then run:

```powershell
npm run seed:project -- --project YOUR_PROJECT_ID --confirm-demo-project
```

New demo accounts created by the seed use these credentials:

| Role | Email | Password |
| --- | --- | --- |
| Administrator | `admin@harvesthub.app` | `Admin@123` |
| Farmer | `farmer1@harvesthub.app` and the other demo farmer emails in the snapshot | `Farmer@123` |
| Customer | `customer@harvesthub.app` | `Customer@123` |

The script does not change passwords for accounts that already exist. The committed snapshot is the sample-data backup for grading; no export step is needed to use it.

## Firebase and assets

Access rules are in `firebase/firestore.rules` and `firebase/storage.rules`; indexes are in `firebase/firestore.indexes.json`. Run `npm run test:snapshot` to validate the sample data, `npm run test:seed` to test the importer, and `npm run test:rules` to test Firebase rules with the Emulator (Java required).

Shared UI images are in `packages/harvesthub_core/assets/images/`. Launcher icons are in each app's platform resources; original logo artwork is in `assets/branding/`.
