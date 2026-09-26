import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:customer_app/screens/chatbot_screen.dart';
import 'package:provider/provider.dart';

class FakeProductService extends ProductService {
  final List<Product> products;
  FakeProductService([this.products = const []]);

  @override
  Stream<List<Product>> streamActiveProducts({String? categoryId, String? search}) {
    return Stream.value(products);
  }
}

void main() {
  group('FaqService & AI Assistant Tests', () {
    test('FaqService produces offline fallback for standard queries', () {
      final faq = FaqService();

      final deliveryAns = faq.answer('How does delivery or pickup work?');
      expect(deliveryAns.contains('pickup'), isTrue);

      final organicAns = faq.answer('Are products organic?');
      expect(organicAns.contains('organic') || organicAns.contains('fresh'), isTrue);

      final nutritionAns = faq.answer('What vitamins are in fresh vegetables?');
      expect(nutritionAns.contains('vitamins'), isTrue);
    });

    test('FaqService parses fallback answers with live products', () async {
      final faq = FaqService(apiKey: '');
      final testProducts = [
        Product(
          id: 'p1',
          farmerId: 'f1',
          farmerName: 'Green Farm',
          name: 'Da Lat Strawberries',
          categoryId: 'fruits',
          description: 'Fresh organic strawberries',
          price: 450,
          unit: 'kg',
          stockQty: 20,
          imageUrl: '',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = await faq.getAiResponse(
        'Recommend fresh fruits in store',
        liveProducts: testProducts,
      );

      expect(result.text.isNotEmpty, isTrue);
      expect(result.pinnedProductIds.contains('p1'), isTrue);
    });
  });

  group('ChatbotScreen Widget Tests', () {
    testWidgets('renders AI Farm Assistant header and quick topic chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>(
                create: (_) => AuthController(),
              ),
              ChangeNotifierProvider<CartController>(
                create: (_) => CartController(),
              ),
            ],
            child: ChatbotScreen(
              customApiKey: '',
              productService: FakeProductService(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Farm Assistant'), findsOneWidget);
      expect(find.text('Nutrition & Health'), findsOneWidget);
      expect(find.text('Storage & Preservation'), findsOneWidget);
    });
  });
}
