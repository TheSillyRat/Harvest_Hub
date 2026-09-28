import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'farmer_app.dart';
import 'farmer_profile_screen.dart';
import 'farmer_stock_screen.dart';

/// ============================================================
/// FARMER NOTIFICATION SCREEN
/// Dedicated history & notification management screen for farmers.
/// Handles:
/// - Real-time stream of incoming notifications (NEW_ORDER, LOW_STOCK_ALERT, PRODUCT_DEACTIVATED, PRODUCT_REVIEW)
/// - Unread state tracking and quick "Mark all as read"
/// - Filter chips: All, Orders, Stock Alerts, Admin & Reviews
/// - Direct deep-linking navigation on tap (e.g. to Order Detail, Stock Management, Product Form)
/// ============================================================
class NotificationScreen extends StatefulWidget {
  final String userId;
  final void Function(String orderId)? onSelectOrder;

  const NotificationScreen({
    super.key,
    required this.userId,
    this.onSelectOrder,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  String _selectedFilter = 'all'; // 'all', 'orders', 'stock', 'admin_reviews'

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
              await _notificationService.markAllAsRead(widget.userId, role: Roles.farmer);
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
              stream: _notificationService.streamNotifications(widget.userId, role: Roles.farmer),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(label: 'All', key: 'all'),
            const SizedBox(width: 8),
            _filterChip(label: 'Orders', key: 'orders', icon: Icons.shopping_bag_outlined),
            const SizedBox(width: 8),
            _filterChip(label: 'Stock Alerts', key: 'stock', icon: Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _filterChip(label: 'Admin & Reviews', key: 'admin_reviews', icon: Icons.star_border_rounded),
          ],
        ),
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
    if (_selectedFilter == 'admin_reviews') {
      return list.where((n) {
        final t = n.type.toUpperCase();
        return t.contains('REVIEW') ||
            t.contains('DEACTIVAT') ||
            t.contains('ADMIN') ||
            t.contains('POLICY') ||
            t.contains('ACTIVAT');
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
              'When new customer orders arrive, reviews are submitted, or alerts are sent, they will appear here.',
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
    final type = notif.type.toUpperCase();
    final isNewOrder = type.contains('ORDER') || type == 'NEW_ORDER';
    final isStockAlert = type == 'LOW_STOCK_ALERT' || type.contains('STOCK');
    final isReview = type.contains('REVIEW') || type.contains('RATE');
    final isDeactivation = type.contains('DEACTIVAT') || type.contains('POLICY');

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
    } else if (isReview) {
      icon = Icons.star_rounded;
      iconBg = Colors.amber.shade100;
      iconColor = Colors.amber.shade800;
    } else if (isDeactivation) {
      icon = Icons.gavel_rounded;
      iconBg = Colors.red.shade100;
      iconColor = Colors.red.shade700;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDeactivation
                ? Colors.red.shade300
                : (notif.isRead
                    ? Colors.black.withValues(alpha: 0.06)
                    : FarmerColors.primaryOlive.withValues(alpha: 0.35)),
            width: isDeactivation ? 1.5 : (notif.isRead ? 1 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: isDeactivation
                  ? Colors.red.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: notif.isRead ? 0.02 : 0.05),
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
                            color: isDeactivation ? Colors.red.shade900 : FarmerColors.textDark,
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

  Future<void> _handleNotificationClick(AppNotification notif) async {
    if (!notif.isRead) {
      _notificationService.markAsRead(notif.id);
    }

    final type = notif.type.toUpperCase();
    final targetId = notif.targetId;

    if (type.contains('ORDER') || type == 'NEW_ORDER' || type == 'ORDER_PLACED' || type == 'ORDER_STATUS') {
      if (targetId != null && targetId.isNotEmpty) {
        Navigator.of(context).pop(targetId);
        widget.onSelectOrder?.call(targetId);
      }
      return;
    }

    if (type == 'LOW_STOCK_ALERT' || type.contains('STOCK')) {
      openPage(
        context,
        FarmerStockManagementScreen(
          farmerId: widget.userId,
          initialFilter: StockFilter.lowStock,
        ),
      );
      return;
    }

    if (type.contains('DEACTIVAT') || type.contains('REVIEW') || type.contains('PRODUCT') || type.contains('POLICY')) {
      if (targetId != null && targetId.isNotEmpty) {
        try {
          final prod = await ProductService().getProduct(targetId);
          if (prod != null && mounted) {
            openPage(context, ProductFormScreen(product: prod));
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  type.contains('DEACTIVAT') ? Icons.gavel_rounded : Icons.info_outline_rounded,
                  color: type.contains('DEACTIVAT') ? FarmerColors.alertRed : FarmerColors.primaryOlive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notif.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              notif.body,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}

