import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedCategoryId = 'ALL';
  String _selectedSort = 'Newest';
  RangeValues? _priceRange;

  static const List<Category> _defaultCategories = [
    Category(id: 'vegetables', name: 'Vegetables', imageUrl: '', sortOrder: 1, isActive: true),
    Category(id: 'fruits', name: 'Fruit', imageUrl: '', sortOrder: 2, isActive: true),
    Category(id: 'dairy', name: 'Dairy & eggs', imageUrl: '', sortOrder: 3, isActive: true),
    Category(id: 'grains', name: 'Grains', imageUrl: '', sortOrder: 4, isActive: true),
    Category(id: 'herbs', name: 'Herbs', imageUrl: '', sortOrder: 5, isActive: true),
    Category(id: 'organic', name: 'Organic', imageUrl: '', sortOrder: 6, isActive: true),
  ];

  late final Stream<QuerySnapshot> _productsStream;
  StreamSubscription<List<Category>>? _catSub;
  List<Category> _categories = _defaultCategories;
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _categoryNames = {for (final c in _categories) c.id: c.name};
    _productsStream =
        FirebaseFirestore.instance.collection('products').snapshots();
    _catSub = CategoryService().streamAll().listen((categories) {
      if (mounted && categories.isNotEmpty) {
        final mergedMap = {for (final c in _defaultCategories) c.id: c};
        for (final c in categories) {
          mergedMap[c.id] = c;
        }
        final mergedList = mergedMap.values.toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        setState(() {
          _categories = mergedList;
          _categoryNames = {for (final c in mergedList) c.id: c.name};
        });
      }
    });
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleProductStatus(
      String productId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
        'isActive': !currentStatus,
        'updatedAt': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus ? 'Product activated' : 'Product deactivated',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Platform Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: HhColors.text.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by product or farmer name...',
                  prefixIcon: const Icon(Icons.search, color: HhColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: HhColors.text.withValues(alpha: 0.12),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 3,
                        icon: const Icon(Icons.arrow_drop_down,
                            size: 18, color: HhColors.primary),
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'All Status',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Active',
                            child: Text(
                              'Active',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Inactive',
                            child: Text(
                              'Inactive',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatus = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: HhColors.text.withValues(alpha: 0.12),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedCategoryId == 'ALL' ||
                                _categories
                                    .any((c) => c.id == _selectedCategoryId))
                            ? _selectedCategoryId
                            : 'ALL',
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        menuMaxHeight: 300,
                        elevation: 3,
                        icon: const Icon(Icons.arrow_drop_down,
                            size: 18, color: HhColors.primary),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'ALL',
                            child: Text(
                              'All Categories',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ..._categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(
                                categoryDisplayName(cat.id, cat.name),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategoryId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: HhColors.text.withValues(alpha: 0.12),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      tooltip: 'Sort Products',
                      initialValue: _selectedSort,
                      onSelected: (val) {
                        setState(() {
                          _selectedSort = val;
                        });
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.sort,
                              size: 16, color: HhColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _selectedSort == 'Newest'
                                  ? 'Sort'
                                  : _selectedSort,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HhColors.primary,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              size: 16, color: HhColors.primary),
                        ],
                      ),
                      itemBuilder: (context) => [
                        'Newest',
                        'Category (A-Z)',
                        'Name (A-Z)',
                        'Price: Low to High',
                        'Price: High to Low',
                      ].map((sortOption) {
                        return PopupMenuItem(
                          value: sortOption,
                          child: Row(
                            children: [
                              if (_selectedSort == sortOption)
                                const Icon(Icons.check,
                                    size: 16, color: HhColors.primary)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(sortOption),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SproutLoadingIndicator(size: 100),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final allProducts = docs.map((doc) {
                  return Product.fromMap(
                    doc.data() as Map<String, dynamic>,
                    id: doc.id,
                  );
                }).toList();

                double maxFound = 0.0;
                for (final p in allProducts) {
                  final d = p.price / 100.0;
                  if (d > maxFound) maxFound = d;
                  if (p.categoryId.isNotEmpty && !_categoryNames.containsKey(p.categoryId)) {
                    _categoryNames[p.categoryId] =
                        categoryDisplayName(p.categoryId, p.categoryId);
                  }
                }
                final minBound = 0.0;
                final safeMaxBound =
                    maxFound > 0 ? (maxFound + 1.0).ceilToDouble() : 50.0;
                final start = (_priceRange?.start ?? minBound)
                    .clamp(minBound, safeMaxBound);
                final end = (_priceRange?.end ?? safeMaxBound)
                    .clamp(start, safeMaxBound);
                final currentRange = RangeValues(start, end);

                final products = allProducts.where((p) {
                  final matchesSearch =
                      p.name.toLowerCase().contains(_searchQuery) ||
                          p.farmerName.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_selectedStatus == 'Active' && !p.isActive) return false;
                  if (_selectedStatus == 'Inactive' && p.isActive) return false;

                  if (_selectedCategoryId != 'ALL' &&
                      p.categoryId != _selectedCategoryId) {
                    return false;
                  }

                  final priceInDollars = p.price / 100.0;
                  if (priceInDollars < currentRange.start ||
                      priceInDollars > currentRange.end) {
                    return false;
                  }

                  return true;
                }).toList();

                switch (_selectedSort) {
                  case 'Category (A-Z)':
                    products.sort((a, b) {
                      final catA =
                          _categoryNames[a.categoryId] ?? a.categoryId;
                      final catB =
                          _categoryNames[b.categoryId] ?? b.categoryId;
                      final cmp = catA
                          .toLowerCase()
                          .compareTo(catB.toLowerCase());
                      if (cmp != 0) return cmp;
                      return a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase());
                    });
                    break;
                  case 'Name (A-Z)':
                    products.sort((a, b) => a.name
                        .toLowerCase()
                        .compareTo(b.name.toLowerCase()));
                    break;
                  case 'Price: Low to High':
                    products.sort((a, b) => a.price.compareTo(b.price));
                    break;
                  case 'Price: High to Low':
                    products.sort((a, b) => b.price.compareTo(a.price));
                    break;
                  case 'Newest':
                  default:
                    products
                        .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    break;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: HhColors.text.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.tune,
                                        size: 16, color: HhColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'Price Range',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: HhColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '\$${currentRange.start.toStringAsFixed(2)} - \$${currentRange.end.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: HhColors.primary,
                                      ),
                                    ),
                                    if (_priceRange != null) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _priceRange = null;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                          color: HhColors.muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            RangeSlider(
                              values: currentRange,
                              min: minBound,
                              max: safeMaxBound,
                              divisions: ((safeMaxBound - minBound) * 2)
                                  .round()
                                  .clamp(10, 100),
                              activeColor: HhColors.primary,
                              inactiveColor:
                                  HhColors.primary.withValues(alpha: 0.15),
                              labels: RangeLabels(
                                '\$${currentRange.start.toStringAsFixed(2)}',
                                '\$${currentRange.end.toStringAsFixed(2)}',
                              ),
                              onChanged: (newRange) {
                                setState(() {
                                  _priceRange = newRange;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: products.isEmpty
                          ? const Center(
                              child: Text(
                                'No products found matching filters.',
                                style: TextStyle(color: HhColors.muted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: products.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = products[index];
                                return _ProductCard(
                                  product: item,
                                  categoryName: categoryDisplayName(
                                      item.categoryId,
                                      _categoryNames[item.categoryId] ??
                                          item.categoryId),
                                  onToggleStatus: () =>
                                      _toggleProductStatus(
                                          item.id, item.isActive),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onToggleStatus;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HhColors.text.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ProductImage(product.imageUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Farm: ${product.farmerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: HhColors.text.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                      if (categoryName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: HhColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HhColors.primary,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stockQty > 0
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Stock: ${product.stockQty}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.stockQty > 0
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: product.isActive,
                  activeThumbColor: HhColors.primary,
                  onChanged: (_) => onToggleStatus(),
                ),
                Text(
                  product.isActive ? 'Active' : 'Hidden',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: product.isActive ? HhColors.primary : HhColors.muted,
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
