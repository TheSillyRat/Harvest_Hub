import 'dart:async';

import 'package:customer_app/screens/marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class TestProducts extends ProductService {
  final StreamController<List<Product>> events = StreamController.broadcast();
  int requests = 0;

  @override
  Stream<List<Product>> streamActiveProducts(
      {String? categoryId, String search = ''}) {
    requests++;
    return events.stream;
  }
}

class TestCategories extends CategoryService {
  @override
  Stream<List<Category>> streamActive() => Stream.value(const []);
}

void main() {
  testWidgets('empty catalog stays empty and failed loading can be retried',
      (tester) async {
    final products = TestProducts();
    final cart = CartController();
    addTearDown(products.events.close);
    addTearDown(cart.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
          home: MarketplaceScreen(
        productService: products,
        categoryService: TestCategories(),
        onOpenCart: () {},
        onOpenOrders: () {},
        onOpenProfile: () {},
      )),
    ));
    products.events.add([]);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('No produce found'), findsOneWidget);
    expect(find.text('Heirloom Vine Tomatoes'), findsNothing);
    products.events.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load products.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(products.requests, 2);
    products.events.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No produce found'), findsOneWidget);
  });
}
