import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import '../location/customer_location.dart';
import '../widgets/save_button.dart';
import 'farmers_screen.dart';
import 'marketplace_screen.dart';
import 'product_detail_sections.dart';

void openSavedItems(BuildContext context, {int initialTab = 0}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SavedScreen(initialTab: initialTab)));
}

class SavedScreen extends StatefulWidget {
  final int initialTab;
  final ProductService? products;
  final ProductDetailsData? details;
  const SavedScreen(
      {super.key, this.initialTab = 0, this.products, this.details});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final ProductService _products = widget.products ?? ProductService();
  late final ProductDetailsData _details =
      widget.details ?? ProductDetailsData();
  final _location = CustomerLocation();

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  void _browse(SavedKind kind) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => kind == SavedKind.farmer
              ? Scaffold(
                  appBar: AppBar(title: const Text('Discover farms')),
                  body: FarmersScreen(location: _location))
              : Scaffold(
                  appBar: AppBar(title: const Text('Explore products')),
                  body: MarketplaceScreen(
                      catalogOnly: true,
                      location: _location,
                      onOpenCart: () {},
                      onOpenOrders: () {},
                      onOpenProfile: () {}))));

  void _open(_SavedEntry entry, SavedKind kind, String id) {
    if (kind == SavedKind.product) {
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: HhColors.bg,
          builder: (_) => FractionallySizedBox(
              heightFactor: .94,
              child: ProductDetailSheet(
                  product: entry.product!,
                  productService: _products,
                  detailsData: _details)));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
              appBar: AppBar(title: Text(entry.name)),
              body: MarketplaceScreen(
                  catalogOnly: true,
                  farmerId: id,
                  farmerName: entry.name,
                  location: _location,
                  onOpenCart: () {},
                  onOpenOrders: () {},
                  onOpenProfile: () {}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedItemsController?>();
    String tabLabel(SavedKind kind, String title) =>
        saved?.loaded(kind) == true && saved?.failed(kind) != true
            ? '$title (${saved!.ids(kind).length})'
            : title;
    return DefaultTabController(
        length: 2,
        initialIndex: widget.initialTab,
        child: Scaffold(
          appBar: AppBar(title: const Text('Saved')),
          body: Column(children: [
            Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: HhColors.primary,
                    borderRadius: BorderRadius.circular(24)),
                child: const Row(children: [
                  Icon(Icons.favorite_rounded,
                      color: HhColors.sageLight, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Your little harvest',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text(
                            'Keep the produce you love and the farms you trust close.',
                            style: TextStyle(
                                color: HhColors.sageLight, height: 1.4)),
                      ])),
                ])),
            TabBar(
                labelColor: HhColors.primary,
                indicatorColor: HhColors.primary,
                tabs: [
                  Tab(text: tabLabel(SavedKind.product, 'Wishlist')),
                  Tab(text: tabLabel(SavedKind.farmer, 'Following')),
                ]),
            Expanded(
                child: TabBarView(children: [
              for (final kind in SavedKind.values) _list(saved, kind),
            ])),
          ]),
        ));
  }

  Widget _list(SavedItemsController? saved, SavedKind kind) {
    if (saved?.signedIn != true) {
      return const _SavedMessage(
          icon: Icons.lock_outline,
          title: 'Make it yours',
          message: 'Sign in to save products and follow your favorite farms.');
    }
    if (saved!.failed(kind)) {
      return _SavedMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your saved items',
          message: 'Check your connection and try again.',
          action: 'Try again',
          onAction: () => saved.retry(kind));
    }
    if (!saved.loaded(kind)) {
      return const Center(child: CircularProgressIndicator());
    }
    final ids = saved.ids(kind);
    if (ids.isEmpty) {
      final product = kind == SavedKind.product;
      return _SavedMessage(
          icon: product ? Icons.favorite_border : Icons.agriculture_outlined,
          title: product
              ? 'A little room for favorites'
              : 'Good food starts with good farms',
          message: product
              ? 'Tap the heart on any product to keep it here for later.'
              : 'Follow a farm to find your way back to its fresh produce.',
          action: product ? 'Explore products' : 'Discover farms',
          onAction: () => _browse(kind));
    }
    return ListView.separated(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 24 + MediaQuery.paddingOf(context).bottom),
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final id = ids[index];
          return _SavedTile(
              key: ValueKey('${kind.name}:$id'),
              id: id,
              kind: kind,
              watch: () => kind == SavedKind.product
                  ? _products.watch(id).map((p) => p == null
                      ? null
                      : _SavedEntry(
                          name: p.name,
                          subtitle: p.farmerName,
                          image: p.imageUrl,
                          active: p.isActive,
                          product: p))
                  : _details.store(id).map((farm) => farm == null
                      ? null
                      : _SavedEntry(
                          name: farm['businessName'] as String? ?? 'Farm store',
                          subtitle: farm['area'] as String? ?? '',
                          image: (farm['coverImageUrl'] ??
                                  farm['imageUrl'] ??
                                  farm['avatarUrl']) as String? ??
                              '',
                          active: farm['isActive'] == true)),
              onOpen: (entry) => _open(entry, kind, id));
        });
  }
}

