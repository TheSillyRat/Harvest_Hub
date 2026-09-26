import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'main.dart';

String formatPrice(num amount) => '\$$amount';
String vnd(num amount) => formatPrice(amount);

void openPage(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

Future<void> perform(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      showError(context, e);
    }
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(errorMessage(error)),
      backgroundColor: HhColors.danger,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String errorMessage(Object error) {
  final str = error.toString();
  return str
      .replaceAll('Exception: ', '')
      .replaceAll('StateError: ', '')
      .replaceAll(RegExp(r'\[.*?\]'), '')
      .trim();
}

String? nonNegativeInt(String? s) {
  final parsed = int.tryParse(s ?? '');
  if (parsed == null || parsed < 0) {
    return 'Enter a non-negative number';
  }
  return null;
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;

  const StatCard(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: HhColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                color: HhColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final Widget? action;

  const EmptyView({
    super.key,
    this.message = 'No data available',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco_outlined, size: 52, color: HhColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class DataList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext, List<T>) builder;
  final String empty;

  const DataList({
    super.key,
    required this.stream,
    required this.builder,
    this.empty = 'No data available',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EmptyView(message: errorMessage(s.error!));
        if (!s.hasData) return const LoadingView();
        if (s.data!.isEmpty) return EmptyView(message: empty);
        return builder(context, s.data!);
      },
    );
  }
}

class ProductImage extends StatelessWidget {
  final String url;

  const ProductImage(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFE8F5E9),
        child: const Center(
          child: Icon(Icons.eco, size: 28, color: HhColors.primary),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE8F5E9),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 24, color: HhColors.muted),
          ),
        ),
      ),
    );
  }
}

class PriceText extends StatelessWidget {
  final num price;

  const PriceText(this.price, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPrice(price),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: HhColors.primary,
        fontSize: 16,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.confirmed => Colors.blue,
      OrderStatus.readyForPickup => Colors.teal,
      OrderStatus.completed => Colors.green,
      _ => Colors.grey,
    };
    final label = OrderStatus.labels[status] ?? status;
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.14),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class HhTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const HhTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator ??
            (val) => val == null || val.trim().isEmpty
                ? 'Please fill in this field'
                : null,
      ),
    );
  }
}

class HhButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const HhButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: HhColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});

  @override
  State<FarmerMainScreen> createState() => _FarmerMainScreenState();
}

class _FarmerMainScreenState extends State<FarmerMainScreen> {
  int index = 0;
  static const titles = [
    'Dashboard',
    'Produce',
    'Orders',
    'Reports',
    'Profile'
  ];

  late final String uid;
  late final Stream<List<FarmOrder>> orders;
  late final Stream<List<Product>> products;

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthController>().user;
    uid = authUser?.uid ?? '';
    orders = OrderService().streamByFarmer(uid);
    products = ProductService().streamByFarmer(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HarvestHub · ${titles[index]}')),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: HhColors.primaryDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco, color: HhColors.accent, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Farmer Hub',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < titles.length; i++)
              ListTile(
                title: Text(titles[i]),
                selected: i == index,
                onTap: () {
                  setState(() => index = i);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              title: const Text('Log Out'),
              leading: const Icon(Icons.logout),
              onTap: () =>
                  perform(context, context.read<AuthController>().logout),
            ),
          ],
        ),
      ),
      body: switch (index) {
        0 => FarmerDashboard(
            products: products,
            orders: orders,
            onNavigate: (i) => setState(() => index = i),
          ),
        1 => FarmerProducts(stream: products),
        2 => OrdersScreen(stream: orders, role: Roles.farmer),
        3 => FarmerReports(stream: orders),
        _ => const FarmerHomeScreen(),
      },
    );
  }
}

class FarmerDashboard extends StatelessWidget {
  final Stream<List<Product>> products;
  final Stream<List<FarmOrder>> orders;
  final ValueChanged<int> onNavigate;

