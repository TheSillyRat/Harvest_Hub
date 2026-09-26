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
}
