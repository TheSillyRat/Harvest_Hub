import 'package:admin_app/admin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class TestAuth extends ChangeNotifier implements AuthController {
  @override
  bool get isLoading => false;
  @override
  bool get isInitializing => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('admin login never offers registration', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
        value: TestAuth(),
        child: MaterialApp(
            theme: harvestHubTheme(),
            home: const LoginScreen(role: Roles.admin))));
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.textContaining('Register'), findsNothing);
    expect(find.text('Store Name'), findsNothing);
  });
  testWidgets('category form rejects blank name and negative sorting',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: harvestHubTheme(), home: const CategoryForm()));
    await tester.enterText(find.byType(TextFormField).at(1), '-1');
    await tester.tap(find.text('Save Category'));
    await tester.pump();
    expect(find.text('Please enter this field'), findsOneWidget);
    expect(find.text('Please enter a non-negative integer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
