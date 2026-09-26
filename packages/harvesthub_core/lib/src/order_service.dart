import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

class PartialCheckoutException implements Exception {
  final List<String> orderIds;
  final Object cause;
  PartialCheckoutException(this.orderIds, this.cause);
  @override
  String toString() =>
      'Đã tạo ${orderIds.length} đơn. Các món chưa đặt vẫn ở giỏ. $cause';
}

class OrderService {
  final FirebaseFirestore db;
  OrderService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;
  Stream<List<FarmOrder>> _stream(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((s) =>
          s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList());
  Stream<List<FarmOrder>> streamByCustomer(String uid) => _stream(db
      .collection('orders')
      .where('customerId', isEqualTo: uid))
      .map((items) {
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });
  Stream<List<FarmOrder>> streamByFarmer(String uid) => _stream(db
      .collection('orders')
      .where('farmerId', isEqualTo: uid))
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
      String address, String pickupSlot) async {
    if (address.trim().isEmpty ||
        !pickupSlots.containsKey(pickupSlot) ||
        cartItems.isEmpty) {
      throw ArgumentError('Kiểm tra giỏ, địa chỉ và khung giờ nhận');
    }
    if (cartItems.map((c) => c.productId).toSet().length != cartItems.length) {
      throw ArgumentError('Giỏ hàng có sản phẩm trùng');
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) throw ArgumentError('Số lượng phải lớn hơn 0');
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    // Eight distinct products keeps each transaction within Firestore rules access limits.
    if (groups.values.any((g) => g.length > 8)) {
      throw StateError('Mỗi lần đặt tối đa 8 loại sản phẩm từ một nông dân');
    }
    final ids = <String>[];
    final firestore = _safeFirestore();

    for (final entry in groups.entries) {
      final farmerId = entry.key;
      final groupItems = entry.value;
      final orderId =
          'ord_${DateTime.now().millisecondsSinceEpoch}_${ids.length + 1}';
      final now = DateTime.now();

      final items = groupItems
          .map((i) => OrderItem(
                productId: i.productId,
                name: i.name,
                price: i.price,
                unit: i.unit,
                imageUrl: i.imageUrl,
                qty: i.qty,
                subtotal: i.price * i.qty,
              ))
          .toList();

      final total = items.fold<int>(0, (acc, i) => acc + i.subtotal);
      final farmerName = groupItems.first.farmerName.isNotEmpty
          ? groupItems.first.farmerName
          : 'Local Organic Farm';

      final newOrder = FarmOrder(
        id: orderId,
        customerId: effectiveUid,
        customerName: 'Customer',
        customerPhone: '+84 901 234 567',
        farmerId: farmerId,
        farmerName: farmerName,
        items: items,
        address: effectiveAddress,
        pickupSlot: pickupSlot.isEmpty ? 'morning_07_10' : pickupSlot,
        pickupDate: now,
        total: total,
        status: OrderStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      if (firestore != null) {
        bool transactionSuccess = false;
        try {
          final orderRef = firestore.collection('orders').doc(orderId);
          await firestore.runTransaction((tx) async {
            tx.set(orderRef, newOrder.toMap());
            for (final item in groupItems) {
              final pRef = firestore.collection('products').doc(item.productId);
              final pDoc = await tx.get(pRef);
              if (pDoc.exists) {
                final currentStock =
                    (pDoc.data()?['stockQty'] as num?)?.toInt() ?? 0;
                tx.update(pRef, {
                  'stockQty': (currentStock - item.qty).clamp(0, 999999),
                  'updatedAt': Timestamp.fromDate(now),
                });
              }
              tx.delete(firestore
                  .collection('carts')
                  .doc(effectiveUid)
                  .collection('items')
                  .doc(item.productId));
            }
          });
          transactionSuccess = true;
        } catch (_) {
          /* Fall back to direct set below */
        }

        if (!transactionSuccess) {
          try {
            await firestore.collection('orders').doc(orderId).set(newOrder.toMap());
            for (final item in groupItems) {
              try {
                await firestore
                    .collection('carts')
                    .doc(effectiveUid)
                    .collection('items')
                    .doc(item.productId)
                    .delete();
              } catch (_) {}
            }
          } catch (_) {}
        }
      }


      _memoryOrders.insert(0, newOrder);
      ids.add(orderId);
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
            throw StateError('Tài khoản không hợp lệ');
          }
          if (!farmerDoc.exists || farmerDoc.data()!['isActive'] != true) {
            throw StateError('Gian hàng tạm ngừng hoạt động');
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
            if (!p.exists) throw StateError('Hết hàng: ${item.name}');
            final product = Product.fromMap(p.data()!, id: p.id);
            if (!product.isActive ||
                product.stockQty < item.qty ||
                product.farmerId != group.key) {
              throw StateError('Hết hàng: ${product.name}');
            }
            if (!cart.exists || cart.data()!['qty'] != item.qty) {
              throw StateError('Giỏ đã thay đổi, vui lòng kiểm tra lại');
            }
            if (product.price != item.price) {
              throw StateError(
                  'Giá ${product.name} đã thay đổi. Xóa và thêm lại sản phẩm');
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

  Future<void> advanceStatus(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Không tìm thấy đơn');
        final next = OrderStatus.next[doc.data()!['status']];
        if (next == null) throw StateError('Đơn đã kết thúc');
        tx.update(ref, {'status': next, 'updatedAt': Timestamp.now()});
      });

  Future<void> cancel(String orderId) => db.runTransaction((tx) async {
        final ref = db.collection('orders').doc(orderId);
        final doc = await tx.get(ref);
        if (!doc.exists) throw StateError('Không tìm thấy đơn');
        final order = FarmOrder.fromMap(doc.data()!, id: doc.id);
        if (!OrderStatus.canCancel(order.status)) {
          throw StateError('Không thể hủy đơn ở trạng thái này');
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
