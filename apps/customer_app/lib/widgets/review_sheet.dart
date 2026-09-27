import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../services/review_service.dart';

Future<bool?> showWriteReviewSheet(
  BuildContext context, {
  Product? product,
  String? productId,
  String? productName,
  String? farmerId,
  String? farmerName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: WriteReviewSheet(
        product: product,
        productId: productId,
        productName: productName,
        farmerId: farmerId,
        farmerName: farmerName,
      ),
    ),
  );
}

class WriteReviewSheet extends StatefulWidget {
  final Product? product;
  final String? productId;
  final String? productName;
  final String? farmerId;
  final String? farmerName;

  const WriteReviewSheet({
    super.key,
    this.product,
    this.productId,
    this.productName,
    this.farmerId,
    this.farmerName,
  }) : assert(product != null || (productId != null && productName != null) || (farmerId != null && farmerName != null));

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _submitting = false;

  bool get _isProductReview => widget.product != null || widget.productId != null;
  String get _targetName => widget.product?.name ?? widget.productName ?? widget.farmerName ?? 'Item';
  String get _targetProductId => widget.product?.id ?? widget.productId ?? '';
  String get _targetProductName => widget.product?.name ?? widget.productName ?? '';

  List<String> get _availableTags => _isProductReview
      ? [
          '🌿 Super Fresh',
          '🍎 Crisp & Sweet',
          '⚡ Great Value',
          '🌱 100% Organic',
          '📦 Clean Packaging',
          '👍 Highly Recommend',
        ]
      : [
          '👨‍🌾 Friendly Farmer',
          '⚡ Fast Pickup',
          '📍 Easy to Find',
          '🌿 Top Quality',
          '📦 Well Packaged',
          '🔄 Will Revisit',
        ];

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return '5.0 - Excellent!';
    if (rating >= 4.0) return '4.0 - Very Good';
    if (rating >= 3.0) return '3.0 - Good';
    if (rating >= 2.0) return '2.0 - Fair';
    return '1.0 - Poor';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a short comment about your experience.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final auth = context.read<AuthController>();
      final uid = auth.user?.uid ?? 'customer_1';
      final name = auth.user?.name ?? 'Thu Ha Le';
      final avatar = auth.user?.email ?? '';

      if (_isProductReview) {
        await ReviewService.instance.submitProductReview(
          productId: _targetProductId,
          productName: _targetProductName,
          rating: _rating,
          comment: comment,
          authorId: uid,
          authorName: name,
          authorAvatar: avatar,
          tags: _selectedTags.toList(),
        );
      } else {
        await ReviewService.instance.submitFarmerReview(
          farmerId: widget.farmerId!,
          farmerName: widget.farmerName!,
          rating: _rating,
          comment: comment,
          authorId: uid,
          authorName: name,
          authorAvatar: avatar,
          tags: _selectedTags.toList(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Thank you! Your review for $_targetName was submitted.'),
                ),
              ],
            ),
            backgroundColor: HhColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit review: $e'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HhColors.text.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                    ),
                    child: Icon(
                      _isProductReview ? Icons.eco_rounded : Icons.storefront_rounded,
                      color: const Color(0xFFFFA000),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isProductReview ? 'Rate Product' : 'Rate Farm Experience',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _targetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: HhColors.text.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: HhColors.muted),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Star Selector
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = (index + 1).toDouble();
                        final isFilled = starValue <= _rating;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = starValue;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: AnimatedScale(
                              scale: isFilled ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 38,
                                color: const Color(0xFFFFA000),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getRatingLabel(_rating),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Quick Tags
              const Text(
                'What stood out?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HhColors.text),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    checkmarkColor: Colors.white,
                    selectedColor: HhColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : HhColors.text,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? HhColors.primary : HhColors.text.withValues(alpha: 0.12),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Comment box
              const Text(
                'Detailed review',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HhColors.text),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: HhColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HhColors.text.withValues(alpha: 0.1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _isProductReview
                        ? 'Share details about freshness, taste, size, or packaging...'
                        : 'Share your experience with pickup location, timing, and farm hospitality...',
                    hintStyle: TextStyle(fontSize: 13, color: HhColors.text.withValues(alpha: 0.45)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HhColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
