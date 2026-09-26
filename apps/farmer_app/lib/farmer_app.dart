import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});
  @override
  State<FarmerMainScreen> createState() => _FarmerMainScreenState();
}

typedef FarmerApp = FarmerMainScreen;

class _FarmerMainScreenState extends State<FarmerMainScreen> {
  int index = 0;
  static const titles = [
    'Dashboard',
    'My Products',
    'Orders',
    'Reports',
    'Profile'
  ];
  late final uid = context.read<AuthController>().user!.uid;
  late final orders = OrderService().streamByFarmer(uid);
  late final products = ProductService().streamByFarmer(uid);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('HarvestHub · ${titles[index]}')),
      drawer: Drawer(
          child: ListView(children: [
        const DrawerHeader(
            decoration: BoxDecoration(color: HhColors.primaryDark),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.eco, color: HhColors.accent, size: 48),
              SizedBox(height: 12),
              Text('Farmer Hub',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ])),
        for (var i = 0; i < titles.length; i++)
          ListTile(
              title: Text(titles[i]),
              selected: i == index,
              onTap: () {
                setState(() => index = i);
                Navigator.pop(context);
              }),
        ListTile(
            title: const Text('Log Out'),
            leading: const Icon(Icons.logout),
            onTap: () =>
                perform(context, context.read<AuthController>().logout)),
      ])),
      body: switch (index) {
        0 => FarmerDashboard(
            products: products,
            orders: orders,
            onNavigate: (i) => setState(() => index = i)),
        1 => FarmerProducts(stream: products),
        2 => OrdersScreen(stream: orders, role: Roles.farmer),
        3 => FarmerReports(stream: orders),
        _ => const ProfileScreen(),
      });
}

class FarmerDashboard extends StatelessWidget {
  final Stream<List<Product>> products;
  final Stream<List<FarmOrder>> orders;
  final ValueChanged<int> onNavigate;
  const FarmerDashboard(
      {super.key,
      required this.products,
      required this.orders,
      required this.onNavigate});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
      stream: products,
      builder: (context, p) => StreamBuilder<List<FarmOrder>>(
          stream: orders,
          builder: (context, o) {
            if (p.hasError || o.hasError) {
              return EmptyView(message: errorMessage(p.error ?? o.error!));
            }
            if (!p.hasData || !o.hasData) return const LoadingView();

            final allProducts = p.data!;
            final activeProducts =
                allProducts.where((e) => e.isActive).toList();
            final newProducts = activeProducts.take(3).toList();

            final pendingOrders =
                o.data!.where((e) => e.status == OrderStatus.pending).toList();
            final now = DateTime.now();
            final revenue = o.data!
                .where((e) =>
                    e.status == OrderStatus.completed &&
                    e.updatedAt.year == now.year &&
                    e.updatedAt.month == now.month)
                .fold<int>(0, (runningTotal, e) => runningTotal + e.total);

            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Welcome back!',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Text('Manage your crops and pickup orders.'),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => onNavigate(1),
                child: StatCard('Active Products', '${activeProducts.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(2),
                child: StatCard('Pending Orders', '${pendingOrders.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(3),
                child: StatCard('Simulated Revenue (This Month)', vnd(revenue)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recently Added Products',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('View All'),
                  )
                ],
              ),
              if (newProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('You have not added any products yet.'),
                ),
              for (final prod in newProducts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductImage(prod.imageUrl)),
                    title: Text(prod.name),
                    subtitle: Text(
                        '${vnd(prod.price)} / ${prod.unit} · Stock: ${prod.stockQty}'),
                    onTap: () =>
                        openPage(context, ProductFormScreen(product: prod)),
                  ),
                ),
            ]);
          }));
}

class FarmerProducts extends StatefulWidget {
  final Stream<List<Product>> stream;
  const FarmerProducts({super.key, required this.stream});
  @override
  State<FarmerProducts> createState() => _FarmerProductsState();
}

class _FarmerProductsState extends State<FarmerProducts> {
  String search = '';

