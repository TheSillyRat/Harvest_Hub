import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class CustomerCartSheet extends StatelessWidget {
  const CustomerCartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Your Farm Basket',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () {
                for (final item in List<CartItem>.from(cart.items)) {
                  cart.removeItem(item.productId);
                }
              },
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: HhColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: HhColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_basket_outlined,
                        size: 46,
                        color: HhColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your basket is empty',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse fresh farm crops and direct harvests to add your favorite produce.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: HhColors.text.withValues(alpha: 0.65),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 240),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: HhColors.text.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HhColors.text.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: HhColors.sageLight,
                            child: const Icon(
                              Icons.agriculture_rounded,
                              color: HhColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.farmerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: HhColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: HhColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${(item.price / 100).toStringAsFixed(2)} / ${item.unit}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: HhColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 22),
                            color: HhColors.muted,
                            onPressed: () {
                              cart.updateQuantity(item.productId, item.qty - 1);
                            },
                          ),
                          Text(
                            '${item.qty}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 22),
                            color: HhColors.primary,
                            onPressed: () {
                              cart.updateQuantity(item.productId, item.qty + 1);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomSheet: cart.items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: HhColors.text.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HhColors.muted,
                          ),
                        ),
                        Text(
                          '\$${(cart.total / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: HhColors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Order placed successfully with direct farm escrow!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          for (final item in List<CartItem>.from(cart.items)) {
                            cart.removeItem(item.productId);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HhColors.primary,
                          foregroundColor: HhColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                          shadowColor:
                              HhColors.primary.withValues(alpha: 0.35),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Confirm Direct Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
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
