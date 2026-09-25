import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';

class FarmerApp extends StatefulWidget {
  const FarmerApp({super.key});
  @override
  State<FarmerApp> createState() => _FarmerAppState();
}

class _FarmerAppState extends State<FarmerApp> {
  int index = 0;
  static const titles = [
    'Dashboard',
    'Produce',
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
      {super.key, required this.products, required this.orders, required this.onNavigate});
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
            final activeProducts = allProducts.where((e) => e.isActive).toList();
            final newProducts = activeProducts.take(3).toList(); // Lấy 3 SP mới nhất (đã sort by createdAt descending trong Service)

            final pendingOrders = o.data!.where((e) => e.status == OrderStatus.pending).toList();
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
                onTap: () => onNavigate(1), // Chuyển tới tab Sản phẩm
                child: StatCard('Active Produce', '${activeProducts.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(2), // Chuyển tới tab Đơn hàng
                child: StatCard('Pending Orders', '${pendingOrders.length}'),
              ),
              InkWell(
                onTap: () => onNavigate(3), // Chuyển tới tab Báo cáo
                child: StatCard('Simulated Revenue (This Month)', vnd(revenue)),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recently Added Produce', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => onNavigate(1),
                    child: const Text('View All'),
                  )
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
                    leading: SizedBox(width: 48, height: 48, child: ProductImage(prod.imageUrl)),
                    title: Text(prod.name),
                    subtitle: Text('${vnd(prod.price)} / ${prod.unit} · Stock: ${prod.stockQty}'),
                    onTap: () => openPage(context, ProductFormScreen(product: prod)),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
  Widget build(BuildContext context) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openPage(context, const ProductFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Add Produce')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Search produce...'),
                onChanged: (s) => setState(() => search = s.toLowerCase()))),
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
                        if (!p.isActive) return const SizedBox.shrink(); // Hide deleted products
                        return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                                leading: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: ProductImage(p.imageUrl)),
                                title: Text(p.name),
                                subtitle: Text(
                                    '${vnd(p.price)} / ${p.unit}\nAvailable Stock: ${p.stockQty}'),
                                isThreeLine: true,
                                onTap: () => openPage(
                                    context, ProductFormScreen(product: p)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          tooltip: 'Update Inventory',
                                          icon: const Icon(Icons.inventory_2_outlined),
                                          onPressed: () => _updateStock(p)),
                                      IconButton(
                                          tooltip: 'Delete Product',
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => perform(
                                              context,
                                              () => ProductService()
                                                  .setActive(p.id, false))),
                                    ])));
                      });
                })),
      ]));
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

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final uid = context.read<AuthController>().user!.uid;
      final farmer =
          await FirebaseFirestore.instance.collection('farmers').doc(uid).get();
      final url = photo == null
          ? widget.product?.imageUrl ?? ''
          : await StorageService().uploadProductImage(uid, photo!);
      final now = DateTime.now();
      final p = Product(
          id: widget.product?.id ?? '',
          farmerId: uid,
          farmerName: farmer.data()!['businessName'] as String,
          name: name.text.trim(),
          categoryId: category!,
          description: description.text.trim(),
          price: int.parse(price.text),
          unit: unit,
          stockQty: int.parse(stock.text),
          imageUrl: url,
          isActive: widget.product?.isActive ?? true,
          createdAt: widget.product?.createdAt ?? now,
          updatedAt: now);
      if (widget.product == null) {
        await ProductService().create(p);
      } else {
        await ProductService()
            .update(p, expectedUpdatedAt: widget.product!.updatedAt);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.product == null ? 'List New Produce' : 'Update Produce Details')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AspectRatio(
                aspectRatio: 1,
                child: photo == null
                    ? ProductImage(widget.product?.imageUrl ?? '')
                    : Image.file(photo!, fit: BoxFit.cover)),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                      onPressed: busy ? null : () => pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'))),
              Expanded(
                  child: TextButton.icon(
                      onPressed: busy ? null : () => pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera')))
            ]),
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
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: list
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.name)))
                              .toList(),
                          validator: (s) =>
                              s == null ? 'Please select a category' : null,
                          onChanged: (s) => setState(() => category = s)));
                }),
            HhTextField(controller: description, label: 'Description', maxLines: 4),
            HhTextField(
                controller: price,
                label: 'Price (VND)',
                keyboardType: TextInputType.number,
                validator: (s) =>
                    int.tryParse(s ?? '') == null || int.parse(s!) <= 0
                        ? 'Price must be a positive integer'
                        : null),
            DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: productUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (s) => setState(() => unit = s!)),
            const SizedBox(height: 14),
            HhTextField(
                controller: stock,
                label: 'Available Quantity (Stock)',
                keyboardType: TextInputType.number,
                validator: nonNegativeInt),
            HhButton(label: 'Save Produce', busy: busy, onPressed: save),
          ])));
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
        final completed = orders.where((o) => o.status == OrderStatus.completed).toList();
        final totalRevenue = completed.fold<int>(0, (acc, o) => acc + o.total);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Sales Report', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatCard('Total Orders', '${orders.length}')),
                const SizedBox(width: 16),
                Expanded(child: StatCard('Total Revenue', vnd(totalRevenue))),
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent Completed Sales & Customers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (completed.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No completed sales yet. Check your pending orders!'),
              ),
            for (final order in completed.take(10)) // Chỉ lấy 10 đơn hoàn tất gần nhất
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: HhColors.bg,
                    child: Icon(Icons.person, color: HhColors.primaryDark),
                  ),
                  title: Text(order.customerName),
                  subtitle: Text('Contact: ${order.customerPhone}\nCompleted on: ${DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt)}'),
                  trailing: Text(
                    vnd(order.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: HhColors.primary),
                  ),
                  isThreeLine: true,
                ),
              ),
          ]
        );
      });
}
