import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'farmer_profile_screen.dart';
import 'farmer_stock_screen.dart';
import 'notification_screen.dart';

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});
  @override
  State<FarmerMainScreen> createState() => _FarmerMainScreenState();
}

typedef FarmerApp = FarmerMainScreen;

class _FarmerMainScreenState extends State<FarmerMainScreen> {
  int index = 0;
  static const titles = [
    'Dashboard',
    'My Products',
    'Orders',
    'Reports',
    'Profile'
  ];

  AppNotification? _activeInAppNotification;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onInAppNotificationReceived = (notification) {
      if (!mounted) return;

      final t = notification.type.toUpperCase();
      final title = notification.title.toLowerCase();
      final body = notification.body.toLowerCase();

      // Don't show in-app popup for community violation (reports for admin only)
      if (t == 'COMMUNITY_VIOLATION' ||
          title.contains('community guidelines violation') ||
          notification.userId == 'all_admins' ||
          notification.userId == 'admin') {
        return;
      }

      // Don't show in-app popup for delayed orders
      if (t.contains('DELAY') ||
          title.contains('delayed') ||
          body.contains('failed to confirm order')) {
        return;
      }

      // Don't show in-app popup when farmer confirmed order (notification is for customer)
      if (title.contains('order confirmed') && body.contains('confirmed by')) {
        return;
      }

      setState(() {
        _activeInAppNotification = notification;
      });
    };
    NotificationService.instance.onOpenNotificationHistory = () {
      if (mounted) {
        final uid = context.read<AuthController>().user?.uid ?? '';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationScreen(
              userId: uid,
              onSelectOrder: (orderId) {
                openPage(
                  context,
                  OrderDetailScreen(id: orderId, role: Roles.farmer),
                );
              },
            ),
          ),
        );
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notice =
            context.read<AuthController>().consumeReactivationNotice();
        if (notice != null && notice.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(notice)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthController>().user?.uid ?? '';
    if (uid.isNotEmpty) {
      NotificationService.instance
          .startListeningToUserNotifications(uid, role: Roles.farmer);
    }
  }

  @override
  void dispose() {
    NotificationService.instance.stopListeningToUserNotifications();
    NotificationService.instance.onInAppNotificationReceived = null;
    NotificationService.instance.onOpenNotificationHistory = null;
    super.dispose();
  }

  void _handleFarmerInAppNotification(AppNotification notif, String uid) async {
    final type = notif.type.toUpperCase();
    final targetId = notif.targetId;

    if (type.contains('ORDER') ||
        type == 'NEW_ORDER' ||
        type == 'ORDER_PLACED' ||
        type == 'ORDER_STATUS' ||
        type == 'NO_SHOW' ||
        type.contains('NO_SHOW')) {
      if (targetId != null && targetId.isNotEmpty) {
        openPage(
          context,
          OrderDetailScreen(
            id: targetId,
            role: Roles.farmer,
          ),
        );
      }
      return;
    }

    if (type == 'LOW_STOCK_ALERT' || type.contains('STOCK')) {
      openPage(
        context,
        FarmerStockManagementScreen(
          farmerId: uid,
          initialFilter: StockFilter.lowStock,
        ),
      );
      return;
    }

    if (type.contains('DEACTIVAT') ||
        type.contains('REVIEW') ||
        type.contains('PRODUCT') ||
        type.contains('POLICY')) {
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationScreen(userId: uid),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user?.uid ?? '';
    final orders = OrderService().streamByFarmer(uid);
    final products = ProductService().streamByFarmer(uid);
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'HarvestHub · ${titles[index]}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            StreamBuilder<int>(
              stream: NotificationService.instance
                  .streamUnreadCount(uid, role: Roles.farmer),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationScreen(userId: uid),
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
            child: ListView(children: [
          const DrawerHeader(
              decoration: BoxDecoration(color: HhColors.primaryDark),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.eco, color: HhColors.accent, size: 48),
                    SizedBox(height: 12),
                    Text('Farmer Hub',
                        style: TextStyle(color: Colors.white, fontSize: 22)),
                  ])),
          for (var i = 0; i < titles.length; i++)
            ListTile(
                title: Text(titles[i]),
                selected: i == index,
                onTap: () {
                  setState(() => index = i);
                  Navigator.pop(context);
                }),
          const Divider(),
          ListTile(
              title: const Text('Log Out'),
              leading: const Icon(Icons.logout),
              onTap: () =>
                  perform(context, context.read<AuthController>().logout)),
        ])),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
        body: Stack(
          children: [
            switch (index) {
              0 => FarmerDashboard(
                  products: products,
                  orders: orders,
                  onNavigate: (i) => setState(() => index = i)),
              1 => FarmerProducts(farmerId: uid, stream: products),
              2 => FarmerOrdersScreen(stream: orders),
              3 => FarmerReports(stream: orders),
              _ => FarmerProfileScreen(
                  onNavigate: (i) => setState(() => index = i),
                ),
            },
            if (_activeInAppNotification != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: InAppNotificationBanner(
                  notification: _activeInAppNotification!,
                  userId: uid,
                  role: Roles.farmer,
                  onTap: () {
                    final notif = _activeInAppNotification!;
                    setState(() {
                      _activeInAppNotification = null;
                    });
                    _handleFarmerInAppNotification(notif, uid);
                  },
                  onDismiss: () {
                    if (mounted) {
                      setState(() {
                        _activeInAppNotification = null;
                      });
                    }
                  },
                ),
              ),
          ],
        ));
  }
}

class FarmerDashboard extends StatefulWidget {
  final Stream<List<Product>> products;
  final Stream<List<FarmOrder>> orders;
  final ValueChanged<int> onNavigate;

  const FarmerDashboard({
    super.key,
    required this.products,
    required this.orders,
    required this.onNavigate,
  });

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  String? _selectedCategoryId;

  IconData _getCategoryIcon(String name, String id) {
    final lower = ('$name $id').toLowerCase();
    if (lower.contains('veg') ||
        lower.contains('rau') ||
        lower.contains('root')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('fruit') ||
        lower.contains('qua') ||
        lower.contains('trai')) {
      return Icons.apple_rounded;
    }
    if (lower.contains('grain') ||
        lower.contains('nut') ||
        lower.contains('hat')) {
      return Icons.grain_rounded;
    }
    if (lower.contains('herb') ||
        lower.contains('spice') ||
        lower.contains('gia vi')) {
      return Icons.local_florist_rounded;
    }
    if (lower.contains('mushroom') || lower.contains('nam')) {
      return Icons.grass_rounded;
    }
    if (lower.contains('dairy') ||
        lower.contains('milk') ||
        lower.contains('sua') ||
        lower.contains('egg') ||
        lower.contains('trung')) {
      return Icons.egg_alt_rounded;
    }
    if (lower.contains('meat') || lower.contains('thit')) {
      return Icons.kebab_dining_rounded;
    }
    if (lower.contains('bakery') || lower.contains('banh')) {
      return Icons.bakery_dining_rounded;
    }
    if (lower.contains('honey') || lower.contains('mat ong')) {
      return Icons.hive_rounded;
    }
    if (lower.contains('organic')) {
      return Icons.spa_rounded;
    }
    return Icons.category_rounded;
  }

