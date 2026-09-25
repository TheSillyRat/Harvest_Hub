import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../location/nearby_stores.dart';
import 'product_detail_sections.dart';

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
  int _quantity = 1;
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

  Future<void> _addToCart(Product product, int quantity) async {
    if (_adding) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await context.read<CartController>().addToCart(product, quantity);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Added $quantity ${product.unit} of ${product.name} to basket!')));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not add this product. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _buildDetails(BuildContext context, Product product) {
    final isOutOfStock = product.stockQty <= 0;
    final quantity = isOutOfStock ? 0 : _quantity.clamp(1, product.stockQty);
    final images = product.galleryImages;
    return Container(
      decoration: const BoxDecoration(
          color: HhColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Product details',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(
                    tooltip: 'Close product details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              ProductGallery(key: ValueKey(images.join('|')), images: images),
              const SizedBox(height: 18),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: HhColors.text)),
              const SizedBox(height: 6),
              Text(
                  '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: HhColors.primary)),
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
              const SizedBox(height: 18),
              const Text('About this product',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  product.description.trim().isEmpty
                      ? 'No product description yet.'
                      : product.description,
                  style: const TextStyle(fontSize: 14, height: 1.55)),
              const SizedBox(height: 10),
              Text(
                  isOutOfStock
                      ? 'Availability: Currently out of stock'
                      : 'Availability: ${product.stockQty} ${product.unit} in stock',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isOutOfStock ? HhColors.danger : HhColors.primary)),
              const SizedBox(height: 24),
              ProductStoreSection(
                  key: ValueKey(product.farmerId),
                  farmerId: product.farmerId,
                  fallbackName: widget.storeName?.trim().isNotEmpty == true
                      ? widget.storeName!
                      : product.farmerName,
                  fallbackRating: widget.storeRating,
                  data: _data),
              const SizedBox(height: 24),
              ProductReviewsSection(
                  key: ValueKey('reviews-${product.id}'),
                  product: product,
                  data: _data),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: 'Decrease quantity',
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: !isOutOfStock && quantity > 1
                        ? () => setState(() => _quantity = quantity - 1)
                        : null),
                Text('$quantity',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(
                    tooltip: 'Increase quantity',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: !isOutOfStock && quantity < product.stockQty
                        ? () => setState(() => _quantity = quantity + 1)
                        : null),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOutOfStock || _adding
                        ? null
                        : () => _addToCart(product, quantity),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: HhColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16)),
                    child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : 'Add to Basket \u2022 \$${((product.price * quantity) / 100).toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  )),
            ],
          )),
    );
  }
}
