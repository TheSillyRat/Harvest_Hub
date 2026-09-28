# Wishlist & Farmer Follow System

Integrated into `customer_app`; designed with an English user interface matching the application standard.

---

## 📌 Feature Overview & Usage

- **Save Produce**: Tap the heart icon on any product card or details sheet to toggle save state. Out-of-stock items can still be bookmarked for future restocks.
- **View Saved Products**: Access **Saved** via the heart icon in the main search bar, or through **Profile → My Wishlist**.
- **Follow Farmers**: Tap **Follow / Following** on any farmer card or under the **About the Farm** section in product details.
- **View Followed Farmers**: Open the **Following** tab on the Saved screen, from the Following toggle in the Farmers tab, or via **Profile → Following**.
- **Sorting & Direct Action**: Lists are automatically sorted by most recently saved. Tap a product to inspect full details, or tap **View Products** to browse a farmer's active inventory.
- **Resilient Management**: Deactivated or deleted items can still be removed from personal lists. Failed network reads provide an inline retry option, and buttons are debounced during pending writes.

---

## 🔒 Data Schemas & Security Rules

| Firestore Path | Document Fields | Description |
| :--- | :--- | :--- |
| `wishlists/{uid}/items/{productId}` | `productId`, `savedAt` | Customer saved product record |
| `farmerFollows/{uid}/items/{farmerId}` | `farmerId`, `savedAt` | Customer followed farm record |

- **Security Model**: `savedAt` uses server-side timestamps (`request.time`). Document IDs mirror the target product or farmer ID, guaranteeing idempotent writes and zero duplicate entries.
- **Access Control**: Only active customers can write to their personal subcollections; target products or farmers must exist and be active. Active account holders can read and delete their own records even if a target item has subsequently been retired. Cross-user reading or tampering is strictly denied by Firestore Security Rules.
- **State Synchronization**: `SavedItemsController` binds to the active user's UID from `AuthController`, listens reactively to both subcollections, and purges local state on logout or account switch. Optimistic UI updates provide immediate feedback with automatic local rollback if a server rejection occurs.

---

## 🧪 Testing & Verification

```powershell
# From apps/customer_app
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub

# From packages/harvesthub_core
flutter test --no-pub test/saved_items_service_test.dart

# From firebase (requires local Java runtime for emulators)
npm run test:rules
```

Test coverage encompasses cross-widget synchronization, saving/unsaving, multi-device stream updates, insertion ordering, error recovery, duplicate submission debouncing, account switching during active writes, detail routing, handling out-of-stock items, 320px narrow layout scalability with high font scaling, and Firestore declarative security rule enforcement.
