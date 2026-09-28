import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'models.dart';
import 'notification_service.dart';
import 'shared_screens.dart';
import 'theme.dart';
import 'ui_components.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final String userId;
  final String? role;

  const NotificationHistoryScreen({
    super.key,
    required this.userId,
    this.role,
  });

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  List<AppNotification> _currentNotifications = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Notification History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: HhColors.primary),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final unreadIds = _currentNotifications
                  .where((n) => !n.isRead)
                  .map((n) => n.id)
                  .toList();
              await _notificationService.markAllAsRead(
                widget.userId,
                role: widget.role,
                notificationIds: unreadIds,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read.'),
                    backgroundColor: HhColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.streamNotifications(widget.userId, role: widget.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: SproutLoadingIndicator(size: 80));
          }

          final notifications = snapshot.data ?? [];
          _currentNotifications = notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: HhColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: HhColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notifications regarding order statuses and fresh produce restocks will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: HhColors.text.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationCard(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    IconData icon;
    Color iconBg;

    switch (notif.type) {
      case 'NEW_USER_REGISTERED':
      case 'new_user':
        icon = Icons.person_add_rounded;
        iconBg = Colors.teal;
        break;
      case 'NEW_PRODUCT_ADDED':
      case 'new_product':
        icon = Icons.inventory_2_rounded;
        iconBg = Colors.green;
        break;
      case 'NO_SHOW_ORDER':
      case 'no_show':
        icon = Icons.warning_amber_rounded;
        iconBg = Colors.red;
        break;
      case 'PENDING_REMINDER_6H':
      case 'pending_reminder':
        icon = Icons.alarm_rounded;
        iconBg = Colors.deepOrange;
        break;
      case 'order_status':
        icon = Icons.local_shipping_rounded;
        iconBg = Colors.blue;
        break;
      case 'restock':
        icon = Icons.eco_rounded;
        iconBg = Colors.green;
        break;
      case 'order_placed':
      case 'order':
        icon = Icons.check_circle_rounded;
        iconBg = HhColors.primary;
        break;
      case 'violation':
        icon = Icons.report_problem_rounded;
        iconBg = HhColors.danger;
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconBg = Colors.orange;
    }

    final dateStr = DateFormat('dd/MM HH:mm').format(notif.createdAt);

    return InkWell(
      onTap: () {
        _notificationService.markAsRead(notif.id);
        if (notif.targetId != null && notif.targetId!.isNotEmpty) {
          final t = notif.type.toUpperCase();
          if (t.contains('ORDER') || t == 'NEW_ORDER' || t == 'ORDER_PLACED' || t == 'ORDER_STATUS') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  id: notif.targetId!,
                  role: widget.userId.startsWith('farmer') ? Roles.farmer : Roles.customer,
                ),
              ),
            );
          } else if (t == 'NEW_PRODUCT' || t.contains('PRODUCT')) {
            if (_notificationService.onOpenProductDetail != null) {
              _notificationService.onOpenProductDetail!(context, notif.targetId!);
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : HhColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? HhColors.text.withValues(alpha: 0.08)
                : HhColors.primary.withValues(alpha: 0.3),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconBg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: HhColors.text.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: HhColors.text.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: HhColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InAppNotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final String userId;
  final String? role;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const InAppNotificationBanner({
    super.key,
    required this.notification,
    required this.userId,
    this.role,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _openHistory() {
    _dismiss();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (widget.notification.type.toLowerCase().contains('product') &&
        widget.notification.targetId != null &&
        widget.notification.targetId!.isNotEmpty &&
        NotificationService.instance.onOpenProductDetail != null) {
      NotificationService.instance
          .onOpenProductDetail!(context, widget.notification.targetId!);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationHistoryScreen(userId: widget.userId, role: widget.role),
      ),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HhColors.primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openHistory,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HhColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: HhColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: HhColors.text.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: HhColors.text.withValues(alpha: 0.5)),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
