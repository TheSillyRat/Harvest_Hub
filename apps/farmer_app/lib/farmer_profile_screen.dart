import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'farmer_location_screen.dart';
import 'farmer_stock_screen.dart';
import 'farmer_schedule_screen.dart';
import 'review_products_screen.dart';

/// Design tokens and color palette matching requirements:
/// - 4F5B2A (Olive Green)
/// - B8892D (Warm Amber Gold)
/// Distributed as accents and highlights on clean, minimalist surfaces.
class FarmerColors {
  static const Color primaryOlive = Color(0xFF4F5B2A);
  static const Color accentGold = Color(0xFFB8892D);
  static const Color background = Color(0xFFF9FAF6);
  static const Color cardSurface = Colors.white;
  static const Color textDark = Color(0xFF1B2C1F);
  static const Color textMuted = Color(0xFF7A8679);
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color tagBg = Color(0xFFF1F3ED);
  static const Color starGold = Color(0xFFF59E0B);
}

/// Helper function to format relative timestamps cleanly (e.g. "2h ago").
String formatTimeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}

/// ============================================================
/// FARMER PROFILE SCREEN (Minimalist, Clean Architecture)
/// Features:
/// 1. Custom Header App Bar (Avatar/Name, Location, Notification Bell)
/// 2. Stats Grid (Active Crops, Followers, Avg Rating, Low Stock Items)
/// 3. Stock Management Call-To-Action Button
/// 4. Low Stock Alerts List View with detailed item cards
/// ============================================================
class FarmerProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const FarmerProfileScreen({super.key, this.onNavigate});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  FarmerProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthController>().user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _profile = FarmerProfile.fromMap(doc.data()!, id: doc.id);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _profile = FarmerProfile(
              uid: user.uid,
              userId: user.uid,
              businessName: 'My Farm Store',
              description: '',
              area: '',
              rating: 4.8,
              isActive: true,
              createdAt: user.createdAt,
              avatarUrl: user.avatarUrl,
            );
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditProfile(AppUser user) async {
    final updated = await openPage<bool>(
      context,
      FarmerEditProfileScreen(
        user: user,
        initialProfile: _profile,
      ),
    );
    if (updated == true) {
      _loadProfile();
    }
  }

  void _openLocationScreen(AppUser user) async {
    await openPage(
      context,
      FarmerLocationScreen(farmerId: user.uid),
    );
    if (mounted) {
      _loadProfile();
    }
  }

  void _openScheduleScreen(AppUser user) async {
    final updated = await openPage<bool>(
      context,
      FarmerScheduleScreen(
        farmerId: user.uid,
        initialOperatingHours: _profile?.operatingHours,
        initialOperatingDays: _profile?.operatingDays,
      ),
    );
    if (updated == true && mounted) {
      _loadProfile();
    }
  }

  String _formatScheduleSubtitle(FarmerProfile? profile) {
    if (profile == null) return 'Active days and opening hours';
    final hours = profile.operatingHours?.trim() ?? '';
    final days = profile.operatingDays;
    if (hours.isEmpty && (days == null || days.isEmpty)) {
      return 'Active days and opening hours';
    }
    String dayText = 'Mon - Sat';
    if (days != null && days.isNotEmpty) {
      if (days.length == 7) {
        dayText = 'Everyday';
      } else if (days.length == 5 &&
          days.contains('Mon') &&
          days.contains('Fri') &&
          !days.contains('Sat') &&
          !days.contains('Sun')) {
        dayText = 'Mon - Fri';
      } else if (days.length == 2 &&
          days.contains('Sat') &&
          days.contains('Sun')) {
        dayText = 'Sat - Sun';
      } else {
        dayText = days.join(', ');
      }
    }
    if (hours.isNotEmpty) {
      return '$dayText • $hours';
    }
    return dayText;
  }

  String _cleanDisplayArea(String text) {
    if (text.isEmpty) return 'Da Lat';
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final filtered = parts.where((part) {
      if (RegExp(r'^\d+$').hasMatch(part)) return false;
      final lower = part.toLowerCase();
      if (lower == 'việt nam' ||
          lower == 'vietnam' ||
          lower == 'vn' ||
          lower == 'united states' ||
          lower == 'usa' ||
          lower == 'us') {
        return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) return 'Da Lat';

    List<String> candidates = filtered;
    if (candidates.length >= 2 &&
        (candidates.last.toLowerCase().startsWith('tỉnh ') ||
            candidates.last.toLowerCase().endsWith(' province'))) {
      candidates = candidates.sublist(0, candidates.length - 1);
    }

    String ward = '';
    String city = '';

    if (candidates.length >= 2) {
      ward = candidates[candidates.length - 2];
      city = candidates.last;
    } else if (candidates.isNotEmpty) {
      city = candidates.last;
    }

    city = _simplifyCity(city);
    ward = _simplifyWard(ward, city);

    if (ward.isNotEmpty && city.isNotEmpty && ward.toLowerCase() != city.toLowerCase()) {
      return '$ward, $city';
    }
    return city.isNotEmpty ? city : (ward.isNotEmpty ? ward : 'Da Lat');
  }

  static String _simplifyCity(String raw) {
    var c = raw.trim();
    final lower = c.toLowerCase();
    if (lower == 'thành phố hồ chí minh' ||
        lower == 'thành phố hcm' ||
        lower == 'tp. hồ chí minh' ||
        lower == 'tp hồ chí minh') {
      return 'TP. HCM';
    }
    if (lower.startsWith('thành phố ')) {
      c = c.substring(10).trim();
    } else if (lower.startsWith('thị xã ')) {
      c = c.substring(7).trim();
    } else if (lower.endsWith(' city')) {
      c = c.substring(0, c.length - 5).trim();
    }
    return c;
  }

  static String _simplifyWard(String raw, String city) {
    var w = raw.trim();
    if (w.contains(' - ')) {
      final sub = w.split(' - ');
      if (sub.length == 2) {
        final right = sub[1].trim().toLowerCase();
        if (right == city.toLowerCase() ||
            city.toLowerCase().contains(right) ||
            right.contains(city.toLowerCase())) {
          w = sub[0].trim();
        }
      }
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    if (user == null) {
      return const EmptyView(message: 'Not logged in');
    }

    if (_isLoading) {
      return const LoadingView();
    }

    final avatarUrl = _profile?.avatarUrl.isNotEmpty == true
        ? _profile!.avatarUrl
        : user.avatarUrl;
    final rawArea = _profile?.area.isNotEmpty == true
        ? _profile!.area
        : (user.address.isNotEmpty ? user.address : 'Da Lat');
    final locationText = _cleanDisplayArea(rawArea);
    final rating = _profile?.rating ?? 5.0;

    final productsStream = ProductService().streamProductsByFarmer(user.uid);
    final ordersStream = OrderService().streamByFarmer(user.uid);
    final followersStream = SavedItemsService().streamFarmerFollowersCount(user.uid);

    return Scaffold(
      backgroundColor: FarmerColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: productsStream,
          builder: (context, prodSnapshot) {
            final products = prodSnapshot.data ?? [];
            final lowStockProducts = products
                .where((p) => p.stockQty <= 5)
                .toList();

            return StreamBuilder<List<FarmOrder>>(
              stream: ordersStream,
              builder: (context, orderSnapshot) {
                final orders = orderSnapshot.data ?? [];
                final totalOrdersCount = orders.length;

                return StreamBuilder<int>(
                  stream: followersStream,
                  builder: (context, followSnapshot) {
                    final followersCount = followSnapshot.data ?? 0;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      child: Column(
                        children: [
                          FarmerHeroSection(
                            name: user.name.isNotEmpty
                                ? user.name
                                : (_profile?.businessName ?? 'Farm Store'),
                            avatarUrl: avatarUrl,
                            locationText: locationText,
                            onAvatarTap: () => _openEditProfile(user),
                            onLocationTap: () => _openLocationScreen(user),
                          ),
                          const SizedBox(height: 22),

                          // 3. Stats Card (Elevated white card with 3 columns: AVG. rating, Followers, Total Orders)
                          FarmerThreeColumnStatsCard(
                            avgRating: rating,
                            followersCount: followersCount,
                            totalOrders: totalOrdersCount,
                            onRatingTap: () {
                              openPage(
                                context,
                                const ReviewProductsScreen(),
                              );
                            },
                          ),
                          const SizedBox(height: 22),

                          // 4. Stock Management CTA Button
                          StockManagementCtaButton(
                            onPressed: () {
                              openPage(
                                context,
                                FarmerStockManagementScreen(farmerId: user.uid),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // 5. Account & Store Settings
                          _buildAccountOptions(context, user),
                          const SizedBox(height: 20),

                          // 6. Low Stock Alerts Section (if low stock products exist)
                          if (lowStockProducts.isNotEmpty) ...[
                            LowStockSection(
                              lowStockProducts: lowStockProducts,
                              allProducts: products,
                              onViewAll: () {
                                final filter = lowStockProducts.any((p) => p.stockQty == 0)
                                    ? StockFilter.outOfStock
                                    : StockFilter.lowStock;
                                openPage(
                                  context,
                                  FarmerStockManagementScreen(
                                    farmerId: user.uid,
                                    initialFilter: filter,
                                  ),
                                );
                              },
                              onManageProduct: (prod) {
                                openPage(
                                  context,
                                  FarmerStockManagementScreen(farmerId: user.uid),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountOptions(BuildContext context, AppUser user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FarmerColors.primaryOlive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, color: FarmerColors.primaryOlive, size: 20),
            ),
            title: const Text('Manage Store Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Store name, avatar, and description', style: TextStyle(fontSize: 12, color: FarmerColors.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: FarmerColors.textMuted),
            onTap: () => _openEditProfile(user),
          ),
          Divider(height: 1, indent: 56, endIndent: 16, color: Colors.black.withValues(alpha: 0.05)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FarmerColors.accentGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_outlined, color: FarmerColors.accentGold, size: 20),
            ),
            title: const Text('Farm Location & Pickup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('GPS coordinates and customer pickup address', style: TextStyle(fontSize: 12, color: FarmerColors.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: FarmerColors.textMuted),
            onTap: () => _openLocationScreen(user),
          ),
          Divider(height: 1, indent: 56, endIndent: 16, color: Colors.black.withValues(alpha: 0.05)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FarmerColors.primaryOlive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, color: FarmerColors.primaryOlive, size: 20),
            ),
            title: const Text('Operating Schedule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              _formatScheduleSubtitle(_profile),
              style: const TextStyle(fontSize: 12, color: FarmerColors.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: FarmerColors.textMuted),
            onTap: () => _openScheduleScreen(user),
          ),
          Divider(height: 1, indent: 56, endIndent: 16, color: Colors.black.withValues(alpha: 0.05)),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FarmerColors.alertRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: FarmerColors.alertRed, size: 20),
            ),
            title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: FarmerColors.alertRed)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to sign out of HarvestHub Farmer?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: FarmerColors.alertRed),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                context.read<AuthController>().logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// 1. CUSTOM TOP APP BAR WIDGET
/// - Centered Title: "Profile"
/// - Right: Circular Bell Button with unread badge (max "9+")
/// ============================================================
class FarmerProfileTopBar extends StatelessWidget {
  final String userId;
  final VoidCallback onNotificationTap;

  const FarmerProfileTopBar({
    super.key,
    required this.userId,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Balance spacer
        const SizedBox(width: 44, height: 44),

        // Center: Title "Profile"
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: FarmerColors.textDark,
          ),
        ),

        // Right: Notification Bell Button with Badge
        NotificationBellButton(
          userId: userId,
          onTap: onNotificationTap,
        ),
      ],
    );
  }
}

/// ============================================================
/// NOTIFICATION BELL BUTTON WITH DYNAMIC BADGE (MAX "9+")
/// ============================================================
class NotificationBellButton extends StatelessWidget {
  final String userId;
  final VoidCallback onTap;

  const NotificationBellButton({
    super.key,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.streamUnreadCount(userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        final hasUnread = unreadCount > 0;
        final badgeText = unreadCount > 9 ? '9+' : '$unreadCount';

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: FarmerColors.textDark,
                  size: 22,
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                        color: FarmerColors.alertRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: FarmerColors.alertRed.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================
/// 2. FARMER HERO SECTION (Large Circular Avatar + Name + Location)
/// ============================================================
class FarmerHeroSection extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String locationText;
  final VoidCallback onAvatarTap;
  final VoidCallback? onLocationTap;

  const FarmerHeroSection({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.locationText,
    required this.onAvatarTap,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large Circular Avatar (Tap to edit profile)
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? ProductImage(avatarUrl)
                      : Container(
                          color: FarmerColors.primaryOlive.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 56,
                            color: FarmerColors.primaryOlive,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FarmerColors.accentGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Farmer Name
        Text(
          name.isNotEmpty ? name : 'Farm Store',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: FarmerColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        InkWell(
          onTap: onLocationTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: FarmerColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      locationText.isNotEmpty ? locationText : 'Da Lat',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: FarmerColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// 3. THREE-COLUMN STATS CARD (Elevated White Card)
/// Column 1: AVG. rating (star icon)
/// Column 2: Followers (people icon)
/// Column 3: Total Orders (assignment / order icon)
/// ============================================================
class FarmerThreeColumnStatsCard extends StatelessWidget {
  final double avgRating;
  final int followersCount;
  final int totalOrders;
  final VoidCallback? onRatingTap;

  const FarmerThreeColumnStatsCard({
    super.key,
    required this.avgRating,
    required this.followersCount,
    required this.totalOrders,
    this.onRatingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Column 1: AVG. rating (tappable to view customer reviews)
          Expanded(
            child: InkWell(
              onTap: onRatingTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildStatColumn(
                label: 'AVG. rating',
                icon: Icons.star_rounded,
                iconColor: FarmerColors.starGold,
                value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '5.0',
              ),
            ),
          ),
          _buildDivider(),

          // Column 2: Followers (Real follower count from customer app)
          Expanded(
            child: _buildStatColumn(
              label: 'Followers',
              icon: Icons.people_alt_rounded,
              iconColor: FarmerColors.accentGold,
              value: '$followersCount',
            ),
          ),
          _buildDivider(),

          // Column 3: Total Orders (Real orders count)
          Expanded(
            child: _buildStatColumn(
              label: 'Total Orders',
              icon: Icons.assignment_turned_in_rounded,
              iconColor: FarmerColors.primaryOlive,
              value: '$totalOrders',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 38,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: FarmerColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ============================================================
/// 3. STOCK MANAGEMENT CALL-TO-ACTION BUTTON
/// Full-width rounded pill button styled with primaryOlive (4F5B2A).
/// ============================================================
class StockManagementCtaButton extends StatelessWidget {
  final VoidCallback onPressed;

  const StockManagementCtaButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: FarmerColors.primaryOlive,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: FarmerColors.primaryOlive.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 20, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Stock Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// 4. LOW STOCK ALERTS SECTION
/// Header (Low Stock Alerts / View all) + ListView of alert cards
/// ============================================================
class LowStockSection extends StatelessWidget {
  final List<Product> lowStockProducts;
  final List<Product> allProducts;
  final VoidCallback onViewAll;
  final ValueChanged<Product> onManageProduct;

  const LowStockSection({
    super.key,
    required this.lowStockProducts,
    required this.allProducts,
    required this.onViewAll,
    required this.onManageProduct,
  });

  @override
  Widget build(BuildContext context) {
    // If no products are currently below threshold, show lowest stock products
    final displayList = lowStockProducts.isNotEmpty
        ? lowStockProducts
        : (List<Product>.from(allProducts)
          ..sort((a, b) => a.stockQty.compareTo(b.stockQty)))
            .take(3)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Low Stock Alerts + View all
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Low Stock Alerts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
                letterSpacing: -0.2,
              ),
            ),
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.accentGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (allProducts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: const Text(
              'No crops listed yet in store.',
              style: TextStyle(color: FarmerColors.textMuted),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = displayList[index];
              return LowStockProductCard(
                product: product,
                onTap: () => onManageProduct(product),
              );
            },
          ),
      ],
    );
  }
}

/// Clean Minimalist Product Card for Low Stock Alerts
class LowStockProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const LowStockProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDepleted = product.stockQty == 0;
    final formattedPrice = vnd(product.price);
    final relativeTime = formatTimeAgo(product.updatedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDepleted
                ? FarmerColors.alertRed.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            width: isDepleted ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category/Brand + Time Ago + More icon
            Row(
              children: [
                Text(
                  product.categoryId.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.primaryOlive,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  relativeTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FarmerColors.textMuted,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: FarmerColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Product Name (Bold)
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Gray Tags Row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildGrayTag(product.unit.toUpperCase()),
                _buildGrayTag('Fresh Farm'),
                if (isDepleted)
                  _buildTagBadge('Out of Stock', FarmerColors.alertRed)
                else if (product.stockQty <= 5)
                  _buildTagBadge('Low Stock', const Color(0xFFE65100))
                else
                  _buildGrayTag('In Stock'),
              ],
            ),
            const SizedBox(height: 14),

            // Bottom Row: Remaining Quantity + Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDepleted
                          ? Icons.cancel_outlined
                          : Icons.inventory_2_outlined,
                      size: 15,
                      color: isDepleted
                          ? FarmerColors.alertRed
                          : FarmerColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDepleted
                          ? 'Remaining: 0 ${product.unit} (Out of stock)'
                          : 'Remaining: ${product.stockQty} ${product.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDepleted
                            ? FarmerColors.alertRed
                            : FarmerColors.textDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$formattedPrice / ${product.unit}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.primaryOlive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrayTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FarmerColors.tagBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: FarmerColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTagBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// ============================================================
/// FARMER EDIT PROFILE SCREEN (Manage farmer profile)
/// Features:
/// - Edit shop name (businessName)
/// - Change avatar (ImagePicker & presets)
/// - Edit address
/// - Dirty checking with English confirmation dialog on back
/// - Success & failure notifications
/// ============================================================
class FarmerEditProfileScreen extends StatefulWidget {
  final AppUser user;
  final FarmerProfile? initialProfile;

  const FarmerEditProfileScreen({
    super.key,
    required this.user,
    this.initialProfile,
  });

  @override
  State<FarmerEditProfileScreen> createState() =>
      _FarmerEditProfileScreenState();
}

class _FarmerEditProfileScreenState extends State<FarmerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _areaController;

  String _currentAvatarUrl = '';
  File? _pickedAvatarFile;
  bool _busy = false;

  // Initial snapshot to compare dirty state
  late final String _initialBusinessName;
  late final String _initialAddress;
  late final String _initialName;
  late final String _initialPhone;
  late final String _initialDescription;
  late final String _initialArea;
  late final String _initialAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initialBusinessName = widget.initialProfile?.businessName ?? '';
    _initialAddress = widget.user.address;
    _initialName = widget.user.name;
    _initialPhone = widget.user.phone;
    _initialDescription = widget.initialProfile?.description ?? '';
    _initialArea = widget.initialProfile?.area ?? '';
    _initialAvatarUrl = widget.initialProfile?.avatarUrl.isNotEmpty == true
        ? widget.initialProfile!.avatarUrl
        : widget.user.avatarUrl;

    _businessNameController =
        TextEditingController(text: _initialBusinessName);
    _addressController = TextEditingController(text: _initialAddress);
    _nameController = TextEditingController(text: _initialName);
    _phoneController = TextEditingController(text: _initialPhone);
    _descriptionController =
        TextEditingController(text: _initialDescription);
    _areaController = TextEditingController(text: _initialArea);
    _currentAvatarUrl = _initialAvatarUrl;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    return _pickedAvatarFile != null ||
        _currentAvatarUrl != _initialAvatarUrl ||
        _businessNameController.text.trim() != _initialBusinessName.trim() ||
        _addressController.text.trim() != _initialAddress.trim() ||
        _nameController.text.trim() != _initialName.trim() ||
        _phoneController.text.trim() != _initialPhone.trim() ||
        _descriptionController.text.trim() != _initialDescription.trim() ||
        _areaController.text.trim() != _initialArea.trim();
  }

  /// English confirmation dialog when user attempts to exit with unsaved changes.
  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to discard your changes? Any unsaved information will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmerColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedAvatarFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: FarmerColors.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedAvatarFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not take photo: $e'),
            backgroundColor: FarmerColors.alertRed,
          ),
        );
      }
    }
  }

  void _showAvatarOptions() {
    final hasAvatar =
        _currentAvatarUrl.isNotEmpty || _pickedAvatarFile != null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Farm Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FarmerColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: FarmerColors.primaryOlive),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatarFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: FarmerColors.primaryOlive),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatarFromGallery();
                },
              ),
              if (hasAvatar) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: FarmerColors.alertRed),
                  title: const Text(
                    'Remove Avatar',
                    style: TextStyle(
                      color: FarmerColors.alertRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentAvatarUrl = '';
                      _pickedAvatarFile = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      String finalAvatarUrl = _currentAvatarUrl;
      final authController = context.read<AuthController>();

      // Upload newly picked avatar if present
      if (_pickedAvatarFile != null) {
        final storage = StorageService();
        finalAvatarUrl = await storage.uploadAvatar(
          widget.user.uid,
          _pickedAvatarFile!,
        );
      }
      if (!mounted) return;

      final success = await authController.updateFarmerProfile(
        businessName: _businessNameController.text.trim(),
        address: _addressController.text.trim(),
        avatarUrl: finalAvatarUrl,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        area: _areaController.text.trim(),
      );

      if (success) {
        if (mounted) {
          // Success notification
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          // Failure notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update profile: ${authController.errorMessage ?? 'Unknown error'}',
              ),
              backgroundColor: FarmerColors.alertRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Failure notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: FarmerColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: FarmerColors.background,
        appBar: AppBar(
          title: const Text(
            'Edit Farm Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: FarmerColors.textDark,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              final shouldPop = await _confirmDiscardChanges();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Picker Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: FarmerColors.primaryOlive.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: FarmerColors.primaryOlive.withValues(alpha: 0.1),
                              child: _pickedAvatarFile != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _pickedAvatarFile!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_currentAvatarUrl.isNotEmpty
                                      ? ClipOval(
                                          child: SizedBox(
                                            width: 96,
                                            height: 96,
                                            child: ProductImage(
                                                _currentAvatarUrl),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 48,
                                          color: FarmerColors.primaryOlive,
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: InkWell(
                              onTap: _showAvatarOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: FarmerColors.primaryOlive,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showAvatarOptions,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('Change Avatar'),
                        style: TextButton.styleFrom(
                          foregroundColor: FarmerColors.primaryOlive,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields
                const Text(
                  'Store & Farm Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Shop / Storefront Name
                PillTextField(
                  controller: _businessNameController,
                  label: 'Storefront / Farm Name',
                  hint: 'e.g. Green Valley Farm',
                  icon: Icons.storefront_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter storefront name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Farm Address
                PillTextField(
                  controller: _addressController,
                  label: 'Farm Contact & Pickup Address',
                  hint: 'e.g. 123 Farm Road, Da Lat, Lam Dong',
                  icon: Icons.location_on_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter farm address'
                      : null,
                ),
                const SizedBox(height: 14),

                // Farm Area / Region
                PillTextField(
                  controller: _areaController,
                  label: 'Area / Region',
                  hint: 'e.g. Da Lat, Lam Dong',
                  icon: Icons.landscape_outlined,
                ),
                const SizedBox(height: 14),

                // Farm Description
                PillTextField(
                  controller: _descriptionController,
                  label: 'Farm Description',
                  hint:
                      'Describe your farming methods, organic certifications...',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 20),

                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Full Name
                PillTextField(
                  controller: _nameController,
                  label: 'Farmer Full Name',
                  hint: 'e.g. John Farmer',
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Phone
                PillTextField(
                  controller: _phoneController,
                  label: 'Contact Phone Number',
                  hint: '+84 912 345 678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: phoneValidator,
                ),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmerColors.primaryOlive,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
