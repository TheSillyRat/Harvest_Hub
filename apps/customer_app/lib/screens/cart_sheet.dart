import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import '../location/customer_location.dart';
import 'checkout_screen.dart';

class CustomerCartSheet extends StatefulWidget {
  final VoidCallback? onOrderPlaced;
  final VoidCallback? onExplore;
  final CustomerLocation? location;

  const CustomerCartSheet({
    super.key,
    this.onOrderPlaced,
    this.onExplore,
    this.location,
  });

  @override
  State<CustomerCartSheet> createState() => _CustomerCartSheetState();
}

class _CustomerCartSheetState extends State<CustomerCartSheet> {
  final Set<String> _updatingItems = {};
  final Set<String> _selectedProductIds = {};
  bool _initializedSelection = false;
  late final Stream<Map<String, Product>> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = ProductService().streamProductsMap();
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                borderRadius: BorderRadius.circular(8),
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
      setState(() {
        _selectedProductIds.clear();
      });
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
        setState(() {
          _selectedProductIds.remove(item.productId);
        });
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

  Future<void> _handleQuantityChange(
    BuildContext context,
    CartController cart,
    CartItem item,
    int newQty,
    int availableStock,
  ) async {
    if (_updatingItems.contains(item.productId)) return;

    if (newQty <= 0) {
      await _handleRemoveItem(context, cart, item);
      return;
    }

    if (newQty > availableStock) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              availableStock <= 0
                  ? 'This product is out of stock.'
                  : 'Only $availableStock items left in stock (max $availableStock).',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  Future<void> _handlePlaceOrder(
    CartController cart,
    List<CartItem> selectedItems,
    Map<String, Product> productsMap,
  ) async {
    if (selectedItems.isEmpty) return;

    for (final item in selectedItems) {
      final p = productsMap[item.productId];
      final stock = p?.stockQty ?? 0;
      final isOutOfStock = p != null && (!p.isActive || stock <= 0);
      if (isOutOfStock) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} is out of stock. Please deselect it to proceed with checkout.',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (p != null && item.qty > stock) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} exceeds available stock (only $stock available).',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final groups = _groupByFarmer(selectedItems);
    for (final entry in groups.entries) {
      if (entry.value.length > 8) {
        if (!mounted) return;
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

    final navigator = Navigator.of(context);
    final placed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => MultiShopCheckoutScreen(
          selectedItems: selectedItems,
          location: widget.location,
          onOrderPlaced: widget.onOrderPlaced,
        ),
      ),
    );

    if (placed == true && mounted) {
      if (cart.items.isEmpty) {
        navigator.maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final farmerGroups = _groupByFarmer(cart.items);
    final topPadding = MediaQuery.paddingOf(context).top;

    return StreamBuilder<Map<String, Product>>(
      stream: _productsStream,
      builder: (context, productSnapshot) {
        final productsMap = productSnapshot.data ?? const {};

        // Sync selection state with cart contents & stock availability
        final currentIds = cart.items.map((i) => i.productId).toSet();
        if (!_initializedSelection) {
          for (final item in cart.items) {
            final p = productsMap[item.productId];
            final isOutOfStock = p != null && (!p.isActive || p.stockQty <= 0);
            if (!isOutOfStock) {
              _selectedProductIds.add(item.productId);
            }
          }
          if (cart.items.isNotEmpty) {
            _initializedSelection = true;
          }
        } else {
          _selectedProductIds.removeWhere((id) {
            if (!currentIds.contains(id)) return true;
            final p = productsMap[id];
            return p != null && (!p.isActive || p.stockQty <= 0);
          });
        }

        return Container(
          margin: EdgeInsets.only(top: topPadding > 0 ? topPadding + 10 : 0),
          decoration: const BoxDecoration(
            color: HhColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scaffold(
            backgroundColor: HhColors.bg,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 16),
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      children: farmerGroups.entries.map((entry) {
                        return _buildFarmerGroupCard(
                          context: context,
                          cart: cart,
                          farmerId: entry.key,
                          items: entry.value,
                          productsMap: productsMap,
                        );
                      }).toList(),
                    ),
                  ),
            bottomNavigationBar: cart.items.isEmpty
                ? null
                : _buildBottomSheet(context, cart, farmerGroups, productsMap),
          ),
        );
      },
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
                    borderRadius: BorderRadius.circular(8),
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
    required Map<String, Product> productsMap,
  }) {
    final farmerName = items.first.farmerName.isNotEmpty
        ? items.first.farmerName
        : 'Local Farm';
    final groupSubtotal =
        items.fold<int>(0, (total, item) => total + (item.price * item.qty));
    final hasTooManyItems = items.length > 8;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasTooManyItems
              ? HhColors.danger.withValues(alpha: 0.5)
              : HhColors.text.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Farm
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: HhColors.sageLight.withValues(alpha: 0.35),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: HhColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: HhColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              farmerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: HhColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 14, color: HhColors.primary),
                        ],
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
          // Items in farm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              children: items.map((item) {
                return _buildCartItemTile(context, cart, item, productsMap);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(
    BuildContext context,
    CartController cart,
    CartItem item,
    Map<String, Product> productsMap,
  ) {
    final isUpdating = _updatingItems.contains(item.productId);
    final product = productsMap[item.productId];
    final stockQty = product?.stockQty ?? 99;
    final isOutOfStock = product != null && (!product.isActive || stockQty <= 0);
    final isSelected = !isOutOfStock && _selectedProductIds.contains(item.productId);
    final isAtStockLimit = !isOutOfStock && item.qty >= stockQty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: HhColors.primary,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: isOutOfStock
                ? null
                : (val) {
                    setState(() {
                      if (val == true) {
                        _selectedProductIds.add(item.productId);
                      } else {
                        _selectedProductIds.remove(item.productId);
                      }
                    });
                  },
          ),
          const SizedBox(width: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ProductImage(
              item.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: Container(
                width: 56,
                height: 56,
                color: HhColors.sageLight,
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: HhColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock ? HhColors.muted : HhColors.text,
                    decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isOutOfStock) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: HhColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: HhColors.danger,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    '\$${(item.price / 100).toStringAsFixed(2)} / ${item.unit}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: HhColors.text.withValues(alpha: 0.65),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Subtotal: \$${((item.price * item.qty) / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: HhColors.primary,
                        ),
                      ),
                      if (isAtStockLimit) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(Max $stockQty)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
                        context, cart, item, item.qty - 1, stockQty),
              ),
              isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HhColors.primary,
                      ),
                    )
                  : Text(
                      '${item.qty}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock ? HhColors.muted : HhColors.text,
                      ),
                    ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, size: 22),
                color: (isOutOfStock || isAtStockLimit)
                    ? Colors.black26
                    : HhColors.primary,
                onPressed: (isUpdating || isOutOfStock || isAtStockLimit)
                    ? null
                    : () => _handleQuantityChange(
                        context, cart, item, item.qty + 1, stockQty),
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

  Widget _buildBottomSheet(
    BuildContext context,
    CartController cart,
    Map<String, List<CartItem>> farmerGroups,
    Map<String, Product> productsMap,
  ) {
    final selectedItems = cart.items
        .where((item) => _selectedProductIds.contains(item.productId))
        .toList();

    final inStockItems = cart.items.where((i) {
      final p = productsMap[i.productId];
      return p == null || (p.isActive && p.stockQty > 0);
    }).toList();

    final isAllSelected = inStockItems.isNotEmpty &&
        inStockItems.every((i) => _selectedProductIds.contains(i.productId));

    final selectedGroups = _groupByFarmer(selectedItems);
    final hasLimitViolation =
        farmerGroups.values.any((items) => items.length > 8);

    final selectedTotal = selectedItems.fold<int>(
        0, (total, item) => total + (item.price * item.qty));
    final selectedQty =
        selectedItems.fold<int>(0, (total, item) => total + item.qty);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
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
                  '$selectedQty item${selectedQty == 1 ? '' : 's'} selected (${selectedGroups.length} farm${selectedGroups.length == 1 ? '' : 's'})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HhColors.muted,
                  ),
                ),
                Text(
                  '\$${(selectedTotal / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: HhColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // "Select All" checkbox on the left
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isAllSelected) {
                        _selectedProductIds.clear();
                      } else {
                        _selectedProductIds
                            .addAll(inStockItems.map((e) => e.productId));
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isAllSelected,
                          activeColor: HhColors.primary,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: inStockItems.isEmpty
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProductIds.addAll(
                                          inStockItems.map((e) => e.productId));
                                    } else {
                                      _selectedProductIds.clear();
                                    }
                                  });
                                },
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'All',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HhColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Place Order button
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedItems.isEmpty || hasLimitViolation)
                        ? null
                        : () => _handlePlaceOrder(
                            cart, selectedItems, productsMap),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: HhColors.bg,
                      disabledBackgroundColor:
                          HhColors.muted.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasLimitViolation
                              ? 'Reduce items to checkout'
                              : 'Place Order',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!hasLimitViolation && selectedItems.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ],
                    ),
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
