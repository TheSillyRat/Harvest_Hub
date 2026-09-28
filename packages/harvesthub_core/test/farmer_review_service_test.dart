import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

Product _sampleProduct({
  required String id,
  required String name,
  required String categoryId,
  int price = 50000,
  int stockQty = 100,
  String farmerId = 'f1',
  String farmerName = 'Farmer One',
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    farmerId: farmerId,
    farmerName: farmerName,
    name: name,
    categoryId: categoryId,
    description: 'Fresh organic produce harvested directly from farm.',
    price: price,
    unit: 'kg',
    stockQty: stockQty,
    imageUrl: 'https://example.com/item.jpg',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('FarmerReviewItem and FarmerProductReviewSummary Tests', () {
    test('FarmerReviewItem serializes and deserializes correctly', () {
      final now = DateTime(2026, 9, 28, 12, 0, 0);
      final item = FarmerReviewItem(
        id: 'rev_1',
        productId: 'prod_1',
        productName: 'Organic Tomato',
        authorId: 'cust_1',
        authorName: 'John Doe',
        authorAvatar: 'https://example.com/avatar.jpg',
        rating: 4.5,
        comment: 'Very fresh and juicy tomatoes!',
        createdAt: now,
        tags: const ['Fresh', 'Sweet'],
      );

      final map = item.toMap();
      expect(map['id'], 'rev_1');
      expect(map['productId'], 'prod_1');
      expect(map['productName'], 'Organic Tomato');
      expect(map['authorName'], 'John Doe');
      expect(map['rating'], 4.5);
      expect(map['comment'], 'Very fresh and juicy tomatoes!');
      expect(map['tags'], ['Fresh', 'Sweet']);

      final restored = FarmerReviewItem.fromMap(map, id: 'rev_1');
      expect(restored.id, 'rev_1');
      expect(restored.productId, 'prod_1');
      expect(restored.productName, 'Organic Tomato');
      expect(restored.authorName, 'John Doe');
      expect(restored.rating, 4.5);
      expect(restored.comment, 'Very fresh and juicy tomatoes!');
      expect(restored.tags, ['Fresh', 'Sweet']);
    });

    test('FarmerReviewItem handles missing and null values safely', () {
      final item = FarmerReviewItem.fromMap(const {}, id: 'rev_empty');
      expect(item.id, 'rev_empty');
      expect(item.authorName, 'Verified Customer');
      expect(item.comment, '');
      expect(item.rating, 0.0);
      expect(item.tags, isEmpty);
    });

    test('FarmerProductReviewSummary calculates hasReviews correctly', () {
      final summary = FarmerProductReviewSummary(
        product: _sampleProduct(
          id: 'p1',
          name: 'Apple',
          categoryId: 'fruits',
        ),
        categoryName: 'Fruits',
        avgRating: 4.5,
        reviewCount: 3,
        soldCount: 25,
        stockQty: 100,
        starBreakdown: const {1: 0, 2: 0, 3: 1, 4: 1, 5: 1},
      );

      expect(summary.hasReviews, isTrue);
      expect(summary.avgRating, 4.5);
      expect(summary.reviewCount, 3);
      expect(summary.starBreakdown[5], 1);
      expect(summary.starBreakdown[4], 1);
      expect(summary.starBreakdown[3], 1);
      expect(summary.starBreakdown[2], 0);
      expect(summary.starBreakdown[1], 0);

      final emptySummary = FarmerProductReviewSummary(
        product: _sampleProduct(
          id: 'p2',
          name: 'Banana',
          categoryId: 'fruits',
          stockQty: 0,
        ),
        categoryName: 'Fruits',
        avgRating: 0.0,
        reviewCount: 0,
        soldCount: 0,
        stockQty: 0,
      );

      expect(emptySummary.hasReviews, isFalse);
    });

    test('FarmerReviewService filters memory products by farmer and query', () async {
      final service = FarmerReviewService();
      // farmer_1 owns fallback products
      final result = await service.getFarmerReviewedProducts(
        farmerId: 'farmer_1',
      );

      expect(result, isNotEmpty);
      for (final item in result) {
        expect(item.product.farmerId, 'farmer_1');
        expect(item.avgRating, greaterThanOrEqualTo(0.0));
      }

      // Filter by search query
      final filtered = await service.getFarmerReviewedProducts(
        farmerId: 'farmer_1',
        searchQuery: 'tomato',
      );

      for (final item in filtered) {
        expect(
          item.product.name.toLowerCase().contains('tomato') ||
              item.product.searchKeywords.any((k) => k.toLowerCase().contains('tomato')),
          isTrue,
        );
      }
    });

    test('FarmerReviewService respects star filter', () async {
      final service = FarmerReviewService();
      final fiveStarOnly = await service.getFarmerReviewedProducts(
        farmerId: 'farmer_1',
        filterStar: 5,
      );

      for (final item in fiveStarOnly) {
        expect(item.avgRating, greaterThanOrEqualTo(4.5));
      }
    });
  });
}
