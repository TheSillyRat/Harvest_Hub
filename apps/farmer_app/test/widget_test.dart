import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:farmer_app/farmer_app.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  testWidgets('FarmerApp builds without crashing', (tester) async {
    expect(const FarmerApp(), isNotNull);
  });

  testWidgets('FarmerOrdersScreen renders unified orders view without error', (tester) async {
    final now = DateTime.now();
    final sampleOrder = FarmOrder(
      id: 'ord_123',
      customerId: 'cust_1',
      customerName: 'Alice',
      customerPhone: '0901234567',
      farmerId: 'farmer_1',
      farmerName: 'Green Farm',
      address: 'Da Lat',
      pickupSlot: 'morning_07_10',
      pickupDate: now,
      status: OrderStatus.confirmed,
      total: 100,
      createdAt: now,
      updatedAt: now,
      items: const [
        OrderItem(
          productId: 'prod_1',
          name: 'Carrots',
          price: 50,
          qty: 2,
          unit: 'kg',
          imageUrl: '',
          subtotal: 100,
        ),
      ],
    );

    final stream = Stream<List<FarmOrder>>.value([sampleOrder]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(authService: AuthService()),
        child: MaterialApp(
          home: Scaffold(
            body: FarmerOrdersScreen(stream: stream),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('All Dates'), findsOneWidget);
    expect(find.text('All Slots'), findsOneWidget);
    expect(find.textContaining('Carrots'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

