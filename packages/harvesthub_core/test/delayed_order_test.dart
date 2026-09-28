import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late OrderService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    service = OrderService(db: db);

    await db.doc('products/prod_apple').set({
      'name': 'Organic Apples',
      'farmerId': 'farmer_test',
      'price': 300,
      'unit': 'kg',
      'stockQty': 10,
      'isActive': true,
    });
  });

  test('auto-cancels pending orders older than 12 hours and restocks items', () async {
    final overdueOrderTime = DateTime.now().subtract(const Duration(hours: 13));
    final recentOrderTime = DateTime.now().subtract(const Duration(hours: 2));

    await db.doc('orders/ord_overdue').set({
      'customerId': 'cust_1',
      'customerName': 'Alice',
      'farmerId': 'farmer_test',
      'farmerName': 'Apple Farm',
      'address': 'Farm 1',
      'pickupSlot': 'morning_07_10',
      'pickupDate': Timestamp.fromDate(overdueOrderTime),
      'status': OrderStatus.pending,
      'total': 600,
      'createdAt': Timestamp.fromDate(overdueOrderTime),
      'updatedAt': Timestamp.fromDate(overdueOrderTime),
      'items': [
        {
          'productId': 'prod_apple',
          'name': 'Organic Apples',
          'price': 300,
          'unit': 'kg',
          'imageUrl': '',
          'qty': 2,
          'subtotal': 600,
        }
      ],
    });

    await db.doc('orders/ord_recent').set({
      'customerId': 'cust_2',
      'customerName': 'Bob',
      'farmerId': 'farmer_test',
      'farmerName': 'Apple Farm',
      'address': 'Farm 1',
      'pickupSlot': 'morning_07_10',
      'pickupDate': Timestamp.fromDate(recentOrderTime),
      'status': OrderStatus.pending,
      'total': 300,
      'createdAt': Timestamp.fromDate(recentOrderTime),
      'updatedAt': Timestamp.fromDate(recentOrderTime),
      'items': [
        {
          'productId': 'prod_apple',
          'name': 'Organic Apples',
          'price': 300,
          'unit': 'kg',
          'imageUrl': '',
          'qty': 1,
          'subtotal': 300,
        }
      ],
    });

    final cancelled = await service.checkAndCancelOverduePendingOrders();
    expect(cancelled.any((o) => o.id == 'ord_overdue'), isTrue);

    final overdueDoc = await db.doc('orders/ord_overdue').get();
    expect(overdueDoc.data()!['status'], OrderStatus.cancelled);
    expect(overdueDoc.data()!['cancellationReason'], 'auto_timeout_12h');

    final recentDoc = await db.doc('orders/ord_recent').get();
    expect(recentDoc.data()!['status'], OrderStatus.pending);

    final prodDoc = await db.doc('products/prod_apple').get();
    expect(prodDoc.data()!['stockQty'], 12);

    final logs = await service.fetchDelayedOrderLogs();
    expect(logs, isNotEmpty);
    expect(logs.any((l) => l.orderId == 'ord_overdue'), isTrue);
  });
}
