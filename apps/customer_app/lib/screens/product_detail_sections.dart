import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/save_button.dart';

Future<void> callFarmerPhone(BuildContext context, String rawPhone, {String? farmerName}) async {
  final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  final phoneToUse = cleanPhone.isNotEmpty ? cleanPhone : '02837381816';

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded, color: HhColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    farmerName != null && farmerName.isNotEmpty ? 'Call $farmerName' : 'Call Farm Store',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the phone bar below to open your phone dialer app.',
              style: TextStyle(
                fontSize: 12.5,
                color: HhColors.text.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: phoneToUse));
                final uri = Uri(scheme: 'tel', path: phoneToUse);
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (context.mounted) {
                    TopToast.show(context, 'Copied $phoneToUse & opening phone app...');
                  }
                } catch (_) {
                  if (context.mounted) {
                    TopToast.show(context, 'Copied phone number $phoneToUse');
                  }
                }
              },
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    const Icon(
                      Icons.phone_rounded,
                      size: 28,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.black26,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          phoneToUse,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}


class ProductDetailsData {
  Stream<Map<String, dynamic>?> store(String id) async* {
    yield* FirebaseFirestore.instance
        .collection('farmers')
        .doc(id)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> reviews(String id, int limit) async* {
    yield* FirebaseFirestore.instance
        .collection('products')
        .doc(id)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}

Widget detailPhoto(String url, {BoxFit fit = BoxFit.cover}) {
  final placeholder = Container(
    color: HhColors.sageLight,
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: HhColors.muted, size: 36),
  );
  if (url.isEmpty) return placeholder;
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    placeholder: (_, __) => placeholder,
    errorWidget: (_, __, ___) => placeholder,
  );
}

class ProductGallery extends StatefulWidget {
  final List<String> images;
  const ProductGallery({super.key, required this.images});
  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPhoto() {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                  child: Column(children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        tooltip: 'Close photo',
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))),
                Expanded(
                    child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                      child: detailPhoto(widget.images[_index],
                          fit: BoxFit.contain)),
                )),
              ])),
            ));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: widget.images.isEmpty
                  ? detailPhoto('')
                  : Stack(children: [
                      PageView.builder(
                        controller: _controller,
                        itemCount: widget.images.length,
                        onPageChanged: (index) =>
                            setState(() => _index = index),
                        itemBuilder: (_, index) => Semantics(
                          label:
                              'Product photo ${index + 1} of ${widget.images.length}',
                          button: true,
                          child: GestureDetector(
                              onTap: _openPhoto,
                              child: detailPhoto(widget.images[index])),
                        ),
                      ),
                      Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                '${_index + 1} / ${widget.images.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          )),
                    ]),
            )),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => Semantics(
                  label: 'Select photo ${index + 1}',
                  selected: index == _index,
                  child: InkWell(
                    onTap: () => _controller.animateToPage(index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut),
                    child: Container(
                      width: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              width: 2,
                              color: index == _index
                                  ? HhColors.primary
                                  : Colors.transparent)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: detailPhoto(widget.images[index])),
                    ),
                  ),
                ),
              )),
        ],
      ]);
}

class ProductStoreSection extends StatefulWidget {
  final String farmerId;
  final String fallbackName;
  final double? fallbackRating;
  final ProductDetailsData data;
  const ProductStoreSection(
      {super.key,
      required this.farmerId,
      required this.fallbackName,
      this.fallbackRating,
      required this.data});
  @override
  State<ProductStoreSection> createState() => _ProductStoreSectionState();
}

