import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('Farmer App Inventory & Stock Limit Rules', () {
    test('Zero stock product is marked as OUT_OF_STOCK_LIMIT and prevented from order', () {
      final product = Product(
        id: 'p_empty',
        farmerId: 'f1',
        farmerName: 'Green Farm',
        name: 'Organic Cucumbers',
        categoryId: 'vegetables',
        description: 'Crisp fresh cucumbers',
        price: 20000,
        unit: 'kg',
        stockQty: 0,
        imageUrl: '',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Attempting to buy 1 item when stock is 0
      final check = evaluatePurchaseLimit(
        requestedQty: 1,
        currentStock: product.stockQty,
        categoryLimit: 20,
      );

      expect(check.isAllowed, isFalse);
      expect(check.errorCode, 'OUT_OF_STOCK_LIMIT');
      expect(check.maxPurchasable, 0);
    });

    test('Customer order exceeding current inventory returns OUT_OF_STOCK_LIMIT', () {
      final check = evaluatePurchaseLimit(
        requestedQty: 10,
        currentStock: 8, // available 8
        categoryLimit: 20,
      );

      expect(check.isAllowed, isFalse);
      expect(check.errorCode, 'OUT_OF_STOCK_LIMIT');
      expect(check.maxPurchasable, 8);
    });

    test('Customer order exceeding category ceiling returns MAX_LIMIT_REACHED', () {
      final check = evaluatePurchaseLimit(
        requestedQty: 25,
        currentStock: 40, // plenty of stock
        categoryLimit: 20, // category max is 20
      );

      expect(check.isAllowed, isFalse);
      expect(check.errorCode, 'MAX_LIMIT_REACHED');
      expect(check.maxPurchasable, 20);
    });

    test('Customer order within both limits is approved', () {
      final check = evaluatePurchaseLimit(
        requestedQty: 5,
        currentStock: 8,
        categoryLimit: 20,
      );

      expect(check.isAllowed, isTrue);
      expect(check.errorCode, isNull);
      expect(check.maxPurchasable, 8);
    });
  });
}
