import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:farmer_app/farmer_app.dart';

class TestAuth extends ChangeNotifier implements AuthController {
  @override
  bool get submitting => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('farmer registration includes business profile', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
        value: TestAuth(),
        child: MaterialApp(
            theme: harvestHubTheme(),
            home: const LoginScreen(role: Roles.farmer))));
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Tên gian hàng'), findsOneWidget);
    expect(find.text('Giới thiệu gian hàng'), findsOneWidget);
    expect(find.text('Khu vực'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
  });
  testWidgets('dashboard renders zero metrics for a new farmer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FarmerDashboard(
                products: Stream.value(<Product>[]),
                orders: Stream.value(<FarmOrder>[])))));
    await tester.pumpAndSettle();
    expect(find.text('Sản phẩm đang bán'), findsOneWidget);
    expect(find.text('Đơn chờ xác nhận'), findsOneWidget);
    expect(find.text('Doanh thu mô phỏng tháng này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
