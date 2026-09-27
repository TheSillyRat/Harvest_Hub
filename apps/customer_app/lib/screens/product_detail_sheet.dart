import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../location/nearby_stores.dart';
import 'product_detail_sections.dart';
import '../widgets/save_button.dart';

class ProductDetailSheet extends StatefulWidget {
  final Product product;
  final String? categoryName;
  final ProductDetailsData? detailsData;
  final String? storeName;
  final double? storeRating;
  final double? distanceKm;
  final bool showDistance;
  final ProductService? productService;

  const ProductDetailSheet(
      {super.key,
      required this.product,
      this.categoryName,
      this.detailsData,
      this.storeName,
      this.storeRating,
      this.productService,
      this.distanceKm,
      this.showDistance = false});

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  static const int maxPerOrder = 10;
  late String _selectedUnit;
  int _quantity = 1;
  int _selectedGrams = 500;
  bool _adding = false;
  late final ProductService _service;
  late final ProductDetailsData _data;
  late Stream<Product?> _product;

  @override
  void initState() {
    super.initState();
    _service = widget.productService ?? ProductService();
    _data = widget.detailsData ?? ProductDetailsData();
    _product = _service.watch(widget.product.id);
    _selectedUnit = widget.product.unit.toLowerCase() == 'g' ? 'g' : 'kg';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: StreamBuilder<Product?>(
          stream: _product,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message('Could not load this product.', retry: true);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()));
            }
            final product = snapshot.data;
            if (product == null || !product.isActive) {
              return _message('This product is no longer available.');
            }
            return _buildDetails(context, product);
          },
        ),
      );

  Widget _message(String text, {bool retry = false}) => SafeArea(
        child: Container(
            width: double.infinity,
            color: HhColors.bg,
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(text),
              if (retry)
                TextButton(
                    onPressed: () => setState(() {
                          _product = _service.watch(widget.product.id);
                        }),
                    child: const Text('Try again')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ])),
      );

  Future<void> _addToCart(
    Product product,
    int quantity, {
    required String selectedUnit,
    required int customPrice,
  }) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await context.read<CartController>().addToCart(
            product,
            quantity,
            selectedUnit,
            customPrice,
          );
      if (!mounted) return;
      final unitDisplay = selectedUnit == 'kg' ? '$quantity kg' : selectedUnit;
      TopToast.show(context, 'Added $unitDisplay of ${product.name} to basket!');
    } catch (_) {
      if (mounted) {
        TopToast.show(context, 'Could not add this product. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _buildDetails(BuildContext context, Product product) {
    final isOutOfStock = product.stockQty <= 0;
    final maxAllowedKg = product.stockQty.clamp(0, maxPerOrder);
    final quantity = isOutOfStock ? 0 : _quantity.clamp(1, maxAllowedKg > 0 ? maxAllowedKg : 1);
    final images = product.galleryImages;
    final topPadding = MediaQuery.of(context).padding.top;
    final supportsGramChoice = product.unit.toLowerCase() == 'kg' || product.unit.toLowerCase() == 'g';

    final computedGramPrice = ((product.price * _selectedGrams) / 1000).round();
    final finalPriceCents = _selectedUnit == 'g' ? computedGramPrice : (product.price * quantity);
    final isAtKgLimit = quantity >= product.stockQty || quantity >= maxPerOrder;

    return Container(
      margin: EdgeInsets.only(top: topPadding + 16),
      decoration: const BoxDecoration(
          color: HhColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                const Expanded(
                    child: Text('Product details',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16))),
                SaveButton(kind: SavedKind.product, itemId: product.id),
                IconButton(
                    tooltip: 'Close product details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              ProductGallery(key: ValueKey(images.join('|')), images: images),
              const SizedBox(height: 18),
              Text(
                  '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: HhColors.primary)),
              const SizedBox(height: 8),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: HhColors.text)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Chip(
                    label: Text(widget.categoryName ?? product.categoryId),
                    backgroundColor: HhColors.sageLight,
                    side: BorderSide.none),
                Chip(label: Text(product.unit), side: BorderSide.none),
              ]),
              if (widget.showDistance)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(distanceLabel(widget.distanceKm),
                      style: const TextStyle(color: HhColors.primary)),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: HhColors.primary.withValues(alpha: .12))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (supportsGramChoice) ...[
                        Row(
                          children: [
                            const Text(
                              'Select Unit:',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: HhColors.text,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: HhColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => setState(() => _selectedUnit = 'kg'),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _selectedUnit == 'kg' ? HhColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        'Kilogram (kg)',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedUnit == 'kg' ? Colors.white : HhColors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _selectedUnit = 'g'),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _selectedUnit == 'g' ? HhColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        'Grams (g)',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedUnit == 'g' ? Colors.white : HhColors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                          isOutOfStock
                              ? 'Currently unavailable'
                              : '${product.stockQty} ${product.unit} in stock',
                          style: const TextStyle(
                              fontSize: 12, color: HhColors.muted)),
                      const SizedBox(height: 8),
                      if (_selectedUnit != 'g') ...[
                        Row(children: [
                          const Expanded(
                              child: Text('Quantity (kg)',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600))),
                          IconButton(
                              tooltip: 'Decrease quantity',
                              icon: const Icon(Icons.remove_rounded, size: 24),
                              color: HhColors.primary,
                              onPressed: !isOutOfStock && quantity > 1
                                  ? () => setState(() => _quantity = quantity - 1)
                                  : null),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: HhColors.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text('$quantity',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                              tooltip: 'Increase quantity',
                              icon: const Icon(Icons.add_rounded, size: 24),
                              color: isAtKgLimit ? Colors.grey : HhColors.primary,
                              onPressed: !isOutOfStock && !isAtKgLimit
                                  ? () => setState(() => _quantity = quantity + 1)
                                  : null),
                        ]),
                        if (quantity >= product.stockQty && !isOutOfStock)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Maximum stock reached (${product.stockQty} kg)',
                              style: const TextStyle(color: HhColors.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (quantity >= maxPerOrder && quantity < product.stockQty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Maximum purchase limit of $maxPerOrder kg per order reached',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ] else ...[
                        Row(children: [
                          const Expanded(
                              child: Text('Weight (100g - 900g)',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600))),
                          IconButton(
                              tooltip: 'Decrease 100g',
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                              color: _selectedGrams > 100 ? HhColors.primary : Colors.grey,
                              onPressed: !isOutOfStock && _selectedGrams > 100
                                  ? () => setState(() => _selectedGrams -= 100)
                                  : null),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: HhColors.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text('${_selectedGrams}g',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800, color: HhColors.primary)),
                          ),
                          IconButton(
                              tooltip: 'Increase 100g',
                              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
                              color: isOutOfStock || _selectedGrams >= 900 || (_selectedGrams + 100) > (product.stockQty * 1000) ? Colors.grey : HhColors.primary,
                              onPressed: isOutOfStock
                                  ? null
                                  : () {
                                      if (_selectedGrams >= 900) {
                                        TopToast.show(context, 'Maximum 900g reached. Please switch unit to Kilogram (kg) for 1kg or more.');
                                        return;
                                      }
                                      final nextGrams = _selectedGrams + 100;
                                      if (nextGrams > product.stockQty * 1000) {
                                        TopToast.show(context, 'Stock limit reached (${product.stockQty} kg available).', isError: true);
                                        return;
                                      }
                                      setState(() => _selectedGrams = nextGrams);
                                    }),
                        ]),
                        if (_selectedGrams >= 900)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Reached 900g limit. Please switch unit to Kilogram (kg) for 1kg or more.',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (_selectedGrams > product.stockQty * 1000 && !isOutOfStock)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Selected quantity exceeds stock (${product.stockQty} kg available)',
                              style: const TextStyle(color: HhColors.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isOutOfStock || _adding
                                ? null
                                : () {
                                    if (_selectedUnit == 'g') {
                                      _addToCart(
                                        product,
                                        1,
                                        selectedUnit: '${_selectedGrams}g',
                                        customPrice: computedGramPrice,
                                      );
                                    } else {
                                      _addToCart(
                                        product,
                                        quantity,
                                        selectedUnit: 'kg',
                                        customPrice: product.price,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: HhColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: Text(
                                isOutOfStock
                                    ? 'Out of Stock'
                                    : 'Add to Basket \u2022 \$${(finalPriceCents / 100).toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          )),
                    ]),
              ),
              const SizedBox(height: 18),
              const Text('About this product',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  product.description.trim().isEmpty
                      ? 'No product description yet.'
                      : product.description,
                  style: const TextStyle(fontSize: 14, height: 1.55)),
              const SizedBox(height: 24),
              ProductReviewsSection(
                  key: ValueKey('reviews-${product.id}'),
                  product: product,
                  data: _data),
              const SizedBox(height: 24),
              ProductStoreSection(
                  key: ValueKey(product.farmerId),
                  farmerId: product.farmerId,
                  fallbackName: widget.storeName?.trim().isNotEmpty == true
                      ? widget.storeName!
                      : product.farmerName,
                  fallbackRating: widget.storeRating,
                  data: _data),
            ],
          )),
    );
  }
}