  Future<void> _updateStock(Product p) async {
    final ctrl = TextEditingController(text: p.stockQty.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${p.name}'),
        content: HhTextField(
          controller: ctrl,
          label: 'New Quantity',
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0 && mounted) {
      perform(context, () => ProductService().updateStock(p.id, result),
          success: 'Stock updated to $result ${p.unit}');
    }
  }

  Future<void> _removeProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text(
          'Are you sure you want to remove "${p.name}" from your active product list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove from product list'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await perform(
        context,
        () async {
          try {
            await ProductService().delete(p.id);
          } catch (_) {
            await ProductService().setActive(p.id, false);
          }
        },
        success: 'Product "${p.name}" was removed from the catalog.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openPage(context, const ProductFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Add Product')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products...'),
                onChanged: (s) => setState(() => search = s.toLowerCase()))),
        Expanded(
            child: DataList<Product>(
                stream: widget.stream,
                empty: 'List your first product to start selling',
                builder: (context, products) {
                  final items = products
                      .where((p) => p.name.toLowerCase().contains(search))
                      .toList();
                  if (items.isEmpty) {
                    return const EmptyView(message: 'No products found');
                  }
                  return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final p = items[i];
                        if (!p.isActive) return const SizedBox.shrink();
                        return _FarmerProductCard(
                          key: ValueKey(p.id),
                          product: p,
                          onEdit: () =>
                              openPage(context, ProductFormScreen(product: p)),
                          onDelete: () => _removeProduct(p),
                          onUpdateStock: () => _updateStock(p),
                        );
                      });
                })),
      ]));
}

class _FarmerProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpdateStock;

  const _FarmerProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateStock,
  });

  @override
  State<_FarmerProductCard> createState() => _FarmerProductCardState();
}

