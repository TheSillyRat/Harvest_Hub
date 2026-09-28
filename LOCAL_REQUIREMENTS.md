# Project Guidelines & Feature Tracking

## 📌 Development Rules
1. **English Only**:
   - All code, variable names, documentation, UI text, and git commit messages must be strictly in English.

2. **No `//` Single-line Comments**:
   - Do not include `//` comments in code files. Use `/* */` block comments if needed.

3. **Branch Target**:
   - Push all completed tasks and updates directly to branch `SangHuynh`.

4. **Version Control**:
   - Project feature tracker and guidelines tracked in `LOCAL_REQUIREMENTS.md`.

5. **Human-Style Granular Commits & Staggered Pushes**:
   - Split modifications into small, single-purpose commits (commit 1 small change/module at a time).
   - Use natural human-like commit messages (e.g. "update filter", "update method edit profile", "fix cart order button"). Avoid overly formatted AI commit messages.
   - Push commits sequentially with a random delay of 15 to 30 minutes between pushes until all commits are pushed.

---

## 🎯 Task Tracker: Sang Huỳnh (Sang Nguyễn) - Customer App Features

| Task Name | Priority | Deadline | Status | Detailed Requirements & Notes |
| :--- | :---: | :---: | :---: | :--- |
| **1. Customer Authentication & Profile Management** | 🔴 High | 25/09/2026 | 🟢 Completed | • Auth login & registration screens created.<br>• Profile edit sheet (`CustomerEditProfileSheet`) allows editing Name, Phone, and Address with live Firestore sync. |
| **2. Search & Filtering Engine** | 🟡 Medium | 26/09/2026 | 🟢 Completed | • Real-time search bar & category navigation.<br>• Filter & Sort Bottom Sheet (`_showFilterBottomSheet`): Sort (Featured, Price Low->High, Price High->Low, Name), In-Stock toggle, and active filter badge. |
| **3. AI Farm Products Assistant** | 🟡 Medium | 27/09/2026 | 🟢 Completed | • Integrated Gemini 1.5 Flash AI Assistant (`ChatbotScreen` / `FaqService`) with live store inventory awareness, intent classification, pinned product cards, and offline fallback. |
| **4. Order History & Current Order Status Tracking** | 🔴 High | 27/09/2026 | 🟢 Completed | • Stream real-time orders from Firestore (`OrderService.streamByCustomer`).<br>• Status Filter Chips (All, Pending, Confirmed, Ready, Completed, Cancelled).<br>• `OrderTrackingSheet` timeline stepper & interactive direct order cancellation with inventory auto-restock. |
| **5. Disable "Out of Stock" Purchases** | 🔴 High | 27/09/2026 | 🟢 Completed | • Zero stock badge ("OUT OF STOCK") with greyscale image indicator.<br>• Disabled "Add to Basket" & Quick Add button on cards and detail sheet when stock quantity is 0, capping max quantity at available stock. |
| **6. Farm Map Discovery & Interactive Search** | 🔴 High | 27/09/2026 | 🟢 Completed | • OpenStreetMap integration with GPS geolocation & distance calculation.<br>• Accent-insensitive search matching (Vietnamese diacritics removal across name, farmer, area, address, pickup point, description, and phone).<br>• Real-time floating search suggestions dropdown with auto camera panning, zoom focus, and card preview selection. |

---

## 📦 Comparison: Features in `D:\TechWiz7\HarvestHub` missing/incomplete in current app (`TecchWiz/Harvest_Hub`)

### 🛒 Customer App Missing & Incomplete Features Matrix:

| Feature Area | Source Code Reference (`HarvestHub`) | Current App Status (`TecchWiz`) | Responsible Member | Action Required |
| :--- | :--- | :--- | :---: | :--- |
| **AI Farm Assistant (Chatbot)** | `apps/customer_app/lib/customer_app.dart` (`ChatbotScreen`, `FaqService`) | Not connected in UI | **Sang Huỳnh** | Integrate chatbot screen into Customer App profile / floating action or main navigation. |
| **Order History & Real-Time Tracking** | `apps/customer_app/lib/customer_app.dart` (`OrdersScreen`, `OrderService.streamByCustomer`) | Static mock UI (`_buildOrdersScreen`) | **Sang Huỳnh** | Replace static UI with Firestore order stream list & status progress indicator. |
| **Wishlist & Favorite Items** | `apps/customer_app/lib/customer_app.dart` (`WishlistScreen`, `WishlistService`) | Missing from main navigation | **Tài** | Add Wishlist toggle on product cards & create Wishlist screen. |
| **Pickup Slot Selection & Order Checkout** | `apps/customer_app/lib/customer_app.dart` (`CheckoutScreen`, `pickupSlots`) | Simplified sheet modal | **Tài** | Enhance checkout with pickup slot selection dropdown & multi-stall handling. |
| **Push Notification Receiver** | Firebase Cloud Messaging (FCM) handlers | Not configured | **Tài** | Setup FCM listeners for restock alerts & order status changes. |

