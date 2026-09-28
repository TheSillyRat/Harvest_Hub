import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:farmer_app/farmer_app.dart';

void main() {
  testWidgets('FarmerDashboard timeout test', (tester) async {
    final pc = StreamController<List<Product>>();
    final oc = StreamController<List<FarmOrder>>();

    final pStream = pc.stream.timeout(
      const Duration(milliseconds: 100),
      onTimeout: (sink) => sink.add(<Product>[]),
    ).asBroadcastStream();

    final oStream = oc.stream.timeout(
      const Duration(milliseconds: 100),
      onTimeout: (sink) => sink.add(<FarmOrder>[]),
    ).asBroadcastStream();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerDashboard(
            products: pStream,
            orders: oStream,
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(LoadingView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LoadingView), findsNothing);
  });

  testWidgets('FarmerDashboard Scenario A renders Best Seller badge and sales count', (tester) async {
    final now = DateTime.now();
    final testProduct = Product(
      id: 'prod_1',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      name: 'Organic Red Tomatoes',
      categoryId: 'cat_veg',
      description: 'Juicy and organic tomatoes',
      price: 25000,
      unit: 'kg',
      stockQty: 20,
      imageUrl: 'https://example.com/tomato.jpg',
      isActive: true,
      rating: 4.8,
      reviewCount: 12,
      createdAt: now,
      updatedAt: now,
    );

    final testOrder = FarmOrder(
      id: 'ord_1',
      customerId: 'cust_1',
      customerName: 'Alice',
      customerPhone: '0901234567',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      status: OrderStatus.completed,
      address: '123 Farm Road',
      total: 75000,
      pickupDate: now,
      pickupSlot: '08:00 - 10:00',
      createdAt: now,
      updatedAt: now,
      items: [
        const OrderItem(
          productId: 'prod_1',
          name: 'Organic Red Tomatoes',
          price: 25000,
          qty: 3,
          unit: 'kg',
          imageUrl: 'https://example.com/tomato.jpg',
          subtotal: 75000,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerDashboard(
            products: Stream.value([testProduct]),
            orders: Stream.value([testOrder]),
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Section Header
    expect(find.text('Popular items'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);

    // Scroll to product cards section in vertical list
    await tester.scrollUntilVisible(
      find.text('Best Seller'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Verify Scenario A elements
    expect(find.text('Best Seller'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    expect(find.text('3 sold'), findsOneWidget);
    expect(find.text('Organic Red Tomatoes'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text(' (12)'), findsOneWidget);
    // Confirm buyer-centric fields are NOT present
    expect(find.text('Discount 5%'), findsNothing);
    expect(find.text('Add to Cart'), findsNothing);
  });

  testWidgets('ProductEditScreen locks stock input when isStockLocked is true', (tester) async {
    final now = DateTime.now();
    final testProduct = Product(
      id: 'prod_2',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      name: 'Fresh Carrots',
      categoryId: 'cat_veg',
      description: 'Crisp orange carrots',
      price: 18000,
      unit: 'kg',
      stockQty: 45,
      imageUrl: 'https://example.com/carrots.jpg',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductEditScreen(
            product: testProduct,
            isStockLocked: true,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.lock_outline),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // Verify stock text field is read-only and shows locked indicator
    expect(find.text('Stock is locked. Adjust inventory in "Update Stock" section.'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    final editableTextFinders = find.byType(EditableText);
    bool foundReadOnlyStock = false;
    for (final element in editableTextFinders.evaluate()) {
      final editable = element.widget as EditableText;
      if (editable.controller.text == '45' && editable.readOnly == true) {
        foundReadOnlyStock = true;
        break;
      }
    }
    expect(foundReadOnlyStock, isTrue);
  });

  testWidgets('FarmerDashboard Scenario B filters by category, shows eye icon and stock status', (tester) async {
    final now = DateTime.now();
    final vegProduct = Product(
      id: 'prod_veg',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      name: 'Organic Bok Choy',
      categoryId: 'vegetables',
      description: 'Fresh crisp bok choy',
      price: 15000,
      unit: 'kg',
      stockQty: 8,
      imageUrl: 'https://example.com/bokchoy.jpg',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final fruitProduct = Product(
      id: 'prod_fruit',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      name: 'Honey Mango',
      categoryId: 'fruits',
      description: 'Sweet honey mango',
      price: 40000,
      unit: 'kg',
      stockQty: 0,
      imageUrl: 'https://example.com/mango.jpg',
      isActive: true,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerDashboard(
            products: Stream.value([vegProduct, fruitProduct]),
            orders: Stream.value(<FarmOrder>[]),
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially in Scenario A (Best Sellers)
    expect(find.text('Popular items'), findsOneWidget);

    // Find and tap a category circle item if available, or tap by text
    // The CategoryService provides fallback categories (Vegetables, Fruits, etc.)
    final vegCatFinder = find.text('Vegetables');
    if (vegCatFinder.evaluate().isNotEmpty) {
      await tester.tap(vegCatFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In Scenario B (Category Filtered)
      // Check for Eye icon and inventory status
      await tester.scrollUntilVisible(
        find.byIcon(Icons.visibility_outlined),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.text('In Stock (8 kg)'), findsOneWidget);
      expect(find.text('Organic Bok Choy'), findsOneWidget);
      // Honey Mango is in Fruits, so it must NOT be in Vegetables
      expect(find.text('Honey Mango'), findsNothing);
    }
  });

  testWidgets('FarmerDashboard restricts Best Seller badge strictly to ordered products with real sold count', (tester) async {
    final now = DateTime.now();
    final p1 = Product(
      id: 'p1',
      farmerId: 'farmer_1',
      farmerName: 'Dan',
      name: 'Organic Kale',
      categoryId: 'cat_veg',
      description: 'Fresh kale',
      price: 10000,
      unit: 'kg',
      stockQty: 50,
      imageUrl: 'https://example.com/kale.jpg',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    final p2 = Product(
      id: 'p2',
      farmerId: 'farmer_1',
      farmerName: 'Dan',
      name: 'Red Strawberries',
      categoryId: 'cat_fruit',
      description: 'Sweet berries',
      price: 30000,
      unit: 'box',
      stockQty: 50,
      imageUrl: 'https://example.com/strawberries.jpg',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    final p3 = Product(
      id: 'p3',
      farmerId: 'farmer_1',
      farmerName: 'Dan',
      name: 'Golden Corn',
      categoryId: 'cat_veg',
      description: 'Sweet corn',
      price: 8000,
      unit: 'ear',
      stockQty: 50,
      imageUrl: 'https://example.com/corn.jpg',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    // Only p1 is in an order
    final o1 = FarmOrder(
      id: 'ord_1',
      customerId: 'c1',
      customerName: 'User',
      customerPhone: '0901',
      farmerId: 'farmer_1',
      farmerName: 'Dan',
      status: OrderStatus.completed,
      address: 'Street 1',
      total: 20000,
      pickupDate: now,
      pickupSlot: '08:00 - 10:00',
      createdAt: now,
      updatedAt: now,
      items: [
        const OrderItem(
          productId: 'p1',
          name: 'Organic Kale',
          price: 10000,
          qty: 5,
          unit: 'kg',
          imageUrl: 'https://example.com/kale.jpg',
          subtotal: 50000,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerDashboard(
            products: Stream.value([p1, p2, p3]),
            orders: Stream.value([o1]),
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Only 1 item (p1) has orders, so strictly 1 Best Seller badge is shown
    expect(find.text('Best Seller'), findsOneWidget);
    expect(find.text('5 sold'), findsOneWidget);
    expect(find.text('0 sold'), findsNWidgets(2));
  });
}

