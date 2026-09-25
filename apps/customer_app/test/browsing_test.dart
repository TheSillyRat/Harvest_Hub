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
  final List<Category> categories;
  TestCategories([this.categories = const []]);
  @override
  Stream<List<Category>> streamActive() => Stream.value(categories);
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
  testWidgets('category and search stay selected when switching to catalog',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = TestProducts();
    final cart = CartController();
    final categories = TestCategories(CategoryService.getFallbackCategories());
    addTearDown(products.events.close);
    addTearDown(cart.dispose);
    Widget app(bool catalog) => ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
              home: MarketplaceScreen(
            catalogOnly: catalog,
            productService: products,
            categoryService: categories,
            onOpenCart: () {},
            onOpenOrders: () {},
            onOpenProfile: () {},
          )),
        );
    await tester.pumpWidget(app(false));
    products.events.add(ProductService.getFallbackProducts()
        .map((p) => p.copyWith(imageUrl: ''))
        .toList());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetables'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsNothing);
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    await tester.tap(find.text('Vegetables'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsNothing);
    await tester.enterText(find.byType(TextField), 'TOMATO');
    await tester.pumpAndSettle();
    expect(find.text('Crisp Butterhead Lettuce'), findsNothing);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    expect(find.text('Honeycrisp Apples'), findsNothing);
    expect(products.requests, 1);
  });
  testWidgets(
      'filters validate prices, apply on confirm and View All resets them',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = TestProducts();
    final cart = CartController();
    addTearDown(products.events.close);
    addTearDown(cart.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
            home: MarketplaceScreen(
          catalogOnly: true,
          productService: products,
          categoryService: TestCategories(),
          onOpenCart: () {},
          onOpenOrders: () {},
          onOpenProfile: () {},
        ))));
    products.events.add(ProductService.getFallbackProducts()
        .take(2)
        .map((p) => p.copyWith(imageUrl: ''))
        .toList());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'farm');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Filter products'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '5');
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Must be at least min price'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '7');
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsOneWidget);
    expect(find.text('Heirloom Vine Tomatoes'), findsNothing);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset All'));
    await tester.pumpAndSettle();
    // Closing the sheet discards the draft reset.
    Navigator.of(tester.element(find.text('Apply Filters'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Heirloom Vine Tomatoes'), findsNothing);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    expect(find.text('Honeycrisp Apples'), findsOneWidget);
  });
}
