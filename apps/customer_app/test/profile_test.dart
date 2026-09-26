import 'dart:async';
import 'package:customer_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class ProfileAuth extends AuthController {
  final result = Completer<bool>();
  int saves = 0;
  @override
  Future<bool> updateProfile({required String name, required String phone, required String address}) {
    saves++;
    return result.future;
  }
}

void main() {
  testWidgets('profile form validates phone, prevents duplicate saves and keeps edits on failure', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = ProfileAuth();
    addTearDown(auth.dispose);
    final user = AppUser(uid: 'customer', name: 'Customer', email: 'customer@example.com', phone: '0901234567', address: 'Hanoi', role: 'customer', isActive: true, createdAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileEditSheet(user: user, auth: auth))));
    await tester.enterText(find.byType(TextFormField).at(1), 'abc');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(auth.saves, 0);
    await tester.enterText(find.byType(TextFormField).at(1), '0901234567');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(auth.saves, 1);
    auth.result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Could not save your profile. Please try again.'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
