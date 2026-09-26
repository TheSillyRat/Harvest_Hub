import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

class PartialCheckoutException implements Exception {
  final List<String> orderIds;
  final Object cause;
  PartialCheckoutException(this.orderIds, this.cause);
  @override
  String toString() =>
      'Created ${orderIds.length} orders. Remaining items stay in cart. $cause';
}

FirebaseFirestore? _safeFirestore() {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

class OrderService {
  final FirebaseFirestore? _db;
  OrderService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore? get db => _db ?? _safeFirestore();

  Stream<List<FarmOrder>> _stream(Query<Map<String, dynamic>>? q) {
    if (q == null) return Stream.value([]);
    return q.snapshots().map((s) =>
        s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList());
  }

  Stream<List<FarmOrder>> streamByCustomer(String uid) {
    final firestore = db;
    if (firestore == null) return Stream.value([]);
    return _stream(firestore
        .collection('orders')
        .where('customerId', isEqualTo: uid))
        .map((items) {
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Stream<List<FarmOrder>> streamByFarmer(String uid) {
    final firestore = db;
    if (firestore == null) return Stream.value([]);
    return _stream(firestore
        .collection('orders')
        .where('farmerId', isEqualTo: uid))
        .map((items) {
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Stream<List<FarmOrder>> streamAll() {
    final firestore = db;
    if (firestore == null) return Stream.value([]);
    return _stream(
        firestore.collection('orders').orderBy('createdAt', descending: true));
  }

  Stream<FarmOrder?> watch(String id) {
    final firestore = db;
    if (firestore == null) return Stream.value(null);
    return firestore
        .collection('orders')
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? FarmOrder.fromMap(d.data()!, id: d.id) : null);
  }

  Future<List<String>> placeOrders(String uid, List<CartItem> cartItems,
      String address, String pickupSlot) async {
    final firestore = db;
    if (firestore == null) throw StateError('Firebase is not initialized');

    if (address.trim().isEmpty ||
        !pickupSlots.containsKey(pickupSlot) ||
        cartItems.isEmpty) {
      throw ArgumentError('Please check cart items, address, and pickup slot.');
    }
    if (cartItems.map((c) => c.productId).toSet().length != cartItems.length) {
      throw ArgumentError('Cart contains duplicate items.');
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) throw ArgumentError('Quantity must be greater than 0.');
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    // Eight distinct products keeps each transaction within Firestore rules access limits.
    if (groups.values.any((g) => g.length > 8)) {
      throw StateError('Maximum 8 distinct products per farm per order.');
    }
    final ids = <String>[];
    try {
      for (final group in groups.entries) {
        final orderRef = firestore.collection('orders').doc();
        await firestore.runTransaction((tx) async {
          final userDoc = await tx.get(firestore.collection('users').doc(uid));
          final farmerDoc =
              await tx.get(firestore.collection('farmers').doc(group.key));
          if (!userDoc.exists ||
              userDoc.data()!['role'] != Roles.customer ||
              userDoc.data()!['isActive'] != true) {
            throw StateError('Invalid customer account.');
          }
          if (!farmerDoc.exists || farmerDoc.data()!['isActive'] != true) {
            throw StateError('Store is currently inactive.');
          }
          final user = AppUser.fromMap(userDoc.data()!, id: uid);
          final products = <Product>[];
          // Firestore requires ALL reads before the first write.
          for (final item in group.value) {
            final p = await tx
                .get(firestore.collection('products').doc(item.productId));
            final cart = await tx.get(firestore
                .collection('carts')
                .doc(uid)
                .collection('items')
                .doc(item.productId));
            if (!p.exists) throw StateError('Out of stock: ${item.name}');
            final product = Product.fromMap(p.data()!, id: p.id);
            if (!product.isActive ||
                product.stockQty < item.qty ||
                product.farmerId != group.key) {
              throw StateError('Out of stock: ${product.name}');
            }
            if (!cart.exists || cart.data()!['qty'] != item.qty) {
              throw StateError('Cart items have changed, please review.');
            }
            if (product.price != item.price) {
              throw StateError(
                  'Price of ${product.name} has changed. Please update your cart.');
            }
            products.add(product);
          }
          final now = DateTime.now();
          final items = <OrderItem>[];
          for (var i = 0; i < products.length; i++) {
            final p = products[i];
            final qty = group.value[i].qty;
            items.add(OrderItem(
                productId: p.id,
                name: p.name,
                price: p.price,
                unit: p.unit,
                imageUrl: p.imageUrl,
                qty: qty,
                subtotal: p.price * qty));
            tx.update(firestore.collection('products').doc(p.id), {
              'stockQty': p.stockQty - qty,
              'updatedAt': Timestamp.fromDate(now),
              'stockMutation': {
                'orderId': orderRef.id,
                'itemIndex': i,
                'kind': 'Pending'
              },
            });
            tx.delete(firestore
                .collection('carts')
                .doc(uid)
                .collection('items')
                .doc(p.id));
          }
          tx.set(
              orderRef,
              FarmOrder(
                      id: orderRef.id,
                      customerId: uid,
                      customerName: user.name,
                      customerPhone: user.phone,
                      farmerId: group.key,
                      farmerName: farmerDoc.data()!['businessName'] as String,
                      items: items,
                      address: address.trim(),
                      pickupSlot: pickupSlot,
                      pickupDate: now,
                      total: items.fold<int>(
                          0, (runningTotal, i) => runningTotal + i.subtotal),
                      status: OrderStatus.pending,
                      createdAt: now,
                      updatedAt: now)
                  .toMap());
        });
        ids.add(orderRef.id);
      }
    } catch (e) {
      if (ids.isNotEmpty) throw PartialCheckoutException(ids, e);
      rethrow;
    }
    return ids;
  }

  Future<void> advanceStatus(String orderId) async {
    final firestore = db;
    if (firestore == null) throw StateError('Firebase is not initialized');
    return firestore.runTransaction((tx) async {
      final ref = firestore.collection('orders').doc(orderId);
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Order not found.');
      final next = OrderStatus.next[doc.data()!['status']];
      if (next == null) throw StateError('Order process has already completed.');
      tx.update(ref, {'status': next, 'updatedAt': Timestamp.now()});
    });
  }

  Future<void> cancel(String orderId) async {
    final firestore = db;
    if (firestore == null) throw StateError('Firebase is not initialized');
    return firestore.runTransaction((tx) async {
      final ref = firestore.collection('orders').doc(orderId);
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Order not found.');
      final order = FarmOrder.fromMap(doc.data()!, id: doc.id);
      if (!OrderStatus.canCancel(order.status)) {
        throw StateError('Order cannot be cancelled in its current state.');
      }
      final products = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in order.items) {
        final p =
            await tx.get(firestore.collection('products').doc(item.productId));
        if (!p.exists) {
          throw StateError('Product not found for stock restoration.');
        }
        products.add(p);
      }
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        tx.update(p.reference, {
          'stockQty':
              (p.data()!['stockQty'] as num).toInt() + order.items[i].qty,
          'updatedAt': Timestamp.now(),
          'stockMutation': {
            'orderId': orderId,
            'itemIndex': i,
            'kind': 'Cancelled'
          }
        });
      }
      tx.update(ref,
          {'status': OrderStatus.cancelled, 'updatedAt': Timestamp.now()});
    });
  }
}
