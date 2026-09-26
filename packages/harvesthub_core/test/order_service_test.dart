import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
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
}
