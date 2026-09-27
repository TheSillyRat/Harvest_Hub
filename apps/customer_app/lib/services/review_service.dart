import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  static final ReviewService instance = ReviewService._internal();
  ReviewService._internal();

  // In-memory cache of locally submitted reviews by target (productId or farmerId)
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
      // Yield local + fallback when Firestore is unavailable or in mock test environment
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

  Future<void> submitProductReview({
    required String productId,
    required String productName,
    required double rating,
    required String comment,
    required String authorId,
    required String authorName,
    String? authorAvatar,
    List<String> tags = const [],
  }) async {
    final reviewId = 'rev_${DateTime.now().millisecondsSinceEpoch}_${authorId.hashCode}';
    final review = <String, dynamic>{
      'id': reviewId,
      'productId': productId,
      'productName': productName,
      'authorId': authorId,
      'authorName': authorName.isNotEmpty ? authorName : 'Customer',
      'authorAvatar': authorAvatar ?? '',
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'createdAt': Timestamp.now(),
      'isDemo': false,
    };

    _localProductReviews.putIfAbsent(productId, () => []);
    _localProductReviews[productId]!.insert(0, review);
    _updateNotifier.add(productId);

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .set(review);
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
  }) async {
    final reviewId = 'farm_rev_${DateTime.now().millisecondsSinceEpoch}_${authorId.hashCode}';
    final review = <String, dynamic>{
      'id': reviewId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'authorId': authorId,
      'authorName': authorName.isNotEmpty ? authorName : 'Customer',
      'authorAvatar': authorAvatar ?? '',
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'createdAt': Timestamp.now(),
      'isDemo': false,
    };

    _localFarmerReviews.putIfAbsent(farmerId, () => []);
    _localFarmerReviews[farmerId]!.insert(0, review);
    _updateNotifier.add(farmerId);

    try {
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId)
          .collection('reviews')
          .doc(reviewId)
          .set(review);
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
    final result = <Map<String, dynamic>>[];

    for (final rev in locals) {
      final id = rev['id'] as String? ?? '';
      if (id.isNotEmpty && seenIds.add(id)) {
        result.add(rev);
      }
    }

    for (final rev in source) {
      final id = rev['id'] as String? ?? rev['authorName'] as String? ?? '';
      if (seenIds.add(id)) {
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
        'tags': ['🌿 Super Fresh', '⭐ Outstanding Quality'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_p2',
        'authorName': 'David Nguyen',
        'rating': 4.5,
        'comment': 'Organic produce direct from local farm. Great taste, excellent value for direct pickup.',
        'tags': ['🌱 Direct Farm', '👍 Highly Recommend'],
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
        'tags': ['👨‍🌾 Friendly Owner', '⚡ Fast Pickup'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_f2',
        'authorName': 'Minh Lam',
        'rating': 4.8,
        'comment': 'Reliable organic produce supplier in Da Lat. Products always stay fresh for days.',
        'tags': ['🌿 100% Organic', '📦 Well Packaged'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))),
        'isDemo': true,
      },
      {
        'id': 'seed_rev_f3',
        'authorName': 'Thanh Son',
        'rating': 4.5,
        'comment': 'Friendly pickup process. Delicious seasonal fruits straight from the orchard.',
        'tags': ['🍎 Fresh Harvest'],
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 14))),
        'isDemo': true,
      },
    ];
  }
}
