import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:customer_app/customer_app.dart';

class TestAuth extends ChangeNotifier implements AuthController {
  @override
  bool get submitting => false;
  int attempts = 0;
  @override
  Future<void> authenticate(
      Future<AppUser> Function(AuthService) action) async {
    attempts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('FAQ screen responds to a pickup question without a cloud API', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: harvestHubTheme(), home: const ChatbotScreen()));
    expect(find.text(FaqService.greeting), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Có giao hàng không?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('HarvestHub không hỗ trợ vận chuyển. Nhận tại điểm bán theo khung giờ.'), findsOneWidget);
  });
  testWidgets('customer registration validates fields before contacting Auth',
      (tester) async {
    final auth = TestAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
            theme: harvestHubTheme(),
            home: const LoginScreen(role: Roles.customer))));
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
    expect(find.text('Tên gian hàng'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.pump();
    expect(auth.attempts, 0);
    expect(find.text('Email không hợp lệ'), findsOneWidget);
  });
  testWidgets('sold-out product remains visible with stock badge',
      (tester) async {
    final now = DateTime(2026);
    final product = Product(
        id: 'p',
        farmerId: 'f',
        farmerName: 'Vườn Xanh',
        name: 'Cà chua bi',
        categoryId: 'vegetables',
        description: '',
        price: 35000,
        unit: 'kg',
        stockQty: 0,
        imageUrl: '',
        isActive: true,
        createdAt: now,
        updatedAt: now);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 200,
                height: 340,
                child: ProductCard(product: product, onTap: () {})))));
    expect(find.text('Hết hàng'), findsOneWidget);
    expect(find.text('Cà chua bi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
