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
  });
}
