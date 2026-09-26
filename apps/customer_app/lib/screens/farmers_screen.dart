import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import '../location/customer_location.dart';
import '../location/nearby_stores.dart';
import 'marketplace_screen.dart';
import 'product_detail_sections.dart';
import '../widgets/save_button.dart';
import 'saved_screen.dart';

class FarmerListing {
  final String id;
  final Map<String, dynamic> data;
  const FarmerListing(this.id, this.data);
  String text(String field) =>
      data[field] is String ? (data[field] as String).trim() : '';
  String get name =>
      text('businessName').isEmpty ? 'Farm store' : text('businessName');
}

class FarmersData {
  Stream<List<FarmerListing>> watch() async* {
    yield* FirebaseFirestore.instance
        .collection('farmers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FarmerListing(doc.id, doc.data()))
            .toList());
  }
}

class FarmersScreen extends StatefulWidget {
  final CustomerLocation location;
  final FarmersData? data;
  const FarmersScreen({super.key, required this.location, this.data});
  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  late final FarmersData _data;
  late Stream<List<FarmerListing>> _farmers;
  String _search = '';
  String _sort = 'name';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double? _distance(FarmerListing farmer) {
    final point = farmer.data['pickupLocation'];
    final position = widget.location.position;
    return point is GeoPoint && position != null
        ? Geolocator.distanceBetween(position.latitude, position.longitude,
                point.latitude, point.longitude) /
            1000
        : null;
  }

  @override
  void initState() {
    super.initState();
    _data = widget.data ?? FarmersData();
    _farmers = _data.watch();
  }

  void _open(FarmerListing farmer) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
              appBar: AppBar(title: Text(farmer.name)),
              body: MarketplaceScreen(
                catalogOnly: true,
                farmerId: farmer.id,
                farmerName: farmer.name,
                location: widget.location,
                onOpenCart: () {},
                onOpenOrders: () {},
                onOpenProfile: () {},
              ),
            )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HhColors.bg,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Farmers',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: HhColors.primary))),
                          TextButton.icon(
                              onPressed: () =>
                                  openSavedItems(context, initialTab: 1),
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: const Text('Following')),
                        ]),
                        const SizedBox(height: 4),
                        const Text('Meet the farms behind your food.',
                            style: TextStyle(color: HhColors.muted)),
                        const SizedBox(height: 14),
                        TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(
                                () => _search = value.trim().toLowerCase()),
                            decoration: InputDecoration(
                                hintText: 'Search farms or areas...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _search.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _search = '');
                                        }),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final option in const {
                            'name': 'All farms',
                            'nearest': 'Nearest',
                            'rating': 'Top rated'
                          }.entries)
                            ChoiceChip(
                                label: Text(option.value,
                                    style: const TextStyle(fontSize: 12)),
                                selected: _sort == option.key,
                                onSelected: (_) async {
                                  if (option.key == 'nearest' &&
                                      !await widget.location.ensureRecent()) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(widget
                                                      .location.message ??
                                                  'Location unavailable.')));
                                    }
                                    return;
                                  }
                                  if (mounted) {
                                    setState(() => _sort = option.key);
                                  }
                                }),
                        ]),
                      ])),
              Expanded(
                  child: StreamBuilder<List<FarmerListing>>(
                stream: _farmers,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Could not load farmers.'),
                      TextButton(
                          onPressed: () =>
                              setState(() => _farmers = _data.watch()),
                          child: const Text('Try again')),
                    ]));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final farmers = snapshot.data!
                      .where((farmer) =>
                          '${farmer.name} ${farmer.text('area')} ${farmer.text('address')}'
                              .toLowerCase()
                              .contains(_search))
                      .toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  if (farmers.isEmpty) {
                    return Center(
                        child: Text(_search.isEmpty
                            ? 'No farmers available yet.'
                            : 'No farms match your search.'));
                  }
                  return AnimatedBuilder(
                      animation: widget.location,
                      builder: (_, __) {
                        farmers.sort((a, b) {
                          final result = _sort == 'nearest'
                              ? (_distance(a) ?? double.infinity)
                                  .compareTo(_distance(b) ?? double.infinity)
                              : _sort == 'rating'
                                  ? ((b.data['rating'] as num?) ?? 0).compareTo(
                                      (a.data['rating'] as num?) ?? 0)
                                  : 0;
                          return result != 0
                              ? result
                              : a.name
                                  .toLowerCase()
                                  .compareTo(b.name.toLowerCase());
                        });
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(16, 4, 16,
                              110 + MediaQuery.paddingOf(context).bottom),
                          itemCount: farmers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) => _card(farmers[index]),
                        );
                      });
                },
              )),
            ])),
      );

  Widget _card(FarmerListing farmer) {
    final position = widget.location.position;
    final distance = _distance(farmer);
    final rating = (farmer.data['rating'] as num?)?.toDouble() ?? 0;
    final count = (farmer.data['reviewCount'] as num?)?.toInt();
    final cover = farmer.text('coverImageUrl').isNotEmpty
        ? farmer.text('coverImageUrl')
        : farmer.text('imageUrl').isNotEmpty
            ? farmer.text('imageUrl')
            : farmer.text('avatarUrl');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          AspectRatio(
              aspectRatio: 2.5,
              child:
                  SizedBox(width: double.infinity, child: detailPhoto(cover))),
          if (distance != null)
            Positioned(
                bottom: 10,
                left: 12,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.near_me_outlined,
                          size: 14, color: HhColors.primary),
                      const SizedBox(width: 4),
                      Text(distanceLabel(distance),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]))),
        ]),
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(farmer.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: HhColors.sageLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      rating > 0
                          ? '\u2605 ${rating.toStringAsFixed(1)}${count == null ? '' : ' / $count reviews'}'
                          : 'No reviews yet',
                      style: const TextStyle(
                          color: HhColors.primary, fontSize: 12))),
              if (farmer.text('area').isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(farmer.text('area'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: HhColors.muted))),
              const SizedBox(height: 5),
              if (distance == null)
                Text(
                    distance != null
                        ? distanceLabel(distance)
                        : position == null
                            ? 'Allow location to see distance'
                            : 'Pickup location unavailable',
                    style:
                        const TextStyle(fontSize: 12, color: HhColors.muted)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SaveButton(kind: SavedKind.farmer, itemId: farmer.id),
                  OutlinedButton.icon(
                    onPressed: () {
                      final phoneNum = farmer.text('phone').isNotEmpty
                          ? farmer.text('phone')
                          : '0918234590';
                      callFarmerPhone(context, phoneNum);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HhColors.primary,
                      side: BorderSide(
                        color: HhColors.primary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _open(farmer),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('View products'),
                  )),
            ])),
      ]),
    );
  }
}
