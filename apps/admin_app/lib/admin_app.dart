import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});
  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  int index = 0;
  static const titles = [
    'Tổng quan',
    'Người dùng',
    'Nông dân',
    'Danh mục',
    'Sản phẩm',
    'Đơn hàng',
    'Liên hệ'
  ];
  final users = UserAdminService().streamUsers();
  final farmers = UserAdminService().streamFarmers();
  final categories = CategoryService().streamAll();
  final products = ProductService().streamAll();
  final orders = OrderService().streamAll();
  final contacts = ContactService().stream();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('HarvestHub · ${titles[index]}')),
      drawer: Drawer(
          child: ListView(children: [
        const DrawerHeader(
            decoration: BoxDecoration(color: HhColors.primaryDark),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 48, color: HhColors.accent),
              SizedBox(height: 12),
              Text('Quản trị HarvestHub',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ])),
        for (var i = 0; i < titles.length; i++)
          ListTile(
              title: Text(titles[i]),
              selected: index == i,
              onTap: () {
                setState(() => index = i);
                Navigator.pop(context);
              }),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () =>
                perform(context, context.read<AuthController>().logout)),
      ])),
      body: switch (index) {
        0 => AdminDashboard(users: users, orders: orders),
        1 => AdminUsers(stream: users),
        2 => AdminFarmers(stream: farmers),
        3 => AdminCategories(stream: categories),
        4 => AdminProducts(stream: products),
        5 => OrdersScreen(stream: orders, role: Roles.admin),
        _ => AdminContacts(stream: contacts),
      });
}

class AdminDashboard extends StatelessWidget {
  final Stream<List<AppUser>> users;
  final Stream<List<FarmOrder>> orders;
  const AdminDashboard({super.key, required this.users, required this.orders});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
      stream: users,
      builder: (context, u) => StreamBuilder<List<FarmOrder>>(
          stream: orders,
          builder: (context, o) {
            if (u.hasError || o.hasError) {
              return EmptyView(message: errorMessage(u.error ?? o.error!));
            }
            if (!u.hasData || !o.hasData) return const LoadingView();
            final now = DateTime.now();
            final days = List.generate(
                7,
                (i) => DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: 6 - i)));
            final counts = days
                .map((day) => o.data!
                    .where((order) =>
                        !order.createdAt.isBefore(day) &&
                        order.createdAt
                            .isBefore(day.add(const Duration(days: 1))))
                    .length)
                .toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Toàn cảnh HarvestHub',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Text('Số liệu đặt hàng mô phỏng'),
              const SizedBox(height: 12),
              StatCard('Tổng khách hàng',
                  '${u.data!.where((e) => e.role == Roles.customer).length}'),
              StatCard('Tổng nông dân',
                  '${u.data!.where((e) => e.role == Roles.farmer).length}'),
              StatCard('Tổng đơn', '${o.data!.length}'),
              StatCard(
                  'Doanh thu mô phỏng hoàn tất',
                  vnd(o.data!
                      .where((e) => e.status == OrderStatus.completed)
                      .fold<int>(
                          0, (runningTotal, e) => runningTotal + e.total))),
              const SizedBox(height: 20),
              const Text('Đơn hàng trong 7 ngày gần nhất'),
              const SizedBox(height: 16),
              SizedBox(
                  height: 240,
                  child: BarChart(BarChartData(
                    barGroups: List.generate(
                        7,
                        (i) => BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                  toY: counts[i].toDouble(),
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
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  return Text(i >= 0 && i < 7
                                      ? '${days[i].day}/${days[i].month}'
                                      : '');
                                }))),
                  ))),
            ]);
          }));
}

class SearchHeader extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchHeader({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
          decoration: InputDecoration(
              hintText: hint, prefixIcon: const Icon(Icons.search)),
          onChanged: (s) => onChanged(s.toLowerCase().trim())));
}