  Widget _buildCategoryRow() {
    return StreamBuilder<List<Category>>(
      stream: CategoryService().streamActive(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

        return SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return _buildCategoryCircleItem(
                  title: 'All',
                  icon: Icons.local_fire_department_rounded,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                  },
                );
              }

              final cat = categories[index - 1];
              final isSelected = _selectedCategoryId == cat.id;
              final icon = _getCategoryIcon(cat.name, cat.id);
              final displayName = categoryDisplayName(cat.id, cat.name);

              return _buildCategoryCircleItem(
                title: displayName,
                icon: icon,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (_selectedCategoryId == cat.id) {
                      _selectedCategoryId = null;
                    } else {
                      _selectedCategoryId = cat.id;
                    }
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCircleItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? HhColors.primary : Colors.white,
                border: Border.all(
                  color: isSelected ? HhColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2.2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? HhColors.primary.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.white : HhColors.text,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? HhColors.primary
                    : HhColors.text.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
        stream: widget.products,
        builder: (context, p) => StreamBuilder<List<FarmOrder>>(
          stream: widget.orders,
          builder: (context, o) {
            if (p.hasError && o.hasError) {
              return EmptyView(message: errorMessage(p.error ?? o.error!));
            }
            if (!p.hasData &&
                !o.hasData &&
                p.connectionState == ConnectionState.waiting &&
                o.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }

            final allProducts = p.data ?? <Product>[];
            final activeProducts =
                allProducts.where((e) => e.isActive).toList();

            final allOrders = o.data ?? <FarmOrder>[];
            // Tally order frequency (how many orders contain the item) and sold count
            final salesByPid = <String, int>{};
            final salesByName = <String, int>{};
            final orderFreqByPid = <String, int>{};
            final orderFreqByName = <String, int>{};

            for (final order in allOrders) {
              if (order.status == OrderStatus.cancelled) continue;

              final seenPidsInOrder = <String>{};
              final seenNamesInOrder = <String>{};

              for (final item in order.items) {
                final pid = item.productId.trim();
                final nameKey = item.name.trim().toLowerCase();
                final quantity = item.qty > 0 ? item.qty : 1;

                if (pid.isNotEmpty) {
                  salesByPid[pid] = (salesByPid[pid] ?? 0) + quantity;
                  seenPidsInOrder.add(pid);
                }
                if (nameKey.isNotEmpty) {
                  salesByName[nameKey] = (salesByName[nameKey] ?? 0) + quantity;
                  seenNamesInOrder.add(nameKey);
                }
              }

              for (final pid in seenPidsInOrder) {
                orderFreqByPid[pid] = (orderFreqByPid[pid] ?? 0) + 1;
              }
              for (final nameKey in seenNamesInOrder) {
                orderFreqByName[nameKey] = (orderFreqByName[nameKey] ?? 0) + 1;
              }
            }

            int getSoldCount(Product prod) {
              final byPid = prod.id.isNotEmpty ? (salesByPid[prod.id] ?? 0) : 0;
              final byName = salesByName[prod.name.trim().toLowerCase()] ?? 0;
              return byPid > 0 ? byPid : byName;
            }

            int getOrderFrequency(Product prod) {
              final byPid =
                  prod.id.isNotEmpty ? (orderFreqByPid[prod.id] ?? 0) : 0;
              final byName =
                  orderFreqByName[prod.name.trim().toLowerCase()] ?? 0;
              return byPid > 0 ? byPid : byName;
            }

            // Rank products: 1) Most frequently ordered, 2) Total volume sold, 3) Rating, 4) Recency
            final candidateProducts = List<Product>.from(activeProducts);
            candidateProducts.sort((a, b) {
              final freqA = getOrderFrequency(a);
              final freqB = getOrderFrequency(b);
              if (freqB != freqA) {
                return freqB.compareTo(freqA);
              }
              final soldA = getSoldCount(a);
              final soldB = getSoldCount(b);
              if (soldB != soldA) {
                return soldB.compareTo(soldA);
              }
              if (b.rating != a.rating) {
                return b.rating.compareTo(a.rating);
              }
              return b.createdAt.compareTo(a.createdAt);
            });

            // Best Seller badge is awarded strictly to top 2-3 items that have actual orders
            final bestSellerIds = candidateProducts
                .where((prod) =>
                    getOrderFrequency(prod) > 0 || getSoldCount(prod) > 0)
                .take(3)
                .map((prod) => prod.id)
                .toSet();

            final isCategoryMode = _selectedCategoryId != null;
            List<Product> displayedProducts;

            if (isCategoryMode) {
              // Scenario B: Category Filtered
              displayedProducts = activeProducts
                  .where((prod) => prod.categoryId == _selectedCategoryId)
                  .toList();
              // Sort by recently added in this category
              displayedProducts
                  .sort((a, b) => b.createdAt.compareTo(a.createdAt));
            } else {
              // Scenario A: Popular items / Best Sellers first
              displayedProducts = candidateProducts;
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your crops, inventory, and pickup orders.',
                        style: TextStyle(
                          fontSize: 13,
                          color: HhColors.text.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Category Row
                _buildCategoryRow(),
                const SizedBox(height: 16),

                // Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<List<Category>>(
                    stream: CategoryService().streamActive(),
                    builder: (context, catSnap) {
                      final categories = catSnap.data ?? [];
                      String sectionTitle = 'Popular items';
                      String sectionSubtitle =
                          'Top performing crops by sales & customer ratings';

                      if (isCategoryMode) {
                        final matched = categories
                            .where((c) => c.id == _selectedCategoryId);
                        final catName = matched.isNotEmpty
                            ? categoryDisplayName(
                                matched.first.id, matched.first.name)
                            : _selectedCategoryId!;
                        sectionTitle = catName;
                        sectionSubtitle =
                            '${displayedProducts.length} items in this category';
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (!isCategoryMode) ...[
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 20,
                                        color: Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        sectionTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sectionSubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: HhColors.text.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (isCategoryMode) {
                                setState(() => _selectedCategoryId = null);
                              } else {
                                widget.onNavigate(1);
                              }
                            },
                            child: const Text(
                              'See All',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Product Cards List
                if (displayedProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            isCategoryMode
                                ? Icons.category_outlined
                                : Icons.inventory_2_outlined,
                            size: 46,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isCategoryMode
                                ? 'No products in this category yet'
                                : 'No products added yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isCategoryMode
                                ? 'Clear filter to see Best Sellers or add crops to this category.'
                                : 'Add your first produce to start selling.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 14),
                          if (isCategoryMode)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedCategoryId = null),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Show Best Sellers'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () =>
                                  openPage(context, const ProductFormScreen()),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Product'),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: displayedProducts.map((prod) {
                        return _FarmerDashboardProductCard(
                          key: ValueKey('dash_${prod.id}_$isCategoryMode'),
                          product: prod,
                          soldCount: getSoldCount(prod),
                          isCategoryMode: isCategoryMode,
                          isBestSeller: bestSellerIds.contains(prod.id),
                          onTap: () => openPage(
                            context,
                            ProductFormScreen(
                              product: prod,
                              isStockLocked: isCategoryMode,
                            ),
                          ),
                          onViewDetail: () => openPage(
                            context,
                            ProductEditScreen(
                              product: prod,
                              isStockLocked: true,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      );
}

class _FarmerDashboardProductCard extends StatelessWidget {
  final Product product;
  final int soldCount;
  final bool isCategoryMode;
  final bool isBestSeller;
  final VoidCallback onTap;
  final VoidCallback onViewDetail;

  const _FarmerDashboardProductCard({
    super.key,
    required this.product,
    required this.soldCount,
    required this.isCategoryMode,
    this.isBestSeller = false,
    required this.onTap,
    required this.onViewDetail,
  });

  Widget _buildInventoryBadge(int stockQty, String unit) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (stockQty <= 0) {
      bg = Colors.red.shade50;
      border = Colors.red.shade200;
      text = Colors.red.shade800;
      icon = Icons.cancel_outlined;
      label = 'Out of Stock';
    } else if (stockQty <= 5) {
      bg = Colors.orange.shade50;
      border = Colors.orange.shade200;
      text = Colors.orange.shade800;
      icon = Icons.warning_amber_rounded;
      label = 'Low Stock ($stockQty $unit)';
    } else {
      bg = Colors.green.shade50;
      border = Colors.green.shade200;
      text = Colors.green.shade800;
      icon = Icons.check_circle_outline_rounded;
      label = 'In Stock ($stockQty $unit)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Proportional Product Image with contextual badge / eye icon
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ProductImage(
                    product.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),

                if (product.isDeactivated)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: HhColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEACTIVATED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Scenario A: Best Seller Flame Badge (only top 2-3 with real orders)
                if (!product.isDeactivated && !isCategoryMode && isBestSeller)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Best Seller',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Scenario B: Eye Icon Button (View / Detail)
                if (isCategoryMode)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onViewDetail,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: HhColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name and Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            product.rating > 0
                                ? product.rating.toStringAsFixed(1)
                                : '5.0',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          if (product.reviewCount > 0)
                            Text(
                              ' (${product.reviewCount})',
                              style: TextStyle(
                                fontSize: 11,
                                color: HhColors.text.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Price and Contextual Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${vnd(product.price)} / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                      if (!isCategoryMode)
                        // Scenario A: Sales Volume
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_outlined,
                                  size: 13, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                '$soldCount sold',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Scenario B: Inventory Status
                        _buildInventoryBadge(product.stockQty, product.unit),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FarmerProducts extends StatefulWidget {
  final Stream<List<Product>>? stream;
  final String? farmerId;
  const FarmerProducts({super.key, this.stream, this.farmerId});
  @override
  State<FarmerProducts> createState() => _FarmerProductsState();
}

class _FarmerProductsState extends State<FarmerProducts> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _sortDescending = true;
  String _stockFilter = 'All';

  List<Product> _products = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts(initial: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadProducts(initial: false);
    }
  }

  String _getFarmerId() {
    if (widget.farmerId != null && widget.farmerId!.isNotEmpty) {
      return widget.farmerId!;
    }
    return context.read<AuthController>().user?.uid ?? '';
  }

  Future<void> _loadProducts({bool initial = true}) async {
    final farmerId = _getFarmerId();
    if (initial) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await ProductService().getFarmerProductsPage(
        farmerId: farmerId,
        categoryId: _selectedCategory,
        searchQuery: _searchQuery,
        sortDescending: _sortDescending,
        limit: 50,
        startAfterDoc: initial ? null : _lastDoc,
      );

      if (!mounted) return;
      setState(() {
        if (initial) {
          _products = result.products;
        } else {
          _products.addAll(result.products);
        }
        _lastDoc = result.lastDoc;
        _hasMore = result.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
      });
      _loadProducts(initial: true);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = trimmed;
        });
        _loadProducts(initial: true);
      }
    });
  }

  void _onCategoryChanged(String? catId) {
    setState(() {
      _selectedCategory = catId;
    });
    _loadProducts(initial: true);
  }

  void _onSortChanged(bool? descending) {
    if (descending == null) return;
    setState(() {
      _sortDescending = descending;
    });
    _loadProducts(initial: true);
  }

  Future<void> _openCreateProduct() async {
    final result = await openPage(context, const ProductFormScreen());
    if (result == true && mounted) {
      _loadProducts(initial: true);
    }
  }

  Future<void> _openEditProduct(Product p) async {
    final result = await openPage(context, ProductFormScreen(product: p));
    if (result == true && mounted) {
      _loadProducts(initial: true);
    }
  }

  Future<void> _updateStock(Product p) async {
    final ctrl = TextEditingController(text: p.stockQty.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${p.name}'),
        content: HhTextField(
          controller: ctrl,
          label: 'New Quantity (${p.unit})',
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0 && mounted) {
      await perform(context, () => ProductService().updateStock(p.id, result),
          success: 'Stock updated to $result ${p.unit}');
      if (mounted) {
        _loadProducts(initial: true);
      }
    }
  }

  Future<void> _adjustStock(Product p, int delta) async {
    final next = (p.stockQty + delta).clamp(0, 999999);
    await perform(context, () => ProductService().updateStock(p.id, next));
    if (mounted) {
      _loadProducts(initial: true);
    }
  }

  Widget _buildStockChip(String label, int count) {
    final isSelected = _stockFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _stockFilter = label),
    );
  }

  Future<void> _removeProduct(Product p) async {
    final activeOrdersCount =
        await OrderService().countActiveOrdersWithProduct(p.farmerId, p.id);
    if (!mounted) return;

    if (activeOrdersCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: HhColors.danger),
              SizedBox(width: 8),
              Expanded(child: Text('Cannot Remove Product')),
            ],
          ),
          content: Text(
            'Cannot remove "${p.name}" because there are $activeOrdersCount active order(s) pending preparation or pickup.\n\nPlease fulfill or cancel those orders before removing this product.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text(
          'Are you sure you want to remove "${p.name}" from your active product list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove from product list'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await perform(
        context,
        () async {
          await ProductService().setActive(p.id, false);
          try {
            await ProductService().delete(p.id);
          } catch (_) {}
        },
        success: 'Product "${p.name}" was removed from the catalog.',
      );
      if (mounted) {
        _loadProducts(initial: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateProduct,
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search products by name...',
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  _onSearchChanged(val);
                  setState(() {});
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: StreamBuilder<List<Category>>(
                      stream: CategoryService().streamActive(),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: const Icon(Icons.filter_list, size: 18),
                              hint: const Row(
                                children: [
                                  Icon(Icons.category_outlined,
                                      size: 16, color: HhColors.primary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'All Categories',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      Icon(Icons.category_outlined,
                                          size: 16, color: HhColors.primary),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'All Categories',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...categories
                                    .map((c) => DropdownMenuItem<String?>(
                                          value: c.id,
                                          child: Text(
                                            categoryDisplayName(c.id, c.name),
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        )),
                              ],
                              onChanged: _onCategoryChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<bool>(
                          value: _sortDescending,
                          isExpanded: true,
                          icon: const Icon(Icons.sort, size: 18),
                          items: const [
                            DropdownMenuItem<bool>(
                              value: true,
                              child: Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 16, color: HhColors.primary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Newest First',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem<bool>(
                              value: false,
                              child: Row(
                                children: [
                                  Icon(Icons.history,
                                      size: 16, color: HhColors.primary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Oldest First',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: _onSortChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildStockChip('All', _products.length),
                  const SizedBox(width: 8),
                  _buildStockChip('In Stock',
                      _products.where((p) => p.stockQty > 0).length),
                  const SizedBox(width: 8),
                  _buildStockChip(
                      'Low Stock',
                      _products
                          .where((p) => p.stockQty > 0 && p.stockQty <= 5)
                          .length),
                  const SizedBox(width: 8),
                  _buildStockChip('Out of Stock',
                      _products.where((p) => p.stockQty <= 0).length),
                ],
              ),
            ),
            if (_products.any((p) => p.stockQty <= 0))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: HhColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: HhColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: HhColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_products.where((p) => p.stockQty <= 0).length} items are Out of Stock and hidden from buyers (Zero-Stock Prevention).',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HhColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadProducts(initial: true),
                child: _buildProductList(),
              ),
            ),
          ],
        ),
      );

  Widget _buildProductList() {
    if (_isLoading) {
      return const LoadingView();
    }
    if (_errorMessage != null) {
      return EmptyView(message: _errorMessage!);
    }
    final displayedProducts = _products.where((p) {
      if (_stockFilter == 'In Stock') {
        return p.stockQty > 0;
      }
      if (_stockFilter == 'Low Stock') {
        return p.stockQty > 0 && p.stockQty <= 5;
      }
      if (_stockFilter == 'Out of Stock') {
        return p.stockQty <= 0;
      }
      return true;
    }).toList();

    if (displayedProducts.isEmpty) {
      return const EmptyView(
        message: 'No products found matching your search or filters',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: displayedProducts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < displayedProducts.length) {
          final p = displayedProducts[i];
          return _FarmerProductCard(
            key: ValueKey(p.id),
            product: p,
            onEdit: () => _openEditProduct(p),
            onDelete: () => _removeProduct(p),
            onUpdateStock: () => _updateStock(p),
            onAdjustStock: (delta) => _adjustStock(p, delta),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: _isLoadingMore
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : TextButton.icon(
                    onPressed: () => _loadProducts(initial: false),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: const Text('Load More Products'),
                  ),
          ),
        );
      },
    );
  }
}

class _FarmerProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpdateStock;
  final void Function(int delta) onAdjustStock;

  const _FarmerProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateStock,
    required this.onAdjustStock,
  });

  @override
  State<_FarmerProductCard> createState() => _FarmerProductCardState();
}

class _FarmerProductCardState extends State<_FarmerProductCard> {
  bool isHovered = false;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isZero = p.stockQty == 0;
    final isLow = p.stockQty > 0 && p.stockQty <= 5;
    final isDeactivated = !p.isActive || p.deactivatedByAdmin;
    final badgeColor = isZero
        ? HhColors.danger
        : (isLow ? Colors.orange.shade800 : Colors.green.shade700);
    final badgeLabel = isZero
        ? 'OUT OF STOCK'
        : (isLow ? 'LOW STOCK (${p.stockQty})' : 'IN STOCK (${p.stockQty})');

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        transform: isHovered
            ? Matrix4.translationValues(0, -3, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isDeactivated
              ? Colors.red.shade50.withValues(alpha: 0.3)
              : (isHovered ? const Color(0xFFFDFBF7) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDeactivated
                ? Colors.red.shade400
                : (isZero
                    ? HhColors.danger.withValues(alpha: 0.5)
                    : isHovered
                        ? const Color(0xFFD8C9A8)
                        : const Color(0xFFEBE6DF)),
            width: isDeactivated ? 1.6 : (isZero ? 1.8 : (isHovered ? 2 : 1)),
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFFD8C9A8).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProductImage(p.imageUrl),
                        if (isDeactivated)
                          Container(
                            color: Colors.black.withValues(alpha: 0.65),
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: HhColors.danger,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'DEACTIVATED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (isDeactivated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: HhColors.danger,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DEACTIVATED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vnd(p.price)} / ${p.unit} · Stock: ${p.stockQty}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            p.isEdited
                                ? Icons.edit_calendar
                                : Icons.calendar_today,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.dateStatusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (isDeactivated)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 13, color: Colors.red.shade700),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  p.isCategoryViolation
                                      ? 'Lý do: Sai danh mục đăng ký (SAI_DANH_MUC_DANG_KY)'
                                      : (p.deactivationReason?.isNotEmpty == true
                                          ? 'Reason: ${p.deactivationReason}'
                                          : 'Inactive due to policy violation or unregistered category.'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                isThreeLine: true,
                onTap: isDeactivated
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sản phẩm đã bị khóa do vi phạm danh mục, không thể chỉnh sửa.',
                            ),
                            backgroundColor: HhColors.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : widget.onEdit,
                trailing: IconButton(
                  tooltip: isExpanded ? 'Hide Actions' : 'View Actions',
                  icon: Icon(
                    isExpanded ? Icons.visibility : Icons.visibility_outlined,
                    color: isExpanded ? HhColors.primary : Colors.grey.shade700,
                    size: 26,
                  ),
                  onPressed: () => setState(() => isExpanded = !isExpanded),
                ),
              ),
              if (isZero)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: HhColors.danger.withValues(alpha: 0.08),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: HhColors.danger),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Zero-Stock Prevention: Hidden from buyers until restocked.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HhColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: HhColors.bg.withValues(alpha: 0.4),
                  borderRadius: isExpanded
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(
                          bottom: Radius.circular(13)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quick Stock: ',
                          style: TextStyle(fontSize: 12, color: HhColors.muted),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon:
                              const Icon(Icons.remove_circle_outline, size: 20),
                          color: (!isDeactivated && p.stockQty > 0)
                              ? HhColors.danger
                              : Colors.grey,
                          onPressed: (!isDeactivated && p.stockQty > 0)
                              ? () => widget.onAdjustStock(-1)
                              : null,
                        ),
                        InkWell(
                          onTap: isDeactivated ? null : widget.onUpdateStock,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p.stockQty}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit,
                                    size: 13, color: HhColors.muted),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          color: isDeactivated ? Colors.grey : HhColors.primary,
                          onPressed: isDeactivated
                              ? null
                              : () => widget.onAdjustStock(1),
                        ),
                      ],
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: isDeactivated ? null : widget.onUpdateStock,
                        child: const Text(
                          'Tap to edit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            color: HhColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpanded)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF7EE),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(13)),
                    border: Border(
                      top: BorderSide(color: Color(0xFFD8C9A8), width: 1),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDeactivated
                                ? Colors.grey.shade400
                                : HhColors.primary,
                            side: BorderSide(
                              color: isDeactivated
                                  ? Colors.grey.shade300
                                  : HhColors.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isDeactivated ? null : widget.onEdit,
                          icon: Icon(
                            isDeactivated
                                ? Icons.lock_outline
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                          label: Text(
                            isDeactivated ? 'Edit Locked' : 'Edit Product',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            backgroundColor: Colors.red.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text(
                            'Remove from product list',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final bool isStockLocked;
  const ProductFormScreen(
      {super.key, this.product, this.isStockLocked = false});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

typedef ProductEditScreen = ProductFormScreen;

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const int _maxPhotos = 6;

  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name);
  late final description =
      TextEditingController(text: widget.product?.description);
  late final price = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '');
  late final stock = TextEditingController(
      text: widget.product != null ? widget.product!.stockQty.toString() : '');
  late String unit = widget.product?.unit ?? 'kg';
  late String? category = widget.product?.categoryId;

  final List<File> photos = [];
  bool photoError = false;

  final Map<String, String> _photoAiStatus = {};

  String? _nameMismatchError;

  bool _autoValidate = false;
  bool busy = false;
  final categories = CategoryService().streamActive();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      category = widget.product!.categoryId;
      unit = getFixedUnitForCategory(widget.product!.categoryId);
    }
    name.addListener(_validateNameWithPhoto);
  }

  @override
  void dispose() {
    name.removeListener(_validateNameWithPhoto);
    for (final c in [name, description, price, stock]) {
      c.dispose();
    }
    super.dispose();
  }

  void _validateNameWithPhoto() {
    final input = name.text.trim();
    if (input.isEmpty || photos.isEmpty) {
      if (_nameMismatchError != null) {
        setState(() => _nameMismatchError = null);
      }
      return;
    }

    final hasSafetyViolation = photos.any(
      (p) => _photoAiStatus[p.path]?.startsWith('safety_violation:') == true,
    );
    if (hasSafetyViolation) {
      const error =
          'Uploaded photo violates community safety standards (weapons, firearms, ammunition, or violence).';
      if (_nameMismatchError != error) {
        setState(() => _nameMismatchError = error);
      }
      return;
    }

    final hasRejectedPhoto = photos.any(
      (p) => _photoAiStatus[p.path]?.startsWith('rejected:') == true,
    );
    if (hasRejectedPhoto) {
      const error = 'Uploaded photo is not recognized as agricultural produce.';
      if (_nameMismatchError != error) {
        setState(() => _nameMismatchError = error);
      }
      return;
    }

    String? detectedProduce;
    for (final photo in photos) {
      final status = _photoAiStatus[photo.path];
      if (status != null && status.startsWith('verified: ')) {
        detectedProduce = status.substring('verified: '.length).trim();
        break;
      }
    }

    if (detectedProduce == null ||
        detectedProduce.isEmpty ||
        detectedProduce.toLowerCase() == 'produce') {
      if (_nameMismatchError != null) {
        setState(() => _nameMismatchError = null);
      }
      return;
    }

    final isMatch = ProductModerationService.isProduceNameMatching(
      inputName: input,
      detectedProduce: detectedProduce,
    );

    final error = isMatch
        ? null
        : 'Product name must match the produce in the photo (photo shows: $detectedProduce)';

    if (_nameMismatchError != error) {
      setState(() {
        _nameMismatchError = error;
      });
    }
  }

  Future<void> _pickAddPhoto() async {
    if (photos.length >= _maxPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $_maxPhotos photos allowed per product.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await perform(context, () async {
      final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 900,
          maxHeight: 900,
          imageQuality: 75);
      if (selected != null && mounted) {
        final newFile = File(selected.path);
        setState(() {
          photos.add(newFile);
          photoError = false;
          _photoAiStatus[newFile.path] = 'checking';
        });
        _auditPhotoInBackground(newFile);
      }
    });
  }

  Future<void> _auditPhotoInBackground(File file) async {
    try {
      final inspection =
          await ProductModerationService().inspectProduceImage(imageFile: file);
      if (!mounted) return;

      if (inspection.isSafetyViolation) {
        setState(() {
          _photoAiStatus[file.path] = 'safety_violation: ${inspection.reason}';
        });
        _validateNameWithPhoto();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Community Safety Violation'),
                ),
              ],
            ),
            content: Text(
              'This photo contains prohibited content (weapons, firearms, ammunition, or violence) violating community standards.\n\nReason: ${inspection.reason}\n\nYou must remove this photo to continue.',
              style: const TextStyle(fontSize: 13.5),
            ),
            actions: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  _removePhoto(photos.indexOf(file));
                },
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Remove Prohibited Photo'),
              ),
            ],
          ),
        );
      } else if (inspection.isSystemError) {
        setState(() {
          _photoAiStatus[file.path] = 'system_error: ${inspection.reason}';
        });
        _validateNameWithPhoto();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System error: ${inspection.reason}'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _photoAiStatus[file.path] = 'checking';
                });
                _auditPhotoInBackground(file);
              },
            ),
          ),
        );
      } else if (!inspection.isProduce) {
        setState(() {
          _photoAiStatus[file.path] = 'rejected: ${inspection.reason}';
        });
        _validateNameWithPhoto();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.hide_image_rounded,
                    color: HhColors.danger, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Non-Produce Image'),
                ),
              ],
            ),
            content: Text(
              'The uploaded photo does not appear to be agricultural produce (${inspection.reason}). Please upload a clear photo of your produce.',
              style: const TextStyle(fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removePhoto(photos.indexOf(file));
                },
                child: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Change Photo'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _photoAiStatus[file.path] =
              'verified: ${inspection.productName ?? "Produce"}';
          if (category == null && inspection.categoryId != null) {
            category = inspection.categoryId;
            unit = getFixedUnitForCategory(inspection.categoryId);
          }
          if (name.text.trim().isEmpty && inspection.productName != null) {
            name.text = inspection.productName!;
          }
        });
        _validateNameWithPhoto();
        if (inspection.productName != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'AI verified produce: ${inspection.productName} (${categoryDisplayName(inspection.categoryId ?? '', '')})'),
              backgroundColor: HhColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _photoAiStatus[file.path] =
              'system_error: Could not reach AI verification service.';
        });
        _validateNameWithPhoto();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('System error: Could not reach AI verification service.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < photos.length) {
      final removed = photos.removeAt(index);
      _photoAiStatus.remove(removed.path);
      setState(() {});
      _validateNameWithPhoto();
    }
  }

  void _onCategoryChanged(String? newCat) {
    if (newCat == null) return;
    setState(() {
      category = newCat;
      unit = getFixedUnitForCategory(newCat);
    });
  }

  Future<void> _confirmCancel() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to cancel? Any unsaved product information will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteProduct() async {
    if (widget.product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa sản phẩm?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "${widget.product!.name}" khỏi gian hàng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa sản phẩm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => busy = true);
      try {
        await ProductService().deleteProduct(widget.product!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa sản phẩm khỏi gian hàng.'),
              backgroundColor: HhColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          showError(context, 'Lỗi khi xóa sản phẩm: $e');
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> _promptSave() async {
    setState(() {
      _autoValidate = true;
    });

    final hasPhoto = photos.isNotEmpty ||
        (widget.product != null && widget.product!.imageUrl.isNotEmpty);
    setState(() {
      photoError = !hasPhoto;
    });

    final formValid = form.currentState?.validate() ?? false;
    final hasCategory = category != null && category!.trim().isNotEmpty;

    final missingErrors = <String>[];
    if (!hasPhoto) missingErrors.add('Product Photo (at least 1 required)');
    if (name.text.trim().isEmpty) missingErrors.add('Product Name');
    if (!hasCategory) missingErrors.add('Category');
    if (description.text.trim().isEmpty) {
      missingErrors.add('Description');
    } else if (description.text.trim().length < 15) {
      missingErrors.add('Description (min 15 characters)');
    }
    if (price.text.trim().isEmpty) {
      missingErrors.add('Base Price');
    } else {
      final p = int.tryParse(price.text.trim());
      if (p == null || p <= 0) {
        missingErrors.add('Valid Price (> 0)');
      }
    }
    if (stock.text.trim().isEmpty) {
      missingErrors.add('Available Quantity');
    } else {
      final q = int.tryParse(stock.text.trim());
      if (q == null || q <= 0) {
        missingErrors.add('Valid Quantity (> 0)');
      }
    }

    if (!hasPhoto || !hasCategory || !formValid || missingErrors.isNotEmpty) {
      showError(
        context,
        'Please complete all required fields:\n${missingErrors.join(', ')}',
      );
      return;
    }

    final isStillChecking =
        photos.any((p) => _photoAiStatus[p.path] == 'checking');
    if (isStillChecking) {
      showError(context,
          'Please wait a moment for AI image verification to complete.');
      return;
    }

    final hasSafetyViolation = photos.any(
      (p) => _photoAiStatus[p.path]?.startsWith('safety_violation:') == true,
    );
    if (hasSafetyViolation) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text('Listing Blocked'),
              ),
            ],
          ),
          content: const Text(
            'Your product cannot be saved because one or more uploaded photos violate community safety standards (weapons, firearms, ammunition, or violence). You must remove the prohibited photos.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understand & Revise'),
            ),
          ],
        ),
      );
      return;
    }

    final hasRejectedPhoto = photos.any(
      (p) => _photoAiStatus[p.path]?.startsWith('rejected:') == true,
    );
    if (hasRejectedPhoto) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.hide_image_rounded, color: HhColors.danger, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Non-Produce Image Detected'),
              ),
            ],
          ),
          content: const Text(
            'One or more of your uploaded photos are not related to agricultural produce. Please remove or replace the flagged photos before listing.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understand & Revise'),
            ),
          ],
        ),
      );
      return;
    }

    final hasSystemErrorPhoto = photos.any(
      (p) => _photoAiStatus[p.path]?.startsWith('system_error:') == true,
    );
    if (hasSystemErrorPhoto) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('AI Verification Unavailable'),
              ),
            ],
          ),
          content: const Text(
            'Some photos could not be verified by AI due to a system error. You can still save and submit the listing — it will be reviewed manually. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    _validateNameWithPhoto();
    if (_nameMismatchError != null) {
      showError(context, _nameMismatchError!);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Verifying community standards & inspecting images with AI...',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final existingUrls =
        widget.product != null ? widget.product!.galleryImages : <String>[];

    final moderation = await ProductModerationService().moderateProduct(
      name: name.text.trim(),
      description: description.text.trim(),
      categoryId: category!,
      imageFiles: photos.isNotEmpty ? photos : null,
      existingImageUrls: photos.isEmpty ? existingUrls : null,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!moderation.isApproved) {
      if (moderation.isCategoryMismatch) {
        final suggestedName = moderation.suggestedCategoryName ??
            moderation.suggestedCategoryId ??
            'Suggested Category';
        if (!mounted) return;
        final switchCat = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.category_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Category Mismatch'),
              ],
            ),
            content: Text(
              '${moderation.message}\n\nWould you like to switch to "$suggestedName"?',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep & Report to Admin'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Switch to $suggestedName'),
              ),
            ],
          ),
        );

        if (switchCat == true && mounted) {
          setState(() {
            category = moderation.suggestedCategoryId!;
            unit = getFixedUnitForCategory(moderation.suggestedCategoryId!);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched category to $suggestedName.'),
              backgroundColor: HhColors.primary,
            ),
          );
        } else if (switchCat == false) {
          if (!mounted) return;
          final authUser = context.read<AuthController>().user;
          if (authUser != null) {
            await ProductModerationService().reportViolationToAdmin(
              farmerId: authUser.uid,
              farmerName: authUser.name,
              productName: name.text.trim(),
              violationType: 'category_mismatch',
              reason:
                  'Farmer elected to keep category "$category" instead of recommended "$suggestedName".',
              severity: 'medium',
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Category mismatch logged and reported to Admin for review.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          return;
        }
      } else {
        if (moderation.isSevere) {
          if (!mounted) return;
          final authUser = context.read<AuthController>().user;
          if (authUser != null) {
            await ProductModerationService().reportViolationToAdmin(
              farmerId: authUser.uid,
              farmerName: authUser.name,
              productName: name.text.trim(),
              violationType: moderation.violationType ?? 'policy_violation',
              reason: moderation.message,
              severity: moderation.severity,
            );
          }
        }

        if (!mounted) return;
        final isImageViolation =
            moderation.violationType == 'irrelevant_image' ||
                moderation.violationType == 'nsfw_image' ||
                moderation.violationType == 'violence_image' ||
                moderation.violationType == 'spam_image';
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isImageViolation
                      ? Icons.hide_image_rounded
                      : Icons.gpp_bad_rounded,
                  color: HhColors.danger,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(isImageViolation ? 'Invalid Photo' : 'Listing Rejected'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImageViolation) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Your photo must show the actual product you are selling. Please upload a clear photo of your produce.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  moderation.message,
                  style: const TextStyle(fontSize: 13.5),
                ),
                if (moderation.detectedKeywords.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Flagged terms:',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: moderation.detectedKeywords
                        .map((kw) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(kw,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              backgroundColor: HhColors.danger,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(
                  isImageViolation ? Icons.photo_library_outlined : Icons.edit,
                  size: 16,
                ),
                label: Text(
                    isImageViolation ? 'Change Photo' : 'Understand & Revise'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final isNew = widget.product == null;
    final actionLabel = isNew ? 'Save Product' : 'Update Product';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Save New Product?' : 'Update Product?'),
        content: Text(
          isNew
              ? 'Are you sure you want to list "${name.text.trim()}" in the product catalog?'
              : 'Are you sure you want to update "${name.text.trim()}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeSave();
    }
  }

  Future<void> _executeSave() async {
    final authUser = context.read<AuthController>().user;
    if (authUser == null) return;
    final uid = authUser.uid;

    setState(() => busy = true);
    try {
      final farmerDoc =
          await FirebaseFirestore.instance.collection('farmers').doc(uid).get();
      final farmerName = (farmerDoc.exists &&
              farmerDoc.data() != null &&
              farmerDoc.data()!['businessName'] != null)
          ? farmerDoc.data()!['businessName'] as String
          : (authUser.name.isNotEmpty ? authUser.name : 'Organic Farm Store');

      String finalCoverUrl = '';
      List<String> finalExtraUrls = [];

      if (photos.isNotEmpty) {
        final allUrls = await StorageService().uploadProductImages(uid, photos);
        if (allUrls.isNotEmpty) {
          finalCoverUrl = allUrls.first;
          finalExtraUrls = allUrls.length > 1 ? allUrls.sublist(1) : [];
        }
      } else if (widget.product != null &&
          widget.product!.imageUrl.isNotEmpty) {
        finalCoverUrl = widget.product!.imageUrl;
        finalExtraUrls = List<String>.from(widget.product!.imageUrls);
      }

      if (finalCoverUrl.isEmpty) {
        throw 'Product photo is missing. Please upload at least one photo.';
      }

      final now = DateTime.now();
      final p = Product(
          id: widget.product?.id ?? '',
          farmerId: uid,
          farmerName: farmerName,
          name: name.text.trim(),
          categoryId: category!,
          description: description.text.trim(),
          price: int.parse(price.text),
          unit: unit,
          stockQty: int.parse(stock.text),
          imageUrl: finalCoverUrl,
          imageUrls: finalExtraUrls,
          videoUrl: widget.product?.videoUrl,
          isActive: widget.product?.isActive ?? true,
          createdAt: widget.product?.createdAt ?? now,
          updatedAt: now);

      if (widget.product == null) {
        await ProductService().addProduct(p);
      } else {
        await ProductService().updateProduct(p);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product == null
                  ? 'Product "${p.name}" listed successfully!'
                  : 'Product "${p.name}" updated successfully!',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _confirmCancel();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                widget.product == null ? 'List New Product' : 'Update Product'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: _confirmCancel,
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : _confirmCancel,
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: Form(
            key: form,
            autovalidateMode: _autoValidate
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.product != null &&
                    (!widget.product!.isActive ||
                        widget.product!.deactivatedByAdmin ||
                        (widget.product!.deactivationReason != null &&
                            widget.product!.deactivationReason!.isNotEmpty)))
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.shade300, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gavel_rounded,
                            color: Colors.red.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product!.isCategoryViolation
                                    ? 'Sản phẩm đã bị khóa: Sai danh mục đăng ký'
                                    : 'Deactivated by Administration',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.product!.isCategoryViolation
                                    ? 'Lý do: Mã lỗi SAI_DANH_MUC_DANG_KY. Sản phẩm này không thuộc danh mục nông dân đã đăng ký kinh doanh.'
                                    : (widget.product!.deactivationReason
                                                ?.isNotEmpty ==
                                            true
                                        ? 'Reason: ${widget.product!.deactivationReason}'
                                        : 'This product has been marked inactive due to policy violation or unregistered category.'),
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Khóa thao tác: Nút chỉnh sửa đã bị vô hiệu hóa để bảo vệ tính toàn vẹn dữ liệu. Bạn có thể xóa sản phẩm khỏi danh mục bằng nút Xóa bên dưới.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Product Photos',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: HhColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '${photos.length + (widget.product?.galleryImages.length ?? 0).clamp(0, photos.isEmpty ? 999 : 0)}/$_maxPhotos',
                      style:
                          const TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (photoError &&
                    photos.isEmpty &&
                    (widget.product?.imageUrl.isEmpty ?? true))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'At least 1 product photo is required.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (photos.isEmpty &&
                    widget.product != null &&
                    widget.product!.galleryImages.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.product!.galleryImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final url = widget.product!.galleryImages[idx];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: ProductImage(url, fit: BoxFit.cover),
                              ),
                            ),
                            if (idx == 0)
                              Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HhColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Cover',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Existing photos. Upload new photos above to replace them all.',
                    style: TextStyle(fontSize: 11.5, color: HhColors.muted),
                  ),
                  const SizedBox(height: 8),
                ],
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          photos.length + (photos.length < _maxPhotos ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        if (idx == photos.length) {
                          return GestureDetector(
                            onTap: busy ? null : _pickAddPhoto,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: HhColors.primary,
                                    width: 1.5,
                                    style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(8),
                                color: HhColors.primary.withValues(alpha: 0.05),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      color: HhColors.primary, size: 26),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add\n(${photos.length}/$_maxPhotos)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: HhColors.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final photoFile = photos[idx];
                        final status = _photoAiStatus[photoFile.path];
                        final isChecking = status == 'checking';
                        final isSafetyViolation =
                            status?.startsWith('safety_violation:') == true;
                        final isRejected =
                            status?.startsWith('rejected:') == true;
                        final isVerified =
                            status?.startsWith('verified:') == true;
                        final isSystemError =
                            status?.startsWith('system_error:') == true;
                        final isError = isSafetyViolation || isRejected;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSafetyViolation
                                      ? Colors.red.shade900
                                      : isRejected
                                          ? Colors.red
                                          : isSystemError
                                              ? Colors.orange.shade700
                                              : isVerified
                                                  ? HhColors.primary
                                                  : Colors.transparent,
                                  width: isError || isVerified || isSystemError
                                      ? 2.5
                                      : 0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child:
                                      Image.file(photoFile, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            if (isChecking)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Checking...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (idx == 0)
                              Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HhColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Cover',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            if (!isChecking &&
                                (isError || isVerified || isSystemError))
                              Positioned(
                                left: 4,
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSafetyViolation
                                        ? Colors.red.shade900
                                        : isRejected
                                            ? Colors.red
                                            : isSystemError
                                                ? Colors.orange.shade800
                                                : Colors.green.shade800,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isSafetyViolation
                                        ? 'PROHIBITED'
                                        : isRejected
                                            ? 'Not Produce'
                                            : isSystemError
                                                ? 'Error'
                                                : 'Verified',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: busy ? null : () => _removePhoto(idx),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (photos.any((p) =>
                    _photoAiStatus[p.path]?.startsWith('safety_violation:') ==
                        true ||
                    _photoAiStatus[p.path]?.startsWith('rejected:') == true))
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gpp_bad_rounded,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'One or more photos violate community safety standards or are not agricultural produce. You must remove them before listing.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (photos.any((p) =>
                    _photoAiStatus[p.path]?.startsWith('system_error:') ==
                    true))
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'AI verification failed for some photos (system error). Tap "Retry" on the snackbar or remove and re-add the photo.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                if (photos.isEmpty)
                  FilledButton.icon(
                    onPressed: busy ? null : _pickAddPhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                    label: const Text(
                      'Add Photos from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (widget.product != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 14),
                    child: TextFormField(
                      key: ValueKey(
                          'product_date_display_${widget.product!.id}'),
                      initialValue: widget.product!.dateStatusText,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: widget.product!.isEdited
                            ? 'Last Edited'
                            : 'Created Date',
                        prefixIcon: Icon(
                          widget.product!.isEdited
                              ? Icons.edit_calendar
                              : Icons.calendar_today,
                          size: 20,
                          color: HhColors.primary,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F6),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                HhTextField(
                  controller: name,
                  label: 'Product Name',
                  validator: (s) {
                    if (s == null || s.trim().isEmpty) {
                      return 'Product name is required';
                    }
                    if (s.trim().length < 2) {
                      return 'Product name must be at least 2 characters';
                    }
                    if (_nameMismatchError != null) {
                      return _nameMismatchError;
                    }
                    return null;
                  },
                ),
                if (_nameMismatchError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nameMismatchError!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                StreamBuilder<List<Category>>(
                  stream: categories,
                  initialData: CategoryService.getFallbackCategories(),
                  builder: (context, s) {
                    if (s.hasError) return Text(errorMessage(s.error!));
                    final list = (s.data != null && s.data!.isNotEmpty)
                        ? s.data!
                        : CategoryService.getFallbackCategories();
                    final valid =
                        list.any((c) => c.id == category) ? category : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                            'product_category_dropdown_${valid ?? "none"}'),
                        initialValue: valid,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: list
                            .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(categoryDisplayName(c.id, c.name))))
                            .toList(),
                        validator: (s) => (s == null || s.trim().isEmpty)
                            ? 'Category is required'
                            : null,
                        onChanged: _onCategoryChanged,
                      ),
                    );
                  },
                ),
                HhTextField(
                  controller: description,
                  label: 'Description (min 15 characters)',
                  maxLines: 3,
                  validator: (s) {
                    if (s == null || s.trim().isEmpty) {
                      return 'Product description is required';
                    }
                    if (s.trim().length < 15) {
                      return 'Description must be at least 15 characters';
                    }
                    return null;
                  },
                ),
                HhTextField(
                  controller: price,
                  label: 'Base Price (\$) per $unit',
                  keyboardType: TextInputType.number,
                  validator: (s) {
                    if (s == null || s.trim().isEmpty) {
                      return 'Price is required';
                    }
                    final p = int.tryParse(s.trim());
                    if (p == null) {
                      return 'Price must be a valid number';
                    }
                    if (p <= 0) {
                      return 'Price must be greater than 0';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    key: ValueKey('unit_${category}_$unit'),
                    initialValue: unitDisplayName(unit),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit of Measure',
                    ),
                  ),
                ),
                HhTextField(
                  controller: stock,
                  label: 'Available Quantity ($unit)',
                  keyboardType: TextInputType.number,
                  readOnly: widget.isStockLocked,
                  suffixIcon: widget.isStockLocked
                      ? const Tooltip(
                          message: 'Stock is managed via Update Stock screen',
                          child: Icon(Icons.lock_outline,
                              size: 20, color: Colors.grey),
                        )
                      : null,
                  helperText: widget.isStockLocked
                      ? 'Stock is locked. Adjust inventory in "Update Stock" section.'
                      : null,
                  validator: (s) {
                    if (s == null || s.trim().isEmpty) {
                      return 'Available quantity is required';
                    }
                    final qty = int.tryParse(s.trim());
                    if (qty == null) {
                      return 'Quantity must be a valid number';
                    }
                    if (qty < 0) {
                      return 'Quantity cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                if (widget.product?.isDeactivated == true)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Quay lại'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HhColors.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: busy ? null : _deleteProduct,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text(
                            'Xóa sản phẩm vi phạm',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: busy ? null : _confirmCancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: HhButton(
                          label: widget.product == null
                              ? 'Save Product'
                              : 'Update Product',
                          busy: busy,
                          onPressed: _promptSave,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      );
}

class FarmerReports extends StatefulWidget {
  final Stream<List<FarmOrder>> stream;
  const FarmerReports({super.key, required this.stream});

  @override
  State<FarmerReports> createState() => _FarmerReportsState();
}

class _FarmerReportsState extends State<FarmerReports> {
  String _timeFilter = 'all'; // 'all', 'week', 'month'
  String _sortOrder = 'newest'; // 'newest', 'oldest'
  String _statusFilter = 'all'; // 'all', 'completed', 'pending'
  int _currentPage = 1;
  static const int _pageSize = 5;

  bool _isWithinWeek(DateTime date, DateTime now) {
    final diff = now.difference(date).inDays;
    return diff >= 0 && diff <= 7;
  }

  bool _isWithinMonth(DateTime date, DateTime now) {
    return date.year == now.year && date.month == now.month;
  }

  Widget _buildTimeFilterChip(String label, String value, IconData icon) {
    final isSelected = _timeFilter == value;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : HhColors.text,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: HhColors.primary,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : HhColors.text,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? HhColors.primary : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _timeFilter = value;
          _currentPage = 1;
        });
      },
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortOrder == value;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : HhColors.text,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: HhColors.primaryDark,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : HhColors.text,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? HhColors.primaryDark : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _sortOrder = value;
          _currentPage = 1;
        });
      },
    );
  }

  Widget _buildOrderCard(FarmOrder order) {
    Color statusBg;
    Color statusBorder;
    Color statusText;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.completed:
        statusBg = Colors.green.shade50;
        statusBorder = Colors.green.shade200;
        statusText = Colors.green.shade800;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case OrderStatus.pending:
        statusBg = Colors.orange.shade50;
        statusBorder = Colors.orange.shade200;
        statusText = Colors.orange.shade800;
        statusIcon = Icons.pending_outlined;
        break;
      case OrderStatus.readyForPickup:
        statusBg = Colors.blue.shade50;
        statusBorder = Colors.blue.shade200;
        statusText = Colors.blue.shade800;
        statusIcon = Icons.storefront_outlined;
        break;
      case OrderStatus.cancelled:
        statusBg = Colors.red.shade50;
        statusBorder = Colors.red.shade200;
        statusText = Colors.red.shade800;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusBg = Colors.grey.shade100;
        statusBorder = Colors.grey.shade300;
        statusText = Colors.grey.shade800;
        statusIcon = Icons.info_outline;
    }

    final totalItems = order.items.fold<int>(0, (acc, item) => acc + item.qty);
    final itemsSummary =
        order.items.map((i) => '${i.name} x${i.qty} ${i.unit}').join(', ');

    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: HhColors.bg,
                      child:
                          Icon(Icons.person, size: 18, color: HhColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        Text(
                          order.customerPhone,
                          style: TextStyle(
                            fontSize: 12,
                            color: HhColors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusText),
                      const SizedBox(width: 4),
                      Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: HhColors.text.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Created: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: HhColors.text.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 13, color: HhColors.text.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    itemsSummary.isNotEmpty
                        ? '$totalItems items: $itemsSummary'
                        : 'No items details',
                    style: TextStyle(
                      fontSize: 12,
                      color: HhColors.text.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Slot: ${order.pickupSlot}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: HhColors.text.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  vnd(order.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                    color: HhColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages, int totalItems) {
    if (totalItems <= _pageSize) {
      return const SizedBox.shrink();
    }

    final startItem = (_currentPage - 1) * _pageSize + 1;
    final endItem = (_currentPage * _pageSize).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: TextStyle(
              fontSize: 12,
              color: HhColors.text.withValues(alpha: 0.7),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous page',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<FarmOrder>>(
        stream: widget.stream,
        builder: (context, s) {
          if (s.hasError) return EmptyView(message: errorMessage(s.error!));
          if (!s.hasData && s.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          final allOrders = s.data ?? <FarmOrder>[];
          final now = DateTime.now();

          // 1. Time Filter
          var filteredOrders = allOrders.where((order) {
            if (_timeFilter == 'week') {
              return _isWithinWeek(order.createdAt, now);
            } else if (_timeFilter == 'month') {
              return _isWithinMonth(order.createdAt, now);
            }
            return true;
          }).toList();

          // 2. Status Filter
          if (_statusFilter == 'completed') {
            filteredOrders = filteredOrders
                .where((o) => o.status == OrderStatus.completed)
                .toList();
          } else if (_statusFilter == 'pending') {
            filteredOrders = filteredOrders
                .where((o) => o.status == OrderStatus.pending)
                .toList();
          }

          // 3. Sorting (Newest vs Oldest)
          filteredOrders.sort((a, b) {
            if (_sortOrder == 'oldest') {
              return a.createdAt.compareTo(b.createdAt);
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          // 4. Statistics from filtered orders
          final completedOrders = filteredOrders
              .where((o) => o.status == OrderStatus.completed)
              .toList();
          final totalRevenue =
              completedOrders.fold<int>(0, (acc, o) => acc + o.total);

          // 5. Pagination
          final totalPages =
              (filteredOrders.length / _pageSize).ceil().clamp(1, 9999);
          if (_currentPage > totalPages) {
            _currentPage = totalPages;
          }
          final startIndex = (_currentPage - 1) * _pageSize;
          final pageOrders =
              filteredOrders.skip(startIndex).take(_pageSize).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Sales & Order Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track completed revenue and filter order records over time.',
                style: TextStyle(
                  fontSize: 13,
                  color: HhColors.text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),

              // Time Filters Row
              const Text(
                'Time Period',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeFilterChip(
                        'All Time', 'all', Icons.all_inclusive_rounded),
                    const SizedBox(width: 8),
                    _buildTimeFilterChip(
                        'This Week', 'week', Icons.calendar_view_week_rounded),
                    const SizedBox(width: 8),
                    _buildTimeFilterChip(
                        'This Month', 'month', Icons.calendar_month_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Sorting & Status Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Sort:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip(
                      'Newest', 'newest', Icons.arrow_downward_rounded),
                  const SizedBox(width: 8),
                  _buildSortChip(
                      'Oldest', 'oldest', Icons.arrow_upward_rounded),
                  const Spacer(),
                  PopupMenuButton<String>(
                    initialValue: _statusFilter,
                    tooltip: 'Filter by Status',
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _statusFilter != 'all'
                          ? HhColors.primary
                          : HhColors.text,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _statusFilter = val;
                        _currentPage = 1;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      const PopupMenuItem(
                          value: 'completed', child: Text('Completed Only')),
                      const PopupMenuItem(
                          value: 'pending', child: Text('Pending Only')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stat Cards Overview for Filtered Period
              Row(
                children: [
                  Expanded(
                    child: StatCard('Orders', '${filteredOrders.length}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard('Revenue', vnd(totalRevenue)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Records (${filteredOrders.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                  if (_statusFilter != 'all')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: HhColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Status: ${_statusFilter.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Orders List or Empty state
              if (pageOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 42, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'No orders found matching the selected filter.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                for (final order in pageOrders) _buildOrderCard(order),
                _buildPaginationControls(totalPages, filteredOrders.length),
              ],
            ],
          );
        },
      );
}

class FarmerOrdersScreen extends StatefulWidget {
  final Stream<List<FarmOrder>> stream;
  const FarmerOrdersScreen({super.key, required this.stream});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _statusFilter;
  String? _pickupStatusFilter;
  String _slotFilter = 'all';
  String _dateFilter = 'all';
  final Set<String> _selectedOrderIds = <String>{};
  final Set<String> _checkedCropItems = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _advanceOrder(String orderId) async {
    setState(() => _busy = true);
    try {
      await OrderService().advanceStatus(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Ordered item quantities will be returned to stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: HhColors.danger),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await OrderService().cancel(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has been cancelled and items restocked'),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batchMarkReady(List<FarmOrder> slotOrders) async {
    final confirmedOrders =
        slotOrders.where((o) => o.status == OrderStatus.confirmed).toList();
    if (confirmedOrders.isEmpty) return;

    final title = 'Mark ${confirmedOrders.length} Orders Ready?';
    final message =
        'Mark all confirmed orders in this slot as ready for pickup?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HhColors.primary),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final order in confirmedOrders) {
        await OrderService().advanceStatus(order.id);
      }
      _selectedOrderIds.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${confirmedOrders.length} orders updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleBatchAction(List<FarmOrder> orders) async {
    final selectedOrders =
        orders.where((o) => _selectedOrderIds.contains(o.id)).toList();
    if (selectedOrders.isEmpty || _busy) return;

    final actionLabel = _batchActionLabel(orders);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$actionLabel?'),
        content: Text(
          'Are you sure you want to process ${selectedOrders.length} selected orders?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HhColors.primary),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final order in selectedOrders) {
        await OrderService().advanceStatus(order.id);
      }
      _selectedOrderIds.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedOrders.length} orders updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleBatchCancel(List<FarmOrder> orders) async {
    final selectedOrders =
        orders.where((o) => _selectedOrderIds.contains(o.id)).toList();
    if (selectedOrders.isEmpty || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cancel ${selectedOrders.length} Orders?'),
        content: Text(
          'Are you sure you want to cancel ${selectedOrders.length} selected orders? Ordered item quantities will be returned to stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HhColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final order in selectedOrders) {
        await OrderService().cancel(order.id);
      }
      _selectedOrderIds.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedOrders.length} orders cancelled and restocked',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _batchActionLabel(List<FarmOrder> orders) {
    final selectedOrders =
        orders.where((o) => _selectedOrderIds.contains(o.id)).toList();
    if (selectedOrders.isEmpty) return 'Batch Action';
    if (selectedOrders.every((o) => o.status == OrderStatus.pending)) {
      return 'Confirm (${selectedOrders.length})';
    }
    if (selectedOrders.every((o) => o.status == OrderStatus.confirmed)) {
      return 'Mark Ready (${selectedOrders.length})';
    }
    if (selectedOrders.every((o) => o.status == OrderStatus.readyForPickup)) {
      return 'Complete (${selectedOrders.length})';
    }
    return 'Advance (${selectedOrders.length})';
  }

  bool _matchesDate(DateTime date, String filter) {
    if (filter == 'all') return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (filter == 'today') {
      return target.isAtSameMomentAs(today);
    }
    if (filter == 'tomorrow') {
      final tomorrow = today.add(const Duration(days: 1));
      return target.isAtSameMomentAs(tomorrow);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: HhColors.primary,
            unselectedLabelColor: HhColors.muted,
            indicatorColor: HhColors.primary,
            indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.list_alt_outlined),
                text: 'All Orders',
              ),
              Tab(
                icon: Icon(Icons.schedule_outlined),
                text: 'Pickup Prep',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FarmOrder>>(
            stream: widget.stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyView(message: errorMessage(snapshot.error!));
              }
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final allOrders = snapshot.data ?? <FarmOrder>[];
              OrderService().checkOverdueOrders(allOrders);
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildWorkflowTab(allOrders),
                  _buildPickupPreparationTab(allOrders),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowTab(List<FarmOrder> orders) {
    final filtered = orders.where((o) {
      if (_statusFilter != null && o.status != _statusFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('All (${orders.length})'),
                selected: _statusFilter == null,
                onSelected: (_) => setState(() => _statusFilter = null),
              ),
              const SizedBox(width: 8),
              ...OrderStatus.labels.entries.map((e) {
                final count = orders.where((o) => o.status == e.key).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${e.value} ($count)'),
                    selected: _statusFilter == e.key,
                    onSelected: (_) => setState(() => _statusFilter = e.key),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyView(message: 'No orders found for this status')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24, top: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final o = filtered[i];
                    return _buildOrderCard(
                      o,
                      showActions: false,
                      showStepper: false,
                      showStatusChip: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWorkflowStepper(String currentStatus) {
    if (currentStatus == OrderStatus.cancelled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 16, color: HhColors.danger),
            SizedBox(width: 6),
            Text(
              'Order Cancelled',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: HhColors.danger,
              ),
            ),
          ],
        ),
      );
    }

    const steps = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.readyForPickup,
      OrderStatus.completed,
    ];

    final currentIndex = steps.indexOf(currentStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            final isPassed = currentIndex != -1 && stepBefore < currentIndex;
            return Expanded(
              child: Container(
                height: 2.5,
                color: isPassed ? HhColors.primary : Colors.grey.shade300,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isDone = currentIndex != -1 && stepIndex < currentIndex;
          final isCurrent = stepIndex == currentIndex;
          Color circleColor;
          Widget innerIcon;

          if (isDone) {
            circleColor = HhColors.primary;
            innerIcon = const Icon(Icons.check, size: 11, color: Colors.white);
          } else if (isCurrent) {
            circleColor = HhColors.accent;
            innerIcon = Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            );
          } else {
            circleColor = Colors.grey.shade300;
            innerIcon = const SizedBox.shrink();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                ),
                child: Center(child: innerIcon),
              ),
              const SizedBox(height: 3),
              Text(
                switch (steps[stepIndex]) {
                  OrderStatus.pending => 'Pending',
                  OrderStatus.confirmed => 'Confirmed',
                  OrderStatus.readyForPickup => 'Ready',
                  _ => 'Done',
                },
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? HhColors.text
                      : (isDone ? HhColors.primary : HhColors.muted),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOrderCard(
    FarmOrder o, {
    bool showActions = true,
    bool showStepper = true,
    bool showStatusChip = true,
    bool showCheckbox = true,
  }) {
    final nextStatus = OrderStatus.next[o.status];
    final canCancel = OrderStatus.canCancel(o.status);
    final selectable = showCheckbox &&
        (o.status == OrderStatus.pending ||
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.readyForPickup);
    final isSelected = selectable && _selectedOrderIds.contains(o.id);

    String actionLabel = '';
    IconData actionIcon = Icons.arrow_forward;
    Color actionColor = HhColors.primary;
    if (o.status == OrderStatus.pending) {
      actionLabel = 'Confirm Order';
      actionIcon = Icons.check_circle_outline;
      actionColor = Colors.orange.shade800;
    } else if (o.status == OrderStatus.confirmed) {
      actionLabel = 'Mark Ready for Pickup';
      actionIcon = Icons.inventory_2_outlined;
      actionColor = HhColors.primary;
    } else if (o.status == OrderStatus.readyForPickup) {
      actionLabel = 'Verify & Complete';
      actionIcon = Icons.checklist_rounded;
      actionColor = HhColors.primaryDark;
    }

    final itemsSummary =
        o.items.map((it) => '${it.qty} ${it.unit} ${it.name}').join(', ');

    final slotLabel = pickupSlots[o.pickupSlot] ?? o.pickupSlot;
    final dateStr = DateFormat('dd/MM/yyyy').format(o.pickupDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? HhColors.primary
              : (o.status == OrderStatus.pending
                  ? Colors.orange.shade200
                  : Colors.grey.shade200),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openPage(
          context,
          OrderDetailScreen(id: o.id, role: Roles.farmer),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (selectable) ...[
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: HhColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedOrderIds.add(o.id);
                            } else {
                              _selectedOrderIds.remove(o.id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      '#${o.id.substring(0, o.id.length > 8 ? 8 : o.id.length)} · ${DateFormat('dd/MM HH:mm').format(o.createdAt)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: HhColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (o.isOverdueNoShow) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HhColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: HhColors.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: HhColors.danger,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'NO-SHOW (+12H)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: HhColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (o.isOverduePending) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Colors.amber.shade700.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  Colors.amber.shade700.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'PENDING (+6H)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (showStatusChip) StatusChip(o.status),
                    ],
                  ),
                ],
              ),
              if (showStepper) _buildWorkflowStepper(o.status),
              if (o.isOverdueNoShow)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HhColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HhColors.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: HhColors.danger),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No-Show Alert: Pickup window expired (+12h). Review and cancel order to restock produce.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HhColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (o.isOverduePending)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pending Alert: Order has been pending for over 6 hours. Please review and confirm.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: HhColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    o.customerPhone,
                    style: const TextStyle(
                      color: HhColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 15, color: HhColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$slotLabel · $dateStr',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  itemsSummary.isEmpty ? 'No items' : itemsSummary,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Price',
                        style: TextStyle(fontSize: 11, color: HhColors.muted),
                      ),
                      Text(
                        vnd(o.total),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (showActions)
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (canCancel)
                            OutlinedButton(
                              onPressed:
                                  _busy ? null : () => _cancelOrder(o.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HhColors.danger,
                                side: const BorderSide(color: HhColors.danger),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (nextStatus != null)
                            FilledButton.icon(
                              onPressed:
                                  _busy ? null : () => _advanceOrder(o.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: actionColor,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(actionIcon, size: 16),
                              label: Text(
                                actionLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (o.status == OrderStatus.completed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Order Completed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HhColors.primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right,
                            size: 18, color: HhColors.primary),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickupPreparationTab(List<FarmOrder> orders) {
    final filtered = orders.where((o) {
      if (_slotFilter != 'all' && o.pickupSlot != _slotFilter) {
        return false;
      }
      if (!_matchesDate(o.pickupDate, _dateFilter)) {
        return false;
      }
      return true;
    }).toList();

    final activeOrders = filtered
        .where((o) =>
            o.status == OrderStatus.confirmed ||
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.readyForPickup)
        .toList();

    final cropTotals = <String, _CropItemAggregate>{};
    for (final order in activeOrders) {
      for (final item in order.items) {
        final key = '${item.name}_${item.unit}';
        if (cropTotals.containsKey(key)) {
          cropTotals[key]!.totalQty += item.qty;
          cropTotals[key]!.orderCount += 1;
        } else {
          cropTotals[key] = _CropItemAggregate(
            cropName: item.name,
            unit: item.unit,
            totalQty: item.qty,
            orderCount: 1,
          );
        }
      }
    }

    final confirmedInSlot =
        filtered.where((o) => o.status == OrderStatus.confirmed).toList();

    final displayedOrders = filtered.where((o) {
      if (_pickupStatusFilter != null && o.status != _pickupStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    final isBatchSelectableStatus =
        _pickupStatusFilter == OrderStatus.pending ||
            _pickupStatusFilter == OrderStatus.confirmed ||
            _pickupStatusFilter == OrderStatus.readyForPickup;

    final selectableOrders = isBatchSelectableStatus
        ? displayedOrders.where((o) => o.status == _pickupStatusFilter).toList()
        : <FarmOrder>[];

    final areAllSelected = selectableOrders.isNotEmpty &&
        selectableOrders.every((o) => _selectedOrderIds.contains(o.id));

    final hasActiveFilter = _pickupStatusFilter != null ||
        _dateFilter != 'all' ||
        _slotFilter != 'all';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: HhColors.text.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _dateFilter,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: HhColors.primary,
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: HhColors.text,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('All Dates',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'today',
                                child: Row(
                                  children: [
                                    Icon(Icons.today_outlined,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Today',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'tomorrow',
                                child: Row(
                                  children: [
                                    Icon(Icons.event_outlined,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Tomorrow',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedOrderIds.clear();
                                  _dateFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _slotFilter,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: HhColors.primary,
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: HhColors.text,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('All Slots',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'morning_07_10',
                                child: Row(
                                  children: [
                                    Icon(Icons.wb_sunny_outlined,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Morning 07-10',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'afternoon_15_18',
                                child: Row(
                                  children: [
                                    Icon(Icons.wb_twilight_outlined,
                                        size: 14, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Afternoon 15-18',
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedOrderIds.clear();
                                  _slotFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (confirmedInSlot.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: HhColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: Text(
                      'Mark All Confirmed as Ready (${confirmedInSlot.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed:
                        _busy ? null : () => _batchMarkReady(confirmedInSlot),
                  ),
                ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Crop Packing Checklist',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${activeOrders.length} active orders',
                            style: const TextStyle(
                              color: HhColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aggregated harvest totals required for selected pickup slots:',
                        style: TextStyle(
                          fontSize: 12,
                          color: HhColors.muted,
                        ),
                      ),
                      const Divider(),
                      if (cropTotals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                                'No produce to prepare for this slot selection'),
                          ),
                        )
                      else
                        ...cropTotals.entries.map((entry) {
                          final key = entry.key;
                          final item = entry.value;
                          final isChecked = _checkedCropItems.contains(key);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _checkedCropItems.add(key);
                                } else {
                                  _checkedCropItems.remove(key);
                                }
                              });
                            },
                            title: Text(
                              item.cropName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: isChecked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isChecked ? Colors.grey : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Total: ${item.totalQty} ${item.unit} (${item.orderCount} orders)',
                              style: TextStyle(
                                decoration: isChecked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slot Orders (${displayedOrders.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectableOrders.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (areAllSelected) {
                                for (final o in selectableOrders) {
                                  _selectedOrderIds.remove(o.id);
                                }
                              } else {
                                for (final o in selectableOrders) {
                                  _selectedOrderIds.add(o.id);
                                }
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: Icon(
                            areAllSelected ? Icons.deselect : Icons.select_all,
                            size: 16,
                            color: HhColors.primary,
                          ),
                          label: Text(
                            areAllSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: HhColors.primary,
                            ),
                          ),
                        ),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Reset Filters',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(
                            Icons.restart_alt_rounded,
                            size: 20,
                            color: HhColors.muted,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedOrderIds.clear();
                              _pickupStatusFilter = null;
                              _dateFilter = 'all';
                              _slotFilter = 'all';
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${filtered.length})'),
                      selected: _pickupStatusFilter == null,
                      onSelected: (_) => setState(() {
                        _selectedOrderIds.clear();
                        _pickupStatusFilter = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ...OrderStatus.labels.entries.map((e) {
                      final count =
                          filtered.where((o) => o.status == e.key).length;
                      final isPending = e.key == OrderStatus.pending;
                      final isReady = e.key == OrderStatus.readyForPickup;
                      final overduePendingCount = isPending
                          ? filtered.where((o) => o.isOverduePending).length
                          : 0;
                      final overdueNoShowCount = isReady
                          ? filtered.where((o) => o.isOverdueNoShow).length
                          : 0;

                      Widget chipLabel = Text('${e.value} ($count)');
                      Color? chipBgColor;
                      Color? chipSelectedColor;
                      BorderSide? chipSide;

                      if (isPending && overduePendingCount > 0) {
                        chipBgColor = Colors.amber.shade50;
                        chipSelectedColor = Colors.amber.shade200;
                        chipSide = BorderSide(
                          color: _pickupStatusFilter == e.key
                              ? Colors.amber.shade800
                              : Colors.amber.shade400,
                          width: _pickupStatusFilter == e.key ? 1.5 : 1,
                        );
                        chipLabel = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${e.value} ($count)',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+6h: $overduePendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      } else if (isReady && overdueNoShowCount > 0) {
                        chipBgColor = HhColors.danger.withValues(alpha: 0.08);
                        chipSelectedColor =
                            HhColors.danger.withValues(alpha: 0.2);
                        chipSide = BorderSide(
                          color: _pickupStatusFilter == e.key
                              ? HhColors.danger
                              : HhColors.danger.withValues(alpha: 0.4),
                          width: _pickupStatusFilter == e.key ? 1.5 : 1,
                        );
                        chipLabel = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: HhColors.danger,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${e.value} ($count)',
                              style: const TextStyle(
                                color: HhColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: HhColors.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+12h: $overdueNoShowCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: chipLabel,
                          selected: _pickupStatusFilter == e.key,
                          backgroundColor: chipBgColor,
                          selectedColor: chipSelectedColor,
                          side: chipSide,
                          onSelected: (_) => setState(() {
                            _selectedOrderIds.clear();
                            _pickupStatusFilter = e.key;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (displayedOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No orders found matching this filter'),
                  ),
                )
              else
                for (final order in displayedOrders)
                  _buildOrderCard(
                    order,
                    showActions: true,
                    showStepper: true,
                    showStatusChip: false,
                    showCheckbox: isBatchSelectableStatus,
                  ),
            ],
          ),
        ),
        if (isBatchSelectableStatus && _selectedOrderIds.isNotEmpty)
          _buildBatchActionBar(displayedOrders),
      ],
    );
  }

  Widget _buildBatchActionBar(List<FarmOrder> orders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HhColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedOrderIds.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Clear selection',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              onPressed: () => setState(() => _selectedOrderIds.clear()),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HhColors.danger,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: Text(
                'Cancel (${_selectedOrderIds.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
              onPressed: _busy ? null : () => _handleBatchCancel(orders),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: HhColors.primaryDark,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.done_all, size: 15),
              label: Text(
                _batchActionLabel(orders),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
              onPressed: _busy ? null : () => _handleBatchAction(orders),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropItemAggregate {
  final String cropName;
  final String unit;
  int totalQty;
  int orderCount;

  _CropItemAggregate({
    required this.cropName,
    required this.unit,
    required this.totalQty,
    required this.orderCount,
  });
}
