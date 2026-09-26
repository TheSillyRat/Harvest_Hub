import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../location/customer_location.dart';
import '../location/nearby_stores.dart';
import 'farmer_detail_screen.dart';
import 'product_detail_sheet.dart';
import 'product_detail_sections.dart';
import 'notifications_screen.dart';
import 'saved_screen.dart';

class CustomerHomeLandingTab extends StatefulWidget {
  final CustomerLocation location;
  final ProductService? productService;
  final CategoryService? categoryService;
  final NearbyStores? nearbyStores;
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<String?> onSelectCategory;

  const CustomerHomeLandingTab({
    super.key,
    required this.location,
    required this.onNavigateTab,
    required this.onSelectCategory,
    this.productService,
    this.categoryService,
    this.nearbyStores,
  });

  @override
  State<CustomerHomeLandingTab> createState() => _CustomerHomeLandingTabState();
}

class _CustomerHomeLandingTabState extends State<CustomerHomeLandingTab> {
  late final ProductService _productService;
  late final CategoryService _categoryService;
  late Stream<List<Product>> _productsStream;
  late Stream<List<Category>> _categoriesStream;
  late Stream<List<StorePickup>> _storesStream;

  final PageController _carouselController = PageController();
  int _carouselIndex = 0;
  Timer? _carouselTimer;