class _FarmerProductCardState extends State<_FarmerProductCard> {
  bool isHovered = false;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        transform: isHovered
            ? Matrix4.translationValues(0, -3, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isHovered ? const Color(0xFFFDFBF7) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isHovered ? const Color(0xFFD8C9A8) : const Color(0xFFEBE6DF),
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFFD8C9A8).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: ProductImage(p.imageUrl),
                ),
              ),
              title: Text(
                p.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${vnd(p.price)} / ${p.unit}\nAvailable Stock: ${p.stockQty}',
                  style: const TextStyle(height: 1.3),
                ),
              ),
              isThreeLine: true,
              onTap: widget.onEdit,
              trailing: IconButton(
                tooltip: isExpanded ? 'Hide Actions' : 'View Actions',
                icon: Icon(
                  isExpanded ? Icons.visibility : Icons.visibility_outlined,
                  color: isExpanded ? HhColors.primary : Colors.grey.shade700,
                  size: 26,
                ),
                onPressed: () => setState(() => isExpanded = !isExpanded),
              ),
            ),
            if (isExpanded)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF7EE),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(13)),
                  border: Border(
                    top: BorderSide(color: Color(0xFFD8C9A8), width: 1),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HhColors.primary,
                          side: const BorderSide(color: HhColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Product'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Remove from product list',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name);
  late final description =
      TextEditingController(text: widget.product?.description);
  late final price = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '');
  late final stock = TextEditingController(
      text: widget.product != null ? widget.product!.stockQty.toString() : '');
  late String unit = widget.product?.unit ?? 'kg';
  late String? category = widget.product?.categoryId;
  File? photo;
  bool photoError = false;
  bool busy = false;
  final categories = CategoryService().streamActive();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      category = widget.product!.categoryId;
      unit = getFixedUnitForCategory(widget.product!.categoryId);
    }
  }

  @override
  void dispose() {
    for (final c in [name, description, price, stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    await perform(context, () async {
      final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (selected != null && mounted) {
        setState(() {
          photo = File(selected.path);
          photoError = false;
        });
      }
    });
  }

  void _onCategoryChanged(String? newCat) {
    if (newCat == null) return;
    setState(() {
      category = newCat;
      // Fixed unit strictly locked per category (farmers cannot choose or change unit)
      unit = getFixedUnitForCategory(newCat);
    });
  }

  Future<void> _confirmCancel() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to cancel? Any unsaved product information will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _promptSave() async {
    final hasPhoto = photo != null ||
        (widget.product != null && widget.product!.imageUrl.isNotEmpty);
    final formValid = form.currentState!.validate();
    final hasCategory = category != null;

    if (!hasPhoto) {
      setState(() => photoError = true);
      showError(
        context,
        'Product photo is missing! Please upload a photo from your gallery.',
      );
      return;
    } else if (photoError) {
      setState(() => photoError = false);
    }

    if (!hasCategory) {
      showError(context, 'Please select a category for this product.');
      return;
    }

    if (!formValid) {
      showError(
        context,
        'Please complete all required product fields before saving.',
      );
      return;
    }

    final priceVal = int.tryParse(price.text.trim());
    if (priceVal == null || priceVal <= 0) {
      showError(context, 'Please enter a valid price greater than 0.');
      return;
    }

    final stockVal = int.tryParse(stock.text.trim());
    if (stockVal == null || stockVal <= 0) {
      showError(context, 'Please enter an available quantity greater than 0.');
      return;
    }

    final isNew = widget.product == null;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Save New Product?' : 'Update Product?'),
        content: Text(
          isNew
              ? 'Are you sure you want to list "${name.text.trim()}" in the product catalog?'
              : 'Are you sure you want to save updates to "${name.text.trim()}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Product'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeSave();
    }
  }

  Future<void> _executeSave() async {
    final authUser = context.read<AuthController>().user;
    if (authUser == null) return;
    final uid = authUser.uid;

    setState(() => busy = true);
    try {
      final farmerDoc =
          await FirebaseFirestore.instance.collection('farmers').doc(uid).get();
      final farmerName = (farmerDoc.exists &&
              farmerDoc.data() != null &&
              farmerDoc.data()!['businessName'] != null)
          ? farmerDoc.data()!['businessName'] as String
          : (authUser.name.isNotEmpty ? authUser.name : 'Organic Farm Store');

      String finalUrl = '';
      if (photo != null) {
        finalUrl = await StorageService().uploadProductImage(uid, photo!);
      } else if (widget.product != null &&
          widget.product!.imageUrl.isNotEmpty) {
        finalUrl = widget.product!.imageUrl;
      }

      if (finalUrl.isEmpty) {
        throw 'Product photo is missing. Please upload a photo from your gallery.';
      }

      final now = DateTime.now();
      final p = Product(
          id: widget.product?.id ?? '',
          farmerId: uid,
          farmerName: farmerName,
          name: name.text.trim(),
          categoryId: category!,
          description: description.text.trim(),
          price: int.parse(price.text),
          unit: unit,
          stockQty: int.parse(stock.text),
          imageUrl: finalUrl,
          isActive: widget.product?.isActive ?? true,
          createdAt: widget.product?.createdAt ?? now,
          updatedAt: now);

      if (widget.product == null) {
        await ProductService().create(p);
      } else {
        await ProductService()
            .update(p, expectedUpdatedAt: widget.product!.updatedAt);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product "${p.name}" saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _confirmCancel();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.product == null
                ? 'List New Product'
                : 'Update Product Details'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: _confirmCancel,
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : _confirmCancel,
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (photoError &&
                              photo == null &&
                              (widget.product?.imageUrl.isEmpty ?? true))
                          ? Colors.red
                          : Colors.grey.shade300,
                      width: (photoError &&
                              photo == null &&
                              (widget.product?.imageUrl.isEmpty ?? true))
                          ? 2
                          : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: photo != null
                          ? Image.file(photo!, fit: BoxFit.cover)
                          : (widget.product?.imageUrl.isNotEmpty == true)
                              ? ProductImage(widget.product!.imageUrl)
                              : Container(
                                  color: const Color(0xFFF8F9FA),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 52,
                                        color: HhColors.muted,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'No photo selected',
                                        style: TextStyle(
                                          color: HhColors.text,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tap Upload from Gallery below to choose photo',
                                        style: TextStyle(
                                          color: HhColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ),
                if (photoError &&
                    photo == null &&
                    (widget.product?.imageUrl.isEmpty ?? true))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          'Product photo is required. Please upload via Gallery.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : _pickFromGallery,
                      style: FilledButton.styleFrom(
                        backgroundColor: HhColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: Text(
                        photo != null ||
                                (widget.product?.imageUrl.isNotEmpty == true)
                            ? 'Change Photo from Gallery'
                            : 'Upload from Gallery',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (photo != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  photo = null;
                                  photoError = false;
                                }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                HhTextField(
                  controller: name,
                  label: 'Product Name',
                  validator: (s) => s == null || s.trim().isEmpty
                      ? 'Please enter a product name'
                      : null,
                ),
                StreamBuilder<List<Category>>(
                  stream: categories,
                  builder: (context, s) {
                    if (s.hasError) return Text(errorMessage(s.error!));
                    final list = s.data ?? [];
                    final valid =
                        list.any((c) => c.id == category) ? category : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(list.map((c) => c.id).join(',')),
                        initialValue: valid,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: list
                            .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(categoryDisplayName(c.id, c.name))))
                            .toList(),
                        validator: (s) =>
                            s == null ? 'Please select a category' : null,
                        onChanged: _onCategoryChanged,
                      ),
                    );
                  },
                ),
                HhTextField(
                  controller: description,
                  label: 'Description',
                  maxLines: 3,
                  validator: (s) => s == null || s.trim().isEmpty
                      ? 'Please provide a product description'
                      : null,
                ),
                HhTextField(
                  controller: price,
                  label: 'Base Price (\$) per $unit',
                  keyboardType: TextInputType.number,
                  validator: (s) =>
                      int.tryParse(s ?? '') == null || int.parse(s!) <= 0
                          ? 'Price must be a positive integer'
                          : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    key: ValueKey('unit_${category}_$unit'),
                    initialValue: unitDisplayName(unit),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit of Measure',
                    ),
                  ),
                ),
                HhTextField(
                  controller: stock,
                  label: 'Available Quantity ($unit)',
                  keyboardType: TextInputType.number,
                  validator: (s) {
                    if (s == null || s.trim().isEmpty) {
                      return 'Please enter available quantity';
                    }
                    final qty = int.tryParse(s.trim());
                    if (qty == null || qty <= 0) {
                      return 'Quantity must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: busy ? null : _confirmCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: HhButton(
                        label: 'Save Product',
                        busy: busy,
                        onPressed: _promptSave,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      );
}

class FarmerReports extends StatelessWidget {
  final Stream<List<FarmOrder>> stream;
  const FarmerReports({super.key, required this.stream});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FarmOrder>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EmptyView(message: errorMessage(s.error!));
        if (!s.hasData) return const LoadingView();

        final orders = s.data!;
        final completed =
            orders.where((o) => o.status == OrderStatus.completed).toList();
        final totalRevenue = completed.fold<int>(0, (acc, o) => acc + o.total);

        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Sales Report',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard('Total Orders', '${orders.length}')),
              const SizedBox(width: 16),
              Expanded(child: StatCard('Total Revenue', vnd(totalRevenue))),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Completed Sales & Customers',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (completed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No completed sales yet. Check your pending orders!'),
            ),
          for (final order in completed.take(10))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: HhColors.bg,
                  child: Icon(Icons.person, color: HhColors.primaryDark),
                ),
                title: Text(order.customerName),
                subtitle: Text(
                    'Contact: ${order.customerPhone}\nCompleted on: ${DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt)}'),
                trailing: Text(
                  vnd(order.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: HhColors.primary),
                ),
                isThreeLine: true,
              ),
            ),
        ]);
      });
}
