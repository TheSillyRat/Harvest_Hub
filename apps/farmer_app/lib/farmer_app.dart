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
      if (mounted) {
        setState(() {
          _activeInAppNotification = notification;
        });
      }
    };
    NotificationService.instance.onOpenNotificationHistory = () {
      if (mounted) {
        final uid = context.read<AuthController>().user?.uid ?? '';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationScreen(userId: uid),
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
        type == 'ORDER_STATUS') {
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

class FarmerDashboard extends StatelessWidget {
  final Stream<List<Product>> products;
  final Stream<List<FarmOrder>> orders;
  final ValueChanged<int> onNavigate;
  const FarmerDashboard(
      {super.key,
      required this.products,
      required this.orders,
      required this.onNavigate});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
      stream: products,
      builder: (context, p) => StreamBuilder<List<FarmOrder>>(
          stream: orders,
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
            final newProducts = activeProducts.take(3).toList();

            final allOrders = o.data ?? <FarmOrder>[];
            final pendingOrders = allOrders
                .where((e) => e.status == OrderStatus.pending)
                .toList();
            final now = DateTime.now();
            final revenue = allOrders
                .where((e) =>
                    e.status == OrderStatus.completed &&
                    e.updatedAt.year == now.year &&
                    e.updatedAt.month == now.month)
                .fold<int>(0, (runningTotal, e) => runningTotal + e.total);

            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Welcome back!',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Text('Manage your crops and pickup orders.'),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => onNavigate(1),
                child: StatCard('Active Products', '${activeProducts.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(2),
                child: StatCard('Pending Orders', '${pendingOrders.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(3),
                child: StatCard('Simulated Revenue (This Month)', vnd(revenue)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recently Added Products',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('View All'),
                  )
                ],
              ),
              if (newProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('You have not added any products yet.'),
                ),
              for (final prod in newProducts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductImage(prod.imageUrl)),
                    title: Text(
                      prod.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                        '${vnd(prod.price)} / ${prod.unit} · Stock: ${prod.stockQty}'),
                    onTap: () =>
                        openPage(context, ProductFormScreen(product: prod)),
                  ),
                ),
            ]);
          }));
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
          try {
            await ProductService().delete(p.id);
          } catch (_) {
            await ProductService().setActive(p.id, false);
          }
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
                    child: ProductImage(p.imageUrl),
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
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.red.shade400, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gavel_rounded,
                                size: 10, color: Colors.red.shade800),
                            const SizedBox(width: 3),
                            Text(
                              'DEACTIVATED BY ADMIN',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                                  p.deactivationReason?.isNotEmpty == true
                                      ? 'Reason: ${p.deactivationReason}'
                                      : 'Inactive due to policy violation or unregistered category.',
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
                onTap: widget.onEdit,
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
                          color: p.stockQty > 0 ? HhColors.danger : Colors.grey,
                          onPressed: p.stockQty > 0
                              ? () => widget.onAdjustStock(-1)
                              : null,
                        ),
                        InkWell(
                          onTap: widget.onUpdateStock,
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
                          color: HhColors.primary,
                          onPressed: () => widget.onAdjustStock(1),
                        ),
                      ],
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: widget.onUpdateStock,
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
                            foregroundColor: HhColors.primary,
                            side: const BorderSide(color: HhColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Product'),
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
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

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
      const error =
          'Uploaded photo is not recognized as agricultural produce.';
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
          _photoAiStatus[file.path] = 'system_error: Could not reach AI verification service.';
        });
        _validateNameWithPhoto();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System error: Could not reach AI verification service.'),
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

    final isStillChecking = photos.any((p) => _photoAiStatus[p.path] == 'checking');
    if (isStillChecking) {
      showError(context, 'Please wait a moment for AI image verification to complete.');
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
              Icon(Icons.hide_image_rounded,
                  color: HhColors.danger, size: 24),
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
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 24),
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

    final existingUrls = widget.product != null
        ? widget.product!.galleryImages
        : <String>[];

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
              reason: 'Farmer elected to keep category "$category" instead of recommended "$suggestedName".',
              severity: 'medium',
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Category mismatch logged and reported to Admin for review.'),
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
        final isImageViolation = moderation.violationType == 'irrelevant_image' ||
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
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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
                                'Deactivated by Administration',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.product!.deactivationReason
                                            ?.isNotEmpty ==
                                        true
                                    ? 'Reason: ${widget.product!.deactivationReason}'
                                    : 'This product has been marked inactive due to policy violation or unregistered category.',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Status: Hidden from marketplace. Please update your product details or contact support for review.',
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
                      style: const TextStyle(fontSize: 12, color: HhColors.muted),
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
                      itemCount: photos.length + (photos.length < _maxPhotos ? 1 : 0),
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
                                    color: HhColors.primary, width: 1.5,
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
                                  width: isError || isVerified || isSystemError ? 2.5 : 0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Image.file(photoFile, fit: BoxFit.cover),
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
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
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
                            if (!isChecking && (isError || isVerified || isSystemError))
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
                    _photoAiStatus[p.path]?.startsWith('safety_violation:') == true ||
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
                    _photoAiStatus[p.path]?.startsWith('system_error:') == true))
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
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
                        key: ValueKey('product_category_dropdown_${valid ?? "none"}'),
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

