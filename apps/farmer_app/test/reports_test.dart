import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:farmer_app/farmer_app.dart';

void main() {
  FarmOrder createTestOrder({
    required String id,
    required String customerName,
    required int total,
    required DateTime createdAt,
    String status = OrderStatus.completed,
  }) {
    return FarmOrder(
      id: id,
      customerId: 'cust_$id',
      customerName: customerName,
      customerPhone: '0901234567',
      farmerId: 'farmer_1',
      farmerName: 'Farmer Dan',
      status: status,
      address: '123 Farm Road',
      total: total,
      pickupDate: createdAt,
      pickupSlot: '08:00 - 10:00',
      createdAt: createdAt,
      updatedAt: createdAt,
      items: [
        OrderItem(
          productId: 'prod_1',
          name: 'Fresh Produce',
          price: total,
          qty: 1,
          unit: 'kg',
          imageUrl: 'https://example.com/item.jpg',
          subtotal: total,
        ),
      ],
    );
  }

  testWidgets('FarmerReports supports pagination, time filters, and sorting without emojis', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();

    // Create 7 orders:
    // 3 from this week
    // 2 from earlier this month
    // 2 from previous months
    final orders = [
      createTestOrder(
        id: 'ord_1',
        customerName: 'Customer One',
        total: 100000,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      createTestOrder(
        id: 'ord_2',
        customerName: 'Customer Two',
        total: 150000,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      createTestOrder(
        id: 'ord_3',
        customerName: 'Customer Three',
        total: 200000,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      createTestOrder(
        id: 'ord_4',
        customerName: 'Customer Four',
        total: 120000,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      createTestOrder(
        id: 'ord_5',
        customerName: 'Customer Five',
        total: 180000,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      createTestOrder(
        id: 'ord_6',
        customerName: 'Customer Six',
        total: 220000,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      createTestOrder(
        id: 'ord_7',
        customerName: 'Customer Seven',
        total: 90000,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerReports(
            stream: Stream.value(orders),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title & overview
    expect(find.text('Sales & Order Reports'), findsOneWidget);
    expect(find.text('Order Records (7)'), findsOneWidget);

    // Verify page 1 items (5 items on page 1)
    expect(find.text('Showing 1-5 of 7'), findsOneWidget);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Customer Five'), findsOneWidget);
    // Page 2 items not yet rendered
    expect(find.text('Customer Six'), findsNothing);

    // Test Pagination Next button
    final nextBtn = find.byTooltip('Next page');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pump();

    // Verify Page 2 items
    expect(find.text('Showing 6-7 of 7'), findsOneWidget);
    expect(find.text('Customer Six'), findsOneWidget);
    expect(find.text('Customer Seven'), findsOneWidget);
    expect(find.text('Customer One'), findsNothing);

    // Test Pagination Previous button
    final prevBtn = find.byTooltip('Previous page');
    expect(prevBtn, findsOneWidget);
    await tester.tap(prevBtn);
    await tester.pump();
    expect(find.text('Showing 1-5 of 7'), findsOneWidget);
    expect(find.text('Customer One'), findsOneWidget);

    // Test Time Filter: 'This Week'
    final thisWeekChip = find.text('This Week');
    expect(thisWeekChip, findsOneWidget);
    await tester.tap(thisWeekChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Should only have 3 orders from this week
    expect(find.text('Order Records (3)'), findsOneWidget);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Customer Two'), findsOneWidget);
    expect(find.text('Customer Three'), findsOneWidget);
    expect(find.text('Customer Four'), findsNothing);

    // Test Sorting: 'Oldest'
    final oldestSortChip = find.text('Oldest');
    expect(oldestSortChip, findsOneWidget);
    await tester.tap(oldestSortChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // With oldest first in this week: Customer Three (3 days ago) is first
    expect(find.text('Customer Three'), findsOneWidget);

    // Confirm absolutely NO emojis in the rendered text widgets
    final emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    final allTextWidgets = find.byType(Text);
    for (final element in allTextWidgets.evaluate()) {
      final textWidget = element.widget as Text;
      final content = textWidget.data ?? '';
      expect(
        emojiRegex.hasMatch(content),
        isFalse,
        reason: 'Detected emoji in rendered Text: "$content"',
      );
    }
  });
}