class AdminUsers extends StatefulWidget {
  final Stream<List<AppUser>> stream;
  const AdminUsers({super.key, required this.stream});
  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  String search = '';
  String? role;
  final pending = <String>{};
  @override
  Widget build(BuildContext context) => Column(children: [
        SearchHeader(
            hint: 'Tìm theo tên hoặc email',
            onChanged: (s) => setState(() => search = s)),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Tất cả'),
              selected: role == null,
              onSelected: (_) => setState(() => role = null)),
          for (final r in [Roles.customer, Roles.farmer, Roles.admin])
            ChoiceChip(
                label: Text(r == Roles.customer
                    ? 'Khách hàng'
                    : r == Roles.farmer
                        ? 'Nông dân'
                        : 'Quản trị'),
                selected: role == r,
                onSelected: (_) => setState(() => role = r)),
        ]),
        Expanded(
            child: DataList<AppUser>(
                stream: widget.stream,
                builder: (context, all) {
                  final users = all
                      .where((u) =>
                          (role == null || role == u.role) &&
                          '${u.name} ${u.email}'.toLowerCase().contains(search))
                      .toList();
                  if (users.isEmpty) {
                    return const EmptyView(
                        message: 'Không tìm thấy người dùng');
                  }
                  final me = context.read<AuthController>().user!.uid;
                  return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final u = users[i];
                        return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                                title: Text(u.name),
                                subtitle: Text(
                                    '${u.email}\n${u.role == Roles.customer ? 'Khách hàng' : u.role == Roles.farmer ? 'Nông dân' : 'Quản trị'}'),
                                isThreeLine: true,
                                trailing: Switch(
                                    value: u.isActive,
                                    onChanged: u.uid == me ||
                                            pending.contains(u.uid)
                                        ? null
                                        : (value) async {
                                            setState(() => pending.add(u.uid));
                                            await perform(
                                                context,
                                                () => UserAdminService()
                                                    .setIsActive(u, value));
                                            if (mounted) {
                                              setState(
                                                  () => pending.remove(u.uid));
                                            }
                                          })));
                      });
                })),
      ]);
}

class AdminFarmers extends StatefulWidget {
  final Stream<List<FarmerProfile>> stream;
  const AdminFarmers({super.key, required this.stream});
  @override
  State<AdminFarmers> createState() => _AdminFarmersState();
}

class _AdminFarmersState extends State<AdminFarmers> {
  String search = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        SearchHeader(
            hint: 'Tìm gian hàng hoặc khu vực',
            onChanged: (s) => setState(() => search = s)),
        Expanded(
            child: DataList<FarmerProfile>(
                stream: widget.stream,
                builder: (context, all) {
                  final farmers = all
                      .where((f) => '${f.businessName} ${f.area}'
                          .toLowerCase()
                          .contains(search))
                      .toList();
                  if (farmers.isEmpty) {
                    return const EmptyView(message: 'Không tìm thấy gian hàng');
                  }
                  return ListView(
                      children: farmers
                          .map((f) => Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ExpansionTile(
                                  leading:
                                      const Icon(Icons.storefront_outlined),
                                  title: Text(f.businessName),
                                  subtitle: Text(
                                      '${f.area} · ${f.isActive ? 'Đang hoạt động' : 'Đã khóa'}'),
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(f.description)),
                                    Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text('UID: ${f.userId}'))
                                  ])))
                          .toList());
                })),
      ]);
}

class AdminCategories extends StatefulWidget {
  final Stream<List<Category>> stream;
  const AdminCategories({super.key, required this.stream});
  @override
  State<AdminCategories> createState() => _AdminCategoriesState();
}

class _AdminCategoriesState extends State<AdminCategories> {
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openPage(context, const CategoryForm()),
          icon: const Icon(Icons.add),
          label: const Text('Thêm danh mục')),
      body: Column(children: [
        SearchHeader(
            hint: 'Tìm danh mục', onChanged: (s) => setState(() => search = s)),
        Expanded(
            child: DataList<Category>(
                stream: widget.stream,
                builder: (context, all) {
                  final categories = all
                      .where((c) => c.name.toLowerCase().contains(search))
                      .toList();
                  if (categories.isEmpty) {
                    return const EmptyView(message: 'Không tìm thấy danh mục');
                  }
                  return ListView(
                      padding: const EdgeInsets.only(bottom: 90),
                      children: categories
                          .map((c) => ListTile(
                              leading:
                                  CircleAvatar(child: Text('${c.sortOrder}')),
                              title: Text(c.name),
                              subtitle:
                                  Text(c.isActive ? 'Đang hiển thị' : 'Đã ẩn'),
                              onTap: () =>
                                  openPage(context, CategoryForm(category: c)),
                              trailing: IconButton(
                                  tooltip: c.isActive
                                      ? 'Ẩn danh mục'
                                      : 'Hiện danh mục',
                                  icon: Icon(c.isActive
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => perform(
                                      context,
                                      () => CategoryService().save(
                                          c.copyWith(isActive: !c.isActive))))))
                          .toList());
                })),
      ]));
}

