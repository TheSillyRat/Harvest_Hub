import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

/// Error codes returned when purchase limits are violated.
class PurchaseLimitCodes {
  /// Customer requested quantity exceeds category ceiling limit (e.g. 20).
  static const String maxLimitReached = 'MAX_LIMIT_REACHED';

  /// Customer requested quantity exceeds current actual inventory (e.g. stock is 8, or stock is 0).
  static const String outOfStockLimit = 'OUT_OF_STOCK_LIMIT';
}

/// Structured outcome of a purchase limit validation check.
class PurchaseLimitResult {
  final bool isAllowed;
  final String? errorCode; // 'MAX_LIMIT_REACHED' or 'OUT_OF_STOCK_LIMIT'
  final String? errorMessage;
  final int currentStock;
  final int categoryLimit;
  final int maxPurchasable;

  const PurchaseLimitResult({
    required this.isAllowed,
    this.errorCode,
    this.errorMessage,
    required this.currentStock,
    required this.categoryLimit,
    required this.maxPurchasable,
  });

  bool get isMaxLimitReached => errorCode == PurchaseLimitCodes.maxLimitReached;
  bool get isOutOfStock => errorCode == PurchaseLimitCodes.outOfStockLimit;

  Map<String, dynamic> toMap() => {
        'isAllowed': isAllowed,
        'status': isAllowed ? 'SUCCESS' : errorCode,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'currentStock': currentStock,
        'categoryLimit': categoryLimit,
        'maxPurchasable': maxPurchasable,
      };

  @override
  String toString() =>
      'PurchaseLimitResult(isAllowed: $isAllowed, errorCode: $errorCode, maxPurchasable: $maxPurchasable, stock: $currentStock, limit: $categoryLimit)';
}

/// Dedicated exception thrown when order quantity exceeds allowed purchase limits.
/// Can be directly caught by Backend API or caller without altering customer UI.
class PurchaseLimitException implements Exception {
  final String code; // 'MAX_LIMIT_REACHED' or 'OUT_OF_STOCK_LIMIT'
  final String productId;
  final String productName;
  final int requestedQty;
  final int currentStock;
  final int categoryLimit;
  final int maxPurchasable;
  final String message;

  PurchaseLimitException({
    required this.code,
    required this.productId,
    this.productName = '',
    required this.requestedQty,
    required this.currentStock,
    required this.categoryLimit,
    required this.maxPurchasable,
    String? message,
  }) : message = message ??
            (code == PurchaseLimitCodes.maxLimitReached
                ? 'Đã đạt giới hạn mua tối đa của danh mục ($categoryLimit sản phẩm)'
                : (currentStock <= 0
                    ? 'Sản phẩm đã hết hàng trong kho'
                    : 'Vượt quá số lượng tồn kho khả dụng ($currentStock sản phẩm)'));

  Map<String, dynamic> toMap() => {
        'code': code,
        'productId': productId,
        'productName': productName,
        'requestedQty': requestedQty,
        'currentStock': currentStock,
        'categoryLimit': categoryLimit,
        'maxPurchasable': maxPurchasable,
        'message': message,
      };

  @override
  String toString() => '$code: $message';
}

/// Evaluates purchase quantity against category limits and real-time inventory.
/// Calculates max purchasable using MIN(categoryLimit, currentStock).
///
/// Rules:
/// - If currentStock <= 0 OR requestedQty > currentStock: returns 'OUT_OF_STOCK_LIMIT'
/// - If requestedQty > categoryLimit: returns 'MAX_LIMIT_REACHED'
/// - Otherwise: purchase is allowed
PurchaseLimitResult evaluatePurchaseLimit({
  required int requestedQty,
  required int currentStock,
  int categoryLimit = 20,
}) {
  final effectiveStock = currentStock < 0 ? 0 : currentStock;
  final effectiveLimit = categoryLimit < 0 ? 0 : categoryLimit;
  final maxPurchasable = math.min(effectiveLimit, effectiveStock);

  // 1. Check stock depletion or exceeding physical stock
  if (effectiveStock <= 0 || requestedQty > effectiveStock) {
    return PurchaseLimitResult(
      isAllowed: false,
      errorCode: PurchaseLimitCodes.outOfStockLimit,
      errorMessage: effectiveStock <= 0
          ? 'Sản phẩm đã hết hàng trong kho'
          : 'Số lượng đặt ($requestedQty) vượt quá tồn kho thực tế ($effectiveStock)',
      currentStock: effectiveStock,
      categoryLimit: effectiveLimit,
      maxPurchasable: maxPurchasable,
    );
  }

  // 2. Check category ceiling limit
  if (requestedQty > effectiveLimit) {
    return PurchaseLimitResult(
      isAllowed: false,
      errorCode: PurchaseLimitCodes.maxLimitReached,
      errorMessage:
          'Số lượng đặt ($requestedQty) vượt mức trần danh mục ($effectiveLimit)',
      currentStock: effectiveStock,
      categoryLimit: effectiveLimit,
      maxPurchasable: maxPurchasable,
    );
  }

  return PurchaseLimitResult(
    isAllowed: true,
    errorCode: null,
    errorMessage: null,
    currentStock: effectiveStock,
    categoryLimit: effectiveLimit,
    maxPurchasable: maxPurchasable,
  );
}

