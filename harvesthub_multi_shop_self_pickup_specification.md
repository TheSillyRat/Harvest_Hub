# TECHNICAL SPECIFICATION: MULTI-SHOP SELF-PICKUP CHECKOUT & ORDER FLOW

**System:** HarvestHub Mobile App (TechWiz Specification)  
**Architecture Model:** Shopee-like Multi-Vendor Grouping with In-Person Pickup Fulfillment  
**Primary Roles:** `Customer`, `Farmer`, `Administrator`  
**Target Environment:** Flutter / Dart, SQLite / Cloud Firestore  

---

## 1. COMPONENT OVERVIEW & SYSTEM CONSTRAINTS

1. **No External Logistics / 3PL:** The application strictly implements in-person collection (`Pickup Scheduling`) at the farmer's stall or market location. Shipping addresses and delivery fee calculations are omitted.
2. **Multi-Shop Cart Partitioning:** When a customer checks out items from multiple farmers simultaneously, the checkout screen groups items by `Farmer_Id`. Upon checkout, the system performs an atomic split into distinct `Order` records per farmer.
3. **Location-Aware Self-Pickup:** Each shop section exposes the farm or market address, operating hours, real-time Haversine distance from the user's current GPS coordinates, and an external intent link to Google Maps navigation.
4. **Independent Slot Selection:** Customers must select an explicit pickup window (`Pickup_Slot_Time`) for each distinct farmer prior to submitting the simulated order.

---

## 2. DATA SCHEMAS & CONTRACTS

### 2.1 Extended Order Document (`Orders` Collection)

```json
{
  "order_id": "String (UUID / Firestore Document ID)",
  "customer_id": "String (Ref: Users.User_Id)",
  "customer_name": "String",
  "customer_phone": "String",
  "farmer_id": "String (Ref: Farmers.Farmer_Id)",
  "market_id": "String (Ref: FarmersMarket.Market_Id, nullable)",
  "market_snapshot": {
    "market_name": "String",
    "address": "String",
    "latitude": "Float",
    "longitude": "Float",
    "operating_hours": "String"
  },
  "pickup_slot_time": "String (e.g. '2026-09-28 09:00 - 11:00')",
  "status": "String (Enum: 'Pending' | 'Confirmed' | 'Ready for Pickup' | 'Completed' | 'Cancelled')",
  "items": [
    {
      "product_id": "String (Ref: Products.Product_Id)",
      "item_name": "String",
      "price_per_unit": "Float",
      "quantity": "Integer",
      "subtotal": "Float"
    }
  ],
  "total_price": "Float",
  "created_at": "Timestamp",
  "updated_at": "Timestamp"
}
```

### 2.2 Cart Item State Model

```json
{
  "cart_item_id": "String",
  "product_id": "String",
  "farmer_id": "String",
  "farmer_name": "String",
  "market_id": "String",
  "item_name": "String",
  "image_url": "String",
  "price_per_unit": "Float",
  "quantity": "Integer",
  "stock_qty": "Integer",
  "is_selected": "Boolean"
}
```

---

## 3. CHECKOUT UI & BUSINESS LOGIC SPECIFICATION

### 3.1 Screen Layout Hierarchy (Shopee-Style Grouping)

1. **Header Section: Collector Information**
   * Customer full name (`Full Name`).
   * Contact phone number (`Mobile Phone Number`).
   * Note informing customer that contact details are used for order verification at pickup.

2. **Body Section: Multi-Shop Grouped Cards (`ListView`)**
   * For each distinct `Farmer_Id` present in selected cart items:
     * **Farmer Header:** Business Name + Verification Badge.
     * **Pickup Location Block:**
       * Market Name & Street Address.
       * Operating Hours badge (e.g., `07:00 - 18:00`).
       * Geodesic Distance: Computed distance between `device_lat_lng` and `market_lat_lng` formatted as `XX.X km` or `XXX m`.
       * **Google Maps Action Button:** Triggers URI schema `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}`.
     * **Product Items List:** Item thumbnail, product name, quantity, unit price, line subtotal.
     * **Pickup Slot Selector (`Dropdown` / `BottomSheet`):**
       * Populated dynamically using the farmer's `Operating_Hours`.
       * Filters out slots that have already passed for the current date.
       * Required field. Selection is mandatory per shop card.
     * **Shop Subtotal Calculation:** Displays `Sum(price_per_unit * quantity)` for items in this shop.

3. **Footer Section: Persistent Sticky Action Bar**
   * Cumulative Price: Sum of subtotals across all selected shop groups.
   * Fulfillment Notice: "Direct Pickup at Farm/Market".
   * Action Button: **"Place Order (Simulated Checkout)"**.
     * Enabled only if:
       * All shop sections have a valid `pickup_slot_time` selected.
       * All line items satisfy `quantity <= stock_qty` and `stock_qty > 0`.

