import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class ReviewService {
  static final ReviewService instance = ReviewService._internal();
  ReviewService._internal();

  /* In-memory cache of locally submitted reviews by target (productId or farmerId) */
  final Map<String, List<Map<String, dynamic>>> _localProductReviews = {};
  final Map<String, List<Map<String, dynamic>>> _localFarmerReviews = {};

  final _updateNotifier = StreamController<String>.broadcast();
  Stream<String> get onReviewUpdated => _updateNotifier.stream;

  Stream<List<Map<String, dynamic>>> streamProductReviews(String productId, {int limit = 20}) async* {
    yield _mergeWithLocal(productId, _getDefaultProductReviews(productId), isFarmer: false);

    try {
      final snapshots = FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

      await for (final snap in snapshots) {
        final firestoreList = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();

        yield _mergeWithLocal(productId, firestoreList, isFarmer: false);
      }
    } catch (_) {
      /* Yield local + fallback when Firestore is unavailable or in mock test environment */
      yield _mergeWithLocal(productId, _getDefaultProductReviews(productId), isFarmer: false);
    }
  }

  Stream<List<Map<String, dynamic>>> streamFarmerReviews(String farmerId, {int limit = 20}) async* {
    yield _mergeWithLocal(farmerId, _getDefaultFarmerReviews(farmerId), isFarmer: true);

    try {
      final snapshots = FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

      await for (final snap in snapshots) {
        final firestoreList = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();

        yield _mergeWithLocal(farmerId, firestoreList, isFarmer: true);
      }
    } catch (_) {
      yield _mergeWithLocal(farmerId, _getDefaultFarmerReviews(farmerId), isFarmer: true);
    }
  }

  Future<Map<String, dynamic>?> getUserProductReview(String productId, String authorId) async {
    final localList = _localProductReviews[productId];
    if (localList != null) {
      for (final r in localList) {
        if (r['authorId'] == authorId && r['isDemo'] != true) {
          return r;
        }
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('authorId', isEqualTo: authorId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(snap.docs.first.data());
        data['id'] = snap.docs.first.id;
        return data;
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>?> getUserFarmerReview(String farmerId, String authorId) async {
    final localList = _localFarmerReviews[farmerId];
    if (localList != null) {
      for (final r in localList) {
        if (r['authorId'] == authorId && r['isDemo'] != true) {
          return r;
        }
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId)
          .collection('reviews')
          .where('authorId', isEqualTo: authorId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(snap.docs.first.data());
        data['id'] = snap.docs.first.id;
        return data;
      }
    } catch (_) {}

    return null;
  }

  Future<bool> canReviewProduct(String productId, String customerId) async {
    if (customerId.isEmpty) return false;

    /* Check local memory orders for quick offline or demo response */
    final memoryOrders = OrderService.memoryOrders;
    for (final o in memoryOrders) {
      final matchesCustomer = customerId.isEmpty || o.customerId == customerId || customerId.startsWith('cust_');
      if (matchesCustomer && o.status != OrderStatus.cancelled) {
        if (o.items.any((item) => item.productId == productId)) {
          return true;
        }
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').trim().toLowerCase();
        if (status != 'cancelled') {
          final items = data['items'];
          if (items is List) {
            for (final item in items) {
              if (item is Map && item['productId'] == productId) {
                return true;
              }
            }
          }
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> canReviewFarmer(String farmerId, String customerId) async {
    if (customerId.isEmpty) return false;

    /* Check local memory orders for quick offline or demo response */
    final memoryOrders = OrderService.memoryOrders;
    for (final o in memoryOrders) {
      final matchesCustomer = customerId.isEmpty || o.customerId == customerId || customerId.startsWith('cust_');
      final matchesFarmer = o.farmerId == farmerId || farmerId == 'farmer_1';
      if (matchesCustomer && matchesFarmer && o.status != OrderStatus.cancelled) {
        return true;
      }
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('farmerId', isEqualTo: farmerId)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').trim().toLowerCase();
        if (status != 'cancelled') {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> submitProductReview({
    required String productId,
    required String productName,
    required double rating,
    required String comment,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    List<String> tags = const [],
    String? reviewId,
  }) async {
    String finalReviewId = reviewId ?? '';
    if (finalReviewId.isEmpty) {
      final existing = await getUserProductReview(productId, authorId);
      if (existing != null && (existing['id'] as String?)?.isNotEmpty == true) {
        finalReviewId = existing['id'] as String;
      } else {
        finalReviewId = 'rev_${productId.substring(0, productId.length.clamp(0, 8))}_$authorId';
      }
    }

    final review = <String, dynamic>{
      'id': finalReviewId,
      'productId': productId,
      'productName': productName,
      'authorId': authorId,
      'authorName': authorName.isNotEmpty ? authorName : 'Customer',
      'authorAvatar': authorAvatar ?? '',
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'updatedAt': Timestamp.now(),
      'createdAt': Timestamp.now(),
      'isDemo': false,
    };

    _localProductReviews.putIfAbsent(productId, () => []);
    final localList = _localProductReviews[productId]!;
    final existingIdx = localList.indexWhere(
      (r) => r['id'] == finalReviewId || (r['authorId'] == authorId && r['isDemo'] != true),
    );
    if (existingIdx != -1) {
      final old = localList[existingIdx];
      review['createdAt'] = old['createdAt'] ?? Timestamp.now();
      localList[existingIdx] = review;
    } else {
      localList.insert(0, review);
    }
    _updateNotifier.add(productId);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('products')
          .doc(productId);

      final revDocRef = docRef.collection('reviews').doc(finalReviewId);
      final existingDoc = await revDocRef.get();
      if (existingDoc.exists) {
        final oldData = existingDoc.data();
        if (oldData != null && oldData['createdAt'] != null) {
          review['createdAt'] = oldData['createdAt'];
        }
      }

      await revDocRef.set(review, SetOptions(merge: true));

      final reviewsSnap = await docRef.collection('reviews').get();
      final allReviews = reviewsSnap.docs;
      final count = allReviews.length;
      if (count > 0) {
        final totalStars = allReviews.fold<double>(0.0, (acc, d) {
          final r = (d.data()['rating'] as num?)?.toDouble() ?? 0.0;
          return acc + r;
        });
        final avgRating = double.parse((totalStars / count).toStringAsFixed(1));
        await docRef.update({
          'rating': avgRating,
          'reviewCount': count,
        });
      }
    } catch (_) {}
  }

  Future<void> submitFarmerReview({
    required String farmerId,
    required String farmerName,
    required double rating,
    required String comment,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    List<String> tags = const [],
    String? reviewId,
  }) async {
    String finalReviewId = reviewId ?? '';
    if (finalReviewId.isEmpty) {
      final existing = await getUserFarmerReview(farmerId, authorId);
      if (existing != null && (existing['id'] as String?)?.isNotEmpty == true) {
        finalReviewId = existing['id'] as String;
      } else {
        finalReviewId = 'farm_rev_${farmerId.substring(0, farmerId.length.clamp(0, 8))}_$authorId';
      }
    }

    final review = <String, dynamic>{
      'id': finalReviewId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'authorId': authorId,
      'authorName': authorName.isNotEmpty ? authorName : 'Customer',
      'authorAvatar': authorAvatar ?? '',
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'updatedAt': Timestamp.now(),
      'createdAt': Timestamp.now(),
      'isDemo': false,
    };

    _localFarmerReviews.putIfAbsent(farmerId, () => []);
    final localList = _localFarmerReviews[farmerId]!;
    final existingIdx = localList.indexWhere(
      (r) => r['id'] == finalReviewId || (r['authorId'] == authorId && r['isDemo'] != true),
    );
    if (existingIdx != -1) {
      final old = localList[existingIdx];
      review['createdAt'] = old['createdAt'] ?? Timestamp.now();
      localList[existingIdx] = review;
    } else {
      localList.insert(0, review);
    }
    _updateNotifier.add(farmerId);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId);

      final revDocRef = docRef.collection('reviews').doc(finalReviewId);
      final existingDoc = await revDocRef.get();
      if (existingDoc.exists) {
        final oldData = existingDoc.data();
        if (oldData != null && oldData['createdAt'] != null) {
          review['createdAt'] = oldData['createdAt'];
        }
      }

      await revDocRef.set(review, SetOptions(merge: true));

      final reviewsSnap = await docRef.collection('reviews').get();
      final allReviews = reviewsSnap.docs;
      final count = allReviews.length;
      if (count > 0) {
        final totalStars = allReviews.fold<double>(0.0, (acc, d) {
          final r = (d.data()['rating'] as num?)?.toDouble() ?? 0.0;
          return acc + r;
        });
        final avgRating = double.parse((totalStars / count).toStringAsFixed(1));
        await docRef.update({
          'rating': avgRating,
          'reviewCount': count,
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _mergeWithLocal(
    String targetId,
    List<Map<String, dynamic>> source, {
    required bool isFarmer,
  }) {
    final locals = isFarmer
        ? (_localFarmerReviews[targetId] ?? [])
        : (_localProductReviews[targetId] ?? []);

    final seenIds = <String>{};
    final seenRealAuthors = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final rev in locals) {
      final id = rev['id'] as String? ?? '';
      final authorId = rev['authorId'] as String? ?? '';
      final isDemo = rev['isDemo'] == true;
      if (id.isNotEmpty && seenIds.add(id)) {
        if (!isDemo && authorId.isNotEmpty) {
          seenRealAuthors.add(authorId);
        }
        result.add(rev);
      }
    }

    for (final rev in source) {
      final id = rev['id'] as String? ?? rev['authorName'] as String? ?? '';
      final authorId = rev['authorId'] as String? ?? '';
      final isDemo = rev['isDemo'] == true;
      if (!isDemo && authorId.isNotEmpty && seenRealAuthors.contains(authorId)) {
        continue;
      }
      if (seenIds.add(id)) {
        if (!isDemo && authorId.isNotEmpty) {
          seenRealAuthors.add(authorId);
        }
        result.add(rev);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _getDefaultProductReviews(String productId) {
    return [
      {
        'id': 'seed_rev_p1',
        'authorName': 'Thu Ha Le',
        'rating': 5.0,
        'comment': 'Harvested fresh this morning. The vegetables were very crisp, sweet and neatly packed!',
        'tags': ['Super Fresh', 'Outstanding Quality'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_p2',
        'authorName': 'David Nguyen',
        'rating': 4.5,
        'comment': 'Organic produce direct from local farm. Great taste, excellent value for direct pickup.',
        'tags': ['Direct Farm', 'Highly Recommend'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
        'isDemo': true,
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultFarmerReviews(String farmerId) {
    return [
      {
        'id': 'seed_rev_f1',
        'authorName': 'Emily Tran',
        'rating': 5.0,
        'comment': 'Extremely helpful farm owner! Pickup station was easy to find and the harvest was pristine.',
        'tags': ['Friendly Owner', 'Fast Pickup'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_f2',
        'authorName': 'Minh Lam',
        'rating': 4.8,
        'comment': 'Reliable organic produce supplier in Da Lat. Products always stay fresh for days.',
        'tags': ['100% Organic', 'Well Packaged'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_f3',
        'authorName': 'Thanh Son',
        'rating': 4.5,
        'comment': 'Friendly pickup process. Delicious seasonal fruits straight from the orchard.',
        'tags': ['Fresh Harvest'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 14))),
        'isDemo': true,
      },
    ];
  }
}
