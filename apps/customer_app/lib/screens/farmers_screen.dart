import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import '../location/customer_location.dart';
import '../location/nearby_stores.dart';
import 'marketplace_screen.dart';
import 'product_detail_sections.dart';

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
                        const Text('Farmers',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: HhColors.primary)),
                        const SizedBox(height: 4),
                        const Text('Meet the farms behind your food.',
                            style: TextStyle(color: HhColors.muted)),
                        const SizedBox(height: 14),
                        TextField(
                            onChanged: (value) => setState(
                                () => _search = value.trim().toLowerCase()),
                            decoration: InputDecoration(
                                hintText: 'Search farms or areas...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none))),
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
                      builder: (_, __) => ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 4, 16,
                                110 + MediaQuery.paddingOf(context).bottom),
                            itemCount: farmers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) => _card(farmers[index]),
                          ));
                },
              )),
            ])),
      );

  Widget _card(FarmerListing farmer) {
    final point = farmer.data['pickupLocation'];
    final position = widget.location.position;
    final distance = point is GeoPoint && position != null
        ? Geolocator.distanceBetween(position.latitude, position.longitude,
                point.latitude, point.longitude) /
            1000
        : null;
    final rating = (farmer.data['rating'] as num?)?.toDouble() ?? 0;
    final count = (farmer.data['reviewCount'] as num?)?.toInt();
    final cover = farmer.text('coverImageUrl').isNotEmpty
        ? farmer.text('coverImageUrl')
        : farmer.text('imageUrl').isNotEmpty
            ? farmer.text('imageUrl')
            : farmer.text('avatarUrl');
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(aspectRatio: 16 / 9, child: detailPhoto(cover)),
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(farmer.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  rating > 0
                      ? '\u2605 ${rating.toStringAsFixed(1)}${count == null ? '' : ' / $count reviews'}'
                      : 'No reviews yet',
                  style:
                      const TextStyle(color: HhColors.primary, fontSize: 13)),
              if (farmer.text('area').isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(farmer.text('area'),
                        style: const TextStyle(color: HhColors.muted))),
              const SizedBox(height: 5),
              Text(
                  distance != null
                      ? distanceLabel(distance)
                      : position == null
                          ? 'Allow location to see distance'
                          : 'Pickup location unavailable',
                  style: const TextStyle(fontSize: 12, color: HhColors.muted)),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _open(farmer),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('View products'),
                  )),
            ])),
      ]),
    );
  }
}
