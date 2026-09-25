import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

class PartialCheckoutException implements Exception {
  final List<String> orderIds;
  final Object cause;
  PartialCheckoutException(this.orderIds, this.cause);
  @override
  String toString() =>
      'Created ${orderIds.length} orders. Remaining unplaced items stay in your basket. $cause';
}

class OrderService {
  final FirebaseFirestore? _db;

  OrderService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore get db {
    try {
      return _db ?? FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  Stream<List<FarmOrder>> _stream(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((s) =>
          s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList());

  Stream<List<FarmOrder>> streamByCustomer(String uid) {
    try {
      return _stream(db
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true));
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<List<FarmOrder>> streamByFarmer(String uid) {
    try {
      return _stream(db
          .collection('orders')
          .where('farmerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true));
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<List<FarmOrder>> streamAll() {
    try {
      return _stream(db.collection('orders').orderBy('createdAt', descending: true));
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<FarmOrder?> watch(String id) {
    try {
      return db
          .collection('orders')
          .doc(id)
          .snapshots()
          .map((d) => d.exists ? FarmOrder.fromMap(d.data()!, id: d.id) : null);
    } catch (_) {
      return Stream.value(null);
    }
  }

  Future<List<String>> placeOrders(
    String uid,
    List<CartItem> cartItems,
    String address,
    String pickupSlot,
  ) async {
    if (address.trim().isEmpty || cartItems.isEmpty) {
      throw ArgumentError('Please verify basket items and delivery address');
    }
    if (cartItems.map((c) => c.productId).toSet().length != cartItems.length) {
      throw ArgumentError('Cart contains duplicate product items');
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) throw ArgumentError('Item quantity must be greater than zero');
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    if (groups.values.any((g) => g.length > 8)) {
      throw StateError('Maximum 8 produce types per farmer order batch');
    }
    final ids = <String>[];
    try {
      for (final group in groups.entries) {
        final orderRef = db.collection('orders').doc();
        await db.runTransaction((tx) async {
          final userDoc = await tx.get(db.collection('users').doc(uid));
          final farmerDoc = await tx.get(db.collection('farmers').doc(group.key));
          if (!userDoc.exists ||
              userDoc.data()!['role'] != Roles.customer ||
              userDoc.data()!['isActive'] != true) {
            throw StateError('Invalid customer account details');
          }
          if (!farmerDoc.exists || farmerDoc.data()!['isActive'] != true) {
            throw StateError('Farm store is currently inactive');
          }
          final user = AppUser.fromMap(userDoc.data()!, id: uid);
          final products = <Product>[];
          for (final item in group.value) {
            final p = await tx.get(db.collection('products').doc(item.productId));
            final cart = await tx.get(db
                .collection('carts')
                .doc(uid)
                .collection('items')
                .doc(item.productId));
            if (!p.exists) throw StateError('Item out of stock: ${item.name}');
            final product = Product.fromMap(p.data()!, id: p.id);
            if (!product.isActive ||
                product.stockQty < item.qty ||
                product.farmerId != group.key) {
              throw StateError('Item out of stock: ${product.name}');
            }
            if (cart.exists && cart.data()!['qty'] != item.qty) {
              throw StateError('Basket items changed. Please review your cart.');
            }
            if (product.price != item.price) {
              throw StateError('Price for ${product.name} changed. Please refresh cart.');
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
              subtotal: p.price * qty,
            ));
            tx.update(db.collection('products').doc(p.id), {
              'stockQty': p.stockQty - qty,
              'updatedAt': Timestamp.fromDate(now),
              'stockMutation': {
                'orderId': orderRef.id,
                'itemIndex': i,
                'kind': 'Pending',
              },
            });
            tx.delete(db.collection('carts').doc(uid).collection('items').doc(p.id));
          }
          tx.set(
            orderRef,
            FarmOrder(
              id: orderRef.id,
              customerId: uid,
              customerName: user.name,
              customerPhone: user.phone,
              farmerId: group.key,
              farmerName: farmerDoc.data()!['businessName'] as String? ?? 'Local Organic Farm',
              items: items,
              address: address.trim(),
              pickupSlot: pickupSlot,
              pickupDate: now,
              total: items.fold<int>(0, (sum, i) => sum + i.subtotal),
              status: OrderStatus.pending,
              createdAt: now,
              updatedAt: now,
            ).toMap(),
          );
        });
        ids.add(orderRef.id);
      }
    } catch (e) {
      if (ids.isNotEmpty) throw PartialCheckoutException(ids, e);
      rethrow;
    }
    return ids;
  }

  Future<void> advanceStatus(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Order record not found');
        final next = OrderStatus.next[doc.data()!['status']];
        if (next == null) throw StateError('Order process is already finalized');
        tx.update(ref, {'status': next, 'updatedAt': Timestamp.now()});
      });

  Future<void> cancel(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Order record not found');
        final order = FarmOrder.fromMap(doc.data()!, id: doc.id);
        if (!OrderStatus.canCancel(order.status)) {
          throw StateError('Order cannot be cancelled in current status');
        }
        final products = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final item in order.items) {
          final p = await tx.get(db.collection('products').doc(item.productId));
          if (!p.exists) {
            throw StateError('Product not found for inventory restock');
          }
          products.add(p);
        }
        for (var i = 0; i < products.length; i++) {
          final p = products[i];
          tx.update(p.reference, {
            'stockQty': (p.data()!['stockQty'] as num).toInt() + order.items[i].qty,
            'updatedAt': Timestamp.now(),
            'stockMutation': {
              'orderId': orderId,
              'itemIndex': i,
              'kind': 'Cancelled',
            },
          });
        }
        tx.update(ref, {'status': OrderStatus.cancelled, 'updatedAt': Timestamp.now()});
      });
}