---

## 4. MATHEMATICAL & TECHNICAL IMPLEMENTATION DETAILS

### 4.1 Geodesic Distance Calculation (Haversine Formula)

To compute distance $d$ between the customer $( \varphi_1, \lambda_1 )$ and the farm/market $( \varphi_2, \lambda_2 )$:

$$\Delta\varphi = \frac{(\text{lat}_2 - \text{lat}_1) \cdot \pi}{180}, \quad \Delta\lambda = \frac{(\text{lon}_2 - \text{lon}_1) \cdot \pi}{180}$$

$$a = \sin^2\left(\frac{\Delta\varphi}{2}\right) + \cos\left(\frac{\text{lat}_1 \cdot \pi}{180}\right) \cdot \cos\left(\frac{\text{lat}_2 \cdot \pi}{180}\right) \cdot \sin^2\left(\frac{\Delta\lambda}{2}\right)$$

$$c = 2 \cdot \text{atan2}\left(\sqrt{a}, \sqrt{1-a}\right), \quad d = R \cdot c \quad (R = 6371\text{ km})$$

### 4.2 External Google Maps Deep Linking Schema

```dart
// Flutter URL Launcher Implementation Contract
import 'package:url_launcher/url_launcher.dart';

Future<void> launchMapsNavigation(double destLat, double destLng) async {
  final Uri googleMapsUrl = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving'
  );
  
  if (await canLaunchUrl(googleMapsUrl)) {
    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
  } else {
    throw Exception('Could not open map navigation for $destLat, $destLng');
  }
}
```

---

## 5. ORDER SPLITTING TRANSACTION ALGORITHM (PSEUDOCODE)

```python
def process_multi_shop_checkout(customer_id, selected_cart_items, shop_slots_map):
    # Step 1: Validate stock quantity atomically
    for item in selected_cart_items:
        product = db.products.get(item.product_id)
        if product.stock_qty <= 0 or product.stock_qty < item.quantity:
            raise OutOfStockException(f"Product {item.item_name} is insufficient.")

    # Step 2: Group selected items by Farmer_Id
    grouped_by_farmer = group_by(selected_cart_items, key=lambda x: x.farmer_id)
    created_orders = []

    # Step 3: Run Database Atomic Transaction
    with db.transaction():
        for farmer_id, items_list in grouped_by_farmer.items():
            farmer_profile = db.farmers.get(farmer_id)
            market_profile = db.farmers_market.get(farmer_profile.market_id)
            slot_time = shop_slots_map.get(farmer_id)

            if not slot_time:
                raise InvalidPickupSlotException(f"Pickup slot missing for farmer {farmer_id}")

            sub_total = sum(i.price_per_unit * i.quantity for i in items_list)

            # 3a. Create new standalone order per shop
            order_data = {
                "order_id": generate_uuid(),
                "customer_id": customer_id,
                "farmer_id": farmer_id,
                "market_id": market_profile.market_id,
                "market_snapshot": {
                    "market_name": market_profile.market_name,
                    "address": market_profile.address,
                    "latitude": market_profile.gps_coordinates.latitude,
                    "longitude": market_profile.gps_coordinates.longitude,
                    "operating_hours": market_profile.operating_hours
                },
                "items": items_list,
                "pickup_slot_time": slot_time,
                "total_price": sub_total,
                "status": "Pending",
                "created_at": current_timestamp(),
                "updated_at": current_timestamp()
            }
            order_ref = db.orders.create(order_data)
            created_orders.append(order_ref.order_id)

            # 3b. Decrement stock inventory
            for i in items_list:
                db.products.update(i.product_id, {
                    "stock_qty": db.increment(-i.quantity)
                })

            # 3c. Send push notification to specific Farmer
            push_notification_service.send(
                recipient_id=farmer_id,
                title="New Order Received",
                body=f"New order placed for pickup slot: {slot_time}"
            )

        # Step 4: Purge checked-out items from customer's active cart
        db.cart.remove_items(customer_id, [i.cart_item_id for i in selected_cart_items])

    return created_orders
```

---

## 6. ORDER DETAIL / POST-PURCHASE VIEW

Once orders are generated:
* In the Customer's **Order History** and **Order Detail** screens, each shop order retains its snapshot of:
  * Address and Market Name.
  * Distance (recalculated using current user location).
  * Direct action button to re-trigger Google Maps navigation.
* When the Farmer sets `Status = 'Ready for Pickup'`, the customer receives a push notification and can tap the notification directly into the Order Detail screen to trigger Google Maps directions to the pickup stall.