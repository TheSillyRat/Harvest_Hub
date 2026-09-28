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

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isLocalNotificationsInitialized = false;

  NotificationService._internal() {
    _loadPermissionState();
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    try {
      final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final darwinInit = DarwinInitializationSettings();
      final initSettings =
          InitializationSettings(android: androidInit, iOS: darwinInit);

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

  FirebaseFirestore? _customFirestore;

  void setCustomFirestore(FirebaseFirestore? firestore) {
    _customFirestore = firestore;
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
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
  void Function(BuildContext context, String productId)? onOpenProductDetail;

  Future<void> _loadPermissionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPermissionGranted =
          prefs.getBool('push_notifications_granted') ?? false;
      _hasPromptedPermission =
          prefs.getBool('push_notifications_prompted') ?? false;
      notifyListeners();
    } catch (_) {}
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
      final androidDetails = AndroidNotificationDetails(
        'harvesthub_channel_id',
        'HarvestHub Notifications',
        channelDescription:
            'Order updates and restock notifications from HarvestHub',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );
      await _localNotifications.show(id, null, body, notificationDetails);
    } catch (_) {}
  }

  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  String? _activeListeningUserId;
  final Set<String> _recentlyHandledNotificationIds = {};

  static List<String> getTargetChannels(String effectiveUserId, String? role) {
    if (role == 'farmer') {
      return [effectiveUserId, 'all_farmers', 'all'];
    } else if (role == 'customer') {
      return [effectiveUserId, 'all_customers', 'all'];
    } else if (role == 'admin') {
      return [effectiveUserId, 'all_admins', 'admin', 'all'];
    }
    return [
      effectiveUserId,
      'all_customers',
      'all_farmers',
      'all_admins',
      'admin',
      'all',
    ];
  }

  void startListeningToUserNotifications(String userId, {String? role}) {
    final effectiveUserId = userId.trim();
    if (effectiveUserId.isEmpty) return;
    if (_activeListeningUserId == effectiveUserId &&
        _notificationSubscription != null) {
      return;
    }
    stopListeningToUserNotifications();
    _activeListeningUserId = effectiveUserId;

    final firestore = _firestore;
    if (firestore == null) return;

    final channels = getTargetChannels(effectiveUserId, role);
    final startTime = DateTime.now().subtract(const Duration(seconds: 10));
    _notificationSubscription = firestore
        .collection('notifications')
        .where('userId', whereIn: channels)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final notifId = change.doc.id;
                if (_recentlyHandledNotificationIds.contains(notifId)) {
                  continue;
                }
                if (_recentlyHandledNotificationIds.length > 200) {
                  _recentlyHandledNotificationIds.clear();
                }
                _recentlyHandledNotificationIds.add(notifId);
                final notif = AppNotification.fromMap(data, id: notifId);
                if (notif.createdAt.isAfter(startTime) && !notif.isRead) {
                  if (notif.showInAppPopup && onInAppNotificationReceived != null) {
                    onInAppNotificationReceived!(notif);
                  }
                  showNativeNotification(
                    id: notif.id.hashCode,
                    title: notif.title,
                    body: notif.body,
                  );
                }
              }
            }
          }
        }, onError: (_) {});
  }

  void stopListeningToUserNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _activeListeningUserId = null;
  }

  Stream<int> streamUnreadCount(String userId, {String? role}) {
    return streamNotifications(userId, role: role).map(
      (list) => list.where((n) => !n.isRead).length,
    );
  }

  Stream<List<AppNotification>> streamNotifications(String userId,
      {String? role}) {
    final effectiveUserId =
        userId.trim().isEmpty ? 'customer_1' : userId.trim();
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(_getDemoNotifications(effectiveUserId));
    }
    final channels = getTargetChannels(effectiveUserId, role);
    try {
      return firestore
          .collection('notifications')
          .where('userId', whereIn: channels)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          })
          .handleError((_) {});
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

    if (_recentlyHandledNotificationIds.length > 200) {
      _recentlyHandledNotificationIds.clear();
    }
    _recentlyHandledNotificationIds.add(notification.id);

    try {
      await _firestore
          ?.collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (_) {}

    if (showInAppPopup) {
      if (onInAppNotificationReceived != null) {
        onInAppNotificationReceived!(notification);
      }

      await showNativeNotification(
        id: notification.id.hashCode,
        title: title,
        body: body,
      );
    }
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
        body =
            'Your order #$shortId at $farmerName has been completed. Thank you!';
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
      await _firestore
          ?.collection('notifications')
          .doc(notifId)
          .set(notification.toMap());
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
      await _firestore
          ?.collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> markAllAsRead(String userId,
      {List<String>? notificationIds}) async {
    try {
      if (notificationIds != null && notificationIds.isNotEmpty) {
        for (final id in notificationIds) {
          await _firestore
              ?.collection('notifications')
              .doc(id)
              .update({'isRead': true});
        }
      } else {
        final snap = await _firestore
            ?.collection('notifications')
            .where('userId', whereIn: [
              userId,
              'all_customers',
              'all_farmers',
              'all_admins',
              'admin',
              'all',
            ])
            .where('isRead', isEqualTo: false)
            .get();
        if (snap != null) {
          for (final doc in snap.docs) {
            await doc.reference.update({'isRead': true});
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> sendLowStockAlert({
    required String farmerId,
    required String productId,
    required String productName,
    required int remainingStock,
    String unit = 'kg',
  }) async {
    final isOut = remainingStock <= 0;
    await sendNotification(
      userId: farmerId,
      title: isOut ? 'Out of Stock Alert' : 'Low Stock Alert',
      body: isOut
          ? '$productName is now out of stock!'
          : '$productName has only $remainingStock $unit remaining. Restock soon!',
      type: 'LOW_STOCK_ALERT',
      targetId: productId,
      showInAppPopup: false,
    );
  }

  List<AppNotification> _getDemoNotifications(String userId) {
    return [
      AppNotification(
        id: 'notif_farmer_1',
        userId: userId,
        title: 'New Order Received',
        body: 'New order #ORD-7812 received with 3 items from Alice Green.',
        type: 'NEW_ORDER',
        targetId: 'ord_demo_1',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      AppNotification(
        id: 'notif_farmer_2',
        userId: userId,
        title: 'Low Stock Alert',
        body: 'Heirloom Vine Tomatoes is running low (only 3 kg remaining).',
        type: 'LOW_STOCK_ALERT',
        targetId: 'prod_1',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: 'notif_sang12',
        userId: userId,
        title: '🌱 Order Status Update (#ORD-9912)',
        body:
            'Your fresh produce order #ORD-9912 has been confirmed by Da Lat Organic Farm and is ready for pickup!',
        type: 'order_status',
        targetId: 'ORD-9912',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'notif_1',
        userId: userId,
        title: '🌱 Order is being prepared',
        body: 'Da Lat Organic Farm has accepted your order #ORD-8921.',
        type: 'order_status',
        targetId: 'ORD-8921',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: 'notif_2',
        userId: userId,
        title: '🍓 Fresh Produce Restocked!',
        body:
            'Grade A Da Lat Strawberries have been restocked with 50kg fresh harvest.',
        type: 'restock',
        targetId: 'prod_strawberries',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
