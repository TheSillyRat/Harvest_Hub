import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final String userId;

  const NotificationHistoryScreen({super.key, required this.userId});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final NotificationService _notificationService = NotificationService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Lịch Sử Thông Báo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: HhColors.primary),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: () async {
              await _notificationService.markAllAsRead(widget.userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu tất cả thông báo là đã đọc.'),
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
        stream: _notificationService.streamNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: SproutLoadingIndicator(size: 80));
          }

          final notifications = snapshot.data ?? [];

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
                      'Chưa có thông báo nào',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Các thông báo về trạng thái đơn hàng và sản phẩm mới từ nông dân sẽ xuất hiện ở đây.',
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
      case 'order_status':
        icon = Icons.local_shipping_rounded;
        iconBg = Colors.blue;
        break;
      case 'restock':
        icon = Icons.eco_rounded;
        iconBg = Colors.green;
        break;
      case 'order_placed':
        icon = Icons.check_circle_rounded;
        iconBg = HhColors.primary;
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconBg = Colors.orange;
    }

    final dateStr = DateFormat('dd/MM HH:mm').format(notif.createdAt);

    return InkWell(
      onTap: () {
        _notificationService.markAsRead(notif.id);
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