  final List<Map<String, String>> _bannerEvents = const [
    {
      'title': 'FARM PICKUP: FRESH THIS MORNING',
      'subtitle': 'Greens and herbs harvested today from nearby organic farms',
      'badge': 'FRESH HARVEST',
      'image': 'packages/harvesthub_core/assets/images/FSlide-Cus1.png',
    },
    {
      'title': 'WEEKEND SPECIAL: UP TO 25% OFF',
      'subtitle': 'Direct farm discount on selected Da Lat organic vegetables',
      'badge': 'SPECIAL DEAL',
      'image': 'packages/harvesthub_core/assets/images/FSlide-Cus2.png',
    },
    {
      'title': 'SEASONAL HARVEST HIGHLIGHT',
      'subtitle': 'Grade A Da Lat Strawberries restocked directly from local orchards',
      'badge': 'SEASONAL PICK',
      'image': 'packages/harvesthub_core/assets/images/FSlide-Cus3.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    widget.location.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.location.ensureRecent();
      }
    });
    _productService = widget.productService ?? ProductService();
    _categoryService = widget.categoryService ?? CategoryService();
    _productsStream = _productService.streamActiveProducts().asBroadcastStream();
    _categoriesStream = _categoryService.streamActive().asBroadcastStream();
    _storesStream = (widget.nearbyStores ?? NearbyStores()).watch().asBroadcastStream();

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _carouselController.hasClients) {
        final next = (_carouselIndex + 1) % _bannerEvents.length;
        _carouselController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onLocationChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.location.removeListener(_onLocationChanged);
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _openFarmerDetail(String farmerId, String farmerName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FarmerDetailScreen(
          farmerId: farmerId,
          farmerName: farmerName,
          location: widget.location,
          productService: _productService,
        ),
      ),
    );
  }

  String _getStoreDistanceText(StorePickup store) {
    final pos = widget.location.position;
    final km = store.distanceKm(pos ?? const CustomerPosition(11.9404, 108.4583));
    return '${km < 0.1 ? '< 0.1' : km.toStringAsFixed(1)} km away';
  }

  void _openProductDetail(Product product, String categoryName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(
        product: product,
        categoryName: categoryName,
        productService: _productService,
      ),
    );
  }

  Future<void> _quickAddToCart(Product product) async {
    try {
      await context.read<CartController>().addToCart(product, 1);
      if (mounted) {
        TopToast.show(context, 'Added ${product.name} to basket!');
      }
    } catch (_) {
      if (mounted) {
        TopToast.show(context, 'Could not add product', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user?.uid ?? 'customer_1';

    return Scaffold(
      backgroundColor: HhColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(uid),
            ),
            SliverToBoxAdapter(
              child: _buildEventCarousel(),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<StorePickup>>(
                stream: _storesStream,
                builder: (context, snapshot) {
                  final stores = snapshot.data ?? (snapshot.hasError ? [
                    StorePickup('farmer_1', GeoPoint(11.94, 108.45), businessName: 'Green Valley Organic Farm', rating: 4.9),
                    StorePickup('farmer_2', GeoPoint(11.95, 108.44), businessName: 'Highland Orchard', rating: 4.8),
                  ] : []);
                  if (stores.isEmpty) return const SizedBox.shrink();
                  return _buildFeaturedFarmersSection(stores);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<Product>>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  final products = snapshot.data ?? (snapshot.hasError ? ProductService.getFallbackProducts() : []);
                  if (products.isEmpty) return const SizedBox.shrink();
                  final cheapProducts = List<Product>.from(products)
                    ..sort((a, b) => a.price.compareTo(b.price));
                  return _buildBudgetProduceSection(cheapProducts.take(8).toList());
                },
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<StorePickup>>(
                stream: _storesStream,
                builder: (context, snapshot) {
                  final stores = snapshot.data ?? (snapshot.hasError ? [
                    StorePickup('farmer_1', GeoPoint(11.94, 108.45), businessName: 'Green Valley Organic Farm', rating: 4.9),
                    StorePickup('farmer_2', GeoPoint(11.95, 108.44), businessName: 'Highland Orchard', rating: 4.8),
                  ] : []);
                  if (stores.isEmpty) return const SizedBox.shrink();
                  return _buildNearbyFarmersSection(stores);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<Category>>(
                stream: _categoriesStream,
                builder: (context, catSnap) {
                  final categories = catSnap.data ?? (catSnap.hasError ? CategoryService.getFallbackCategories() : []);
                  return StreamBuilder<List<Product>>(
                    stream: _productsStream,
                    builder: (context, prodSnap) {
                      final products = prodSnap.data ?? (prodSnap.hasError ? ProductService.getFallbackProducts() : []);
                      if (categories.isEmpty || products.isEmpty) {
                        return const SizedBox(height: 60);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: categories.take(4).map((cat) {
                          final catProds = products
                              .where((p) => p.categoryId == cat.id)
                              .take(6)
                              .toList();
                          if (catProds.isEmpty) return const SizedBox.shrink();
                          return _buildCategoryPreviewSection(cat, catProds);
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 140),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String uid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const HarvestHubLogo(showName: true, fontSize: 20, iconSize: 20),
              const Spacer(),
              IconButton(
                tooltip: 'Open saved items',
                icon: const Icon(Icons.favorite_border_rounded, size: 22),
                color: HhColors.primary,
                onPressed: () => openSavedItems(context),
              ),
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined, size: 24, color: HhColors.text),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationHistoryScreen(userId: uid),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              widget.onNavigateTab(0);
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HhColors.text.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: HhColors.text.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: HhColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Search fresh produce, farms...',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: HhColors.text.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (idx) => setState(() => _carouselIndex = idx),
            itemCount: _bannerEvents.length,
            itemBuilder: (context, index) {
              final banner = _bannerEvents[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C5E3B), Color(0xFF1E4328)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HhColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        top: -10,
                        width: 170,
                        child: Opacity(
                          opacity: 0.85,
                          child: Image.asset(
                            banner['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              size: 100,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HhColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                banner['badge']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.55,
                              child: Text(
                                banner['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.52,
                              child: Text(
                                banner['subtitle']!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_bannerEvents.length, (idx) {
            final active = idx == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? HhColors.primary : HhColors.text.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: HhColors.text,
            ),
          ),
          InkWell(
            onTap: onViewAll,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: HhColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: HhColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedFarmersSection(List<StorePickup> stores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Featured Farmers', () => widget.onNavigateTab(1)),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: stores.length.clamp(0, 6),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final store = stores[index];
              final farmName = store.businessName.isNotEmpty ? store.businessName : 'Organic Farm';
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _openFarmerDetail(store.farmerId, farmName),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: HhColors.text.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 42,
                                height: 42,
                                color: HhColors.sageLight,
                                child: const Icon(Icons.storefront_rounded, color: HhColors.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: HhColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Local Farm',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HhColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: HhColors.sageLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '★ ${store.rating > 0 ? store.rating.toStringAsFixed(1) : '5.0'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: HhColors.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              child: OutlinedButton(
                                onPressed: () => _openFarmerDetail(store.farmerId, farmName),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(color: HhColors.primary.withValues(alpha: 0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Visit Farm',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: HhColors.primary)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetProduceSection(List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Budget Fresh Produce', () => widget.onNavigateTab(0)),
        SizedBox(
          height: 230,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildHomeProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyFarmersSection(List<StorePickup> stores) {
    final pos = widget.location.position ?? const CustomerPosition(11.9404, 108.4583);
    final sortedStores = List<StorePickup>.from(stores)
      ..sort((a, b) => a.distanceKm(pos).compareTo(b.distanceKm(pos)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Nearby Farms', () => widget.onNavigateTab(1)),
        SizedBox(
          height: 74,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: sortedStores.length.clamp(0, 6),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final store = sortedStores[index];
              final farmName = store.businessName.isNotEmpty ? store.businessName : 'Nearby Organic Farm';
              final distanceText = _getStoreDistanceText(store);
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => _openFarmerDetail(store.farmerId, farmName),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: HhColors.text.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          farmName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: HhColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                distanceText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: HhColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildCategoryPreviewSection(Category category, List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(category.name, () {
          widget.onSelectCategory(category.id);
          widget.onNavigateTab(0);
        }),
        SizedBox(
          height: 230,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildHomeProductCard(product, categoryName: category.name);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomeProductCard(Product product, {String? categoryName}) {
    final isOutOfStock = product.stockQty <= 0;
    return GestureDetector(
      onTap: () => _openProductDetail(product, categoryName ?? product.categoryId),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.25,
                  child: detailPhoto(product.imageUrl),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutOfStock ? HhColors.danger : HhColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOutOfStock ? 'OUT OF STOCK' : 'IN STOCK',
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: HhColors.primary),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: isOutOfStock ? null : () => _quickAddToCart(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HhColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.add_shopping_cart_rounded, size: 16),
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
}
