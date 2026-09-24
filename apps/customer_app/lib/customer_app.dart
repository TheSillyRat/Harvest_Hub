import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProxyProvider<AuthController, CartController>(
          create: (_) => CartController(),
          update: (_, auth, cart) => cart!..bind(auth.user?.uid),
          child: const CustomerShell());
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;
  late final orders =
      OrderService().streamByCustomer(context.read<AuthController>().user!.uid);
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    return Scaffold(
        appBar: AppBar(title: const Text('HarvestHub'), actions: [
          IconButton(
              onPressed: () => setState(() => index = 1),
              icon: Badge(
                  label: Text('${cart.quantity}'),
                  isLabelVisible: cart.quantity > 0,
                  child: const Icon(Icons.shopping_basket_outlined))),
        ]),
        body: IndexedStack(index: index, children: [
          const CatalogScreen(),
          CartScreen(onCheckout: () async {
            final auth = context.read<AuthController>();
            final done = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                        value: cart,
                        child: ChangeNotifierProvider.value(
                            value: auth, child: const CheckoutScreen()))));
            if (done == true && mounted) setState(() => index = 2);
          }),
          OrdersScreen(stream: orders, role: Roles.customer),
          ProfileScreen(extra: [
            ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Yêu thích'),
                onTap: () => openPage(context, const WishlistScreen())),
            ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Trợ lý nông sản'),
                onTap: () => openPage(context, const ChatbotScreen())),
            ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Về HarvestHub'),
                onTap: () => openPage(context, const AboutScreen())),
            ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Liên hệ'),
                onTap: () => openPage(context, const ContactScreen())),
          ]),
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
              NavigationDestination(
                  icon: Icon(Icons.shopping_basket_outlined), label: 'Giỏ'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined), label: 'Đơn hàng'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'Tôi'),
            ]));
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final categories = CategoryService().streamActive();
  final products = ProductService();
  late Stream<List<Product>> stream = products.streamActiveProducts();
  String search = '';
  String? category;
  void refresh() => stream =
      products.streamActiveProducts(categoryId: category, search: search);
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: HhColors.primaryDark,
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Tươi từ vườn,\nngon mỗi ngày',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Chọn nông sản • Đặt trước • Đến lấy',
                        style: TextStyle(color: Colors.white70)),
                  ])),
              Icon(Icons.eco_outlined, size: 60, color: HhColors.accent)
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Tìm nông sản bạn cần',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (s) => setState(() {
                      search = s;
                      refresh();
                    }))),
        SizedBox(
            height: 64,
            child: StreamBuilder<List<Category>>(
                stream: categories,
                builder: (context, s) {
                  if (s.hasError) return Text(errorMessage(s.error!));
                  return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(10),
                      children: [
                        ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: category == null,
                            onSelected: (_) => setState(() {
                                  category = null;
                                  refresh();
                                })),
                        ...?s.data?.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                                label: Text(c.name),
                                selected: category == c.id,
                                onSelected: (_) => setState(() {
                                      category = c.id;
                                      refresh();
                                    })))),
                      ]);
                })),
        Expanded(
            child: DataList<Product>(
                stream: stream,
                empty: 'Chưa tìm thấy nông sản phù hợp',
                builder: (context, items) => ProductGrid(items: items))),
      ]);
}

class ProductGrid extends StatelessWidget {
  final List<Product> items;
  const ProductGrid({super.key, required this.items});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) => GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: (constraints.maxWidth - 30) / 2 + MediaQuery.textScalerOf(context).scale(150),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6),
      itemBuilder: (context, i) => ProductCard(
          product: items[i],
          onTap: () =>
              openPage(context, ProductDetailScreen(id: items[i].id)))));
}

class ProductDetailScreen extends StatefulWidget {
  final String id;
  const ProductDetailScreen({super.key, required this.id});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int qty = 1;
  bool busy = false;
  late final stream = ProductService().watch(widget.id);
  late final wishlist =
      WishlistService().stream(context.read<AuthController>().user!.uid);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Chi tiết nông sản')),
      body: StreamBuilder<Product?>(
          stream: stream,
          builder: (context, s) {
            if (s.hasError) return EmptyView(message: errorMessage(s.error!));
            if (s.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (s.data == null || !s.data!.isActive) {
              return const EmptyView(message: 'Sản phẩm tạm ngừng bán');
            }
            final p = s.data!;
            final available = p.stockQty > 0;
            final count = available ? qty.clamp(1, p.stockQty) : 0;
            return ListView(padding: const EdgeInsets.all(20), children: [
              AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ProductImage(p.imageUrl))),
              const SizedBox(height: 16),
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                      avatar: const Icon(Icons.eco, size: 18),
                      label: Text(p.farmerName))),
              PriceText(p.price),
              Text(
                  'Đơn vị: ${p.unit} · ${available ? 'Còn ${p.stockQty}' : 'Hết hàng'}'),
              const SizedBox(height: 16),
              Text(p.description),
              const SizedBox(height: 16),
              const Text(pickupNotice),
              Row(children: [
                IconButton(
                    onPressed: count > 1
                        ? () => setState(() => qty = count - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$count'),
                IconButton(
                    onPressed: available && count < p.stockQty
                        ? () => setState(() => qty = count + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline)),
                const Spacer(),
                StreamBuilder<Set<String>>(
                    stream: wishlist,
                    builder: (context, saved) {
                      final isSaved = saved.data?.contains(p.id) ?? false;
                      return IconButton(
                          icon: Icon(
                              isSaved ? Icons.favorite : Icons.favorite_border,
                              color: HhColors.danger),
                          tooltip: 'Yêu thích',
                          onPressed: () => perform(
                              context,
                              () => WishlistService().toggle(
                                  context.read<AuthController>().user!.uid,
                                  p.id,
                                  isSaved)));
                    }),
              ]),
              HhButton(
                  label: available ? 'Thêm giỏ' : 'Hết hàng',
                  busy: busy,
                  onPressed: !available
                      ? null
                      : () async {
                          setState(() => busy = true);
                          await perform(
                              context,
                              () => CartService().add(
                                  context.read<AuthController>().user!.uid,
                                  p,
                                  count),
                              success: 'Đã thêm vào giỏ');
                          if (mounted) setState(() => busy = false);
                        }),
            ]);
          }));
}

