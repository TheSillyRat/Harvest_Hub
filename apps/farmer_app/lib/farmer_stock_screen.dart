import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

enum StockFilter { all, outOfStock, lowStock, inStock }

class FarmerStockManagementScreen extends StatefulWidget {
  final String? farmerId;
  final StockFilter initialFilter;

  const FarmerStockManagementScreen({
    super.key,
    this.farmerId,
    this.initialFilter = StockFilter.all,
  });

  @override
  State<FarmerStockManagementScreen> createState() =>
      _FarmerStockManagementScreenState();
}

class _FarmerStockManagementScreenState
    extends State<FarmerStockManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  late StockFilter _selectedFilter;
  String _searchQuery = '';
  final Map<String, bool> _updatingMap = {};

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateStock(Product product, int newQty) async {
    final validQty = newQty < 0 ? 0 : newQty;
    if (validQty == product.stockQty) return;

    setState(() {
      _updatingMap[product.id] = true;
    });

    try {
      await ProductService().quickUpdateStock(product.id, validQty);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  validQty == 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    validQty == 0
                        ? '${product.name} is now marked OUT OF STOCK'
                        : 'Stock for ${product.name} updated to $validQty ${product.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: validQty == 0
                ? HhColors.danger
                : const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingMap.remove(product.id);
        });
      }
    }
  }

  Future<void> _showCustomStockDialog(Product product) async {
    final controller =
        TextEditingController(text: product.stockQty.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Stock · ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current stock: ${product.stockQty} ${product.unit}',
              style: const TextStyle(color: HhColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New Stock Quantity (${product.unit})',
                hintText: 'Enter quantity',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: HhColors.bg,
                suffixText: product.unit,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Set 0 (Out of stock)'),
                  backgroundColor: HhColors.danger.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                      color: HhColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  onPressed: () {
                    controller.text = '0';
                  },
                ),
                ActionChip(
                  label: const Text('+10'),
                  onPressed: () {
                    final curr = int.tryParse(controller.text) ?? 0;
                    controller.text = (curr + 10).toString();
                  },
                ),
                ActionChip(
                  label: const Text('+25'),
                  onPressed: () {
                    final curr = int.tryParse(controller.text) ?? 0;
                    controller.text = (curr + 25).toString();
                  },
                ),
                ActionChip(
                  label: const Text('+50'),
                  onPressed: () {
                    final curr = int.tryParse(controller.text) ?? 0;
                    controller.text = (curr + 50).toString();
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 40),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateStock(product, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUid = widget.farmerId ??
        context.watch<AuthController>().user?.uid ??
        '';
    final stream = ProductService().streamByFarmer(effectiveUid);

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Stock Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyView(message: errorMessage(snapshot.error!));
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final allProducts = snapshot.data!;
          final outOfStockCount =
              allProducts.where((p) => p.stockQty == 0).length;
          final lowStockCount =
              allProducts.where((p) => p.stockQty > 0 && p.stockQty <= 5).length;
          final inStockCount =
              allProducts.where((p) => p.stockQty > 5).length;

          // Filter by stock status
          var filtered = allProducts.where((p) {
            switch (_selectedFilter) {
              case StockFilter.outOfStock:
                return p.stockQty == 0;
              case StockFilter.lowStock:
                return p.stockQty > 0 && p.stockQty <= 5;
              case StockFilter.inStock:
                return p.stockQty > 5;
              case StockFilter.all:
                return true;
            }
          }).toList();

          // Filter by search query
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            filtered = filtered
                .where((p) =>
                    p.name.toLowerCase().contains(query) ||
                    p.categoryId.toLowerCase().contains(query))
                .toList();
          }

          return Column(
            children: [
              // Header Summary Metrics
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildMetricItem(
                      label: 'Total Items',
                      count: allProducts.length,
                      color: HhColors.primary,
                      icon: Icons.inventory_2_outlined,
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    _buildMetricItem(
                      label: 'Out of Stock',
                      count: outOfStockCount,
                      color: HhColors.danger,
                      icon: Icons.cancel_outlined,
                      highlight: outOfStockCount > 0,
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    _buildMetricItem(
                      label: 'Low Stock',
                      count: lowStockCount,
                      color: const Color(0xFFE65100),
                      icon: Icons.warning_amber_rounded,
                      highlight: lowStockCount > 0,
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    _buildMetricItem(
                      label: 'In Stock',
                      count: inStockCount,
                      color: const Color(0xFF2E7D32),
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search products by name...',
                    prefixIcon: const Icon(Icons.search, color: HhColors.muted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All (${allProducts.length})',
                      filter: StockFilter.all,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Out of Stock ($outOfStockCount)',
                      filter: StockFilter.outOfStock,
                      badgeColor: HhColors.danger,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Low Stock ($lowStockCount)',
                      filter: StockFilter.lowStock,
                      badgeColor: const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'In Stock ($inStockCount)',
                      filter: StockFilter.inStock,
                      badgeColor: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),

              // Product List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_outlined,
                              size: 56,
                              color: HhColors.muted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allProducts.isEmpty
                                  ? 'No products found'
                                  : 'No products match the selected filter',
                              style: const TextStyle(
                                fontSize: 16,
                                color: HhColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final product = filtered[i];
                          final isUpdating =
                              _updatingMap[product.id] == true;
                          return _buildStockCard(product, isUpdating);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: highlight ? color : HhColors.muted,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required StockFilter filter,
    Color? badgeColor,
  }) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: (badgeColor ?? HhColors.primary).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? (badgeColor ?? HhColors.primary)
            : HhColors.text.withValues(alpha: 0.8),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? (badgeColor ?? HhColors.primary)
            : Colors.grey.withValues(alpha: 0.3),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() => _selectedFilter = filter);
      },
    );
  }

  Widget _buildStockCard(Product product, bool isUpdating) {
    final isOutOfStock = product.stockQty == 0;
    final isLowStock = product.stockQty > 0 && product.stockQty <= 5;

    final badgeColor = isOutOfStock
        ? HhColors.danger
        : (isLowStock ? const Color(0xFFE65100) : const Color(0xFF2E7D32));

    final badgeText = isOutOfStock
        ? 'OUT OF STOCK'
        : (isLowStock
            ? 'LOW STOCK · ${product.stockQty} ${product.unit}'
            : 'IN STOCK · ${product.stockQty} ${product.unit}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOutOfStock ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOutOfStock
              ? HhColors.danger.withValues(alpha: 0.4)
              : Colors.transparent,
          width: isOutOfStock ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ProductImage(product.imageUrl),
                        ),
                        if (isOutOfStock)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: const Center(
                              child: Text(
                                'EMPTY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: HhColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Stock Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vnd(product.price)} / ${product.unit} · Category: ${product.categoryId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: HhColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Counter & Preset Row
                      Row(
                        children: [
                          // Counter Controls [-] Qty [+]
                          Container(
                            decoration: BoxDecoration(
                              color: HhColors.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  color: product.stockQty > 0
                                      ? HhColors.text
                                      : Colors.grey,
                                  onPressed: isUpdating || product.stockQty <= 0
                                      ? null
                                      : () => _updateStock(
                                          product, product.stockQty - 1),
                                ),
                                GestureDetector(
                                  onTap: isUpdating
                                      ? null
                                      : () => _showCustomStockDialog(product),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: isUpdating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Text(
                                            '${product.stockQty}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: HhColors.text,
                                            ),
                                          ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  color: HhColors.text,
                                  onPressed: isUpdating
                                      ? null
                                      : () => _updateStock(
                                          product, product.stockQty + 1),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Quick Presets
                          Wrap(
                            spacing: 4,
                            children: [
                              _buildQuickAddButton(
                                label: '+5',
                                onPressed: isUpdating
                                    ? null
                                    : () => _updateStock(
                                        product, product.stockQty + 5),
                              ),
                              _buildQuickAddButton(
                                label: '+10',
                                onPressed: isUpdating
                                    ? null
                                    : () => _updateStock(
                                        product, product.stockQty + 10),
                              ),
                              _buildQuickAddButton(
                                label: '+20',
                                onPressed: isUpdating
                                    ? null
                                    : () => _updateStock(
                                        product, product.stockQty + 20),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded,
                                    size: 22, color: HhColors.primary),
                                tooltip: 'Custom quantity',
                                visualDensity: VisualDensity.compact,
                                onPressed: isUpdating
                                    ? null
                                    : () => _showCustomStockDialog(product),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: HhColors.sageLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: HhColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
