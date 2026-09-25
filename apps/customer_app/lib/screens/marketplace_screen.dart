import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class MarketplaceScreen extends StatefulWidget {
  final ProductService? productService;
  final CategoryService? categoryService;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenProfile;

  const MarketplaceScreen({
    super.key,
    this.productService,
    this.categoryService,
    required this.onOpenCart,
    required this.onOpenOrders,
    required this.onOpenProfile,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final ProductService _productService;
  late final CategoryService _categoryService;
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<Product>> _products;
  late Stream<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _productService = widget.productService ?? ProductService();
    _categoryService = widget.categoryService ?? CategoryService();
    _products = _productService.streamActiveProducts();
    _categories = _categoryService.streamActive();
  }

  Widget _loadError(String message, VoidCallback retry) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Try again')),
        ]),
      );

  String _searchQuery = '';
  String? _selectedCategoryId;
  String _selectedLocation = 'Green Valley Hub, West Market';

  bool _onlyInStock = false;
  String _sortBy = 'featured';
  double? _minPrice;
  double? _maxPrice;

  bool get _hasActiveFilters =>
      _onlyInStock ||
      _sortBy != 'featured' ||
      _minPrice != null ||
      _maxPrice != null;

  void _clearFilters() {
    setState(() {
      _onlyInStock = false;
      _sortBy = 'featured';
      _minPrice = null;
      _maxPrice = null;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: HhColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: HhColors.text.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter & Sort Produce',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        if (_hasActiveFilters)
                          TextButton(
                            onPressed: () {
                              _clearFilters();
                              setModalState(() {});
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: HhColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Sort Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('Featured', 'featured', setModalState),
                        _buildSortChip(
                            'Price: Low to High', 'price_asc', setModalState),
                        _buildSortChip(
                            'Price: High to Low', 'price_desc', setModalState),
                        _buildSortChip('Name (A-Z)', 'name', setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: HhColors.text.withValues(alpha: 0.1),
                        ),
                      ),
                      child: SwitchListTile(
                        activeTrackColor: HhColors.primary,
                        title: const Text(
                          'In-Stock Crops Only',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: HhColors.text,
                          ),
                        ),
                        subtitle: const Text(
                          'Hide produce items with 0 stock quantity',
                          style: TextStyle(fontSize: 12, color: HhColors.muted),
                        ),
                        value: _onlyInStock,
                        onChanged: (val) {
                          setModalState(() {
                            _onlyInStock = val;
                          });
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HhColors.primary,
                          foregroundColor: HhColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildSortChip(String label, String value, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: HhColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : HhColors.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: isSelected
            ? HhColors.primary
            : HhColors.text.withValues(alpha: 0.15),
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() {
            _sortBy = value;
          });
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ProductDetailSheet(product: product),
    );
  }

  void _showLocationPicker() {
    final locations = [
      'Green Valley Hub, West Market',
      'Central Highlands Distribution Depot',
      'Sunrise Community Farm Station',
      'Pinecrest Artisan Trading Post',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Farm Pickup Station',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                ...locations.map((loc) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.store_mall_directory_outlined,
                        color: _selectedLocation == loc
                            ? HhColors.primary
                            : HhColors.muted,
                      ),
                      title: Text(
                        loc,
                        style: TextStyle(
                          fontWeight: _selectedLocation == loc
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedLocation == loc
                              ? HhColors.primary
                              : HhColors.text,
                        ),
                      ),
                      trailing: _selectedLocation == loc
                          ? const Icon(Icons.check_circle_rounded,
                              color: HhColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLocation = loc;
                        });
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      backgroundColor: HhColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopHeader(cart),
                    const SizedBox(height: 10),
                    _buildLocationSelector(),
                    const SizedBox(height: 16),
                    _buildHeroBanner(),
                    const SizedBox(height: 18),
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildCategoryRow(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            _buildProduceGridSliver(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: _buildRewardsBanner(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(CartController cart) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const HarvestHubLogo(fontSize: 22, iconSize: 22),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: HhColors.text.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HhColors.text.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
                color: HhColors.text,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new farm notifications.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HhColors.text.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HhColors.text.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.shopping_basket_outlined, size: 22),
                    color: HhColors.primary,
                    onPressed: widget.onOpenCart,
                  ),
                ),
                if (cart.quantity > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: HhColors.accent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${cart.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HhColors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return GestureDetector(
      onTap: _showLocationPicker,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Deliver to',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: HhColors.text.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _selectedLocation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: HhColors.text,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: HhColors.text,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 198,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HhColors.primary,
            Color(0xFF2E5A38),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HhColors.accent.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 10,
            bottom: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'packages/harvesthub_core/assets/images/farmer_slide_2.jpg',
                height: 165,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.agriculture_rounded,
                  size: 90,
                  color: HhColors.sageLight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: HhColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'DIRECT HARVEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: HhColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ORGANIC CROP\nBOX SALE',
                      style: TextStyle(
                        fontSize: 21,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Up to 25% off heirloom produce',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: HhColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Shop Fresh',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: HhColors.text.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          fontSize: 14.5,
          color: HhColors.text,
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search farm produce, herbs, grains...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: HhColors.text.withValues(alpha: 0.4),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: HhColors.primary,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18),
                      if (_hasActiveFilters)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: HhColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  color: HhColors.primary,
                  onPressed: _showFilterBottomSheet,
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return StreamBuilder<List<Category>>(
      stream: _categories,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _loadError(
              'Could not load categories.',
              () => setState(() {
                    _categories = _categoryService.streamActive();
                  }));
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final categories = snapshot.data!;

        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return _buildCategoryCircleItem(
                  title: 'All',
                  icon: Icons.grid_view_rounded,
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

              return _buildCategoryCircleItem(
                title: cat.name,
                icon: _getCategoryIcon(cat.name),
                isSelected: isSelected,
                imageUrl: cat.imageUrl,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = isSelected ? null : cat.id;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('veg')) return Icons.eco_rounded;
    if (lower.contains('fruit')) return Icons.apple_rounded;
    if (lower.contains('grain')) return Icons.grain_rounded;
    if (lower.contains('herb')) return Icons.local_florist_rounded;
    if (lower.contains('dairy') || lower.contains('honey')) {
      return Icons.egg_alt_rounded;
    }
    return Icons.spa_rounded;
  }

  Widget _buildCategoryCircleItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? HhColors.primary : Colors.white,
              border: Border.all(
                color: isSelected
                    ? HhColors.primary
                    : HhColors.text.withValues(alpha: 0.1),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? HhColors.primary.withValues(alpha: 0.28)
                      : HhColors.text.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? HhColors.bg : HhColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? HhColors.primary : HhColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Popular Harvest',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: HhColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HhColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'FRESH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: HhColors.primary,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryId = null;
              _searchController.clear();
              _searchQuery = '';
            });
          },
          child: const Row(
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HhColors.primary,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: HhColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProduceGridSliver() {
    return StreamBuilder<List<Product>>(
      stream: _products,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
              child: _loadError(
                  'Could not load products.',
                  () => setState(() {
                        _products = _productService.streamActiveProducts();
                      })));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: SproutLoadingIndicator(size: 100),
              ),
            ),
          );
        }

        final term = _searchQuery.trim().toLowerCase();
        List<Product> products = (snapshot.data ?? <Product>[])
            .where((p) =>
                (_selectedCategoryId == null ||
                    p.categoryId == _selectedCategoryId) &&
                (term.isEmpty ||
                    p.name.toLowerCase().contains(term) ||
                    p.farmerName.toLowerCase().contains(term) ||
                    p.description.toLowerCase().contains(term)))
            .toList();

        if (_onlyInStock) {
          products = products.where((p) => p.stockQty > 0).toList();
        }

        if (_minPrice != null) {
          products =
              products.where((p) => (p.price / 100) >= _minPrice!).toList();
        }

        if (_maxPrice != null) {
          products =
              products.where((p) => (p.price / 100) <= _maxPrice!).toList();
        }

        if (_sortBy == 'price_asc') {
          products.sort((a, b) => a.price.compareTo(b.price));
        } else if (_sortBy == 'price_desc') {
          products.sort((a, b) => b.price.compareTo(a.price));
        } else if (_sortBy == 'name') {
          products.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }

        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 54,
                    color: HhColors.text.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No produce found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing your search term or filter options.',
                    style: TextStyle(
                      fontSize: 13,
                      color: HhColors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return _buildProduceCard(product);
              },
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProduceCard(Product product) {
    final cart = context.read<CartController>();
    final bool isOutOfStock = product.stockQty <= 0;

    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOutOfStock
                ? HhColors.danger.withValues(alpha: 0.2)
                : HhColors.text.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: HhColors.text.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(19)),
                    child: ColorFiltered(
                      colorFilter: isOutOfStock
                          ? const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            )
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: HhColors.sageLight.withValues(alpha: 0.5),
                          child: const Center(
                            child: Icon(
                              Icons.agriculture_rounded,
                              color: HhColors.primary,
                              size: 32,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: HhColors.sageLight,
                          child: const Icon(
                            Icons.eco_rounded,
                            color: HhColors.primary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? HhColors.danger
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'OUT OF STOCK'
                            : (product.stockQty <= 5 ? 'LOW STOCK' : 'ORGANIC'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isOutOfStock
                              ? Colors.white
                              : (product.stockQty <= 5
                                  ? HhColors.danger
                                  : HhColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.farmerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: HhColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: HhColors.text,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${(product.price / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: HhColors.text,
                              ),
                            ),
                            Text(
                              '/ ${product.unit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: HhColors.text.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: isOutOfStock
                              ? () {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${product.name} is currently out of stock.'),
                                      backgroundColor: HhColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              : () {
                                  cart.addToCart(product, 1);
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Added ${product.name} to basket!'),
                                      duration:
                                          const Duration(milliseconds: 1400),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOutOfStock
                                  ? HhColors.muted.withValues(alpha: 0.3)
                                  : HhColors.primary,
                              boxShadow: isOutOfStock
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: HhColors.primary
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Icon(
                              isOutOfStock
                                  ? Icons.block_rounded
                                  : Icons.add_rounded,
                              color:
                                  isOutOfStock ? HhColors.muted : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: HhColors.text.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HhColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: HhColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harvest Club Rewards',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Earn points on every direct trade order to unlock free farm deliveries!',
                  style: TextStyle(
                    fontSize: 12,
                    color: HhColors.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Harvest Club membership active!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.primary,
              foregroundColor: HhColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailSheet extends StatefulWidget {
  final Product product;

  const ProductDetailSheet({super.key, required this.product});

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.product.stockQty > 0 ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.read<CartController>();
    final bool isOutOfStock = product.stockQty <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: HhColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: HhColors.text.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColorFiltered(
                colorFilter: isOutOfStock
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: HhColors.sageLight,
                    child: const Icon(
                      Icons.agriculture_rounded,
                      size: 64,
                      color: HhColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: HhColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              product.farmerName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: HhColors.primary,
                              ),
                            ),
                          ),
                          if (isOutOfStock) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HhColors.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: HhColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(product.price / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: HhColors.primary,
                      ),
                    ),
                    Text(
                      '/ ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: HhColors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              product.description,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: HhColors.text.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isOutOfStock
                  ? 'Availability: Currently out of stock'
                  : 'Availability: ${product.stockQty} ${product.unit} in stock',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOutOfStock ? HhColors.danger : HhColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: HhColors.text.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        color: HhColors.primary,
                        onPressed: (!isOutOfStock && _quantity > 1)
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        color: HhColors.primary,
                        onPressed:
                            (!isOutOfStock && _quantity < product.stockQty)
                                ? () => setState(() => _quantity++)
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isOutOfStock
                        ? null
                        : () {
                            cart.addToCart(product, _quantity);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Added $_quantity ${product.unit} of ${product.name} to basket!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: HhColors.bg,
                      disabledBackgroundColor:
                          HhColors.muted.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'Out of Stock'
                          : 'Add to Basket • \$${((product.price * _quantity) / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
