import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:customer_app/main.dart';

void main() {
  testWidgets('Marketplace screen renders basic structure', (tester) async {
    final cartController = CartController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartController>.value(value: cartController),
        ],
        child: MaterialApp(
          theme: harvestHubTheme(),
          home: const CustomerHomeScreen(),
        ),
      ),
    );

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });
}
