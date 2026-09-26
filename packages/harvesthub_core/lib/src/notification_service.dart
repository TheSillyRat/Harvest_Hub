import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'models.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isLocalNotificationsInitialized = false;

  NotificationService._internal() {
    _loadPermissionState();
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (onOpenNotificationHistory != null) {
            onOpenNotificationHistory!();
          }
        },
      );
      _isLocalNotificationsInitialized = true;
    } catch (_) {}
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  bool _isPermissionGranted = false;
  bool _hasPromptedPermission = false;
  bool get isPermissionGranted => _isPermissionGranted;
  bool get hasPromptedPermission => _hasPromptedPermission;

  Function(AppNotification notification)? onInAppNotificationReceived;
  VoidCallback? onOpenNotificationHistory;

  Future<void> _loadPermissionState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPermissionGranted = prefs.getBool('push_notifications_granted') ?? false;
    _hasPromptedPermission = prefs.getBool('push_notifications_prompted') ?? false;
    notifyListeners();
  }

  Future<bool> requestPermission({bool forcePrompt = false}) async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted && !forcePrompt) {
        _isPermissionGranted = true;
        _hasPromptedPermission = true;
        return true;
      }
      final result = await Permission.notification.request();
      _isPermissionGranted = result.isGranted;
      _hasPromptedPermission = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications_granted', _isPermissionGranted);
      await prefs.setBool('push_notifications_prompted', true);
      notifyListeners();

      if (result.isPermanentlyDenied) {
        await openAppSettings();
      }

      return _isPermissionGranted;
    } catch (_) {
      _isPermissionGranted = true;
      _hasPromptedPermission = true;
      notifyListeners();
      return true;
    }
  }

  Future<void> showNativeNotification({
    String? title,
    required String body,
    int id = 0,
  }) async {
    if (!_isLocalNotificationsInitialized) {
      await _initLocalNotifications();
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'harvesthub_channel_id',
        'HarvestHub Notifications',
        channelDescription: 'Order updates and restock notifications from HarvestHub',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      /* Omit title parameter so system push notification only renders body text */
      await _localNotifications.show(id, null, body, notificationDetails);
    } catch (_) {}
  }


  Stream<List<AppNotification>> streamNotifications(String userId) {
    final effectiveUserId = userId.trim().isEmpty ? 'customer_1' : userId.trim();
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(_getDemoNotifications(effectiveUserId));
    }
    try {
      final notifQuery = firestore
          .collection('notifications')
          .where('userId', whereIn: [effectiveUserId, 'all_customers', 'all']);

      final ordersQuery = firestore
          .collection('orders')
          .where('customerId', isEqualTo: effectiveUserId);

      return ordersQuery.snapshots().asyncExpand((ordersSnap) {
        return notifQuery.snapshots().map((notifSnap) {
          final notifsMap = <String, AppNotification>{};

          for (final doc in notifSnap.docs) {
            final n = AppNotification.fromMap(doc.data(), id: doc.id);
            notifsMap[n.id] = n;
          }

          /* Synthesize missing order status notifications for customer orders */
          for (final doc in ordersSnap.docs) {
            final order = FarmOrder.fromMap(doc.data(), id: doc.id);
            final status = order.status;
            final notifId = 'notif_order_${order.id}_$status';

            if (!notifsMap.containsKey(notifId)) {
              final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
              String title;
              String body;
              switch (status) {
                case OrderStatus.confirmed:
                  title = 'Order Confirmed 🌾';
                  body = 'Your order #$shortId has been confirmed by ${order.farmerName}.';
                  break;
                case OrderStatus.readyForPickup:
                  title = 'Order Ready for Pickup 🛒';
                  body = 'Your order #$shortId is ready for pickup at ${order.farmerName}.';
                  break;
                case OrderStatus.completed:
                  title = 'Order Completed ✅';
                  body = 'Your order #$shortId at ${order.farmerName} has been completed. Thank you!';
                  break;
                case OrderStatus.cancelled:
                  title = 'Order Cancelled ❌';
                  body = 'Your order #$shortId at ${order.farmerName} has been cancelled.';
                  break;
                case OrderStatus.pending:
                default:
                  title = 'Order Placed Successfully 🌱';
                  body = 'Your order #$shortId has been submitted to ${order.farmerName}.';
                  break;
              }

              final generated = AppNotification(
                id: notifId,
                userId: effectiveUserId,
                title: title,
                body: body,
                type: status == OrderStatus.pending ? 'order_placed' : 'order_status',
                targetId: order.id,
                isRead: false,
                createdAt: order.updatedAt,
              );

              notifsMap[notifId] = generated;

              /* Auto-persist notification to Firestore */
              firestore.collection('notifications').doc(notifId).set(generated.toMap()).catchError((_) {});
            }
          }

          final list = notifsMap.values.toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
      }).handleError((_) => Stream.value(<AppNotification>[]));
    } catch (_) {
      return Stream.value(<AppNotification>[]);
    }
  }


  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? targetId,
    bool showInAppPopup = true,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      targetId: targetId,
      isRead: false,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore?.collection('notifications').doc(notification.id).set(notification.toMap());
    } catch (_) {
      /* Fallback for offline mode */
    }

    if (showInAppPopup && onInAppNotificationReceived != null) {
      onInAppNotificationReceived!(notification);
    }

    await showNativeNotification(
      id: notification.id.hashCode,
      title: title,
      body: body,
    );
  }

  Future<void> sendOrderStatusNotification({
    required String orderId,
    required String customerId,
    required String farmerName,
    required String status,
  }) async {
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    String title;
    String body;

    switch (status) {
      case OrderStatus.confirmed:
        title = 'Order Confirmed 🌾';
        body = 'Your order #$shortId has been confirmed by $farmerName.';
        break;
      case OrderStatus.readyForPickup:
        title = 'Order Ready for Pickup 🛒';
        body = 'Your order #$shortId is ready for pickup at $farmerName.';
        break;
      case OrderStatus.completed:
        title = 'Order Completed ✅';
        body = 'Your order #$shortId at $farmerName has been completed. Thank you!';
        break;
      case OrderStatus.cancelled:
        title = 'Order Cancelled ❌';
        body = 'Your order #$shortId at $farmerName has been cancelled.';
        break;
      default:
        title = 'Order Status Updated 🌱';
        body = 'Your order #$shortId status has been updated to $status.';
    }

    final notifId = 'notif_order_${orderId}_$status';

    final notification = AppNotification(
      id: notifId,
      userId: customerId,
      title: title,
      body: body,
      type: 'order_status',
      targetId: orderId,
      isRead: false,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore?.collection('notifications').doc(notifId).set(notification.toMap());
    } catch (_) {
      /* Fallback for offline mode */
    }

    if (onInAppNotificationReceived != null) {
      onInAppNotificationReceived!(notification);
    }

    await showNativeNotification(
      id: notifId.hashCode,
      title: title,
      body: body,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore?.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _firestore
          ?.collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      if (snap != null) {
        for (final doc in snap.docs) {
          await doc.reference.update({'isRead': true});
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  List<AppNotification> _getDemoNotifications(String userId) {
    return [
      AppNotification(
        id: 'notif_sang12',
        userId: userId,
        title: '🌱 Order Status Update (#ORD-9912)',
        body: 'Your fresh produce order #ORD-9912 has been confirmed by Da Lat Organic Farm and is ready for pickup!',
        type: 'order_status',
        targetId: 'ORD-9912',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: 'notif_1',
        userId: userId,
        title: '🌱 Order is being prepared',
        body: 'Da Lat Organic Farm has accepted your order #ORD-8921.',
        type: 'order_status',
        targetId: 'ORD-8921',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: 'notif_2',
        userId: userId,
        title: '🍓 Fresh Produce Restocked!',
        body: 'Grade A Da Lat Strawberries have been restocked with 50kg fresh harvest.',
        type: 'restock',
        targetId: 'prod_strawberries',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'notif_3',
        userId: userId,
        title: '✅ Order Placed Successfully',
        body: 'Thank you for supporting your local farmers!',
        type: 'order_placed',
        targetId: 'ORD-8920',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
