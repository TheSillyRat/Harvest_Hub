import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  late FakeFirebaseFirestore db;
  late OrderService service;
  late List<CartItem> cart;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = OrderService(db: db);
    final now = DateTime(2026, 9, 23);
    await db.doc('users/customer').set(AppUser(uid: 'customer', name: 'Khách', email: 'customer@harvesthub.app',
      phone: '0900000000', address: 'Đà Lạt', role: Roles.customer, isActive: true, createdAt: now).toMap());
    cart = [];
    for (var i = 1; i <= 2; i++) {
      await db.doc('farmers/farmer$i').set(FarmerProfile(uid: 'farmer$i', userId: 'farmer$i',
        businessName: 'Gian hàng $i', description: '', area: 'Đà Lạt', rating: 5, isActive: true, createdAt: now).toMap());
      final p = Product(id: 'p$i', farmerId: 'farmer$i', farmerName: 'Gian hàng $i', name: 'Nông sản $i',
        categoryId: 'vegetables', description: '', price: 35000, unit: 'kg', stockQty: 10, imageUrl: '',
        isActive: true, createdAt: now, updatedAt: now);
      await db.doc('products/p$i').set(p.toMap());
      final item = CartItem.fromProduct(p, 3);
      cart.add(item);
      await db.doc('carts/customer/items/p$i').set(item.toMap());
    }
  });
  test('two farmers create two orders, deduct stock and consume cart atomically per group', () async {
    final ids = await service.placeOrders('customer', cart, 'Đà Lạt', 'morning_07_10');
    expect(ids, hasLength(2));
    for (var i = 1; i <= 2; i++) {
      expect((await db.doc('products/p$i').get()).data()!['stockQty'], 7);
    }
    expect((await db.collection('carts/customer/items').get()).docs, isEmpty);
    final orders = (await service.streamByCustomer('customer').first);
    expect(orders.map((o) => o.farmerId).toSet(), {'farmer1', 'farmer2'});
    expect(orders.every((o) => o.total == 105000 && o.status == OrderStatus.pending), isTrue);
  });
  test('price change prevents purchase and leaves cart and inventory unchanged', () async {
    await db.doc('products/p1').update({'price': 40000});
    await expectLater(service.placeOrders('customer', cart, 'Đà Lạt', 'morning_07_10'), throwsStateError);
    expect((await db.collection('orders').get()).docs, isEmpty);
    expect((await db.doc('products/p1').get()).data()!['stockQty'], 10);
    expect((await db.collection('carts/customer/items').get()).docs, hasLength(2));
  });
  test('partial checkout preserves failed group and exposes successful IDs', () async {
    await db.doc('products/p2').update({'stockQty': 0});
    await expectLater(service.placeOrders('customer', cart, 'Đà Lạt', 'afternoon_15_18'),
      throwsA(isA<PartialCheckoutException>().having((e) => e.orderIds.length, 'successful orders', 1)));
    expect((await db.doc('carts/customer/items/p1').get()).exists, isFalse);
    expect((await db.doc('carts/customer/items/p2').get()).exists, isTrue);
    expect((await db.doc('products/p1').get()).data()!['stockQty'], 7);
    expect((await db.collection('orders').get()).docs, hasLength(1));
  });
  test('confirmed cancellation restores stock once', () async {
    final ids = await service.placeOrders('customer', [cart.first], 'Đà Lạt', 'morning_07_10');
    await service.advanceStatus(ids.single);
    expect((await db.doc('orders/${ids.single}').get()).data()!['status'], OrderStatus.confirmed);
    await service.cancel(ids.single);
    expect((await db.doc('products/p1').get()).data()!['stockQty'], 10);
    await expectLater(service.cancel(ids.single), throwsStateError);
    expect((await db.doc('products/p1').get()).data()!['stockQty'], 10);
  });
  test('ready and completed orders cannot cancel; completed cannot advance', () async {
    final ids = await service.placeOrders('customer', [cart.first], 'Đà Lạt', 'morning_07_10');
    await service.advanceStatus(ids.single);
    await service.advanceStatus(ids.single);
    await expectLater(service.cancel(ids.single), throwsStateError);
    await service.advanceStatus(ids.single);
    await expectLater(service.cancel(ids.single), throwsStateError);
    await expectLater(service.advanceStatus(ids.single), throwsStateError);
    expect((await db.doc('products/p1').get()).data()!['stockQty'], 7);
  });
  test('invalid slots, quantities, duplicate items and empty cart are rejected', () async {
    await expectLater(service.placeOrders('customer', cart, 'Đà Lạt', 'invalid'), throwsArgumentError);
    await expectLater(service.placeOrders('customer', [], 'Đà Lạt', 'morning_07_10'), throwsArgumentError);
    await expectLater(service.placeOrders('customer', [cart.first, cart.first], 'Đà Lạt', 'morning_07_10'), throwsArgumentError);
    await expectLater(service.placeOrders('customer', [cart.first.copyWith(qty: 0)], 'Đà Lạt', 'morning_07_10'), throwsArgumentError);
  });
  test('product edit cannot overwrite stock changed after the form opened', () async {
    final products = ProductService(db: db);
    final original = (await products.get('p1'))!;
    await service.placeOrders('customer', [cart.first], 'Đà Lạt', 'morning_07_10');
    await expectLater(products.update(original.copyWith(name: 'Tên mới'), expectedUpdatedAt: original.updatedAt), throwsStateError);
    expect((await products.get('p1'))!.stockQty, 7);
  });
}
