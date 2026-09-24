import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:admin_app/admin_app.dart';

class TestAuth extends ChangeNotifier implements AuthController {
  @override
  bool get submitting => false;
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
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.textContaining('Đăng ký'), findsNothing);
    expect(find.text('Tên gian hàng'), findsNothing);
  });
  testWidgets('category form rejects blank name and negative sorting',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: harvestHubTheme(), home: const CategoryForm()));
    await tester.enterText(find.byType(TextFormField).at(1), '-1');
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin'), findsOneWidget);
    expect(find.text('Nhập số nguyên không âm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