/// Core API & Backend service for Inventory & Purchase Limit management.
/// Uses Firestore Transactions to guarantee race-free atomic updates and prevents
/// products with zero stock from being ordered.
class InventoryService {
  final FirebaseFirestore db;

  InventoryService({FirebaseFirestore? db})
      : db = db ?? FirebaseFirestore.instance;

  /// Check purchase limit for a product without placing an order.
  /// Returns [PurchaseLimitResult] containing exact status, errorCode, and maxPurchasable.
  Future<PurchaseLimitResult> checkPurchaseLimit({
    required String productId,
    required int requestedQty,
    int defaultCategoryLimit = 20,
  }) async {
    final doc = await db.collection('products').doc(productId).get();
    if (!doc.exists) {
      return PurchaseLimitResult(
        isAllowed: false,
        errorCode: PurchaseLimitCodes.outOfStockLimit,
        errorMessage: 'Sản phẩm không còn tồn tại',
        currentStock: 0,
        categoryLimit: defaultCategoryLimit,
        maxPurchasable: 0,
      );
    }

    final product = Product.fromMap(doc.data()!, id: doc.id);
    if (!product.isActive) {
      return PurchaseLimitResult(
        isAllowed: false,
        errorCode: PurchaseLimitCodes.outOfStockLimit,
        errorMessage: 'Sản phẩm tạm ngừng kinh doanh',
        currentStock: 0,
        categoryLimit: defaultCategoryLimit,
        maxPurchasable: 0,
      );
    }

    int catLimit = defaultCategoryLimit;
    try {
      final catDoc =
          await db.collection('categories').doc(product.categoryId).get();
      if (catDoc.exists && catDoc.data() != null) {
        final val = catDoc.data()!['maxPurchaseLimit'];
        if (val is num && val > 0) {
          catLimit = val.toInt();
        }
      }
    } catch (_) {}

    return evaluatePurchaseLimit(
      requestedQty: requestedQty,
      currentStock: product.stockQty,
      categoryLimit: catLimit,
    );
  }

  /// Atomic stock deduction with race condition protection using Firestore Transaction.
  /// Validates both category limit and available stock inside the transaction before updating.
  Future<void> deductStockAtomic({
    required String productId,
    required int requestedQty,
    int defaultCategoryLimit = 20,
  }) async {
    await db.runTransaction((tx) async {
      final ref = db.collection('products').doc(productId);
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw PurchaseLimitException(
          code: PurchaseLimitCodes.outOfStockLimit,
          productId: productId,
          requestedQty: requestedQty,
          currentStock: 0,
          categoryLimit: defaultCategoryLimit,
          maxPurchasable: 0,
          message: 'Sản phẩm không tồn tại',
        );
      }
      final product = Product.fromMap(snapshot.data()!, id: snapshot.id);
      if (!product.isActive) {
        throw PurchaseLimitException(
          code: PurchaseLimitCodes.outOfStockLimit,
          productId: productId,
          productName: product.name,
          requestedQty: requestedQty,
          currentStock: 0,
          categoryLimit: defaultCategoryLimit,
          maxPurchasable: 0,
          message: 'Sản phẩm tạm dừng hoạt động',
        );
      }

      int catLimit = defaultCategoryLimit;
      try {
        final catDoc =
            await tx.get(db.collection('categories').doc(product.categoryId));
        if (catDoc.exists && catDoc.data() != null) {
          final val = catDoc.data()!['maxPurchaseLimit'];
          if (val is num && val > 0) catLimit = val.toInt();
        }
      } catch (_) {}

      final check = evaluatePurchaseLimit(
        requestedQty: requestedQty,
        currentStock: product.stockQty,
        categoryLimit: catLimit,
      );

      if (!check.isAllowed) {
        throw PurchaseLimitException(
          code: check.errorCode!,
          productId: product.id,
          productName: product.name,
          requestedQty: requestedQty,
          currentStock: check.currentStock,
          categoryLimit: check.categoryLimit,
          maxPurchasable: check.maxPurchasable,
          message: check.errorMessage,
        );
      }

      tx.update(ref, {
        'stockQty': product.stockQty - requestedQty,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Farmer Quick Update Stock: safely sets new stock quantity and updates timestamp.
  Future<void> quickUpdateStock({
    required String productId,
    required int newStockQty,
  }) async {
    if (newStockQty < 0) {
      throw ArgumentError('Tồn kho không thể âm');
    }
    await db.collection('products').doc(productId).update({
      'stockQty': newStockQty,
      'updatedAt': Timestamp.now(),
    });
  }
}
