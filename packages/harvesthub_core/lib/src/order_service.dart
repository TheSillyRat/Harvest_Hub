import 'dart:async';
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
  static final List<FarmOrder> _memoryOrders = [];
  static final StreamController<List<FarmOrder>> _memoryStream =
      StreamController<List<FarmOrder>>.broadcast();

  OrderService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore? _safeFirestore() {
    try {
      return _db ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore get db => _safeFirestore() ?? FirebaseFirestore.instance;

  Stream<List<FarmOrder>> streamByCustomer(String uid) {
    final targetUid = uid.trim().isEmpty ? 'customer_1' : uid.trim();
    final firestore = _safeFirestore();
    if (firestore == null) {
      return _streamMemory(targetUid);
    }
    try {
      return firestore
          .collection('orders')
          .where('customerId', isEqualTo: targetUid)
          .snapshots()
          .map((s) {
        final fsOrders =
            s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList();
        final mem = _memoryOrders
            .where((o) => o.customerId == targetUid || o.customerId == uid)
            .toList();
        final combined = <FarmOrder>[];
        final seenIds = <String>{};
        for (final o in [...mem, ...fsOrders]) {
          if (seenIds.add(o.id)) {
            combined.add(o);
          }
        }
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return combined;
      }).handleError((_) => _streamMemory(targetUid));
    } catch (_) {
      return _streamMemory(targetUid);
    }
  }

  Stream<List<FarmOrder>> _streamMemory(String uid) async* {
    final targetUid = uid.trim().isEmpty ? 'customer_1' : uid.trim();
    List<FarmOrder> getFiltered() {
      final list = _memoryOrders
          .where((o) => o.customerId == targetUid || o.customerId == uid)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield getFiltered();

    await for (final _ in _memoryStream.stream) {
      yield getFiltered();
    }
  }

  Stream<List<FarmOrder>> streamByFarmer(String uid) {
    final targetUid = uid.trim().isEmpty ? 'farmer_1' : uid.trim();
    final firestore = _safeFirestore();
    if (firestore == null) {
      return _streamMemoryByFarmer(targetUid);
    }
    try {
      return firestore
          .collection('orders')
          .where('farmerId', isEqualTo: targetUid)
          .snapshots()
          .map((s) {
        final fsOrders =
            s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList();
        final mem = _memoryOrders
            .where((o) => o.farmerId == targetUid)
            .toList();
        final combined = <FarmOrder>[];
        final seenIds = <String>{};
        for (final o in [...mem, ...fsOrders]) {
          if (seenIds.add(o.id)) {
            combined.add(o);
          }
        }
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return combined;
      }).handleError((_) => _streamMemoryByFarmer(targetUid));
    } catch (_) {
      return _streamMemoryByFarmer(targetUid);
    }
  }

  Stream<List<FarmOrder>> _streamMemoryByFarmer(String uid) async* {
    final targetUid = uid.trim().isEmpty ? 'farmer_1' : uid.trim();
    List<FarmOrder> getFiltered() {
      final list = _memoryOrders
          .where((o) => o.farmerId == targetUid)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield getFiltered();

    await for (final _ in _memoryStream.stream) {
      yield getFiltered();
    }
  }

  Stream<List<FarmOrder>> streamAll() {
    final firestore = _safeFirestore();
    if (firestore == null) {
      return _streamMemoryAll();
    }
    try {
      return firestore
          .collection('orders')
          .snapshots()
          .map((s) {
        final fsOrders =
            s.docs.map((d) => FarmOrder.fromMap(d.data(), id: d.id)).toList();
        final combined = <FarmOrder>[];
        final seenIds = <String>{};
        for (final o in [..._memoryOrders, ...fsOrders]) {
          if (seenIds.add(o.id)) {
            combined.add(o);
          }
        }
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return combined;
      }).handleError((_) => _streamMemoryAll());
    } catch (_) {
      return _streamMemoryAll();
    }
  }

  Stream<List<FarmOrder>> _streamMemoryAll() async* {
    List<FarmOrder> getFiltered() {
      final list = List<FarmOrder>.from(_memoryOrders);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield getFiltered();

    await for (final _ in _memoryStream.stream) {
      yield getFiltered();
    }
  }

  Stream<FarmOrder?> watch(String id) {
    final firestore = _safeFirestore();
    if (firestore == null) {
      try {
        final found = _memoryOrders.firstWhere((o) => o.id == id);
        return Stream.value(found);
      } catch (_) {
        return Stream.value(null);
      }
    }
    try {
      return firestore
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
    final effectiveUid = uid.trim().isEmpty ? 'customer_1' : uid;
    if (cartItems.isEmpty) {
      throw ArgumentError('Please verify basket items and delivery address');
    }
    final effectiveAddress = address.trim().isEmpty
        ? 'Green Valley Hub, West Market Station'
        : address.trim();

    final groups = <String, List<CartItem>>{};
    for (final item in cartItems) {
      if (item.qty <= 0) continue;
      groups.putIfAbsent(item.farmerId, () => []).add(item);
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
        } catch (_) {
          /* Fall back to memory order */
        }
      }

      _memoryOrders.insert(0, newOrder);
      ids.add(orderId);
    }

    _memoryStream.add(_memoryOrders);
    return ids;
  }

  Future<void> advanceStatus(String orderId) async {
    final idx = _memoryOrders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      final current = _memoryOrders[idx];
      final next = OrderStatus.next[current.status];
      if (next != null) {
        _memoryOrders[idx] =
            current.copyWith(status: next, updatedAt: DateTime.now());
        _memoryStream.add(_memoryOrders);
      }
    }
    final firestore = _safeFirestore();
    if (firestore != null) {
      try {
        final ref = firestore.collection('orders').doc(orderId);
        final doc = await ref.get();
        if (doc.exists) {
          final next = OrderStatus.next[doc.data()!['status']];
          if (next != null) {
            await ref.update({'status': next, 'updatedAt': Timestamp.now()});
          }
        }
      } catch (_) {}
    }
  }

  Future<void> cancel(String orderId) async {
    final idx = _memoryOrders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      _memoryOrders[idx] = _memoryOrders[idx].copyWith(
        status: OrderStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      _memoryStream.add(_memoryOrders);
    }
    final firestore = _safeFirestore();
    if (firestore != null) {
      try {
        final ref = firestore.collection('orders').doc(orderId);
        final doc = await ref.get();
        if (doc.exists) {
          await ref.update(
              {'status': OrderStatus.cancelled, 'updatedAt': Timestamp.now()});
        }
      } catch (_) {}
    }
  }
}
