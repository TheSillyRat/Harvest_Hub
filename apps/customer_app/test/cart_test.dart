import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import 'package:customer_app/screens/cart_sheet.dart';

Product _createProduct({
  required String id,
  required String name,
  required String farmerId,
  required String farmerName,
  int price = 300,
  int stockQty = 20,
}) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: name,
    farmerId: farmerId,
    farmerName: farmerName,
    categoryId: 'veg',
    description: 'Fresh local farm produce',
    price: price,
    unit: 'kg',
    stockQty: stockQty,
    imageUrl: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrapWithCart({
  required CartController cart,
  VoidCallback? onOrderPlaced,
  VoidCallback? onExplore,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: AuthController()),
      ChangeNotifierProvider<CartController>.value(value: cart),
    ],
    child: MaterialApp(
      theme: harvestHubTheme(),
      home: CustomerCartSheet(
        onOrderPlaced: onOrderPlaced,
        onExplore: onExplore,
      ),
    ),
  );
}

void main() {
  testWidgets('renders empty basket state with CTA button', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    var explored = false;
    await tester.pumpWidget(
      _wrapWithCart(
        cart: cart,
        onExplore: () => explored = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your basket is empty'), findsOneWidget);
    expect(find.text('Explore Fresh Produce'), findsOneWidget);

    await tester.tap(find.text('Explore Fresh Produce'));
    await tester.pumpAndSettle();
    expect(explored, isTrue);
  });

  testWidgets('groups items by farmer with headers and correct subtotals', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    final p1 = _createProduct(
      id: 'p1',
      name: 'Organic Carrots',
      farmerId: 'farmer_1',
      farmerName: 'Sunshine Farm',
      price: 200,
    );
    final p2 = _createProduct(
      id: 'p2',
      name: 'Crisp Lettuce',
      farmerId: 'farmer_1',
      farmerName: 'Sunshine Farm',
      price: 150,
    );
    final p3 = _createProduct(
      id: 'p3',
      name: 'Red Apples',
      farmerId: 'farmer_2',
      farmerName: 'Highland Orchard',
      price: 400,
    );

    await cart.addToCart(p1, 2); // 200 * 2 = 400
    await cart.addToCart(p2, 1); // 150 * 1 = 150 => Sunshine Farm subtotal = 550 ($5.50)
    await cart.addToCart(p3, 3); // 400 * 3 = 1200 => Highland Orchard subtotal = 1200 ($12.00)

    await tester.pumpWidget(_wrapWithCart(cart: cart));
    await tester.pumpAndSettle();

    // Verify both farm headers are present
    expect(find.text('Sunshine Farm'), findsOneWidget);
    expect(find.text('Highland Orchard'), findsOneWidget);

    // Verify farm item counts
    expect(find.text('2 produce items'), findsOneWidget);
    expect(find.text('1 produce item'), findsOneWidget);

    // Verify individual items are displayed
    expect(find.text('Organic Carrots'), findsOneWidget);
    expect(find.text('Crisp Lettuce'), findsOneWidget);
    expect(find.text('Red Apples'), findsOneWidget);

    // Verify farm subtotals
    expect(find.text('\$5.50'), findsOneWidget);
    expect(find.text('\$12.00'), findsOneWidget);

    // Overall total: $5.50 + $12.00 = $17.50
    expect(find.text('\$17.50'), findsOneWidget);
  });

  testWidgets('increments and decrements item quantity', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    final p1 = _createProduct(
      id: 'p1',
      name: 'Farm Fresh Eggs',
      farmerId: 'farmer_1',
      farmerName: 'Sunrise Farm',
      price: 500,
    );

    await cart.addToCart(p1, 2);

    await tester.pumpWidget(_wrapWithCart(cart: cart));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('\$10.00'), findsWidgets);

    // Increment
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('\$15.00'), findsWidgets);

    // Decrement
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('\$10.00'), findsWidgets);
  });

  testWidgets('removes an item using delete button', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    final p1 = _createProduct(
      id: 'p1',
      name: 'Sweet Corn',
      farmerId: 'farmer_1',
      farmerName: 'Sunny Acre',
      price: 100,
    );

    await cart.addToCart(p1, 1);

    await tester.pumpWidget(_wrapWithCart(cart: cart));
    await tester.pumpAndSettle();

    expect(find.text('Sweet Corn'), findsOneWidget);

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // Basket should now be empty
    expect(find.text('Your basket is empty'), findsOneWidget);
    expect(find.text('Removed Sweet Corn from basket'), findsOneWidget);
  });

  testWidgets('shows confirmation dialog when clearing all items', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    final p1 = _createProduct(
      id: 'p1',
      name: 'Fresh Mint',
      farmerId: 'farmer_1',
      farmerName: 'Herb Garden',
      price: 80,
    );

    await cart.addToCart(p1, 1);

    await tester.pumpWidget(_wrapWithCart(cart: cart));
    await tester.pumpAndSettle();

    // Tap Clear action in AppBar
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Clear Basket?'), findsOneWidget);
    expect(find.text('Are you sure you want to remove all produce from your basket?'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Mint'), findsOneWidget);

    // Tap Clear again and confirm
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(find.text('Your basket is empty'), findsOneWidget);
    expect(find.text('Farm basket cleared'), findsOneWidget);
  });

  testWidgets('warns and restricts checkout if a farm exceeds 8 items', (tester) async {
    final cart = CartController();
    addTearDown(cart.dispose);

    // Add 9 different products for the same farmer
    for (int i = 1; i <= 9; i++) {
      final p = _createProduct(
        id: 'p$i',
        name: 'Item $i',
        farmerId: 'farmer_heavy',
        farmerName: 'Giant Farm',
        price: 100,
      );
      await cart.addToCart(p, 1);
    }

    await tester.pumpWidget(_wrapWithCart(cart: cart));
    await tester.pumpAndSettle();

    // Verify limit warning banner is shown
    expect(
      find.text('Max 8 items allowed per farm in one order. Please remove extra items.'),
      findsOneWidget,
    );

    // Button should be disabled with warning text
    expect(find.text('Reduce items to checkout'), findsOneWidget);
  });
}
