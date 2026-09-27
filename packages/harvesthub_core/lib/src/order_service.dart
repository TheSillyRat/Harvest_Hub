import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';
import 'notification_service.dart';

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

  static final List<FarmOrder> _memoryOrders = [
    FarmOrder(
      id: 'ord_demo_1',
      customerId: 'cust_demo_1',
      customerName: 'Alice Green',
      customerPhone: '0901234567',
      farmerId: 'farmer_1',
      farmerName: 'Green Valley Organic Farm',
      items: [
        OrderItem(
          productId: 'prod_1',
          name: 'Heirloom Vine Tomatoes',
          price: 450,
          unit: 'kg',
          imageUrl:
              'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80',
          qty: 2,
          subtotal: 900,
        ),
      ],
      address: '123 Market Street, Da Lat',
      pickupSlot: 'morning_07_10',
      pickupDate: DateTime.now(),
      total: 900,
      status: OrderStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    FarmOrder(
      id: 'ord_demo_2',
      customerId: 'cust_demo_2',
      customerName: 'Bob Farmer',
      customerPhone: '0912345678',
      farmerId: 'farmer_1',
      farmerName: 'Green Valley Organic Farm',
      items: [
        OrderItem(
          productId: 'prod_3',
          name: 'Crisp Butterhead Lettuce',
          price: 350,
          unit: 'head',
          imageUrl:
              'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?auto=format&fit=crop&w=600&q=80',
          qty: 3,
          subtotal: 1050,
        ),
      ],
      address: '456 Farm Road, Da Lat',
      pickupSlot: 'afternoon_15_18',
      pickupDate: DateTime.now(),
      total: 1050,
      status: OrderStatus.completed,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
  static final StreamController<List<FarmOrder>> _ordersStream =
      StreamController<List<FarmOrder>>.broadcast();

  Stream<List<FarmOrder>> streamByCustomer(String uid) async* {
    List<FarmOrder> filterMemory(List<FarmOrder> list) {
      return list
          .where((o) =>
              uid.isEmpty ||
              o.customerId == uid ||
              o.customerId == 'cust_demo_1')
          .toList();
    }

    yield filterMemory(_memoryOrders);

    final database = db;
    if (database == null) {
      yield* _ordersStream.stream.map(filterMemory);
      return;
    }

    try {
      final snapshots = database
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .snapshots();

      await for (final snapshot in snapshots) {
        final fsOrders = snapshot.docs
            .map((doc) => FarmOrder.fromMap(doc.data(), id: doc.id))
            .toList();
        final mem = filterMemory(_memoryOrders);
        final combined = <FarmOrder>[];
        final seenIds = <String>{};
        for (final o in [...fsOrders, ...mem]) {
          if (seenIds.add(o.id)) {
            combined.add(o);
          }
        }
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield combined;
      }
    } catch (_) {
      yield* _ordersStream.stream.map(filterMemory);
    }
  }

  Stream<List<FarmOrder>> streamByFarmer(String uid) async* {
    List<FarmOrder> filterMemory(List<FarmOrder> list) {
      return list
          .where((o) =>
              uid.isEmpty ||
              o.farmerId == uid ||
              o.farmerId == 'farmer_1')
          .toList();
    }

    yield filterMemory(_memoryOrders);

    final database = db;
    if (database == null) {
      yield* _ordersStream.stream.map(filterMemory);
      return;
    }

    try {
      final snapshots = database
          .collection('orders')
          .where('farmerId', isEqualTo: uid)
          .snapshots();

      await for (final snapshot in snapshots) {
        final fsOrders = snapshot.docs
            .map((doc) => FarmOrder.fromMap(doc.data(), id: doc.id))
            .toList();
        final mem = filterMemory(_memoryOrders);
        final combined = <FarmOrder>[];
        final seenIds = <String>{};
        for (final o in [...fsOrders, ...mem]) {
          if (seenIds.add(o.id)) {
            combined.add(o);
          }
        }
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield combined;
      }
    } catch (_) {
      yield* _ordersStream.stream.map(filterMemory);
    }
  }

  Stream<List<FarmOrder>> streamAll() {
    final database = db;
    if (database == null) {
      return _ordersStream.stream;
    }
    return database
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList());
  }

  Stream<FarmOrder?> watch(String id) async* {
    final mem = _memoryOrders.where((o) => o.id == id);
    if (mem.isNotEmpty) {
      yield mem.first;
    }
    final database = db;
    if (database == null) return;
    try {
      final docStream = database.collection('orders').doc(id).snapshots().map(
          (d) => d.exists ? FarmOrder.fromMap(d.data()!, id: d.id) : null);
      await for (final o in docStream) {
        if (o != null) yield o;
      }
    } catch (_) {}
  }

  Future<List<String>> placeOrders(String uid, List<CartItem> cartItems,
      String address, String pickupSlot) async {
    if (address.trim().isEmpty ||
        !pickupSlots.containsKey(pickupSlot) ||
        cartItems.isEmpty) {
      throw ArgumentError('Check cart, delivery address and pickup slot');
    }
    if (cartItems.map((c) => c.productId).toSet().length != cartItems.length) {
      throw ArgumentError('Duplicate products in cart');
    }
    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) throw ArgumentError('Quantity must be greater than 0');
      groups.putIfAbsent(item.farmerId, () => []).add(item);
    }
    if (groups.values.any((g) => g.length > 8)) {
      throw StateError('Maximum 8 product types per farmer per order');
    }
    final database = db;
    if (database == null) {
      throw StateError('Database not initialized');
    }
    final ids = <String>[];
    try {
      for (final group in groups.entries) {
        final orderRef = database.collection('orders').doc();
        final orderedProducts = <Product>[];
        String customerName = '';
        await database.runTransaction((tx) async {
          orderedProducts.clear();
          final userDoc = await tx.get(database.collection('users').doc(uid));
          final farmerDoc =
              await tx.get(database.collection('farmers').doc(group.key));
          if (!userDoc.exists ||
              userDoc.data()!['role'] != Roles.customer ||
              userDoc.data()!['isActive'] != true) {
            throw StateError('Invalid customer account');
          }
          if (!farmerDoc.exists || farmerDoc.data()!['isActive'] != true) {
            throw StateError('Farmer store is currently unavailable');
          }
          final user = AppUser.fromMap(userDoc.data()!, id: uid);
          customerName = user.name;
          for (final item in group.value) {
            final p =
                await tx.get(database.collection('products').doc(item.productId));
            final cart = await tx.get(database
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
            if (!cart.exists || cart.data()!['qty'] != item.qty) {
              throw StateError('Cart has changed, please check again');
            }
            if (product.price != item.price) {
              throw StateError(
                  'Price for ${product.name} changed. Please update cart');
            }
            orderedProducts.add(product);
          }
          final now = DateTime.now();
          final items = <OrderItem>[];
          for (var i = 0; i < orderedProducts.length; i++) {
            final p = orderedProducts[i];
            final qty = group.value[i].qty;
            items.add(OrderItem(
                productId: p.id,
                name: p.name,
                price: p.price,
                unit: p.unit,
                imageUrl: p.imageUrl,
                qty: qty,
                subtotal: p.price * qty));
            tx.update(database.collection('products').doc(p.id), {
              'stockQty': p.stockQty - qty,
              'updatedAt': Timestamp.fromDate(now),
              'stockMutation': {
                'orderId': orderRef.id,
                'itemIndex': i,
                'kind': 'Pending'
              },
            });
            tx.delete(
                database.collection('carts').doc(uid).collection('items').doc(p.id));
          }
          final newOrder = FarmOrder(
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
              updatedAt: now);
          tx.set(orderRef, newOrder.toMap());
          _memoryOrders.insert(0, newOrder);
          _ordersStream.add(List<FarmOrder>.from(_memoryOrders));
        });
        ids.add(orderRef.id);
        final slotLabel = pickupSlots[pickupSlot] ?? pickupSlot;
        final shortId = orderRef.id.substring(0, orderRef.id.length > 8 ? 8 : orderRef.id.length);
        try {
          final customerDisplayName =
              customerName.trim().isNotEmpty ? customerName.trim() : 'Customer';
          await NotificationService().sendNotification(
            userId: group.key,
            title: 'New Order Received',
            body: '$customerDisplayName placed order #$shortId (${group.value.length} items) for slot: $slotLabel',
            type: 'NEW_ORDER',
            targetId: orderRef.id,
            showInAppPopup: false,
          );
          // Trigger low stock notifications if inventory drops to <= 5
          for (final item in group.value) {
            final matchingProds = orderedProducts.where((prod) => prod.id == item.productId);
            if (matchingProds.isNotEmpty) {
              final p = matchingProds.first;
              final remaining = p.stockQty - item.qty;
              if (remaining <= 5) {
                await NotificationService().sendLowStockAlert(
                  farmerId: group.key,
                  productId: p.id,
                  productName: p.name,
                  remainingStock: remaining,
                  unit: p.unit,
                );
              }
            }
          }
          await NotificationService().sendNotification(
            userId: 'all_admins',
            title: 'New Platform Order',
            body: 'Order #$shortId placed for ${group.value.first.farmerName}',
            type: 'order',
            targetId: orderRef.id,
            showInAppPopup: false,
          );
        } catch (_) {}
      }
    } catch (e) {
      if (ids.isNotEmpty) throw PartialCheckoutException(ids, e);
      rethrow;
    }
    return ids;
  }

  Future<void> advanceStatus(String orderId) async {
    String? customerId;
    String? nextStatus;
    final database = db;
    if (database != null) {
      try {
        await database.runTransaction((tx) async {
          final ref = database.collection('orders').doc(orderId);
          final doc = await tx.get(ref);
          if (!doc.exists) throw StateError('Order not found');
          final data = doc.data()!;
          final next = OrderStatus.next[data['status']];
          if (next == null) throw StateError('Order already in terminal state');
          customerId = data['customerId'] as String?;
          nextStatus = next;
          tx.update(ref, {'status': next, 'updatedAt': Timestamp.now()});
        });
      } catch (_) {}
    }

    final memIdx = _memoryOrders.indexWhere((o) => o.id == orderId);
    if (memIdx != -1) {
      final cur = _memoryOrders[memIdx];
      final next = OrderStatus.next[cur.status];
      if (next != null) {
        customerId ??= cur.customerId;
        nextStatus ??= next;
        _memoryOrders[memIdx] = cur.copyWith(
          status: next,
          updatedAt: DateTime.now(),
        );
        _ordersStream.add(List<FarmOrder>.from(_memoryOrders));
      }
    }

    if (customerId != null && nextStatus != null) {
      final shortId = orderId.substring(0, orderId.length > 8 ? 8 : orderId.length);
      String notifTitle = 'Order Update';
      String notifBody = 'Order status updated to $nextStatus';
      if (nextStatus == OrderStatus.confirmed) {
        notifTitle = 'Order Confirmed';
        notifBody = 'Your order #$shortId has been confirmed by the farmer.';
      } else if (nextStatus == OrderStatus.readyForPickup) {
        notifTitle = 'Ready for Pickup';
        notifBody = 'Your order #$shortId is packed and ready for pickup!';
      } else if (nextStatus == OrderStatus.completed) {
        notifTitle = 'Order Completed';
        notifBody = 'Thank you! Your order #$shortId has been picked up successfully.';
      }
      try {
        await NotificationService().sendNotification(
          userId: customerId!,
          title: notifTitle,
          body: notifBody,
          type: 'order',
          targetId: orderId,
        );
      } catch (_) {}
    }
  }

  Future<void> cancel(String orderId, {String? role}) async {
    FarmOrder? cancelledOrder;
    final database = db;
    if (database != null) {
      try {
        await database.runTransaction((tx) async {
          final ref = database.collection('orders').doc(orderId);
          final doc = await tx.get(ref);
          if (!doc.exists) throw StateError('Order not found');
          final order = FarmOrder.fromMap(doc.data()!, id: doc.id);
          if (!OrderStatus.canCancel(order.status, role)) {
            throw StateError('Cannot cancel order in this status');
          }
          cancelledOrder = order;
          final products = <DocumentSnapshot<Map<String, dynamic>>>[];
          for (final item in order.items) {
            final p = await tx.get(database.collection('products').doc(item.productId));
            if (!p.exists) {
              throw StateError('Product not found for restocking');
            }
            products.add(p);
          }
          for (var i = 0; i < products.length; i++) {
            final p = products[i];
            final isGrams = order.items[i].unit.endsWith('g') && !order.items[i].unit.endsWith('kg');
            final restoreQty = isGrams ? 1 : order.items[i].qty;
            tx.update(p.reference, {
              'stockQty':
                  (p.data()!['stockQty'] as num).toInt() + restoreQty,
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
      } catch (_) {}
    }

    final memIdx = _memoryOrders.indexWhere((o) => o.id == orderId);
    if (memIdx != -1) {
      final cur = _memoryOrders[memIdx];
      if (OrderStatus.canCancel(cur.status, role)) {
        cancelledOrder ??= cur;
        _memoryOrders[memIdx] = cur.copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );
        _ordersStream.add(List<FarmOrder>.from(_memoryOrders));
      }
    }

    if (cancelledOrder != null) {
      final isCustomer = role == Roles.customer;
      final targetUserId = isCustomer ? cancelledOrder!.farmerId : cancelledOrder!.customerId;
      final shortId = orderId.substring(0, orderId.length > 8 ? 8 : orderId.length);
      final body = isCustomer
          ? 'Order #$shortId was cancelled by customer. Items restocked.'
          : 'Order #$shortId was cancelled. Items restocked.';
      try {
        await NotificationService().sendNotification(
          userId: targetUserId,
          title: 'Order Cancelled',
          body: body,
          type: 'order',
          targetId: orderId,
          showInAppPopup: false,
        );
        if (role != Roles.admin) {
          await NotificationService().sendNotification(
            userId: 'all_admins',
            title: 'Order Cancelled',
            body: 'Order #$shortId was cancelled by $role.',
            type: 'order',
            targetId: orderId,
            showInAppPopup: false,
          );
        }
      } catch (_) {}
    }
  }
}
