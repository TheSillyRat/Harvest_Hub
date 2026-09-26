import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

class PartialCheckoutException implements Exception {
  final List<String> orderIds;
  final Object cause;
  PartialCheckoutException(this.orderIds, this.cause);
  @override
  String toString() =>
      'Created ${orderIds.length} orders. Remaining items are still in your basket. $cause';
}

class OrderService {
  final FirebaseFirestore db;
  OrderService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;
  Stream<List<FarmOrder>> _stream(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((s) =>
          s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList());
  Stream<List<FarmOrder>> streamByCustomer(String uid) =>
      _stream(db.collection('orders').where('customerId', isEqualTo: uid))
          .map((items) {
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });
  Stream<List<FarmOrder>> streamByFarmer(String uid) =>
      _stream(db.collection('orders').where('farmerId', isEqualTo: uid))
          .map((items) {
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });
  Stream<List<FarmOrder>> streamAll() =>
      _stream(db.collection('orders').orderBy('createdAt', descending: true));
  Stream<FarmOrder?> watch(String id) => db
      .collection('orders')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? FarmOrder.fromMap(d.data()!, id: d.id) : null);

  Future<List<String>> placeOrders(String uid, List<CartItem> cartItems,
      String address, String pickupSlot,
      {Map<String, String>? shopSlots}) async {
    if (address.trim().isEmpty ||
        !pickupSlots.containsKey(pickupSlot) ||
        cartItems.isEmpty) {
      throw ArgumentError('Check basket, pickup location and time slot');
    }
    if (cartItems.map((c) => c.productId).toSet().length != cartItems.length) {
      throw ArgumentError('Duplicate items in basket');
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) throw ArgumentError('Quantity must be greater than 0');
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    // Eight distinct products keeps each transaction within Firestore rules access limits.
    if (groups.values.any((g) => g.length > 8)) {
      throw StateError('Maximum 8 distinct items per farmer in one order');
    }
    final ids = <String>[];
    try {
      for (final group in groups.entries) {
        final orderRef = db.collection('orders').doc();
        await db.runTransaction((tx) async {
          final userDoc = await tx.get(db.collection('users').doc(uid));
          final farmerDoc =
              await tx.get(db.collection('farmers').doc(group.key));
          if (!userDoc.exists ||
              userDoc.data()!['role'] != Roles.customer ||
              userDoc.data()!['isActive'] != true) {
            throw StateError('Invalid customer account');
          }
          if (!farmerDoc.exists || farmerDoc.data()!['isActive'] != true) {
            throw StateError('Farmer stall is currently inactive');
          }
          final user = AppUser.fromMap(userDoc.data()!, id: uid);
          final products = <Product>[];
          // Firestore requires ALL reads before the first write.
          for (final item in group.value) {
            final p =
                await tx.get(db.collection('products').doc(item.productId));
            final cart = await tx.get(db
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
              throw StateError('Basket items changed, please review');
            }
            if (product.price != item.price) {
              throw StateError(
                  'Price for ${product.name} changed. Please re-add to basket');
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
            tx.update(db.collection('products').doc(p.id), {
              'stockQty': p.stockQty - qty,
              'updatedAt': Timestamp.fromDate(now),
              'stockMutation': {
                'orderId': orderRef.id,
                'itemIndex': i,
                'kind': 'Pending'
              },
            });
            tx.delete(
                db.collection('carts').doc(uid).collection('items').doc(p.id));
          }
          final farmerData = farmerDoc.data()!;
          final farmerBusiness =
              farmerData['businessName'] as String? ?? 'Local Farm';
          final farmerAddr = farmerData['address'] as String? ??
              (farmerData['marketAddress'] as String? ?? address.trim());
          final marketNm =
              farmerData['marketName'] as String? ?? farmerBusiness;
          final opHours =
              farmerData['operatingHours'] as String? ?? '07:00 - 18:00';
          final lat = (farmerData['latitude'] as num?)?.toDouble() ??
              (farmerData['lat'] as num?)?.toDouble();
          final lng = (farmerData['longitude'] as num?)?.toDouble() ??
              (farmerData['lng'] as num?)?.toDouble();
          final effectiveSlot = shopSlots?[group.key] ?? pickupSlot;

          tx.set(
              orderRef,
              FarmOrder(
                      id: orderRef.id,
                      customerId: uid,
                      customerName: user.name,
                      customerPhone: user.phone,
                      farmerId: group.key,
                      farmerName: farmerBusiness,
                      items: items,
                      address: farmerAddr,
                      pickupSlot: effectiveSlot,
                      pickupDate: now,
                      total: items.fold<int>(
                          0, (runningTotal, i) => runningTotal + i.subtotal),
                      status: OrderStatus.pending,
                      createdAt: now,
                      updatedAt: now,
                      latitude: lat,
                      longitude: lng,
                      operatingHours: opHours,
                      marketName: marketNm)
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

  Future<void> advanceStatus(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Order not found');
        final next = OrderStatus.next[doc.data()!['status']];
        if (next == null) throw StateError('Order is already in final state');
        tx.update(ref, {'status': next, 'updatedAt': Timestamp.now()});
      });

  Future<void> cancel(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Order not found');
        final order = FarmOrder.fromMap(doc.data()!, id: doc.id);
        if (!OrderStatus.canCancel(order.status)) {
          throw StateError('Cannot cancel order in this status');
        }
        final products = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final item in order.items) {
          final p = await tx.get(db.collection('products').doc(item.productId));
          if (!p.exists) {
            throw StateError('Không tìm thấy sản phẩm để hoàn tồn kho');
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
