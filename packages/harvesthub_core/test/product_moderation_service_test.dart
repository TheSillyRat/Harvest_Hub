/*
 * Unit tests for ProductModerationService
 * Covers sensitive keyword filtering, category mismatch detection,
 * description length rules, and administrative escalation logging.
 * Zero single-line comments rule strictly enforced.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('ProductModerationService - Validation and Moderation', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ProductModerationService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ProductModerationService(db: fakeFirestore);
    });

    test('rejects product with description shorter than 15 characters', () async {
      final result = await service.moderateProduct(
        name: 'Fresh Guava',
        description: 'Too short',
        categoryId: 'fruits',
      );

      expect(result.isApproved, isFalse);
      expect(result.violationType, equals('invalid_description'));
      expect(result.severity, equals('low'));
    });

    test('detects sensitive profanity keywords in product name', () async {
      final result = await service.moderateProduct(
        name: 'Product with fuck keyword',
        description: 'This is a test description exceeding fifteen characters.',
        categoryId: 'fruits',
      );

      expect(result.isApproved, isFalse);
      expect(result.violationType, equals('sensitive_keywords'));
      expect(result.isSevere, isTrue);
      expect(result.detectedKeywords, contains('fuck'));
    });

    test('detects prohibited weapons and narcotics in description', () async {
      final result = await service.moderateProduct(
        name: 'Special Green Leaves',
        description: 'Sản phẩm có chứa ma túy và thuốc phiện nguyên chất.',
        categoryId: 'herbs',
      );

      expect(result.isApproved, isFalse);
      expect(result.violationType, equals('sensitive_keywords'));
      expect(result.detectedKeywords, anyOf(contains('ma túy'), contains('thuốc phiện')));
    });

    test('detects category mismatch: fruit listed as vegetable', () async {
      /* Example specified in user prompt: trái thơm, trái ổi -> must be category fruit */
      final result = await service.moderateProduct(
        name: 'Trái ổi sạch ruột hồng',
        description: 'Trái ổi giòn ngọt tự nhiên hái tận vườn mỗi sáng.',
        categoryId: 'vegetables',
      );

      expect(result.isApproved, isFalse);
      expect(result.isCategoryMismatch, isTrue);
      expect(result.suggestedCategoryId, equals('fruits'));
      expect(result.suggestedCategoryName, equals('Fruits'));
    });

    test('detects category mismatch: mushroom listed as fruit', () async {
      final result = await service.moderateProduct(
        name: 'Nấm rơm tươi đóng gói',
        description: 'Nấm rơm tự nhiên sạch không hóa chất bảo quản.',
        categoryId: 'fruits',
      );

      expect(result.isApproved, isFalse);
      expect(result.isCategoryMismatch, isTrue);
      expect(result.suggestedCategoryId, equals('mushrooms'));
    });

    test('approves compliant product text with matching category', () async {
      final result = await service.moderateProduct(
        name: 'Trái ổi sạch ruột hồng tươi ngon',
        description: 'Trái ổi giòn ngọt tự nhiên hái tận vườn mỗi sáng sớm đảm bảo độ ngọt.',
        categoryId: 'fruits',
      );

      /* Local checks pass; without image and remote AI mock it approves locally */
      expect(result.isApproved, isTrue);
      expect(result.violationType, isNull);
    });

    test('logs violation to product_moderation_logs collection in Firestore', () async {
      await service.reportViolationToAdmin(
        farmerId: 'farmer_123',
        farmerName: 'John Farmer',
        productName: 'Prohibited Item',
        violationType: 'sensitive_keywords',
        reason: 'Contained weapons or illicit substance references.',
        severity: 'high',
      );

      final snapshot = await fakeFirestore.collection('product_moderation_logs').get();
      expect(snapshot.docs.length, equals(1));

      final logData = snapshot.docs.first.data();
      expect(logData['farmerId'], equals('farmer_123'));
      expect(logData['farmerName'], equals('John Farmer'));
      expect(logData['productName'], equals('Prohibited Item'));
      expect(logData['violationType'], equals('sensitive_keywords'));
      expect(logData['severity'], equals('high'));
      expect(logData['status'], equals('PENDING_ADMIN_ACTION'));
    });
  });
}
