import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';
import '../location/customer_location.dart';
import '../location/nearby_stores.dart';
import 'farmer_detail_screen.dart';
import 'product_detail_sections.dart';
import '../widgets/save_button.dart';
import 'saved_screen.dart';
import 'farm_map_screen.dart';

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
        builder: (context) => FarmerDetailScreen(
          farmerId: farmer.id,
          farmerName: farmer.name,
          location: widget.location,
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
                          IconButton(
                            tooltip: 'Explore farms on map',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.map_outlined, size: 22),
                            color: HhColors.primary,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    FarmMapScreen(location: widget.location),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Open saved items',
                            icon: const Icon(Icons.favorite_border_rounded, size: 22),
                            color: HhColors.primary,
                            onPressed: () => openSavedItems(context, initialTab: 1),
                          ),
                          IconButton(
                            tooltip: 'Notifications',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.notifications_outlined, size: 22),
                            color: HhColors.text,
                            onPressed: () {
                              final authController = context.read<AuthController>();
                              final uid = authController.user?.uid ?? 'customer_1';
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NotificationHistoryScreen(userId: uid),
                                ),
                              );
                            },
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text('Meet the farms behind your food.',
                            style: TextStyle(color: HhColors.muted)),
                        const SizedBox(height: 12),
                        _buildMapPreviewBanner(context),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HhColors.text.withValues(alpha: 0.12)),
                            boxShadow: [
                              BoxShadow(
                                color: HhColors.text.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(
                                  () => _search = value.trim().toLowerCase()),
                              decoration: InputDecoration(
                                  hintText: 'Search farms or areas...',
                                  hintStyle: TextStyle(fontSize: 13.5, color: HhColors.text.withValues(alpha: 0.45)),
                                  prefixIcon: const Icon(Icons.search_rounded, color: HhColors.primary),
                                  suffixIcon: _search.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _search = '');
                                          }),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  border: InputBorder.none)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final option in const {
                            'name': 'All farms',
                            'nearest': 'Nearest',
                            'rating': 'Top rated'
                          }.entries)
                            ChoiceChip(
                                label: Text(option.value,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _sort == option.key
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _sort == option.key
                                            ? Colors.white
                                            : HhColors.text)),
                                selected: _sort == option.key,
                                checkmarkColor: Colors.white,
                                selectedColor: HhColors.primary,
                                backgroundColor: Colors.white,
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
                              const SizedBox(height: 14),
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
    final avatar = farmer.text('avatarUrl').isNotEmpty
        ? farmer.text('avatarUrl')
        : cover;

    final areaText = farmer.text('area').isNotEmpty
        ? farmer.text('area')
        : farmer.text('address').isNotEmpty
            ? farmer.text('address')
            : 'Local Farm';

    final distanceStr = distance != null
        ? distanceLabel(distance)
        : position == null
            ? 'Allow location'
            : 'Pickup available';

    final description = farmer.text('description');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner cover with badges and overlapping avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              AspectRatio(
                aspectRatio: 3.2,
                child: SizedBox(
                  width: double.infinity,
                  child: detailPhoto(cover),
                ),
              ),
              // Gradient for readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
              ),
              // Farm Producer Badge
              Positioned(
                top: 8,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🌿', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 4),
                      Text(
                        'Verified Farm',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              // Save button
              Positioned(
                top: 6,
                right: 6,
                child: SaveButton(
                  kind: SavedKind.farmer,
                  itemId: farmer.id,
                  iconOnly: true,
                ),
              ),
              // Overlapping Avatar
              Positioned(
                left: 14,
                bottom: -20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: HhColors.sageLight,
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? const Icon(Icons.storefront_rounded, size: 20, color: HhColors.primary)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        farmer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Rating Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFA000)),
                          const SizedBox(width: 3),
                          Text(
                            rating > 0 ? rating.toStringAsFixed(1) : '4.8',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          if (count != null && count > 0)
                            Text(
                              ' ($count)',
                              style: const TextStyle(fontSize: 10, color: HhColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Area & Distance tag (tappable for directions)
                InkWell(
                  onTap: () {
                    final point = farmer.data['pickupLocation'];
                    final lat = point is GeoPoint ? point.latitude : null;
                    final lng = point is GeoPoint ? point.longitude : null;
                    final address = farmer.text('address').isNotEmpty
                        ? farmer.text('address')
                        : areaText;
                    MapLauncher.openDirections(
                      latitude: lat,
                      longitude: lng,
                      address: address,
                      label: farmer.name,
                      context: context,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13.5, color: HhColors.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '$areaText • $distanceStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: HhColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.directions_rounded,
                        size: 14,
                        color: HhColors.primary,
                      ),
                    ],
                  ),
                ),
                // Farm Description / Specialty
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: HhColors.text.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Bottom action buttons
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        final phoneNum = farmer.text('phone').isNotEmpty
                            ? farmer.text('phone')
                            : '02837381816';
                        callFarmerPhone(context, phoneNum, farmerName: farmer.name);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HhColors.text,
                        side: BorderSide(
                          color: HhColors.text.withValues(alpha: 0.18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, size: 15),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final point = farmer.data['pickupLocation'];
                          final lat = point is GeoPoint ? point.latitude : null;
                          final lng = point is GeoPoint ? point.longitude : null;
                          final address = farmer.text('address').isNotEmpty
                              ? farmer.text('address')
                              : areaText;
                          MapLauncher.openDirections(
                            latitude: lat,
                            longitude: lng,
                            address: address,
                            label: farmer.name,
                            context: context,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HhColors.primary,
                          side: const BorderSide(color: HhColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.directions_outlined, size: 15),
                        label: const Text(
                          'Directions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(farmer),
                        style: FilledButton.styleFrom(
                          backgroundColor: HhColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.storefront_outlined, size: 15),
                        label: const Text(
                          'View products',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreviewBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HhColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: HhColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FarmMapScreen(location: widget.location),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HhColors.sageLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: HhColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Nearby Farms on Map',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View real-time farm locations & directions',
                        style: TextStyle(
                          fontSize: 12,
                          color: HhColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HhColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
