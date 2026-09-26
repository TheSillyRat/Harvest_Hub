import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:customer_app/screens/notifications_screen.dart';
import 'package:customer_app/screens/in_app_notification_banner.dart';

void main() {
  testWidgets('NotificationHistoryScreen renders notifications list correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationHistoryScreen(userId: 'test_user'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notification History'), findsOneWidget);

    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('InAppNotificationBanner displays notification pop up and triggers tap', (WidgetTester tester) async {
    final notif = AppNotification(
      id: 'n1',
      userId: 'test_user',
      title: 'Test Notification Title',
      body: 'Test Notification Body Content',
      type: 'order_placed',
      isRead: false,
      createdAt: DateTime.now(),
    );

    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InAppNotificationBanner(
              notification: notif,
              userId: 'test_user',
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Notification Title'), findsOneWidget);
    expect(find.text('Test Notification Body Content'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}