  const FarmerDashboard({
    super.key,
    required this.products,
    required this.orders,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: products,
      builder: (context, p) => StreamBuilder<List<FarmOrder>>(
        stream: orders,
        builder: (context, o) {
          if (p.hasError && o.hasError) {
            return EmptyView(message: errorMessage(p.error ?? o.error!));
          }
          if (!p.hasData && !o.hasData) return const LoadingView();

          final allProducts = p.data ?? const <Product>[];
          final activeProducts =
              allProducts.where((e) => e.isActive).toList();
          final newProducts = activeProducts.take(3).toList();

          final ordersList = o.data ?? const <FarmOrder>[];
          final pendingOrders =
              ordersList.where((e) => e.status == OrderStatus.pending).toList();
          final now = DateTime.now();
          final revenue = ordersList
              .where((e) =>
                  e.status == OrderStatus.completed &&
                  e.updatedAt.year == now.year &&
                  e.updatedAt.month == now.month)
              .fold<int>(0, (runningTotal, e) => runningTotal + e.total);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Welcome back!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('Manage your crops and pickup orders.'),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => onNavigate(1),
                child: StatCard('Active Produce', '${activeProducts.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(2),
                child: StatCard('Pending Orders', '${pendingOrders.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(3),
                child: StatCard('Simulated Revenue (This Month)', formatPrice(revenue)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Added Produce',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('View All'),
                  ),
                ],
              ),
              if (newProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('You have not added any produce yet.'),
                ),
              for (final prod in newProducts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: ProductImage(prod.imageUrl),
                    ),
                    title: Text(prod.name),
                    subtitle: Text(
                      '${formatPrice(prod.price)} / ${prod.unit} · Stock: ${prod.stockQty}',
                    ),
                    onTap: () => openPage(
                      context,
                      ProductFormScreen(product: prod),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0 && mounted) {
      perform(context, () => ProductService().updateStock(p.id, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openPage(context, const ProductFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add Produce'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search produce...',
              ),
              onChanged: (s) => setState(() => search = s.toLowerCase()),
            ),
          ),
          Expanded(
            child: DataList<Product>(
              stream: widget.stream,
              empty: 'List your first produce to start selling',
              builder: (context, products) {
                final items = products
                    .where((p) => p.name.toLowerCase().contains(search))
                    .toList();
                if (items.isEmpty) {
                  return const EmptyView(message: 'No produce found');
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    if (!p.isActive) return const SizedBox.shrink();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: ProductImage(p.imageUrl),
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          '${formatPrice(p.price)} / ${p.unit}\nAvailable Stock: ${p.stockQty}',
                        ),
                        isThreeLine: true,
                        onTap: () => openPage(
                          context,
                          ProductFormScreen(product: p),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Update Inventory',
                              icon: const Icon(Icons.inventory_2_outlined),
                              onPressed: () => _updateStock(p),
                            ),
                            IconButton(
                              tooltip: 'Delete Product',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => perform(
                                context,
                                () => ProductService().setActive(p.id, false),
                              ),
                            ),
                          ],
                        ),
                      ),
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
  late final price =
      TextEditingController(text: widget.product?.price.toString());
  late final stock =
      TextEditingController(text: widget.product?.stockQty.toString() ?? '0');
  late String unit = widget.product?.unit ?? 'kg';
  late String? category = widget.product?.categoryId;
  File? photo;
  bool busy = false;
  final categories = CategoryService().streamActive();

  @override
  void dispose() {
    for (final c in [name, description, price, stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    await perform(context, () async {
      final selected = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (selected != null && mounted) {
        setState(() => photo = File(selected.path));
      }
    });
  }

  void _onCategoryChanged(String? newCat) {
    setState(() {
      category = newCat;
      final allowed = allowedUnitsForCategory(newCat);
      if (!allowed.contains(unit)) {
        unit = allowed.first;
      }
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (category == null) {
      showError(context, 'Please select a category');
      return;
    }
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

      final url = photo == null
          ? widget.product?.imageUrl ?? ''
          : await StorageService().uploadProductImage(uid, photo!);
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
        imageUrl: url,
        isActive: widget.product?.isActive ?? true,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );
      if (widget.product == null) {
        await ProductService().create(p);
      } else {
        await ProductService().update(
          p,
          expectedUpdatedAt: widget.product!.updatedAt,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product == null ? 'List New Produce' : 'Update Produce Details',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: photo == null
                  ? ProductImage(widget.product?.imageUrl ?? '')
                  : Image.file(photo!, fit: BoxFit.cover),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            HhTextField(controller: name, label: 'Produce Name'),
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
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: list
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(categoryDisplayName(c.id, c.name)),
                          ),
                        )
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
              maxLines: 4,
            ),
            HhTextField(
              controller: price,
              label: 'Price (\$)',
              keyboardType: TextInputType.number,
              validator: (s) =>
                  int.tryParse(s ?? '') == null || int.parse(s!) <= 0
                      ? 'Price must be a positive integer'
                      : null,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('unit_${category}_$unit'),
              initialValue: allowedUnitsForCategory(category).contains(unit)
                  ? unit
                  : allowedUnitsForCategory(category).first,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: allowedUnitsForCategory(category)
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(unitDisplayName(u)),
                    ),
                  )
                  .toList(),
              onChanged: allowedUnitsForCategory(category).length > 1
                  ? (s) => setState(() => unit = s!)
                  : null,
            ),
            const SizedBox(height: 14),
            HhTextField(
              controller: stock,
              label: 'Available Quantity (Stock)',
              keyboardType: TextInputType.number,
              validator: nonNegativeInt,
            ),
            HhButton(label: 'Save Produce', busy: busy, onPressed: save),
          ],
        ),
      ),
    );
  }
}

class FarmerReports extends StatelessWidget {
  final Stream<List<FarmOrder>> stream;

