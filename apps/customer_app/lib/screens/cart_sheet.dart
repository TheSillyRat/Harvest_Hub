import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class CustomerCartSheet extends StatefulWidget {
  final VoidCallback? onOrderPlaced;

  const CustomerCartSheet({super.key, this.onOrderPlaced});

  @override
  State<CustomerCartSheet> createState() => _CustomerCartSheetState();
}

class _CustomerCartSheetState extends State<CustomerCartSheet> {
  bool _isSubmitting = false;

  Future<void> _handleCheckout(
      BuildContext context, CartController cart) async {
    if (cart.items.isEmpty || _isSubmitting) return;

    /* Request phone native system notification permission when placing order */
    final notifService = NotificationService.instance;
    if (!notifService.hasPromptedPermission) {
      await notifService.requestPermission();
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSubmitting = true;
    });

    try {
      final authController = context.read<AuthController>();
      final uid = authController.user?.uid ?? 'customer_1';
      final orderService = OrderService();

      final orderIds = await orderService.placeOrders(
        uid,
        List<CartItem>.from(cart.items),
        'Green Valley Hub, West Market Station',
        'morning_07_10',
      );

      await cart.clearAll();

      final orderIdLabel = orderIds.isNotEmpty
          ? (orderIds.first.length > 8
              ? orderIds.first.substring(0, 8)
              : orderIds.first)
          : '';

      await notifService.sendNotification(
        userId: uid,
        title: '✅ Order Placed Successfully! (#$orderIdLabel)',
        body: 'Your order has been sent to the farm. You will receive notifications when produce is ready.',
        type: 'order_placed',
        targetId: orderIds.isNotEmpty ? orderIds.first : null,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Order #$orderIdLabel placed successfully with direct farm escrow!'),
            backgroundColor: HhColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onOrderPlaced?.call();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not place order: ${e.toString()}'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        backgroundColor: HhColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
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
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 160 + MediaQuery.paddingOf(context).bottom),
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
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, 20 + MediaQuery.paddingOf(context).bottom),
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
                      onPressed: _isSubmitting
                          ? null
                          : () => _handleCheckout(context, cart),
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
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
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
    );
  }
}
