import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:customer_app/main.dart';

FarmOrder _createOrder({
  required String id,
  required String status,
  String pickupSlot = 'morning_07_10',
  String address = 'Green Valley Hub, West Market Station',
}) {
  final now = DateTime.now();
  return FarmOrder(
    id: id,
    customerId: 'customer_1',
    customerName: 'Customer Minh Tai',
    customerPhone: '+84901234567',
    farmerId: 'farmer_1',
    farmerName: 'Sunshine Organic Farm',
    items: [
      const OrderItem(
        productId: 'prod_1',
        name: 'Fresh Strawberries',
        price: 350,
        unit: 'box',
        imageUrl: '',
        qty: 2,
        subtotal: 700,
      ),
    ],
    address: address,
    pickupSlot: pickupSlot,
    pickupDate: now,
    total: 700,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('OrderTrackingSheet renders pickup slot and on-farm location', (tester) async {
    final order = _createOrder(
      id: 'ord_12345678',
      status: OrderStatus.readyForPickup,
      pickupSlot: 'morning_07_10',
      address: 'Da Lat Farm Pickup Hub Station #4',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: harvestHubTheme(),
        home: Scaffold(
          body: OrderTrackingSheet(order: order),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify order ID and farm name
    expect(find.text('Order #ord_1234'), findsOneWidget);
    expect(find.text('Sunshine Organic Farm'), findsOneWidget);

    // Verify pickup window label & slot
    expect(find.text('Pickup Slot Window (On-Farm Pickup)'), findsOneWidget);
    expect(find.text('Morning 7:00–10:00'), findsOneWidget);

    // Verify Farm Pickup Location
    expect(find.text('Farm Pickup Location'), findsOneWidget);
    expect(find.text('Da Lat Farm Pickup Hub Station #4'), findsOneWidget);

    // Verify Ready for Pickup step and notification text
    expect(find.text('Ready for Pickup'), findsOneWidget);
    expect(
      find.text('Your harvest is packaged and waiting at the pickup site! Please visit during your pickup window to collect your produce.'),
      findsOneWidget,
    );
  });

  testWidgets('Order tracking steps reflect lifecycle states correctly', (tester) async {
    final pendingOrder = _createOrder(id: 'ord_pending', status: OrderStatus.pending);

    await tester.pumpWidget(
      MaterialApp(
        theme: harvestHubTheme(),
        home: Scaffold(
          body: OrderTrackingSheet(order: pendingOrder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order Placed'), findsOneWidget);
    expect(find.text('Farm Confirmed'), findsOneWidget);
    expect(find.text('Ready for Pickup'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('Cancelled order shows stock refund notification', (tester) async {
    final cancelledOrder = _createOrder(id: 'ord_cancel', status: OrderStatus.cancelled);

    await tester.pumpWidget(
      MaterialApp(
        theme: harvestHubTheme(),
        home: Scaffold(
          body: OrderTrackingSheet(order: cancelledOrder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This order was cancelled. Stock has been refunded to farm inventory.'),
      findsOneWidget,
    );
  });
}