  const FarmerReports({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FarmOrder>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EmptyView(message: errorMessage(s.error!));
        if (!s.hasData) return const LoadingView();

        final orders = s.data!;
        final completed =
            orders.where((o) => o.status == OrderStatus.completed).toList();
        final totalRevenue = completed.fold<int>(0, (acc, o) => acc + o.total);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Sales Report',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatCard('Total Orders', '${orders.length}')),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard('Total Revenue', formatPrice(totalRevenue)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Completed Sales & Customers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
                    'Contact: ${order.customerPhone}\nCompleted on: ${DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt)}',
                  ),
                  trailing: Text(
                    formatPrice(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: HhColors.primary,
                    ),
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class OrdersScreen extends StatefulWidget {
  final Stream<List<FarmOrder>> stream;
  final String role;

  const OrdersScreen({super.key, required this.stream, required this.role});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: status == null,
                  onSelected: (_) => setState(() => status = null),
                ),
              ),
              ...OrderStatus.labels.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: status == e.key,
                    onSelected: (_) => setState(() => status = e.key),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DataList<FarmOrder>(
            stream: widget.stream,
            empty: 'No orders available',
            builder: (context, orders) {
              final filtered = orders
                  .where((o) => status == null || o.status == status)
                  .toList();
              if (filtered.isEmpty) {
                return const EmptyView(message: 'No orders in this status');
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final o = filtered[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(
                        widget.role == Roles.customer
                            ? o.farmerName
                            : o.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '#${o.id.substring(0, o.id.length > 8 ? 8 : o.id.length)} · ${DateFormat('dd/MM/yyyy HH:mm').format(o.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HhColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StatusChip(o.status),
                              const Spacer(),
                              PriceText(o.total),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openPage(
                        context,
                        OrderDetailScreen(id: o.id, role: widget.role),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final String id;
  final String role;

  const OrderDetailScreen({super.key, required this.id, required this.role});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final stream = OrderService().watch(widget.id);
  bool busy = false;

  Future<void> change(Future<void> Function() action, {bool cancel = false}) async {
    if (cancel) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cancel Order?'),
          content: const Text(
            'Ordered quantities will be returned to inventory stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    await perform(context, action);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: StreamBuilder<FarmOrder?>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError) return EmptyView(message: errorMessage(s.error!));
          if (s.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (s.data == null) {
            return const EmptyView(message: 'Order not found');
          }
          final o = s.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Order ID: #${o.id}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(o.status),
              ),
              const SizedBox(height: 12),
              Text(
                'Customer: ${o.customerName} · ${o.customerPhone}',
                style: const TextStyle(fontSize: 15),
              ),
              Text(
                'Address: ${o.address}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Pickup slot: ${pickupSlots[o.pickupSlot] ?? o.pickupSlot} · ${DateFormat('dd/MM/yyyy').format(o.pickupDate)}',
                style: const TextStyle(fontSize: 14, color: HhColors.muted),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ...o.items.map(
                (i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.name),
                  subtitle: Text('${i.qty} ${i.unit} × ${formatPrice(i.price)}'),
                  trailing: Text(
                    formatPrice(i.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  PriceText(o.total),
                ],
              ),
              const SizedBox(height: 24),
              if (widget.role != Roles.customer &&
                  OrderStatus.next.containsKey(o.status)) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => change(
                              () => OrderService().advanceStatus(o.id),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Mark as ${OrderStatus.labels[OrderStatus.next[o.status]] ?? OrderStatus.next[o.status]}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (OrderStatus.canCancel(o.status))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => change(
                              () => OrderService().cancel(o.id),
                              cancel: true,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
