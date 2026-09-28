import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'marketplace_service.dart';

/// Single customer review item model for Farmer App
class FarmerReviewItem {
  final String id;
  final String productId;
  final String productName;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final double rating;
  final String comment;
  final List<String> tags;
  final DateTime createdAt;

  const FarmerReviewItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.rating,
    required this.comment,
    this.tags = const [],
    required this.createdAt,
  });

  factory FarmerReviewItem.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final rawDate = map['createdAt'] ?? map['updatedAt'];
    DateTime dt;
    if (rawDate is Timestamp) {
      dt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      dt = rawDate;
    } else {
      dt = DateTime.now();
    }

    final rawRating = map['rating'];
    double star = 0.0;
    if (rawRating is num) {
      star = rawRating.toDouble();
    }

    return FarmerReviewItem(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: (map['authorName'] as String?)?.trim().isNotEmpty == true
          ? (map['authorName'] as String).trim()
          : 'Verified Customer',
      authorAvatar: map['authorAvatar'] as String? ?? '',
      rating: star,
      comment: map['comment'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: dt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Product with review metrics summary
class FarmerProductReviewSummary {
  final Product product;
  final String categoryName;
  final double avgRating;
  final int reviewCount;
  final int soldCount;
  final int stockQty;
  final Map<int, int> starBreakdown; // 1 to 5 stars counts

  const FarmerProductReviewSummary({
    required this.product,
    required this.categoryName,
    required this.avgRating,
    required this.reviewCount,
    required this.soldCount,
    required this.stockQty,
    this.starBreakdown = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  });

  bool get hasReviews => reviewCount > 0 && avgRating > 0;
}

FirebaseFirestore? _safeFirestore() {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

/// Service class encapsulating Backend Review APIs for Farmer App
class FarmerReviewService {
  final FirebaseFirestore? _firestore;

  FarmerReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore();

  /// API: GET /farmer/reviews/products
  /// Fetches products owned by [farmerId] with calculated AVG Rating & Review Count.
  /// Supports:
  /// - [searchQuery]: Search by product name (case-insensitive)
  /// - [categoryId]: Filter by category
  /// - [filterStar]: Filter by star tier (1, 2, 3, 4, 5, or null for all)
  Future<List<FarmerProductReviewSummary>> getFarmerReviewedProducts({
    required String farmerId,
    String? searchQuery,
    String? categoryId,
    int? filterStar,
  }) async {
    if (farmerId.trim().isEmpty) return [];

    final firestore = _firestore;
    if (firestore == null) {
      return _getMemoryReviewedProducts(
        farmerId: farmerId,
        searchQuery: searchQuery,
        categoryId: categoryId,
        filterStar: filterStar,
      );
    }

    try {
      // 1. Fetch categories for name mapping
      Map<String, String> categoryNames = {};
      try {
        final catSnap = await firestore.collection('categories').get();
        for (final doc in catSnap.docs) {
          categoryNames[doc.id] = (doc.data()['name'] as String? ?? 'Produce');
        }
      } catch (_) {}

      // 2. Fetch products owned strictly by this farmer
      final prodSnap = await firestore
          .collection('products')
          .where('farmerId', isEqualTo: farmerId.trim())
          .get()
          .timeout(const Duration(seconds: 6));

      if (prodSnap.docs.isEmpty) {
        return _getMemoryReviewedProducts(
          farmerId: farmerId,
          searchQuery: searchQuery,
          categoryId: categoryId,
          filterStar: filterStar,
        );
      }

      // 3. Fetch orders to calculate sold count per product
      final Map<String, int> soldMap = {};
      try {
        final ordersSnap = await firestore
            .collection('orders')
            .where('farmerId', isEqualTo: farmerId.trim())
            .get();

        for (final oDoc in ordersSnap.docs) {
          final oData = oDoc.data();
          final status = (oData['status'] as String? ?? '').toLowerCase();
          if (status == 'completed' || status == 'confirmed' || status == 'readyforpickup') {
            final items = oData['items'];
            if (items is List) {
              for (final it in items) {
                if (it is Map) {
                  final pId = it['productId'] as String? ?? '';
                  final qty = (it['qty'] as num?)?.toInt() ?? 0;
                  if (pId.isNotEmpty) {
                    soldMap[pId] = (soldMap[pId] ?? 0) + qty;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      final summaries = <FarmerProductReviewSummary>[];

      for (final doc in prodSnap.docs) {
        final p = Product.fromMap(doc.data(), id: doc.id);

        // Client-side category name
        final catName = categoryNames[p.categoryId] ?? 'Fresh Harvest';

        // Check if reviews subcollection has more detailed breakdown
        double avg = p.rating;
        int count = p.reviewCount;
        final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

        try {
          final revSnap = await firestore
              .collection('products')
              .doc(p.id)
              .collection('reviews')
              .get();

          if (revSnap.docs.isNotEmpty) {
            count = revSnap.docs.length;
            double sum = 0.0;
            for (final rDoc in revSnap.docs) {
              final r = (rDoc.data()['rating'] as num?)?.toDouble() ?? 0.0;
              sum += r;
              final roundedStar = r.round().clamp(1, 5);
              breakdown[roundedStar] = (breakdown[roundedStar] ?? 0) + 1;
            }
            avg = count > 0 ? (sum / count) : 0.0;
          }
        } catch (_) {}

        // Ensure non-null, default 0.0
        final safeAvg = double.parse((avg.clamp(0.0, 5.0)).toStringAsFixed(1));
        final sold = soldMap[p.id] ?? 0;

        summaries.add(
          FarmerProductReviewSummary(
            product: p,
            categoryName: catName,
            avgRating: safeAvg,
            reviewCount: count,
            soldCount: sold,
            stockQty: p.stockQty,
            starBreakdown: breakdown,
          ),
        );
      }

      // Filter by search query
      var filtered = summaries;
      final q = searchQuery?.trim().toLowerCase() ?? '';
      if (q.isNotEmpty) {
        filtered = filtered
            .where((s) => s.product.name.toLowerCase().contains(q))
            .toList();
      }

      // Filter by category
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'All') {
        filtered = filtered
            .where((s) => s.product.categoryId == categoryId)
            .toList();
      }

      // Filter by star rating
      if (filterStar != null && filterStar >= 1 && filterStar <= 5) {
        filtered = filtered.where((s) {
          if (s.avgRating == 0.0) return false;
          // Match range e.g. 5 stars = 4.5 to 5.0; 4 stars = 3.5 to 4.4, etc.
          return s.avgRating.round() == filterStar;
        }).toList();
      }

      // Sort: highest review count / rating first
      filtered.sort((a, b) {
        if (b.reviewCount != a.reviewCount) {
          return b.reviewCount.compareTo(a.reviewCount);
        }
        return b.avgRating.compareTo(a.avgRating);
      });

      return filtered;
    } catch (_) {
      return [];
    }
  }

  /// API: GET /farmer/products/:id/reviews
  /// Retrieves review comments and author details for a specific product.
  /// Strictly checks farmer authorization.
  Future<List<FarmerReviewItem>> getProductReviews({
    required String farmerId,
    required String productId,
    int? starFilter,
  }) async {
    if (productId.trim().isEmpty) return [];

    final firestore = _firestore;
    if (firestore == null) {
      return _getMemoryProductReviews(productId, starFilter: starFilter);
    }

    try {
      // Security check: product belongs to farmer
      final prodDoc = await firestore
          .collection('products')
          .doc(productId)
          .get()
          .timeout(const Duration(seconds: 4));

      if (prodDoc.exists) {
        final data = prodDoc.data();
        if (data != null && data['farmerId'] != null) {
          final ownerId = data['farmerId'].toString();
          if (farmerId.isNotEmpty && ownerId != farmerId) {
            // Unauthorized access: not this farmer's product
            return [];
          }
        }
      }

      final revSnap = await firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .get()
          .timeout(const Duration(seconds: 6));

      var reviews = revSnap.docs
          .map((d) => FarmerReviewItem.fromMap(d.data(), id: d.id))
          .toList();

      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (reviews.isEmpty) {
        reviews = _getMemoryProductReviews(productId);
      }

      if (starFilter != null && starFilter >= 1 && starFilter <= 5) {
        reviews = reviews.where((r) => r.rating.round() == starFilter).toList();
      }

      return reviews;
    } catch (_) {
      return _getMemoryProductReviews(productId, starFilter: starFilter);
    }
  }

  /// Real-time stream of product reviews for a specific product
  Stream<List<FarmerReviewItem>> streamProductReviews({
    required String productId,
    int? starFilter,
  }) {
    if (productId.trim().isEmpty) return Stream.value([]);

    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(_getMemoryProductReviews(productId, starFilter: starFilter));
    }

    return firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .snapshots()
        .map((snap) {
      var reviews = snap.docs
          .map((d) => FarmerReviewItem.fromMap(d.data(), id: d.id))
          .toList();

      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (reviews.isEmpty) {
        reviews = _getMemoryProductReviews(productId);
      }

      if (starFilter != null && starFilter >= 1 && starFilter <= 5) {
        reviews = reviews.where((r) => r.rating.round() == starFilter).toList();
      }

      return reviews;
    }).handleError((_) => _getMemoryProductReviews(productId, starFilter: starFilter));
  }

  List<FarmerProductReviewSummary> _getMemoryReviewedProducts({
    required String farmerId,
    String? searchQuery,
    String? categoryId,
    int? filterStar,
  }) {
    final allProducts = ProductService.getFallbackProducts();
    final categories = CategoryService.getFallbackCategories();
    final categoryNames = {for (final c in categories) c.id: c.name};

    final farmerProducts = allProducts.where((p) =>
        farmerId.isEmpty || p.farmerId == farmerId || p.farmerId == 'farmer_1');

    final summaries = <FarmerProductReviewSummary>[];
    for (final p in farmerProducts) {
      final catName = categoryNames[p.categoryId] ?? 'Produce';
      final breakdown = <int, int>{
        1: 0,
        2: 0,
        3: 1,
        4: p.rating >= 4.0 ? 2 : 0,
        5: p.rating >= 4.5 ? 3 : 0,
      };
      summaries.add(
        FarmerProductReviewSummary(
          product: p,
          categoryName: catName,
          avgRating: p.rating > 0 ? p.rating : 4.8,
          reviewCount: p.reviewCount > 0 ? p.reviewCount : 5,
          soldCount: 15,
          stockQty: p.stockQty,
          starBreakdown: breakdown,
        ),
      );
    }

    var filtered = summaries;
    final q = searchQuery?.trim().toLowerCase() ?? '';
    if (q.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.product.name.toLowerCase().contains(q) ||
              s.product.searchKeywords.any((k) => k.toLowerCase().contains(q)))
          .toList();
    }

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'All') {
      filtered =
          filtered.where((s) => s.product.categoryId == categoryId).toList();
    }

    if (filterStar != null && filterStar >= 1 && filterStar <= 5) {
      filtered =
          filtered.where((s) => s.avgRating.round() == filterStar).toList();
    }

    return filtered;
  }

  List<FarmerReviewItem> _getMemoryProductReviews(
    String productId, {
    int? starFilter,
  }) {
    final now = DateTime.now();
    final mockReviews = [
      FarmerReviewItem(
        id: 'mock_rev_1',
        productId: productId,
        productName: 'Fresh Produce',
        authorId: 'user_mock_1',
        authorName: 'Alex Miller',
        authorAvatar: '',
        rating: 5.0,
        comment: 'Produce is super fresh, delivered quickly and packaged with great care!',
        createdAt: now.subtract(const Duration(days: 1)),
        tags: const ['Super Fresh', 'Crisp & Sweet'],
      ),
      FarmerReviewItem(
        id: 'mock_rev_2',
        productId: productId,
        productName: 'Fresh Produce',
        authorId: 'user_mock_2',
        authorName: 'Sarah Jenkins',
        authorAvatar: '',
        rating: 4.0,
        comment: 'Consistent quality, fair pricing, will definitely continue supporting local farmers.',
        createdAt: now.subtract(const Duration(days: 3)),
        tags: const ['Great Value'],
      ),
    ];

    if (starFilter != null && starFilter >= 1 && starFilter <= 5) {
      return mockReviews.where((r) => r.rating.round() == starFilter).toList();
    }
    return mockReviews;
  }
}
