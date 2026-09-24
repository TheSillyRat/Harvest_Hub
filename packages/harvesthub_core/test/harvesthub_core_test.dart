import 'package:flutter_test/flutter_test.dart';

import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  test('order snapshots survive Firestore round trip', () {
    final now = DateTime(2026, 9, 23, 8);
    final order = FarmOrder(
        id: 'order',
        customerId: 'customer',
        customerName: 'Khách',
        customerPhone: '0900000000',
        farmerId: 'farmer',
        farmerName: 'Vườn Xanh',
        items: const [
          OrderItem(
              productId: 'tomato',
              name: 'Cà chua bi',
              price: 35000,
              unit: 'kg',
              imageUrl: '',
              qty: 3,
              subtotal: 105000)
        ],
        address: 'Đà Lạt',
        pickupSlot: 'morning_07_10',
        pickupDate: now,
        total: 105000,
        status: OrderStatus.pending,
        createdAt: now,
        updatedAt: now);
    final restored = FarmOrder.fromMap(order.toMap(), id: order.id);
    expect(restored.items.single.subtotal, 105000);
    expect(restored.createdAt, now);
    expect(restored.copyWith(status: OrderStatus.confirmed).status,
        OrderStatus.confirmed);
    expect(restored.status, OrderStatus.pending);
    expect(restored.toMap(), order.toMap());
  });
  test('only the specified transitions and cancellation states exist', () {
    expect(OrderStatus.next, {
      'Pending': 'Confirmed',
      'Confirmed': 'ReadyForPickup',
      'ReadyForPickup': 'Completed',
    });
    expect(OrderStatus.canCancel('Pending'), isTrue);
    expect(OrderStatus.canCancel('Confirmed'), isTrue);
    for (final status in ['ReadyForPickup', 'Completed', 'Cancelled']) {
      expect(OrderStatus.canCancel(status), isFalse);
    }
    expect(OrderStatus.next['Completed'], isNull);
    expect(OrderStatus.next['Cancelled'], isNull);
    expect(OrderStatus.labels.length, 5);
    expect(pickupSlots.keys, ['morning_07_10', 'afternoon_15_18']);
  });
  test('cart snapshot has integer VND subtotal', () {
    const item = CartItem(
        productId: 'p',
        name: 'Táo',
        price: 55000,
        unit: 'kg',
        imageUrl: '',
        farmerId: 'f',
        farmerName: 'Vườn',
        qty: 3);
    expect(CartItem.fromMap(item.toMap()).subtotal, 165000);
    expect(item.copyWith(qty: 2).subtotal, 110000);
    expect(item.qty, 3);
  });
}
