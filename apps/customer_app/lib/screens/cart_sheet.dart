import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class CustomerCartSheet extends StatefulWidget {
  final VoidCallback? onOrderPlaced;
  final VoidCallback? onExplore;

  const CustomerCartSheet({
    super.key,
    this.onOrderPlaced,
    this.onExplore,
  });

  @override
  State<CustomerCartSheet> createState() => _CustomerCartSheetState();
}

class _CustomerCartSheetState extends State<CustomerCartSheet> {
  bool _isSubmitting = false;
  final Set<String> _updatingItems = {};

  Map<String, List<CartItem>> _groupByFarmer(List<CartItem> items) {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.farmerId, () => []).add(item);
    }
    return map;
  }

  Future<void> _confirmClearCart(
      BuildContext context, CartController cart) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.remove_shopping_cart_outlined,
                color: HhColors.danger, size: 24),
            SizedBox(width: 10),
            Text(
              'Clear Basket?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: HhColors.text,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all produce from your basket?',
          style: TextStyle(color: HhColors.muted, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: HhColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await cart.clearAll();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Farm basket cleared'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveItem(
      BuildContext context, CartController cart, CartItem item) async {
    if (_updatingItems.contains(item.productId)) return;
    setState(() => _updatingItems.add(item.productId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cart.removeItem(item.productId);
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Removed ${item.name} from basket'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not remove item: ${e.toString()}'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingItems.remove(item.productId));
      }
    }
  }

  Future<void> _handleQuantityChange(BuildContext context, CartController cart,
      CartItem item, int newQty) async {
    if (_updatingItems.contains(item.productId)) return;

    if (newQty <= 0) {
      await _handleRemoveItem(context, cart, item);
      return;
    }

    setState(() => _updatingItems.add(item.productId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cart.updateQuantity(item.productId, newQty);
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('Could not update quantity. Check stock availability.'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingItems.remove(item.productId));
      }
    }
  }

  Future<void> _handleCheckout(
      BuildContext context, CartController cart) async {
    if (cart.items.isEmpty || _isSubmitting) return;

    final groups = _groupByFarmer(cart.items);
    for (final entry in groups.entries) {
      if (entry.value.length > 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.value.first.farmerName} has ${entry.value.length} items. Maximum 8 items allowed per order.',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSubmitting = true;
    });

    try {
      final authController = context.read<AuthController>();
      final uid = authController.user?.uid ?? 'customer_1';
      final orderService = OrderService();

      final notifService = NotificationService.instance;
      if (!notifService.hasPromptedPermission) {
        await notifService.requestPermission();
      }
      if (!mounted) return;

      final orderIds = await orderService.placeOrders(
        uid,
        List<CartItem>.from(cart.items),
        'Green Valley Hub, West Market Station',
        'morning_07_10',
      );

      await cart.clearAll();

      if (mounted) {
        final orderIdLabel = orderIds.isNotEmpty
            ? (orderIds.first.length > 8
                ? orderIds.first.substring(0, 8)
                : orderIds.first)
            : '';
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
    final farmerGroups = _groupByFarmer(cart.items);

    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      margin: EdgeInsets.only(top: topPadding + 20),
      decoration: const BoxDecoration(
        color: HhColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: HhColors.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppBar(
                primary: false,
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
                    TextButton.icon(
                      onPressed: () => _confirmClearCart(context, cart),
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 20, color: HhColors.danger),
                      label: const Text(
                        'Clear',
                        style: TextStyle(
                          color: HhColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        body: cart.items.isEmpty
            ? _buildEmptyBasket(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 260),
                children: [
                  ...farmerGroups.entries.map((entry) {
                    return _buildFarmerGroupCard(
                      context: context,
                      cart: cart,
                      farmerId: entry.key,
                      items: entry.value,
                    );
                  }),
                ],
              ),
        bottomSheet: cart.items.isEmpty
            ? null
            : _buildBottomSheet(context, cart, farmerGroups),
      ),
    );
  }

  Widget _buildEmptyBasket(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: HhColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 50,
                color: HhColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your basket is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: HhColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Browse fresh farm crops and direct harvests to add your favorite produce.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: HhColors.text.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            if (widget.onExplore != null)
              ElevatedButton.icon(
                onPressed: widget.onExplore,
                icon: const Icon(Icons.storefront_rounded, size: 20),
                label: const Text(
                  'Explore Fresh Produce',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HhColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerGroupCard({
    required BuildContext context,
    required CartController cart,
    required String farmerId,
    required List<CartItem> items,
  }) {
    final farmerName = items.first.farmerName.isNotEmpty
        ? items.first.farmerName
        : 'Local Farm';
    final groupSubtotal =
        items.fold<int>(0, (sum, item) => sum + (item.price * item.qty));
    final hasTooManyItems = items.length > 8;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasTooManyItems
              ? HhColors.danger.withValues(alpha: 0.5)
              : HhColors.text.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Farm
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: HhColors.sageLight.withValues(alpha: 0.35),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HhColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: HhColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                      Text(
                        '${items.length} produce item${items.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: HhColors.text.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${(groupSubtotal / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: HhColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (hasTooManyItems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: HhColors.danger.withValues(alpha: 0.08),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: HhColors.danger, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Max 8 items allowed per farm in one order. Please remove extra items.',
                      style: TextStyle(
                        fontSize: 12,
                        color: HhColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Danh sách sản phẩm của farm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: items.map((item) {
                return _buildCartItemTile(context, cart, item);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(
      BuildContext context, CartController cart, CartItem item) {
    final isUpdating = _updatingItems.contains(item.productId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 68,
                height: 68,
                color: HhColors.sageLight,
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: HhColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 2),
                Text(
                  '\$${(item.price / 100).toStringAsFixed(2)} / ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HhColors.text.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: \$${((item.price * item.qty) / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: HhColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                color: HhColors.muted,
                onPressed: isUpdating
                    ? null
                    : () => _handleQuantityChange(
                        context, cart, item, item.qty - 1),
              ),
              isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HhColors.primary,
                      ),
                    )
                  : Text(
                      '${item.qty}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, size: 22),
                color: HhColors.primary,
                onPressed: isUpdating
                    ? null
                    : () => _handleQuantityChange(
                        context, cart, item, item.qty + 1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: HhColors.danger),
                tooltip: 'Remove',
                onPressed: isUpdating
                    ? null
                    : () => _handleRemoveItem(context, cart, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context, CartController cart,
      Map<String, List<CartItem>> farmerGroups) {
    final hasLimitViolation =
        farmerGroups.values.any((items) => items.length > 8);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                Text(
                  '${cart.quantity} items (${farmerGroups.length} farm${farmerGroups.length > 1 ? 's' : ''})',
                  style: const TextStyle(
                    fontSize: 14,
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
                onPressed: (_isSubmitting || hasLimitViolation)
                    ? null
                    : () => _handleCheckout(context, cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HhColors.primary,
                  foregroundColor: HhColors.bg,
                  disabledBackgroundColor:
                      HhColors.muted.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                  shadowColor: HhColors.primary.withValues(alpha: 0.35),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hasLimitViolation
                                ? 'Reduce items to checkout'
                                : 'Confirm Direct Order',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!hasLimitViolation) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
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
