import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('Inventory & Purchase Limit Evaluation', () {
    test('Calculates maxPurchasable using MIN(categoryLimit, currentStock)', () {
      // Case 1: stock (8) < limit (20) -> max is 8
      final result1 = evaluatePurchaseLimit(
        requestedQty: 5,
        currentStock: 8,
        categoryLimit: 20,
      );
      expect(result1.maxPurchasable, 8);
      expect(result1.isAllowed, isTrue);
      expect(result1.errorCode, isNull);

      // Case 2: limit (20) < stock (50) -> max is 20
      final result2 = evaluatePurchaseLimit(
        requestedQty: 15,
        currentStock: 50,
        categoryLimit: 20,
      );
      expect(result2.maxPurchasable, 20);
      expect(result2.isAllowed, isTrue);
      expect(result2.errorCode, isNull);
    });

    test('Returns OUT_OF_STOCK_LIMIT when requested quantity exceeds real stock', () {
      // Current stock is 8, customer requests 10 (which is <= category limit 20, but > stock 8)
      final result = evaluatePurchaseLimit(
        requestedQty: 10,
        currentStock: 8,
        categoryLimit: 20,
      );
      expect(result.isAllowed, isFalse);
      expect(result.errorCode, PurchaseLimitCodes.outOfStockLimit);
      expect(result.isOutOfStock, isTrue);
      expect(result.isMaxLimitReached, isFalse);
      expect(result.maxPurchasable, 8);
    });

    test('Returns OUT_OF_STOCK_LIMIT when stock is 0 (Prevent zero-stock ordering)', () {
      final result = evaluatePurchaseLimit(
        requestedQty: 1,
        currentStock: 0,
        categoryLimit: 20,
      );
      expect(result.isAllowed, isFalse);
      expect(result.errorCode, PurchaseLimitCodes.outOfStockLimit);
      expect(result.isOutOfStock, isTrue);
      expect(result.maxPurchasable, 0);
    });

    test('Returns MAX_LIMIT_REACHED when requested quantity exceeds category ceiling', () {
      // Current stock is 50, category limit is 20, customer requests 25
      final result = evaluatePurchaseLimit(
        requestedQty: 25,
        currentStock: 50,
        categoryLimit: 20,
      );
      expect(result.isAllowed, isFalse);
      expect(result.errorCode, PurchaseLimitCodes.maxLimitReached);
      expect(result.isMaxLimitReached, isTrue);
      expect(result.isOutOfStock, isFalse);
      expect(result.maxPurchasable, 20);
    });

    test('Handles custom category limits correctly', () {
      // Category limit configured to 15
      final result = evaluatePurchaseLimit(
        requestedQty: 16,
        currentStock: 30,
        categoryLimit: 15,
      );
      expect(result.isAllowed, isFalse);
      expect(result.errorCode, PurchaseLimitCodes.maxLimitReached);
      expect(result.maxPurchasable, 15);
    });

    test('PurchaseLimitException contains proper code and details', () {
      final ex = PurchaseLimitException(
        code: PurchaseLimitCodes.maxLimitReached,
        productId: 'prod_123',
        productName: 'Cherry Tomatoes',
        requestedQty: 25,
        currentStock: 30,
        categoryLimit: 20,
        maxPurchasable: 20,
      );
      expect(ex.code, 'MAX_LIMIT_REACHED');
      expect(ex.productId, 'prod_123');
      expect(ex.requestedQty, 25);
      expect(ex.categoryLimit, 20);
      expect(ex.maxPurchasable, 20);

      final map = ex.toMap();
      expect(map['code'], 'MAX_LIMIT_REACHED');
      expect(map['requestedQty'], 25);
    });
  });
}
