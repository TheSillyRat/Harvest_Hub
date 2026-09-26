import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('Search Keywords Tests', () {
    test('generateSearchKeywords generates prefixes and full tokens', () {
      final keywords = generateSearchKeywords('Fresh milk');
      expect(keywords, contains('fresh milk'));
      expect(keywords, contains('fresh'));
      expect(keywords, contains('milk'));
      expect(keywords, contains('fre'));
      expect(keywords, contains('mil'));
    });
  });

  group('Product Date Status Tests', () {
    test('New product shows Created date and isEdited == false', () {
      final now = DateTime(2026, 9, 26, 10, 0);
      final p = Product(
        id: 'p1',
        farmerId: 'farmer_1',
        farmerName: 'Farmer One',
        name: 'Fresh Mango',
        categoryId: 'fruits',
        description: 'Delicious sweet mango',
        price: 50000,
        unit: 'kg',
        stockQty: 20,
        imageUrl: '',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(p.isEdited, isFalse);
      expect(p.dateStatusText, startsWith('Created:'));
    });

    test('Edited product shows Last edited date and isEdited == true', () {
      final created = DateTime(2026, 9, 26, 10, 0);
      final updated = DateTime(2026, 9, 26, 15, 30);
      final p = Product(
        id: 'p1',
        farmerId: 'farmer_1',
        farmerName: 'Farmer One',
        name: 'Fresh Mango',
        categoryId: 'fruits',
        description: 'Delicious sweet mango',
        price: 55000,
        unit: 'kg',
        stockQty: 25,
        imageUrl: '',
        isActive: true,
        createdAt: created,
        updatedAt: updated,
      );

      expect(p.isEdited, isTrue);
      expect(p.dateStatusText, startsWith('Last edited:'));
      expect(p.dateStatusText.contains('15:30'), isTrue);
    });
  });

  group('ProductService Server-side Search & Pagination Tests', () {
    final service = ProductService();

    test('getFarmerProductsPage handles limit and ordering', () async {
      final now = DateTime.now();
      await service.addProduct(Product(
        id: 'test_p1',
        farmerId: 'f_test',
        farmerName: 'Test Farm',
        name: 'Cà rốt hữu cơ Đà Lạt',
        categoryId: 'vegetables',
        description: 'Sweet and crunchy carrots',
        price: 30000,
        unit: 'kg',
        stockQty: 50,
        imageUrl: '',
        isActive: true,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ));

      await service.addProduct(Product(
        id: 'test_p2',
        farmerId: 'f_test',
        farmerName: 'Test Farm',
        name: 'Khoai tây vàng',
        categoryId: 'vegetables',
        description: 'Golden fresh potatoes',
        price: 25000,
        unit: 'kg',
        stockQty: 40,
        imageUrl: '',
        isActive: true,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ));

      final newestResult = await service.getFarmerProductsPage(
        farmerId: 'f_test',
        sortDescending: true,
        limit: 10,
      );
      expect(newestResult.products.isNotEmpty, isTrue);
      expect(newestResult.products.first.name, 'Khoai tây vàng');

      final oldestResult = await service.getFarmerProductsPage(
        farmerId: 'f_test',
        sortDescending: false,
        limit: 10,
      );
      expect(oldestResult.products.isNotEmpty, isTrue);
      expect(oldestResult.products.first.name, 'Cà rốt hữu cơ Đà Lạt');

      final searchResult = await service.getFarmerProductsPage(
        farmerId: 'f_test',
        searchQuery: 'rốt',
        limit: 10,
      );
      expect(searchResult.products.length, 1);
      expect(searchResult.products.first.name, 'Cà rốt hữu cơ Đà Lạt');

      final catResult = await service.getFarmerProductsPage(
        farmerId: 'f_test',
        categoryId: 'fruits',
        limit: 10,
      );
      expect(catResult.products, isEmpty);
    });
  });
}