class _ProductStoreSectionState extends State<ProductStoreSection> {
  late Stream<Map<String, dynamic>?> _store;
  @override
  void initState() {
    super.initState();
    _store = widget.data.store(widget.farmerId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
        stream: _store,
        builder: (context, snapshot) {
          final store = snapshot.data ?? const <String, dynamic>{};
          String field(String key, [String fallback = '']) =>
              (store[key] is String && (store[key] as String).trim().isNotEmpty)
                  ? (store[key] as String).trim()
                  : fallback;
          final rating =
              (store['rating'] as num?)?.toDouble() ?? widget.fallbackRating;
          final count = (store['reviewCount'] as num?)?.toInt();
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border.all(color: HhColors.primary.withValues(alpha: .12)),
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('About the farm',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  InkWell(
                    onTap: () {
                      final phoneNum = field('phone', field('farmerPhone', '0918234590'));
                      callFarmerPhone(context, phoneNum);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: HhColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: HhColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.phone_in_talk_rounded, size: 15, color: HhColors.primary),
                          SizedBox(width: 5),
                          Text(
                            'Call',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: HhColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: detailPhoto(field('avatarUrl', field('imageUrl'))),
                    )),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(field('businessName', widget.fallbackName),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (field('farmerName').isNotEmpty)
                        Text(field('farmerName'),
                            style: const TextStyle(
                                color: HhColors.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                          rating != null && rating > 0
                              ? '★ ${rating.toStringAsFixed(1)} · ${count == null ? 'Review count unavailable' : '$count reviews'}'
                              : 'No store reviews yet',
                          style: const TextStyle(
                              color: HhColors.primary, fontSize: 12)),
                    ])),
              ]),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator()),
              if (snapshot.hasError) ...[
                const SizedBox(height: 8),
                const Text('Could not load farm information.'),
                TextButton(
                    onPressed: () => setState(() {
                          _store = widget.data.store(widget.farmerId);
                        }),
                    child: const Text('Retry farm information')),
              ] else if (snapshot.connectionState !=
                  ConnectionState.waiting) ...[
                const SizedBox(height: 12),
                Text(
                    field('description',
                        'This farm has not added a description yet.'),
                    style: const TextStyle(fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                _contact(
                    Icons.location_on_outlined,
                    field(
                        'address',
                        field('pickupAddress',
                            field('area', 'Address not provided')))),
                const SizedBox(height: 8),
                _contact(
                  Icons.phone_outlined,
                  field('phone', 'Phone number not provided'),
                  onTap: () {
                    final phoneNum = field('phone', field('farmerPhone', '0918234590'));
                    callFarmerPhone(context, phoneNum);
                  },
                ),
                const SizedBox(height: 16),
                SaveButton(
                    kind: SavedKind.farmer,
                    itemId: widget.farmerId,
                    allowSave: store['isActive'] == true),
              ],
            ]),
          );
        },
      );

  Widget _contact(IconData icon, String value, {VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: HhColors.primary),
            const SizedBox(width: 8),
            Expanded(
                child: SelectableText(value, style: const TextStyle(fontSize: 13))),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.call_made_rounded, size: 14, color: HhColors.primary),
            ],
          ]),
        ),
      );

}

class ProductReviewsSection extends StatefulWidget {
  final Product product;
  final ProductDetailsData data;
  const ProductReviewsSection(
      {super.key, required this.product, required this.data});
  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  int _limit = 20;
  late Stream<List<Map<String, dynamic>>> _reviews;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reviews = widget.data.reviews(widget.product.id, _limit + 1);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Customer reviews',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (widget.product.reviewCount > 0)
          Text(
              '★ ${widget.product.rating.toStringAsFixed(1)} / 5 · ${widget.product.reviewCount} reviews',
              style: const TextStyle(color: HhColors.primary)),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _reviews,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Could not load customer reviews.'),
                    TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('Retry reviews')),
                  ]);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator());
            }
            final reviews = snapshot.data ?? const [];
            if (reviews.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No written reviews yet.'));
            }
            return Column(children: [
              for (final review in reviews.take(_limit)) _review(review),
              if (reviews.length > _limit)
                TextButton(
                    onPressed: () => setState(() {
                          _limit += 20;
                          _load();
                        }),
                    child: const Text('Show more reviews')),
            ]);
          },
        ),
      ]);

  Widget _review(Map<String, dynamic> review) {
    final rating = ((review['rating'] as num?)?.toInt() ?? 0).clamp(0, 5);
    final date = readDate(review['createdAt']);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HhColors.primary.withValues(alpha: .1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
              radius: 16,
              backgroundColor: HhColors.sageLight,
              child: Icon(Icons.person_outline,
                  size: 20, color: HhColors.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(review['authorName'] as String? ?? 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          if (review['isDemo'] == true)
            const Text('Sample',
                style: TextStyle(fontSize: 10, color: HhColors.muted)),
        ]),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                  label: '$rating out of 5 stars',
                  child: Text('${'★' * rating}${'☆' * (5 - rating)}',
                      style: const TextStyle(
                          color: HhColors.accent, fontSize: 15))),
              if (date.millisecondsSinceEpoch > 0)
                Text(DateFormat.yMMMd().format(date),
                    style:
                        const TextStyle(fontSize: 11, color: HhColors.muted)),
            ]),
        const SizedBox(height: 8),
        Text(review['comment'] as String? ?? '',
            style: const TextStyle(height: 1.5, fontSize: 13)),
      ]),
    );
  }
}
