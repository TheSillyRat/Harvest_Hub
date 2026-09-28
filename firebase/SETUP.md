# Firebase Setup Guide

## ☁️ Cloud Project Deployment

1. Create a Firebase project named **HarvestHub** on the [Firebase Console](https://console.firebase.google.com).
2. Enable **Authentication** → **Email/Password** sign-in provider.
3. Provision a **Cloud Firestore** database in production mode.
4. Enable **Cloud Storage for Firebase** for product photo uploads.
5. Register three independent Android applications using their respective application IDs:
   - `com.harvesthub.customer` (Customer App)
   - `com.harvesthub.farmer` (Farmer App)
   - `com.harvesthub.admin` (Admin App)
6. Download each generated `google-services.json` file and place it in the correct app folder:
   - `apps/customer_app/android/app/google-services.json`
   - `apps/farmer_app/android/app/google-services.json`
   - `apps/admin_app/android/app/google-services.json`

### Deploying Security Rules & Indexes

From the repository root:

```powershell
cd firebase
npm install
cd ..

# Log in to Firebase CLI
./firebase/node_modules/.bin/firebase login

# Set active project
./firebase/node_modules/.bin/firebase use --add

# Deploy Firestore rules, composite indexes, and Storage rules
./firebase/node_modules/.bin/firebase deploy --only firestore:rules,firestore:indexes,storage
```

---

## 💻 Local Emulators & Testing Environment

To develop or run tests offline without touching production Firebase data:

From `HarvestHub/firebase`:

```powershell
npm install
npm run emulators
```

- **Auth Port**: `9099`
- **Firestore Port**: `8180`
- **Storage Port**: `9199`
- **Emulator UI**: `http://localhost:4000`
- **Project ID**: `demo-harvesthub`

### Seeding Emulator Data

While the emulator process is running, open a second terminal in `HarvestHub/firebase`:

```powershell
npm run seed:emulator
```

This populates default testing accounts, product categories, and sample agricultural listings into the local Firestore instance.

### Running Security Rules Test Suite

Ensure background emulators are stopped before launching unit test suites (the testing runner provisions and cleans its own isolated emulator instances):

```powershell
npm run test:rules
```

### Connecting Flutter Apps to Local Emulators

For Android emulators, the host machine is reached via `10.0.2.2`:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```
