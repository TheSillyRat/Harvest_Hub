import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late OrderService service;
  const item = CartItem(
    productId: 'produce',
    name: 'Carrots',
    price: 200,
    unit: 'kg',
    imageUrl: '',
    farmerId: 'farm',
    farmerName: 'Farm',
    qty: 2,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    service = OrderService(db: db);
    await db.doc('users/customer').set({
      'name': 'Buyer',
      'phone': '0123456789',
      'role': Roles.customer,
      'isActive': true,
    });
    await db.doc('farmers/farm').set({
      'businessName': 'Farm',
      'isActive': true,
    });
    await db.doc('products/produce').set({
      'name': 'Carrots',
      'farmerId': 'farm',
      'price': 200,
      'unit': 'kg',
      'stockQty': 5,
      'isActive': true,
    });
    await db.doc('carts/customer/items/produce').set(item.toMap());
  });

  test(
      'checkout persists one order, reduces stock and removes purchased cart item',
      () async {
    final ids = await service.placeOrders(
      'customer',
      [item],
      'Farm pickup',
      'morning_07_10',
    );
    expect(ids, hasLength(1));
    final orders = await db.collection('orders').get();
    expect(orders.docs, hasLength(1));
    expect(orders.docs.single.data()['total'], 400);
    expect(orders.docs.single.data()['customerId'], 'customer');
    expect((await db.doc('products/produce').get()).data()!['stockQty'], 3);
    expect(
        (await db.doc('carts/customer/items/produce').get()).exists, isFalse);
  });

  test('insufficient stock leaves orders and cart unchanged', () async {
    await db.doc('products/produce').update({'stockQty': 1});
    await expectLater(
      service.placeOrders('customer', [item], 'Farm pickup', 'morning_07_10'),
      throwsStateError,
    );
    expect((await db.collection('orders').get()).docs, isEmpty);
    expect((await db.doc('carts/customer/items/produce').get()).exists, isTrue);
    expect((await db.doc('products/produce').get()).data()!['stockQty'], 1);
  });

  test('isOverdueNoShow only applies to Ready for Pickup orders overdue by 12h', () {
    final pastDate = DateTime.now().subtract(const Duration(days: 2));

    final pendingOrder = FarmOrder(
      id: 'o_pending',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '123',
      farmerId: 'f1',
      farmerName: 'Farmer',
      items: const [],
      address: 'Address',
      pickupSlot: 'morning_07_10',
      pickupDate: pastDate,
      total: 100,
      status: OrderStatus.pending,
      createdAt: pastDate,
      updatedAt: pastDate,
    );
    expect(pendingOrder.isOverdueNoShow, isFalse);

    final confirmedOrder = pendingOrder.copyWith(status: OrderStatus.confirmed);
    expect(confirmedOrder.isOverdueNoShow, isFalse);

    final completedOrder = pendingOrder.copyWith(status: OrderStatus.completed);
    expect(completedOrder.isOverdueNoShow, isFalse);

    final overdueReadyOrder = pendingOrder.copyWith(status: OrderStatus.readyForPickup);
    expect(overdueReadyOrder.isOverdueNoShow, isTrue);

    final recentReadyOrder = FarmOrder(
      id: 'o_recent_ready',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '123',
      farmerId: 'f1',
      farmerName: 'Farmer',
      items: const [],
      address: 'Address',
      pickupSlot: 'morning_07_10',
      pickupDate: DateTime.now().add(const Duration(days: 1)),
      total: 100,
      status: OrderStatus.readyForPickup,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(recentReadyOrder.isOverdueNoShow, isFalse);
  });

  test('checkOverdueNoShowOrders sends notification to farmer for overdue ready orders', () async {
    final notifService = NotificationService.instance;
    notifService.setCustomFirestore(db);

    final pastDate = DateTime.now().subtract(const Duration(days: 2));
    final overdueOrder = FarmOrder(
      id: 'ord_overdue_123',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '123',
      farmerId: 'farmer_target_1',
      farmerName: 'Farmer',
      items: const [],
      address: 'Address',
      pickupSlot: 'morning_07_10',
      pickupDate: pastDate,
      total: 100,
      status: OrderStatus.readyForPickup,
      createdAt: pastDate,
      updatedAt: pastDate,
    );

    await service.checkOverdueNoShowOrders([overdueOrder]);

    final notifs = await db.collection('notifications').where('userId', isEqualTo: 'farmer_target_1').get();
    expect(notifs.docs, hasLength(1));
    expect(notifs.docs.first.data()['type'], 'no_show');
    expect(notifs.docs.first.data()['targetId'], 'ord_overdue_123');
    expect(notifs.docs.first.data()['title'], contains('Cancel to Restock'));

    notifService.setCustomFirestore(null);
  });

  test('isOverduePending only applies to Pending orders older than 6 hours', () {
    final oldDate = DateTime.now().subtract(const Duration(hours: 7));
    final recentDate = DateTime.now().subtract(const Duration(hours: 2));

    final overduePending = FarmOrder(
      id: 'o_overdue_pending',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '123',
      farmerId: 'f1',
      farmerName: 'Farmer',
      items: const [],
      address: 'Address',
      pickupSlot: 'morning_07_10',
      pickupDate: DateTime.now(),
      total: 100,
      status: OrderStatus.pending,
      createdAt: oldDate,
      updatedAt: oldDate,
    );
    expect(overduePending.isOverduePending, isTrue);

    final recentPending = overduePending.copyWith(createdAt: recentDate);
    expect(recentPending.isOverduePending, isFalse);

    final confirmedOld = overduePending.copyWith(status: OrderStatus.confirmed);
    expect(confirmedOld.isOverduePending, isFalse);

    final readyOld = overduePending.copyWith(status: OrderStatus.readyForPickup);
    expect(readyOld.isOverduePending, isFalse);
  });

  test('checkOverduePendingOrders sends notification to farmer for overdue pending orders', () async {
    final notifService = NotificationService.instance;
    notifService.setCustomFirestore(db);

    final oldDate = DateTime.now().subtract(const Duration(hours: 8));
    final overduePending = FarmOrder(
      id: 'ord_pending_6h_1',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '123',
      farmerId: 'farmer_pending_target',
      farmerName: 'Farmer',
      items: const [],
      address: 'Address',
      pickupSlot: 'morning_07_10',
      pickupDate: DateTime.now(),
      total: 100,
      status: OrderStatus.pending,
      createdAt: oldDate,
      updatedAt: oldDate,
    );

    await service.checkOverduePendingOrders([overduePending]);

    final notifs = await db.collection('notifications').where('userId', isEqualTo: 'farmer_pending_target').get();
    expect(notifs.docs, hasLength(1));
    expect(notifs.docs.first.data()['type'], 'pending_reminder');
    expect(notifs.docs.first.data()['targetId'], 'ord_pending_6h_1');

    notifService.setCustomFirestore(null);
  });
}
