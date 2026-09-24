import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class FarmerApp extends StatefulWidget {
  const FarmerApp({super.key});
  @override
  State<FarmerApp> createState() => _FarmerAppState();
}

class _FarmerAppState extends State<FarmerApp> {
  int index = 0;
  static const titles = [
    'Tổng quan',
    'Sản phẩm',
    'Đơn hàng',
    'Báo cáo',
    'Hồ sơ'
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
              Text('Gian hàng nông dân',
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
            title: const Text('Đăng xuất'),
            leading: const Icon(Icons.logout),
            onTap: () =>
                perform(context, context.read<AuthController>().logout)),
      ])),
      body: switch (index) {
        0 => FarmerDashboard(products: products, orders: orders),
        1 => FarmerProducts(stream: products),
        2 => OrdersScreen(stream: orders, role: Roles.farmer),
        3 => FarmerReports(stream: orders),
        _ => const ProfileScreen(),
      });
}

class FarmerDashboard extends StatelessWidget {
  final Stream<List<Product>> products;
  final Stream<List<FarmOrder>> orders;
  const FarmerDashboard(
      {super.key, required this.products, required this.orders});
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
            final now = DateTime.now();
            final revenue = o.data!
                .where((e) =>
                    e.status == OrderStatus.completed &&
                    e.updatedAt.year == now.year &&
                    e.updatedAt.month == now.month)
                .fold<int>(0, (runningTotal, e) => runningTotal + e.total);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Chào ngày mới!',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Text('Quản lý mùa vụ và đơn nhận tại điểm bán'),
              const SizedBox(height: 16),
              StatCard('Sản phẩm đang bán',
                  '${p.data!.where((e) => e.isActive).length}'),
              StatCard('Đơn chờ xác nhận',
                  '${o.data!.where((e) => e.status == OrderStatus.pending).length}'),
              StatCard('Doanh thu mô phỏng tháng này', vnd(revenue)),
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
  @override
  Widget build(BuildContext context) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openPage(context, const ProductFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Thêm sản phẩm')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Tìm sản phẩm'),
                onChanged: (s) => setState(() => search = s.toLowerCase()))),
        Expanded(
            child: DataList<Product>(
                stream: widget.stream,
                empty: 'Tạo sản phẩm đầu tiên cho gian hàng',
                builder: (context, products) {
                  final items = products
                      .where((p) => p.name.toLowerCase().contains(search))
                      .toList();
                  if (items.isEmpty) {
                    return const EmptyView(message: 'Không tìm thấy sản phẩm');
                  }
                  return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final p = items[i];
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
                                    '${vnd(p.price)} · Còn ${p.stockQty} · ${p.isActive ? 'Đang bán' : 'Đã ẩn'}'),
                                onTap: () => openPage(
                                    context, ProductFormScreen(product: p)),
                                trailing: IconButton(
                                    tooltip: p.isActive
                                        ? 'Ẩn sản phẩm'
                                        : 'Hiện sản phẩm',
                                    icon: Icon(p.isActive
                                        ? Icons.visibility
                                        : Icons.visibility_off),
                                    onPressed: () => perform(
                                        context,
                                        () => ProductService()
                                            .setActive(p.id, !p.isActive)))));
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
          title:
              Text(widget.product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm')),
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
                      label: const Text('Thư viện'))),
              Expanded(
                  child: TextButton.icon(
                      onPressed: busy ? null : () => pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Chụp ảnh')))
            ]),
            HhTextField(controller: name, label: 'Tên sản phẩm'),
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
                              const InputDecoration(labelText: 'Danh mục'),
                          items: list
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.name)))
                              .toList(),
                          validator: (s) =>
                              s == null ? 'Chọn danh mục đang hoạt động' : null,
                          onChanged: (s) => setState(() => category = s)));
                }),
            HhTextField(controller: description, label: 'Mô tả', maxLines: 4),
            HhTextField(
                controller: price,
                label: 'Giá (VND)',
                keyboardType: TextInputType.number,
                validator: (s) =>
                    int.tryParse(s ?? '') == null || int.parse(s!) <= 0
                        ? 'Giá phải là số nguyên lớn hơn 0'
                        : null),
            DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Đơn vị'),
                items: productUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (s) => setState(() => unit = s!)),
            const SizedBox(height: 14),
            HhTextField(
                controller: stock,
                label: 'Tồn kho',
                keyboardType: TextInputType.number,
                validator: nonNegativeInt),
            HhButton(label: 'Lưu sản phẩm', busy: busy, onPressed: save),
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
        final completed =
            orders.where((o) => o.status == OrderStatus.completed);
        final now = DateTime.now();
        final days = List.generate(
            7,
            (i) => DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: 6 - i)));
        final values = days
            .map((day) => completed
                .where((o) =>
                    !o.updatedAt.isBefore(day) &&
                    o.updatedAt.isBefore(day.add(const Duration(days: 1))))
                .fold<int>(0, (runningTotal, o) => runningTotal + o.total))
            .toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          StatCard('Tổng đơn', '${orders.length}'),
          StatCard(
              'Doanh thu mô phỏng hoàn tất',
              vnd(completed.fold<int>(
                  0, (runningTotal, o) => runningTotal + o.total))),
          const SizedBox(height: 20),
          const Text('Doanh thu 7 ngày gần nhất (nghìn đồng)'),
          const SizedBox(height: 16),
          SizedBox(
              height: 260,
              child: BarChart(BarChartData(
                barGroups: List.generate(
                    7,
                    (i) => BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                              toY: values[i] / 1000,
                              color: HhColors.primary,
                              width: 20)
                        ])),
                titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              return Text(i >= 0 && i < 7
                                  ? '${days[i].day}/${days[i].month}'
                                  : '');
                            }))),
              ))),
          if (orders.isEmpty)
            const EmptyView(message: 'Báo cáo sẽ cập nhật khi có đơn hàng'),
        ]);
      });
}