class CartScreen extends StatelessWidget {
  final VoidCallback onCheckout;
  const CartScreen({super.key, required this.onCheckout});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    if (cart.error != null) {
      return EmptyView(message: errorMessage(cart.error!));
    }
    if (cart.items.isEmpty) {
      return const EmptyView(
          message: 'Giỏ hàng đang trống. Chọn nông sản ở Trang chủ nhé!');
    }
    return Column(children: [
      Expanded(
          child: ListView(
              children: cart.items
                  .map((i) => Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.farmerName,
                                    style: const TextStyle(
                                        color: HhColors.primary)),
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(i.name),
                                    subtitle:
                                        Text('${vnd(i.price)} / ${i.unit}'),
                                    trailing: IconButton(
                                        tooltip: 'Xóa',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => perform(
                                            context,
                                            () => cart.service.remove(
                                                cart.uid!, i.productId)))),
                                Row(children: [
                                  IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                      onPressed: () => perform(
                                          context,
                                          () => cart.service.changeQty(
                                              cart.uid!,
                                              i.productId,
                                              i.qty - 1))),
                                  Text('${i.qty}'),
                                  IconButton(
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                      onPressed: () => perform(
                                          context,
                                          () => cart.service.changeQty(
                                              cart.uid!,
                                              i.productId,
                                              i.qty + 1))),
                                  const Spacer(),
                                  PriceText(i.subtotal),
                                ]),
                              ]))))
                  .toList())),
      Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            PriceText(cart.total),
            const SizedBox(height: 12),
            HhButton(label: 'Tiếp tục đặt hàng', onPressed: onCheckout),
          ])),
    ]);
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final form = GlobalKey<FormState>();
  late final address =
      TextEditingController(text: context.read<AuthController>().user!.address);
  String? slot;
  bool busy = false;
  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    return Scaffold(
        appBar: AppBar(title: const Text('Đặt hàng')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text(simulationNotice,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Text(pickupNotice),
              const SizedBox(height: 16),
              ...cart.items.map((i) => ListTile(
                  title: Text('${i.name} × ${i.qty}'),
                  subtitle: Text(i.farmerName),
                  trailing: Text(vnd(i.subtotal)))),
              const Divider(),
              HhTextField(controller: address, label: 'Địa chỉ liên hệ'),
              DropdownButtonFormField<String>(
                  initialValue: slot,
                  decoration: const InputDecoration(
                      labelText: 'Khung giờ nhận tại điểm bán'),
                  items: pickupSlots.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  validator: (s) =>
                      s == null ? 'Vui lòng chọn khung giờ' : null,
                  onChanged: busy ? null : (s) => setState(() => slot = s)),
              const SizedBox(height: 20),
              Text(
                  'Số gian hàng: ${cart.items.map((i) => i.farmerId).toSet().length}'),
              PriceText(cart.total),
              const SizedBox(height: 16),
              HhButton(
                  label: 'Đặt hàng (mô phỏng)',
                  busy: busy,
                  onPressed: cart.items.isEmpty
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final items = List<CartItem>.of(cart.items);
                          setState(() => busy = true);
                          try {
                            await OrderService().placeOrders(
                                cart.uid!, items, address.text, slot!);
                            if (context.mounted) Navigator.pop(context, true);
                          } on PartialCheckoutException catch (e) {
                            if (context.mounted) {
                              showError(context, e);
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        }),
            ])));
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final wishlist =
      WishlistService().stream(context.read<AuthController>().user!.uid);
  final products = ProductService().streamActiveProducts();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Yêu thích')),
      body: StreamBuilder<Set<String>>(
          stream: wishlist,
          builder: (context, saved) {
            if (saved.hasError) {
              return EmptyView(message: errorMessage(saved.error!));
            }
            if (!saved.hasData) return const LoadingView();
            return DataList<Product>(
                stream: products,
                builder: (context, all) {
                  final selected =
                      all.where((p) => saved.data!.contains(p.id)).toList();
                  return selected.isEmpty
                      ? const EmptyView(
                          message: 'Chưa có sản phẩm yêu thích đang bán')
                      : ProductGrid(items: selected);
                });
          }));
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <({bool bot, String text})>[
    (bot: true, text: FaqService.greeting)
  ];
  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add((bot: false, text: text));
      messages.add((bot: true, text: FaqService().answer(text)));
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Trợ lý nông sản')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Thông tin tham khảo, không thay lời bác sĩ.',
                style: TextStyle(color: HhColors.muted))),
        Expanded(
            child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) => Align(
                    alignment: messages[i].bot
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                            color: messages[i].bot
                                ? Colors.white
                                : const Color(0xFFDCEED8),
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(messages[i].text))))),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: input,
                          decoration: const InputDecoration(
                              hintText: 'Hỏi về nông sản...'),
                          onSubmitted: (_) => send())),
                  IconButton(
                      onPressed: send,
                      icon: const Icon(Icons.send, color: HhColors.primary)),
                ]))),
      ]));
}
