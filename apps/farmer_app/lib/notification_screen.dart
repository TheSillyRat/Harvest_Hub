import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'farmer_profile_screen.dart';
import 'farmer_stock_screen.dart';

/// ============================================================
/// FARMER NOTIFICATION SCREEN
/// Dedicated history & notification management screen for farmers.
/// Handles:
/// - Real-time stream of incoming notifications (NEW_ORDER, LOW_STOCK_ALERT)
/// - Unread state tracking and quick "Mark all as read"
/// - Filter chips: All, Orders, Stock Alerts
/// - Direct deep-linking navigation on tap (e.g. to Stock Management)
/// ============================================================
class NotificationScreen extends StatefulWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  String _selectedFilter = 'all'; // 'all', 'orders', 'stock'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmerColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FarmerColors.textDark, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: FarmerColors.textDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: FarmerColors.primaryOlive),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await _notificationService.markAllAsRead(widget.userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All notifications marked as read.'),
                    backgroundColor: FarmerColors.primaryOlive,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          _buildFilterTabs(),

          // Notifications Stream List
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: _notificationService.streamNotifications(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: LoadingView());
                }

                final allList = snapshot.data ?? [];
                final filtered = _filterNotifications(allList);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = filtered[index];
                    return _buildNotificationTile(notif);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _filterChip(label: 'All', key: 'all'),
          const SizedBox(width: 8),
          _filterChip(label: 'Orders', key: 'orders', icon: Icons.shopping_bag_outlined),
          const SizedBox(width: 8),
          _filterChip(label: 'Stock Alerts', key: 'stock', icon: Icons.warning_amber_rounded),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required String key, IconData? icon}) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? FarmerColors.primaryOlive : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? FarmerColors.primaryOlive : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : FarmerColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : FarmerColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppNotification> _filterNotifications(List<AppNotification> list) {
    if (_selectedFilter == 'orders') {
      return list.where((n) {
        final t = n.type.toUpperCase();
        return t.contains('ORDER') || t == 'NEW_ORDER' || t == 'ORDER_PLACED' || t == 'ORDER_STATUS';
      }).toList();
    }
    if (_selectedFilter == 'stock') {
      return list.where((n) {
        final t = n.type.toUpperCase();
        return t.contains('STOCK') || t == 'LOW_STOCK_ALERT' || t == 'RESTOCK';
      }).toList();
    }
    return list;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FarmerColors.primaryOlive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: FarmerColors.primaryOlive,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When new orders arrive or stock runs low, alerts will appear here in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: FarmerColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notif) {
    final isNewOrder = notif.type.toUpperCase() == 'NEW_ORDER' || notif.type == 'order';
    final isStockAlert = notif.type.toUpperCase() == 'LOW_STOCK_ALERT';

    Color iconBg;
    Color iconColor;
    IconData icon;

    if (isNewOrder) {
      icon = Icons.shopping_bag_outlined;
      iconBg = FarmerColors.primaryOlive.withValues(alpha: 0.12);
      iconColor = FarmerColors.primaryOlive;
    } else if (isStockAlert) {
      icon = Icons.warning_amber_rounded;
      iconBg = FarmerColors.alertRed.withValues(alpha: 0.12);
      iconColor = FarmerColors.alertRed;
    } else {
      icon = Icons.notifications_none_rounded;
      iconBg = FarmerColors.accentGold.withValues(alpha: 0.15);
      iconColor = FarmerColors.accentGold;
    }

    final timeStr = formatTimeAgo(notif.createdAt);

    return InkWell(
      onTap: () => _handleNotificationClick(notif),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? Colors.black.withValues(alpha: 0.06)
                : FarmerColors.primaryOlive.withValues(alpha: 0.35),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: notif.isRead ? 0.02 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: FarmerColors.textDark,
                          ),
                        ),
                      ),
                      if (!notif.isRead) ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, right: 6),
                          decoration: const BoxDecoration(
                            color: FarmerColors.alertRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: FarmerColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: notif.isRead
                          ? FarmerColors.textMuted
                          : FarmerColors.textDark.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationClick(AppNotification notif) {
    if (!notif.isRead) {
      _notificationService.markAsRead(notif.id);
    }

    if (notif.type.toUpperCase() == 'LOW_STOCK_ALERT') {
      openPage(
        context,
        FarmerStockManagementScreen(
          farmerId: widget.userId,
          initialFilter: StockFilter.lowStock,
        ),
      );
    }
  }
}
