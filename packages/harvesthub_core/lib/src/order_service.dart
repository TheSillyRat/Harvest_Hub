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
      .where('customerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true));
  Stream<List<FarmOrder>> streamByFarmer(String uid) => _stream(db
      .collection('orders')
      .where('farmerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true));
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
