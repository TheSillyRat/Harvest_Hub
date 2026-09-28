import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import 'product_review_details_screen.dart';

class ReviewProductsScreen extends StatefulWidget {
  final String? initialProductId;

  const ReviewProductsScreen({super.key, this.initialProductId});

  @override
  State<ReviewProductsScreen> createState() => _ReviewProductsScreenState();
}

class _ReviewProductsScreenState extends State<ReviewProductsScreen> {
  final FarmerReviewService _reviewService = FarmerReviewService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategoryId;
  int? _selectedStar; // null = all, 1..5

  List<FarmerProductReviewSummary> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final farmer = context.read<AuthController>().user;
    if (farmer == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final results = await _reviewService.getFarmerReviewedProducts(
      farmerId: farmer.uid,
      searchQuery: _searchQuery,
      categoryId: _selectedCategoryId,
      filterStar: _selectedStar,
    );

    if (mounted) {
      setState(() {
        _products = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    _loadProducts();
  }

  void _selectCategory(String? catId) {
    setState(() {
      _selectedCategoryId = catId;
    });
    _loadProducts();
  }

  void _selectStar(int? star) {
    setState(() {
      _selectedStar = _selectedStar == star ? null : star;
    });
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Product Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: HhColors.text,
      ),
      body: Column(
        children: [
          // 1. Search Bar & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: HhColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HhColors.text.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search products by name...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: HhColors.text.withValues(alpha: 0.45),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: HhColors.muted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Star Rating Filter Bar
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildStarChip('All Ratings', null),
                      _buildStarChip('5 ★', 5),
                      _buildStarChip('4 ★', 4),
                      _buildStarChip('3 ★', 3),
                      _buildStarChip('2 ★', 2),
                      _buildStarChip('1 ★', 1),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Dynamic Categories Filter Chips
          StreamBuilder<List<Category>>(
            stream: CategoryService().streamActive(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) return const SizedBox.shrink();

              return Container(
                height: 42,
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 6),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = _selectedCategoryId == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Categories'),
                          selected: isSelected,
                          onSelected: (_) => _selectCategory(null),
                          selectedColor:
                              HhColors.primary.withValues(alpha: 0.15),
                          backgroundColor: HhColors.bg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? HhColors.primary
                                : HhColors.text,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? HhColors.primary
                                  : Colors.black12,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }

                    final cat = categories[index - 1];
                    final isSelected = _selectedCategoryId == cat.id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => _selectCategory(cat.id),
                        selectedColor:
                            HhColors.primary.withValues(alpha: 0.15),
                        backgroundColor: HhColors.bg,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                              isSelected ? HhColors.primary : HhColors.text,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? HhColors.primary
                                : Colors.black12,
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const Divider(height: 1, thickness: 1),

          // 3. Products List View (Reusing Customer Card Structure)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: HhColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    color: HhColors.primary,
                    child: _products.isEmpty
                        ? _buildEmptyProductState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final item = _products[index];
                              return _buildProductReviewCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarChip(String label, int? star) {
    final isSelected = _selectedStar == star;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _selectStar(star),
        backgroundColor: HhColors.bg,
        selectedColor: const Color(0xFFFEF3C7),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFFB45309) : HhColors.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? const Color(0xFFF59E0B) : Colors.black12,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildProductReviewCard(FarmerProductReviewSummary item) {
    final product = item.product;
    final isOutOfStock = product.stockQty <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductReviewDetailsScreen(
                  product: product,
                  categoryName: item.categoryName,
                  avgRating: item.avgRating,
                  reviewCount: item.reviewCount,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: ProductImage(
                          product.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (isOutOfStock)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: HhColors.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Product Details & Review Metrics
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: HhColors.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.categoryName,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: HhColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Name
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price & Unit
                      Text(
                        '${vnd(product.price)} / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: HhColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Stock & Sold Counts
                      Row(
                        children: [
                          Text(
                            isOutOfStock
                                ? 'Out of stock'
                                : 'Stock: ${product.stockQty} ${product.unit}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isOutOfStock
                                  ? HhColors.danger
                                  : HhColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '•  Sold: ${item.soldCount}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: HhColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // AVG Rating & Review Count (Mandatory Requirement)
                      Row(
                        children: [
                          if (item.hasReviews) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${item.reviewCount} ${item.reviewCount == 1 ? 'review' : 'reviews'})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: HhColors.text.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: HhColors.bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_outline_rounded,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'No reviews yet (0.0★)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: HhColors.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProductState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HhColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 52,
                color: HhColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Products Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: HhColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No products match your current search or selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: HhColors.text.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
