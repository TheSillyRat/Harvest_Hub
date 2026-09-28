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
  bool _showSearch = false;

  static const List<Category> _defaultCategories = [
    Category(
        id: 'vegetables',
        name: 'Vegetables',
        imageUrl: '',
        sortOrder: 1,
        isActive: true),
    Category(
        id: 'fruits',
        name: 'Fruit',
        imageUrl: '',
        sortOrder: 2,
        isActive: true),
    Category(
        id: 'dairy',
        name: 'Dairy & eggs',
        imageUrl: '',
        sortOrder: 3,
        isActive: true),
    Category(
        id: 'grains',
        name: 'Grains',
        imageUrl: '',
        sortOrder: 4,
        isActive: true),
    Category(
        id: 'herbs', name: 'Herbs', imageUrl: '', sortOrder: 5, isActive: true),
    Category(
        id: 'organic',
        name: 'Organic',
        imageUrl: '',
        sortOrder: 6,
        isActive: true),
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

  Future<String?> _showDeactivationDialog(Product product) async {
    String selectedReason = 'Sai danh mục';
    final customCtrl = TextEditingController();

    const presetTags = [
      'Sai danh mục',
      'Sản phẩm không hợp lệ',
      'Giá bất thường',
      'Thông tin không chính xác',
      'Vi phạm tiêu chuẩn chất lượng',
      'Lý do khác...',
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isOther = selectedReason == 'Lý do khác...';
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: HhColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khóa sản phẩm: ${product.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn nhanh lý do vi phạm để khóa sản phẩm. Hệ thống sẽ gửi thông báo đến nông dân ngay lập tức.',
                      style: TextStyle(fontSize: 13, color: HhColors.muted),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tag lý do có sẵn:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetTags.map((tag) {
                        final isSelected = selectedReason == tag;
                        return ChoiceChip(
                          label: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isSelected ? Colors.white : HhColors.text,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: HhColors.danger,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? HhColors.danger
                                  : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDlgState(() => selectedReason = tag);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (isOther) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: customCtrl,
                        decoration: InputDecoration(
                          hintText: 'Nhập chi tiết lý do khóa sản phẩm...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HhColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final finalReason = isOther
                        ? (customCtrl.text.trim().isNotEmpty
                            ? customCtrl.text.trim()
                            : 'Vi phạm quy định sản phẩm')
                        : selectedReason;
                    Navigator.pop(ctx, finalReason);
                  },
                  child: const Text('Khóa sản phẩm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleProductStatus(Product product) async {
    String? reason;
    if (product.isActive) {
      reason = await _showDeactivationDialog(product);
      if (reason == null) return;
    }

    try {
      final isCategoryViolation = reason == 'Sai danh mục' ||
          (reason != null && reason.toLowerCase().contains('sai danh muc'));
      final finalReason = isCategoryViolation ? 'SAI_DANH_MUC_DANG_KY' : reason;

      final updateData = <String, dynamic>{
        'isActive': !product.isActive,
        'updatedAt': Timestamp.now(),
      };

      if (product.isActive) {
        updateData['deactivatedByAdmin'] = true;
        updateData['deactivationReason'] = finalReason;
        updateData['deactivatedAt'] = Timestamp.now();

        if (isCategoryViolation && product.farmerId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance.runTransaction((tx) async {
              final userRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(product.farmerId);
              final farmerRef = FirebaseFirestore.instance
                  .collection('farmers')
                  .doc(product.farmerId);
              final userSnap = await tx.get(userRef);
              final strikes =
                  ((userSnap.data()?['violationStrikes'] as num?)?.toInt() ??
                          0) +
                      1;
              final updates = <String, dynamic>{
                'violationStrikes': strikes,
                'violation_strikes': strikes,
                if (strikes >= 3) ...{
                  'status': 'banned',
                  'isActive': false,
                  'deactivationReason': 'Vi pham dang sai danh muc qua 3 lan',
                }
              };
              tx.update(userRef, updates);
              tx.set(farmerRef, updates, SetOptions(merge: true));
            });
          } catch (_) {}
        }
      } else {
        updateData['deactivatedByAdmin'] = false;
        updateData['deactivationReason'] = null;
        updateData['deactivatedAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update(updateData);

      if (product.farmerId.isNotEmpty) {
        if (product.isActive) {
          await NotificationService().sendNotification(
            userId: product.farmerId,
            title: 'Product Deactivated by Admin',
            body: 'Your product "${product.name}" was deactivated: $reason',
            type: 'PRODUCT_DEACTIVATED',
            targetId: product.id,
          );
        } else {
          await NotificationService().sendNotification(
            userId: product.farmerId,
            title: 'Product Re-activated',
            body:
                'Your product "${product.name}" has been reactivated and is now visible on the marketplace.',
            type: 'PRODUCT_ACTIVATED',
            targetId: product.id,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              product.isActive ? 'Product deactivated' : 'Product activated',
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
                  if (p.categoryId.isNotEmpty &&
                      !_categoryNames.containsKey(p.categoryId)) {
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
                      final catA = _categoryNames[a.categoryId] ?? a.categoryId;
                      final catB = _categoryNames[b.categoryId] ?? b.categoryId;
                      final cmp =
                          catA.toLowerCase().compareTo(catB.toLowerCase());
                      if (cmp != 0) return cmp;
                      return a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase());
                    });
                    break;
                  case 'Name (A-Z)':
                    products.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    break;
                  case 'Price: Low to High':
                    products.sort((a, b) => a.price.compareTo(b.price));
                    break;
                  case 'Price: High to Low':
                    products.sort((a, b) => b.price.compareTo(a.price));
                    break;
                  case 'Newest':
                  default:
                    products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    break;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  _showSearch ? HhColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showSearch
                                    ? HhColors.primary
                                    : HhColors.text.withValues(alpha: 0.12),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _showSearch ? Icons.tune : Icons.search,
                                size: 20,
                                color: _showSearch
                                    ? Colors.white
                                    : HhColors.primary,
                              ),
                              tooltip: _showSearch
                                  ? 'Show Price Range'
                                  : 'Search Products',
                              onPressed: () {
                                setState(() {
                                  _showSearch = !_showSearch;
                                  if (!_showSearch) {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _showSearch
                                  ? Container(
                                      key: const ValueKey('search'),
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HhColors.text
                                              .withValues(alpha: 0.12),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        autofocus: true,
                                        style: const TextStyle(fontSize: 13),
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery =
                                                val.trim().toLowerCase();
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Product or farmer name...',
                                          hintStyle:
                                              const TextStyle(fontSize: 13),
                                          prefixIcon: const Icon(Icons.search,
                                              size: 18,
                                              color: HhColors.primary),
                                          suffixIcon: _searchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear,
                                                      size: 16),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {
                                                      _searchQuery = '';
                                                    });
                                                  },
                                                )
                                              : null,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 10),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      key: const ValueKey('price'),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HhColors.text
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '\$${currentRange.start.toStringAsFixed(2)} – \$${currentRange.end.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: HhColors.primary,
                                                ),
                                              ),
                                              if (_priceRange != null)
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _priceRange = null;
                                                    });
                                                  },
                                                  child: const Icon(
                                                    Icons.refresh,
                                                    size: 14,
                                                    color: HhColors.muted,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              trackHeight: 3,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                      enabledThumbRadius: 6),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                      overlayRadius: 12),
                                            ),
                                            child: RangeSlider(
                                              values: currentRange,
                                              min: minBound,
                                              max: safeMaxBound,
                                              divisions:
                                                  ((safeMaxBound - minBound) *
                                                          2)
                                                      .round()
                                                      .clamp(10, 100),
                                              activeColor: HhColors.primary,
                                              inactiveColor: HhColors.primary
                                                  .withValues(alpha: 0.15),
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
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
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
                                      _toggleProductStatus(item),
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
