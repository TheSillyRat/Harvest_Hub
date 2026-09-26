import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'theme.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal() {
    _loadPermissionState();
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

  // Global overlay callback for displaying in-app notification popups
  Function(AppNotification notification)? onInAppNotificationReceived;
  // Callback when notification is tapped to navigate to Notification History
  VoidCallback? onOpenNotificationHistory;

  Future<void> _loadPermissionState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPermissionGranted = prefs.getBool('push_notifications_granted') ?? false;
    _hasPromptedPermission = prefs.getBool('push_notifications_prompted') ?? false;
    notifyListeners();
  }

  Future<bool> requestPermission(BuildContext context, {bool forcePrompt = false}) async {
    if (_isPermissionGranted && !forcePrompt) return true;

    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return _isPermissionGranted;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HhColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: HhColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Bật Thông Báo Đẩy?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: HhColors.text,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cho phép HarvestHub gửi thông báo đẩy để nhắc nhở và cập nhật tức thì trạng thái đơn hàng từ trang trại, thông báo khi nông sản yêu thích có hàng trở lại.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: HhColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Để sau',
              style: TextStyle(
                color: HhColors.text.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'Cho Phép Thông Báo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    final granted = result ?? false;
    _isPermissionGranted = granted;
    _hasPromptedPermission = true;
    await prefs.setBool('push_notifications_granted', granted);
    await prefs.setBool('push_notifications_prompted', true);
    notifyListeners();
    return granted;
  }

  Stream<List<AppNotification>> streamNotifications(String userId) {
    final firestore = _firestore;
    if (userId.isEmpty || firestore == null) {
      return Stream.value(_getDemoNotifications(userId));
    }
    return firestore
        .collection('notifications')
        .where('userId', whereIn: [userId, 'all_customers', 'all'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return _getDemoNotifications(userId);
          }
          return snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
              .toList();
        });
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
      // Offline fallback
    }

    if (showInAppPopup && onInAppNotificationReceived != null) {
      onInAppNotificationReceived!(notification);
    }
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
        id: 'notif_1',
        userId: userId,
        title: '🌱 Đơn hàng đang được chuẩn bị',
        body: 'Nông trại Da Lat Organic vừa tiếp nhận đơn hàng #ORD-8921 của bạn.',
        type: 'order_status',
        targetId: 'ORD-8921',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: 'notif_2',
        userId: userId,
        title: '🍓 Nông sản mới cập nhật kho!',
        body: 'Dâu tây Đà Lạt loại 1 vừa được nông dân bổ sung thêm 50kg tươi mới.',
        type: 'restock',
        targetId: 'prod_strawberries',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'notif_3',
        userId: userId,
        title: '✅ Đặt hàng thành công',
        body: 'Cảm ơn bạn đã đồng hành cùng nông dân địa phương!',
        type: 'order_placed',
        targetId: 'ORD-8920',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
