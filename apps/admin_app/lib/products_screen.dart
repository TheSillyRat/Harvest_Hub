import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _showDeactivationDialog(Product product) async {
    String selectedReason =
        'Mặt hàng không đúng đăng ký kinh doanh (Unregistered business category)';
    final customCtrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: HhColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deactivate: ${product.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select or enter the violation reason for deactivating this product. The farmer will be notified immediately.',
                      style: TextStyle(fontSize: 13, color: HhColors.muted),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Violation Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                              'Mặt hàng không đúng đăng ký kinh doanh (Unregistered business category)',
                          child: Text(
                            'Unregistered business category',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'Vi phạm chính sách tiêu chuẩn chất lượng (Policy violation / Substandard)',
                          child: Text(
                            'Policy violation / Substandard quality',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              'Hình ảnh hoặc mô tả sai lệch (Misleading description / images)',
                          child: Text(
                            'Misleading description / images',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Other Reason',
                          child: Text('Other reason...'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => selectedReason = val);
                        }
                      },
                    ),
                    if (selectedReason == 'Other Reason') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter specific reason for deactivation...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HhColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final finalReason = selectedReason == 'Other Reason'
                        ? (customCtrl.text.trim().isNotEmpty
                            ? customCtrl.text.trim()
                            : 'Policy violation')
                        : selectedReason;
                    Navigator.pop(ctx, finalReason);
                  },
                  child: const Text('Deactivate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleProductStatus(Product product) async {
    String? reason;
    if (product.isActive) {
      reason = await _showDeactivationDialog(product);
      if (reason == null) return;
    }

    try {
      final updateData = <String, dynamic>{
        'isActive': !product.isActive,
        'updatedAt': Timestamp.now(),
      };

      if (product.isActive) {
        updateData['deactivatedByAdmin'] = true;
        updateData['deactivationReason'] = reason;
        updateData['deactivatedAt'] = Timestamp.now();
      } else {
        updateData['deactivatedByAdmin'] = false;
        updateData['deactivationReason'] = null;
        updateData['deactivatedAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update(updateData);

      if (product.farmerId.isNotEmpty) {
        if (product.isActive) {
          await NotificationService().sendNotification(
            userId: product.farmerId,
            title: '⚠️ Product Deactivated by Admin',
            body: 'Your product "${product.name}" was deactivated: $reason',
            type: 'PRODUCT_DEACTIVATED',
            targetId: product.id,
          );
        } else {
          await NotificationService().sendNotification(
            userId: product.farmerId,
            title: '✅ Product Re-activated',
            body:
                'Your product "${product.name}" has been reactivated and is now visible on the marketplace.',
            type: 'PRODUCT_ACTIVATED',
            targetId: product.id,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              product.isActive ? 'Product deactivated' : 'Product activated',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Platform Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: HhColors.text.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by product or farmer name...',
                  prefixIcon: const Icon(Icons.search, color: HhColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Active', 'Inactive'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: HhColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: HhColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? HhColors.primary : HhColors.text,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SproutLoadingIndicator(size: 100),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final products = docs.map((doc) {
                  return Product.fromMap(
                    doc.data() as Map<String, dynamic>,
                    id: doc.id,
                  );
                }).where((p) {
                  final matchesSearch =
                      p.name.toLowerCase().contains(_searchQuery) ||
                          p.farmerName.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_selectedFilter == 'Active') return p.isActive;
                  if (_selectedFilter == 'Inactive') return !p.isActive;
                  return true;
                }).toList();

                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: HhColors.muted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = products[index];
                    return _ProductCard(
                      product: item,
                      onToggleStatus: () =>
                          _toggleProductStatus(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onToggleStatus;

  const _ProductCard({
    required this.product,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HhColors.text.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: HhColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.eco_outlined,
                              color: HhColors.primary),
                        ),
                      )
                    : Container(
                        color: HhColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.eco_outlined,
                            color: HhColors.primary),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Farm: ${product.farmerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: HhColors.text.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stockQty > 0
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Stock: ${product.stockQty}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.stockQty > 0
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: product.isActive,
                  activeThumbColor: HhColors.primary,
                  onChanged: (_) => onToggleStatus(),
                ),
                Text(
                  product.isActive ? 'Active' : 'Hidden',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: product.isActive ? HhColors.primary : HhColors.muted,
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