class CategoryForm extends StatefulWidget {
  final Category? category;
  const CategoryForm({super.key, this.category});
  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.category?.name);
  late final sort =
      TextEditingController(text: widget.category?.sortOrder.toString() ?? '0');
  late bool active = widget.category?.isActive ?? true;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(widget.category == null ? 'Thêm danh mục' : 'Sửa danh mục')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            HhTextField(controller: name, label: 'Tên danh mục'),
            HhTextField(
                controller: sort,
                label: 'Thứ tự hiển thị',
                keyboardType: TextInputType.number,
                validator: nonNegativeInt),
            SwitchListTile(
                title: const Text('Đang hiển thị'),
                value: active,
                onChanged: (v) => setState(() => active = v)),
            HhButton(
                label: 'Lưu danh mục',
                busy: busy,
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => busy = true);
                  try {
                    await CategoryService().save(Category(
                        id: widget.category?.id ?? '',
                        name: name.text.trim(),
                        imageUrl: widget.category?.imageUrl ?? '',
                        sortOrder: int.parse(sort.text),
                        isActive: active));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }),
          ])));
}

class AdminProducts extends StatefulWidget {
  final Stream<List<Product>> stream;
  const AdminProducts({super.key, required this.stream});
  @override
  State<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends State<AdminProducts> {
  String search = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        SearchHeader(
            hint: 'Tìm sản phẩm hoặc nông dân',
            onChanged: (s) => setState(() => search = s)),
        Expanded(
            child: DataList<Product>(
                stream: widget.stream,
                builder: (context, all) {
                  final products = all
                      .where((p) => '${p.name} ${p.farmerName}'
                          .toLowerCase()
                          .contains(search))
                      .toList();
                  if (products.isEmpty) {
                    return const EmptyView(message: 'Không tìm thấy sản phẩm');
                  }
                  return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, i) {
                        final p = products[i];
                        return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                                leading: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: ProductImage(p.imageUrl)),
                                title: Text(p.name),
                                subtitle: Text(
                                    '${p.farmerName}\n${vnd(p.price)} · Còn ${p.stockQty}'),
                                isThreeLine: true,
                                trailing: Switch(
                                    value: p.isActive,
                                    onChanged: (v) => perform(
                                        context,
                                        () => ProductService()
                                            .setActive(p.id, v)))));
                      });
                })),
      ]);
}

class AdminContacts extends StatefulWidget {
  final Stream<List<ContactMessage>> stream;
  const AdminContacts({super.key, required this.stream});
  @override
  State<AdminContacts> createState() => _AdminContactsState();
}

class _AdminContactsState extends State<AdminContacts> {
  String search = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        SearchHeader(
            hint: 'Tìm theo email hoặc chủ đề',
            onChanged: (s) => setState(() => search = s)),
        Expanded(
            child: DataList<ContactMessage>(
                stream: widget.stream,
                empty: 'Chưa có liên hệ',
                builder: (context, all) {
                  final messages = all
                      .where((m) => '${m.email} ${m.subject}'
                          .toLowerCase()
                          .contains(search))
                      .toList();
                  if (messages.isEmpty) {
                    return const EmptyView(message: 'Không tìm thấy liên hệ');
                  }
                  return ListView(
                      children: messages
                          .map((m) => Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ExpansionTile(
                                  title: Text(m.subject),
                                  subtitle: Text('${m.name} · ${m.email}'),
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: SelectableText(m.message))
                                  ])))
                          .toList());
                })),
      ]);
}
