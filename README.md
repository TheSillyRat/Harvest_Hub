# HarvestHub

GitHub: https://github.com/TheSillyRat/Harvest_Hub.git

HarvestHub connects farms with customers so they can browse produce, place orders, and schedule pickups. The project contains three Flutter apps that use Firebase.

## Project structure

- `apps/customer_app`: customer app for browsing and ordering products.
- `apps/farmer_app`: farmer app for managing farms, products, and orders.
- `apps/admin_app`: admin app for managing users and content.
- `packages/harvesthub_core`: shared code, UI components, and services.
- `firebase`: Firestore and Storage configuration, sample data, and seed script.
- `assets/branding`: project logos.

## Requirements

- Flutter SDK 3.47 or later (including Dart), Android Studio, and the Android SDK.
- JDK 17 for Android builds.
- Node.js 20 or later for Firebase Emulator and data seeding.
- On Windows, enable Developer Mode so Flutter can create plugin symlinks.
- An Android emulator or an Android phone with USB debugging enabled.

Run `flutter doctor` to check your setup and `flutter devices` to confirm that your device is available.

## Database and sample data

The project uses Firebase Authentication for sign-in, Cloud Firestore for data, and Cloud Storage for images. Each Android app includes a `google-services.json` file for the `harvesthub-c57ec` Firebase project. When using cloud Firebase, there is no local database server to start. The device needs internet access, and these Firebase services must be enabled in the Firebase Console.

Sample data is stored in `firebase/data/catalog_snapshot.json`. To start the local Firebase Emulator and seed it, open two PowerShell windows at the project root:

```powershell
# Window 1
cd firebase
npm ci
npm run emulators
```

```powershell
# Window 2, after the emulators have started
cd firebase
npm run seed:emulator
```

Open the Firebase Emulator UI at `http://localhost:4000`. The emulator data is useful for checking the seed script. The Flutter apps currently connect to cloud Firebase through `google-services.json`; they are not configured to use the local emulators.

To seed **another Firebase project**, set `GOOGLE_APPLICATION_CREDENTIALS` to a service account JSON file with write access, then run these commands from the `firebase` directory:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
npm ci
npm run seed:project -- --project YOUR_PROJECT_ID --confirm-demo-project
```

Before running the apps with another Firebase project, replace the `google-services.json` file in each app's `android/app/` directory with the matching configuration. The seed script creates missing records only; it does not change passwords for existing accounts.

New demo accounts created by the seed script are: admin `admin@harvesthub.app` / `Admin@123`, farmer `farmer1@harvesthub.app` / `Farmer@123`, and customer `customer@harvesthub.app` / `Customer@123`.

## Run an app on an emulator or a physical phone

Install dependencies for the shared package, then for the app you want to run. For example, from the project root, run the customer app with:

```powershell
cd packages/harvesthub_core
flutter pub get
cd ../../apps/customer_app
flutter pub get
flutter devices
flutter run
```

To run the farmer or admin app, replace `customer_app` in the `cd ../../apps/customer_app` command with `farmer_app` or `admin_app`.

- **Android emulator:** Start a virtual device in Android Studio before running `flutter run`.
- **Physical Android phone:** Enable Developer options and USB debugging, connect the phone by USB, and accept the debugging prompt on the phone. Run `flutter devices`, then `flutter run`. If several devices are listed, use `flutter run -d DEVICE_ID` with the ID shown by `flutter devices`.

Both Android emulators and physical phones need internet access to use the cloud Firebase project.
