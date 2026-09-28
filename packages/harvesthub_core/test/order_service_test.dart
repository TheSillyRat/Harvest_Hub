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

  test('isOverdueNoShow only applies to Ready for Pickup orders past pickup window end', () {
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
    expect(notifs.docs.first.data()['title'], contains('Cancel Order to Return Stock'));

    notifService.setCustomFirestore(null);
  });

  test('isOverduePending only applies to Pending orders past half of pickup window', () {
    final oldDate = DateTime.now().subtract(const Duration(days: 2));

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
      pickupDate: oldDate,
      total: 100,
      status: OrderStatus.pending,
      createdAt: oldDate,
      updatedAt: oldDate,
    );
    expect(overduePending.isOverduePending, isTrue);

    final recentPending = overduePending.copyWith(
      pickupDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now(),
    );
    expect(recentPending.isOverduePending, isFalse);

    final confirmedOld = overduePending.copyWith(status: OrderStatus.confirmed);
    expect(confirmedOld.isOverduePending, isFalse);

    final readyOld = overduePending.copyWith(status: OrderStatus.readyForPickup);
    expect(readyOld.isOverduePending, isFalse);
  });

  test('checkOverduePendingOrders sends notification to farmer for overdue pending orders', () async {
    final notifService = NotificationService.instance;
    notifService.setCustomFirestore(db);

    final oldDate = DateTime.now().subtract(const Duration(days: 2));
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
      pickupDate: oldDate,
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

  test('FarmerScheduleStatus extracts dynamic slots and evaluates slot availability', () {
    final slots2h = FarmerScheduleStatus.getSlotsForOperatingHours('14:00 - 16:00');
    expect(slots2h, ['14:00 – 16:00']);

    final slotsMulti = FarmerScheduleStatus.getSlotsForOperatingHours(
      '07:00 - 18:00',
      operatingSlots: [
        {'from': '07:00', 'to': '11:30'},
        {'from': '14:00', 'to': '18:00'},
      ],
    );
    expect(slotsMulti, ['07:00 – 11:30', '14:00 – 18:00']);

    final pastTime = DateTime(2026, 9, 28, 16, 30);
    expect(
      FarmerScheduleStatus.isSlotAvailableToday('14:00 - 16:00', now: pastTime),
      isFalse,
    );

    final ongoingTime = DateTime(2026, 9, 28, 14, 30);
    expect(
      FarmerScheduleStatus.isSlotAvailableToday('14:00 - 16:00', now: ongoingTime),
      isFalse,
    );

    final beforeSlotTime = DateTime(2026, 9, 28, 13, 30);
    expect(
      FarmerScheduleStatus.isSlotAvailableToday('14:00 - 16:00', now: beforeSlotTime),
      isTrue,
    );

    final at1550 = DateTime(2026, 9, 28, 15, 50);
    expect(
      FarmerScheduleStatus.isSlotAvailableToday('15:00 - 16:00', now: at1550),
      isFalse,
    );
    expect(
      FarmerScheduleStatus.isSlotAvailableToday('16:00 - 18:00', now: at1550),
      isTrue,
    );

    final schedule = FarmerScheduleStatus.calculate(
      operatingDays: ['Mon', 'Tue'],
      now: DateTime(2026, 9, 28),
    );
    expect(schedule.isOpenToday, isTrue);
    expect(schedule.isOpenTomorrow, isTrue);
  });

  test('placeOrders supports dynamic farmer pickup slots and custom shopDates', () async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await db.doc('carts/customer/items/produce').set(item.toMap());

    final ids = await service.placeOrders(
      'customer',
      [item],
      'Farm pickup',
      '14:00 – 16:00',
      shopSlots: {'farm': '14:00 – 16:00'},
      shopDates: {'farm': tomorrow},
    );
    expect(ids, hasLength(1));
    final doc = await db.collection('orders').doc(ids.first).get();
    expect(doc.data()!['pickupSlot'], '14:00 – 16:00');
    final savedPickupDate = readDate(doc.data()!['pickupDate']);
    expect(savedPickupDate.day, tomorrow.day);
  });
}
