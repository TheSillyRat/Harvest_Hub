import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../location/customer_location.dart';
import '../widgets/save_button.dart';
import 'product_detail_sections.dart';
import 'product_detail_sheet.dart';

class FarmerDetailScreen extends StatefulWidget {
  final String farmerId;
  final String farmerName;
  final CustomerLocation location;
  final ProductService? productService;

  const FarmerDetailScreen({
    super.key,
    required this.farmerId,
    required this.farmerName,
    required this.location,
    this.productService,
  });

  @override
  State<FarmerDetailScreen> createState() => _FarmerDetailScreenState();
}

class _FarmerDetailScreenState extends State<FarmerDetailScreen> {
  late final ProductService _productService;
  late final ProductDetailsData _detailsData;
  late Stream<List<Product>> _productsStream;
  late Stream<Map<String, dynamic>?> _storeStream;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _productService = widget.productService ?? ProductService();
    _detailsData = ProductDetailsData();
    _productsStream = _productService
        .streamProductsByFarmer(widget.farmerId)
        .asBroadcastStream();
    _storeStream = _detailsData.store(widget.farmerId).asBroadcastStream();
  }

  void _openProductDetail(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(
        product: product,
        categoryName: product.categoryId,
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
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        backgroundColor: HhColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: HhColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: HhColors.text, size: 22),
            onPressed: () {
              TopToast.show(context, 'Farm link copied to clipboard!');
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SaveButton(kind: SavedKind.farmer, itemId: widget.farmerId),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _storeStream,
        builder: (context, storeSnap) {
          final store = storeSnap.data ?? {};
          final farmName = (store['businessName'] as String?)?.trim().isNotEmpty == true
              ? (store['businessName'] as String).trim()
              : widget.farmerName;
          final area = (store['area'] as String?)?.trim().isNotEmpty == true
              ? (store['area'] as String).trim()
              : (store['address'] as String?)?.trim() ?? 'Local Organic Farm';
          final phone = (store['phone'] as String?)?.trim().isNotEmpty == true
              ? (store['phone'] as String).trim()
              : '02837381816';
          final rating = (store['rating'] as num?)?.toDouble() ?? 4.8;
          final count = (store['reviewCount'] as num?)?.toInt() ?? 12;
          final avatar = (store['avatarUrl'] as String?)?.trim().isNotEmpty == true
              ? (store['avatarUrl'] as String).trim()
              : (store['imageUrl'] as String?)?.trim() ?? '';

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              width: 76,
                              height: 76,
                              color: HhColors.sageLight,
                              child: detailPhoto(avatar),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  farmName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: HhColors.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  area,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: HhColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '★ ${rating.toStringAsFixed(1)} · $count reviews',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: HhColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: SaveButton(
                                kind: SavedKind.farmer,
                                itemId: widget.farmerId,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => callFarmerPhone(
                                  context,
                                  phone,
                                  farmerName: farmName,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: HhColors.text,
                                  side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                                label: const Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildTabItem('Products', 0),
                          const SizedBox(width: 20),
                          _buildTabItem('About', 1),
                          const SizedBox(width: 20),
                          _buildTabItem('Reviews', 2),
                        ],
                      ),
                      const Divider(height: 1, color: Colors.black12),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (_selectedTab == 0)
                StreamBuilder<List<Product>>(
                  stream: _productsStream,
                  builder: (context, snapshot) {
                    final products = snapshot.data ??
                        (snapshot.hasError
                            ? ProductService.getFallbackProducts()
                                .where((p) => p.farmerId == widget.farmerId || widget.farmerId.isEmpty)
                                .toList()
                            : []);

                    if (products.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No products listed by this farm yet.',
                              style: TextStyle(color: HhColors.muted),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            return _buildProductArticleItem(product);
                          },
                          childCount: products.length,
                        ),
                      ),
                    );
                  },
                )
              else if (_selectedTab == 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Farm Description',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (store['description'] as String?)?.isNotEmpty == true
                              ? (store['description'] as String)
                              : 'Welcome to $farmName! We produce fresh, sustainable organic crops harvested directly from our fields with care.',
                          style: const TextStyle(fontSize: 13.5, height: 1.5, color: HhColors.text),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pickup Address',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: HhColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (store['address'] as String?)?.isNotEmpty == true
                                    ? (store['address'] as String)
                                    : 'Da Lat Organic Agricultural Zone, Vietnam',
                                style: const TextStyle(fontSize: 13.5, color: HhColors.text),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '★ ${rating.toStringAsFixed(1)} / 5.0 Rating',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HhColors.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Based on $count customer reviews',
                          style: const TextStyle(fontSize: 13, color: HhColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? HhColors.text : HhColors.muted,
              ),
            ),
          ),
          Container(
            height: 2.5,
            width: 40,
            color: active ? HhColors.text : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildProductArticleItem(Product product) {
    final isOutOfStock = product.stockQty <= 0;
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: HhColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description.isNotEmpty
                          ? product.description
                          : 'Fresh harvest from ${product.farmerName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: HhColors.text.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? HhColors.danger.withValues(alpha: 0.12) : HhColors.sageLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOutOfStock ? 'OUT OF STOCK' : '${product.stockQty} in stock',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock ? HhColors.danger : HhColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: isOutOfStock ? null : () => _quickAddToCart(product),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isOutOfStock ? Colors.grey.shade300 : HhColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 92,
                height: 92,
                child: detailPhoto(product.imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