class _SavedEntry {
  final String name, subtitle, image;
  final bool active;
  final Product? product;
  const _SavedEntry(
      {required this.name,
      required this.subtitle,
      required this.image,
      required this.active,
      this.product});
}

class _SavedTile extends StatefulWidget {
  final String id;
  final SavedKind kind;
  final Stream<_SavedEntry?> Function() watch;
  final ValueChanged<_SavedEntry> onOpen;
  const _SavedTile(
      {super.key,
      required this.id,
      required this.kind,
      required this.watch,
      required this.onOpen});
  @override
  State<_SavedTile> createState() => _SavedTileState();
}

class _SavedTileState extends State<_SavedTile> {
  late Stream<_SavedEntry?> _stream = widget.watch();
  @override
  Widget build(BuildContext context) => StreamBuilder<_SavedEntry?>(
      stream: _stream,
      builder: (context, snapshot) {
        final entry = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final available =
            !snapshot.hasError && !waiting && entry?.active == true;
        final product = entry?.product;
        final title = waiting
            ? 'Loading…'
            : snapshot.hasError
                ? 'Could not load this item'
                : entry?.name ??
                    (widget.kind == SavedKind.product
                        ? 'Unavailable product'
                        : 'Unavailable farm');
        return Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side:
                    BorderSide(color: HhColors.primary.withValues(alpha: .1))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: available ? () => widget.onOpen(entry!) : null,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox.square(
                                        dimension: 76,
                                        child:
                                            detailPhoto(entry?.image ?? ''))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      const SizedBox(height: 5),
                                      if (entry != null)
                                        Text(entry.subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: HhColors.muted)),
                                      if (available && product != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                            '\$${(product.price / 100).toStringAsFixed(2)} / ${product.unit}',
                                            style: const TextStyle(
                                                color: HhColors.primary,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ])),
                                if (widget.kind == SavedKind.product)
                                  SaveButton(
                                      kind: widget.kind,
                                      itemId: widget.id,
                                      allowSave: available),
                              ]),
                          const SizedBox(height: 10),
                          Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (waiting)
                                  const SizedBox(
                                      width: 100,
                                      child: LinearProgressIndicator())
                                else if (snapshot.hasError)
                                  TextButton.icon(
                                      onPressed: () => setState(
                                          () => _stream = widget.watch()),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry details'))
                                else if (!available)
                                  const Text('No longer available',
                                      style: TextStyle(color: HhColors.muted))
                                else if (product != null)
                                  Text(
                                      product.stockQty > 0
                                          ? 'In stock · View product'
                                          : 'Out of stock · Saved for later',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: product.stockQty > 0
                                              ? HhColors.primary
                                              : HhColors.muted))
                                else
                                  TextButton.icon(
                                      onPressed: () => widget.onOpen(entry!),
                                      icon:
                                          const Icon(Icons.storefront_outlined),
                                      label: const Text('View products')),
                                if (widget.kind == SavedKind.farmer)
                                  SaveButton(
                                      kind: widget.kind,
                                      itemId: widget.id,
                                      allowSave: available),
                              ]),
                        ]))));
      });
}

class _SavedMessage extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  const _SavedMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.action,
      this.onAction});
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
                radius: 38,
                backgroundColor: HhColors.sageLight,
                child: Icon(icon, size: 34, color: HhColors.primary)),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HhColors.muted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ])));
}
