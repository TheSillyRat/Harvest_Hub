import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Mark As Read Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late NotificationService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = NotificationService.instance;
      service.setCustomFirestore(fakeFirestore);
    });

    tearDown(() {
      service.setCustomFirestore(null);
    });

    test('markAllAsRead marks both personal and broadcast notifications as read', () async {
      await fakeFirestore.collection('notifications').doc('notif_admin_1').set({
        'userId': 'all_admins',
        'title': 'New User Registered',
        'body': 'A new customer has joined.',
        'type': 'new_user',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('notifications').doc('notif_admin_2').set({
        'userId': 'admin_uid_123',
        'title': 'System Warning',
        'body': 'CPU usage normal.',
        'type': 'general',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final unreadBefore = await service.streamUnreadCount('admin_uid_123').first;
      expect(unreadBefore, 2);

      await service.markAllAsRead('admin_uid_123');

      final doc1 = await fakeFirestore.collection('notifications').doc('notif_admin_1').get();
      final doc2 = await fakeFirestore.collection('notifications').doc('notif_admin_2').get();
      expect(doc1.data()!['isRead'], isTrue);
      expect(doc2.data()!['isRead'], isTrue);

      final unreadAfter = await service.streamUnreadCount('admin_uid_123').first;
      expect(unreadAfter, 0);
    });

    test('markAllAsRead with specific notificationIds updates specified notifications', () async {
      await fakeFirestore.collection('notifications').doc('notif_cust_1').set({
        'userId': 'all_customers',
        'title': 'Special Promo',
        'body': 'Get 10% off today.',
        'type': 'general',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('notifications').doc('notif_cust_2').set({
        'userId': 'customer_456',
        'title': 'Order Dispatched',
        'body': 'Your order is on the way.',
        'type': 'order_status',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await service.markAllAsRead('customer_456', notificationIds: ['notif_cust_1', 'notif_cust_2']);

      final doc1 = await fakeFirestore.collection('notifications').doc('notif_cust_1').get();
      final doc2 = await fakeFirestore.collection('notifications').doc('notif_cust_2').get();
      expect(doc1.data()!['isRead'], isTrue);
      expect(doc2.data()!['isRead'], isTrue);
    });

    test('markAsRead updates single notification by ID', () async {
      await fakeFirestore.collection('notifications').doc('notif_single').set({
        'userId': 'all_farmers',
        'title': 'Produce restocked',
        'body': 'Fresh herbs arrived.',
        'type': 'restock',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await service.markAsRead('notif_single');

      final doc = await fakeFirestore.collection('notifications').doc('notif_single').get();
      expect(doc.data()!['isRead'], isTrue);
    });

    test('streamNotifications for farmer role filters out admin violations, delayed orders, and customer confirmation', () async {
      final now = Timestamp.now();

      // 1. Legitimate farmer notification: No-Show reminder
      await fakeFirestore.collection('notifications').doc('n_noshow').set({
        'userId': 'farmer_1',
        'title': 'Customer No-Show: Cancel to Restock #12345678',
        'body': 'Order #12345678 has been Ready for Pickup for over 12 hours. Review and cancel to restock.',
        'type': 'no_show',
        'isRead': false,
        'createdAt': now,
      });

      // 2. Admin violation notification (should be excluded for farmer)
      await fakeFirestore.collection('notifications').doc('n_violation').set({
        'userId': 'all_admins',
        'title': 'Community Guidelines Violation: Apple',
        'body': 'Farmer "Minh Lam Le" submitted a product violating policies',
        'type': 'COMMUNITY_VIOLATION',
        'isRead': false,
        'createdAt': now,
      });

      // 3. Delayed order of another farmer (should be excluded for farmer)
      await fakeFirestore.collection('notifications').doc('n_delayed').set({
        'userId': 'all_farmers',
        'title': 'Farmer Delayed Order',
        'body': 'Farmer "Ba Vi Dairy Farm" failed to confirm order #Orgw3Czd within 12 hours. The order has been auto-cancelled.',
        'type': 'delayed_order',
        'isRead': false,
        'createdAt': now,
      });

      // 4. Order confirmed notification intended for customer (should be excluded for farmer)
      await fakeFirestore.collection('notifications').doc('n_confirmed').set({
        'userId': 'all',
        'title': 'Order Confirmed',
        'body': 'Your order #ORD123 has been confirmed by the farmer.',
        'type': 'order',
        'isRead': false,
        'createdAt': now,
      });

      final farmerNotifs = await service.streamNotifications('farmer_1', role: Roles.farmer).first;
      expect(farmerNotifs, hasLength(1));
      expect(farmerNotifs.first.id, equals('n_noshow'));
      expect(farmerNotifs.first.title, contains('Cancel to Restock'));
    });
  });
}