class FarmerReports extends StatelessWidget {
  final Stream<List<FarmOrder>> stream;
  const FarmerReports({super.key, required this.stream});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FarmOrder>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EmptyView(message: errorMessage(s.error!));
        if (!s.hasData && s.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }

        final orders = s.data ?? <FarmOrder>[];
        final completed =
            orders.where((o) => o.status == OrderStatus.completed).toList();
        final totalRevenue = completed.fold<int>(0, (acc, o) => acc + o.total);

        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Sales Report',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard('Total Orders', '${orders.length}')),
              const SizedBox(width: 16),
              Expanded(child: StatCard('Total Revenue', vnd(totalRevenue))),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Completed Sales & Customers',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (completed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No completed sales yet. Check your pending orders!'),
            ),
          for (final order in completed.take(10))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: HhColors.bg,
                  child: Icon(Icons.person, color: HhColors.primaryDark),
                ),
                title: Text(order.customerName),
                subtitle: Text(
                    'Contact: ${order.customerPhone}\nCompleted on: ${DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt)}'),
                trailing: Text(
                  vnd(order.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: HhColors.primary),
                ),
                isThreeLine: true,
              ),
            ),
        ]);
      });
}

class FarmerOrdersScreen extends StatefulWidget {
  final Stream<List<FarmOrder>> stream;
  const FarmerOrdersScreen({super.key, required this.stream});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _statusFilter;
  String? _pickupStatusFilter;
  String _slotFilter = 'all';
  String _dateFilter = 'all';
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

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batch Ready for Pickup'),
        content: Text(
          'Mark all ${confirmedOrders.length} confirmed orders in this slot as Ready for Pickup?',
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
    if (shouldProceed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final order in confirmedOrders) {
        await OrderService().advanceStatus(order.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${confirmedOrders.length} orders marked Ready for Pickup',
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
  }) {
    final nextStatus = OrderStatus.next[o.status];
    final canCancel = OrderStatus.canCancel(o.status);

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
      actionLabel = 'Complete Pickup';
      actionIcon = Icons.task_alt;
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
          color: o.status == OrderStatus.pending
              ? Colors.orange.shade200
              : Colors.grey.shade200,
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

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pickup Slot & Date Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('All Slots'),
                      selected: _slotFilter == 'all',
                      onSelected: (_) => setState(() => _slotFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Morning (07:00–10:00)'),
                      selected: _slotFilter == 'morning_07_10',
                      onSelected: (_) =>
                          setState(() => _slotFilter = 'morning_07_10'),
                    ),
                    ChoiceChip(
                      label: const Text('Afternoon (15:00–18:00)'),
                      selected: _slotFilter == 'afternoon_15_18',
                      onSelected: (_) =>
                          setState(() => _slotFilter = 'afternoon_15_18'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('All Dates'),
                      selected: _dateFilter == 'all',
                      onSelected: (_) => setState(() => _dateFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _dateFilter == 'today',
                      onSelected: (_) => setState(() => _dateFilter = 'today'),
                    ),
                    ChoiceChip(
                      label: const Text('Tomorrow'),
                      selected: _dateFilter == 'tomorrow',
                      onSelected: (_) =>
                          setState(() => _dateFilter = 'tomorrow'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: confirmedInSlot.isNotEmpty
                  ? HhColors.primaryDark
                  : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.done_all),
            label: Text(
              confirmedInSlot.isNotEmpty
                  ? 'Mark All Confirmed as Ready (${confirmedInSlot.length})'
                  : 'Mark All as Ready (No confirmed orders)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: confirmedInSlot.isNotEmpty && !_busy
                ? () => _batchMarkReady(confirmedInSlot)
                : null,
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
                    const Expanded(
                      child: Text(
                        'Crop Packing Checklist',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      child:
                          Text('No produce to prepare for this slot selection'),
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
            Expanded(
              child: Text(
                'Slot Orders (${displayedOrders.length})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_pickupStatusFilter != null)
              TextButton(
                onPressed: () => setState(() => _pickupStatusFilter = null),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child:
                    const Text('Clear Filter', style: TextStyle(fontSize: 12)),
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
                onSelected: (_) => setState(() => _pickupStatusFilter = null),
              ),
              const SizedBox(width: 8),
              ...OrderStatus.labels.entries.map((e) {
                final count = filtered.where((o) => o.status == e.key).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${e.value} ($count)'),
                    selected: _pickupStatusFilter == e.key,
                    onSelected: (_) =>
                        setState(() => _pickupStatusFilter = e.key),
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
            ),
      ],
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
