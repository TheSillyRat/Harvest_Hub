import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';

class ProductReviewDetailsScreen extends StatefulWidget {
  final Product product;
  final String? categoryName;
  final double? avgRating;
  final int? reviewCount;

  const ProductReviewDetailsScreen({
    super.key,
    required this.product,
    this.categoryName,
    this.avgRating,
    this.reviewCount,
  });

  @override
  State<ProductReviewDetailsScreen> createState() =>
      _ProductReviewDetailsScreenState();
}

class _ProductReviewDetailsScreenState
    extends State<ProductReviewDetailsScreen> {
  final FarmerReviewService _reviewService = FarmerReviewService();
  int? _selectedStarFilter; // null = all, 1..5

  @override
  Widget build(BuildContext context) {
    final effectiveAvg = widget.avgRating ?? widget.product.rating;
    final effectiveCount = widget.reviewCount ?? widget.product.reviewCount;

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Customer Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: HhColors.text,
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Product Summary Header Card
          SliverToBoxAdapter(
            child: _buildProductHeader(effectiveAvg, effectiveCount),
          ),

          // 2. Star Filter Chips
          SliverToBoxAdapter(
            child: _buildStarFilterBar(),
          ),

          // 3. Customer Reviews Stream List (Strictly Read-Only)
          StreamBuilder<List<FarmerReviewItem>>(
            stream: _reviewService.streamProductReviews(
              productId: widget.product.id,
              starFilter: _selectedStarFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: HhColors.primary),
                  ),
                );
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = reviews[index];
                      return _buildReviewItem(item);
                    },
                    childCount: reviews.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(double avgRating, int reviewCount) {
    final isOutOfStock = widget.product.stockQty <= 0;
    final safeAvg = avgRating > 0 ? avgRating : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Thumbnail, Details & Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: ProductImage(
                    widget.product.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.categoryName != null &&
                        widget.categoryName!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: HhColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.categoryName!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: HhColors.primary,
                          ),
                        ),
                      ),
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vnd(widget.product.price)} / ${widget.product.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HhColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOutOfStock
                          ? 'Out of Stock'
                          : 'Stock: ${widget.product.stockQty} ${widget.product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOutOfStock ? HhColors.danger : HhColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          // Row 2: Large Rating Score & Overview
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        safeAvg > 0 ? safeAvg.toStringAsFixed(1) : '0.0',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        ' / 5.0',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HhColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return Icon(
                        safeAvg >= starVal
                            ? Icons.star_rounded
                            : (safeAvg >= starVal - 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded),
                        size: 20,
                        color: const Color(0xFFF59E0B),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reviewCount > 0
                        ? '$reviewCount verified review${reviewCount > 1 ? 's' : ''}'
                        : 'Chưa có đánh giá nào',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: HhColors.text.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: HhColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        color: HhColors.primary, size: 24),
                    const SizedBox(height: 4),
                    const Text(
                      'Farmer View',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: HhColors.primary,
                      ),
                    ),
                    Text(
                      'Read-Only Feed',
                      style: TextStyle(
                        fontSize: 10,
                        color: HhColors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarFilterBar() {
    return Container(
      height: 42,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip(label: 'All Reviews', starVal: null),
          _filterChip(label: '5 ★', starVal: 5),
          _filterChip(label: '4 ★', starVal: 4),
          _filterChip(label: '3 ★', starVal: 3),
          _filterChip(label: '2 ★', starVal: 2),
          _filterChip(label: '1 ★', starVal: 1),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required int? starVal}) {
    final isSelected = _selectedStarFilter == starVal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStarFilter = isSelected ? null : starVal;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: HhColors.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: isSelected ? HhColors.primary : HhColors.text,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? HhColors.primary : Colors.black12,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildReviewItem(FarmerReviewItem item) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header: Avatar, Name, Verified Badge, Stars, Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: HhColors.primary.withValues(alpha: 0.12),
                backgroundImage: item.authorAvatar.isNotEmpty
                    ? NetworkImage(item.authorAvatar)
                    : null,
                child: item.authorAvatar.isEmpty
                    ? Text(
                        item.authorName.isNotEmpty
                            ? item.authorName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: HhColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 11, color: Color(0xFF2E7D32)),
                              SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: HhColors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Stars badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      item.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comment body
          if (item.comment.trim().isNotEmpty)
            Text(
              item.comment.trim(),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: HhColors.text.withValues(alpha: 0.88),
              ),
            )
          else
            Text(
              'No written feedback provided.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: HhColors.text.withValues(alpha: 0.45),
              ),
            ),

          // Tags (if any)
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: HhColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: HhColors.text.withValues(alpha: 0.7),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.rate_review_outlined,
                size: 56,
                color: HhColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có đánh giá nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HhColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStarFilter != null
                  ? 'Không tìm thấy đánh giá nào với mức $_selectedStarFilter sao.'
                  : 'Sản phẩm này hiện tại chưa có phản hồi nào từ khách hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: HhColors.text.withValues(alpha: 0.65),
              ),
            ),
            if (_selectedStarFilter != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  setState(() => _selectedStarFilter = null);
                },
                child: const Text('Xem tất cả đánh giá'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
