import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import '../location/customer_location.dart';
import '../location/nearby_stores.dart';
import 'farmer_detail_screen.dart';
import 'product_detail_sections.dart';

class FarmMapItem {
  final String id;
  final String name;
  final String area;
  final String address;
  final String coverImageUrl;
  final String phone;
  final double rating;
  final int reviewCount;
  final GeoPoint point;

  const FarmMapItem({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.coverImageUrl,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    required this.point,
  });

  static FarmMapItem? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null || data['isActive'] != true) return null;
    final loc = data['pickupLocation'];
    if (loc is! GeoPoint) return null;

    final businessName = (data['businessName'] as String?)?.trim() ?? '';
    final areaText = (data['area'] as String?)?.trim() ?? '';
    final addressText = (data['address'] as String?)?.trim() ?? '';
    final phoneText = (data['phone'] as String?)?.trim() ?? '';
    final cover = (data['coverImageUrl'] as String?)?.trim().isNotEmpty == true
        ? (data['coverImageUrl'] as String).trim()
        : (data['imageUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['imageUrl'] as String).trim()
            : (data['avatarUrl'] as String?)?.trim() ?? '';

    final ratingVal = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews = (data['reviewCount'] as num?)?.toInt() ?? 0;

    return FarmMapItem(
      id: doc.id,
      name: businessName.isNotEmpty ? businessName : 'Farm store',
      area: areaText,
      address: addressText,
      coverImageUrl: cover,
      phone: phoneText.isNotEmpty ? phoneText : '02837381816',
      rating: ratingVal,
      reviewCount: reviews,
      point: loc,
    );
  }

  double? distanceKm(CustomerPosition? customer) {
    if (customer == null) return null;
    return Geolocator.distanceBetween(
          customer.latitude,
          customer.longitude,
          point.latitude,
          point.longitude,
        ) /
        1000;
  }
}

class FarmMapScreen extends StatefulWidget {
  final CustomerLocation location;
  final String? initialFarmerId;

  const FarmMapScreen({
    super.key,
    required this.location,
    this.initialFarmerId,
  });

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _farmsSub;
  List<FarmMapItem> _allFarms = const [];
  bool _isLoading = true;
  String _searchQuery = '';
  FarmMapItem? _selectedFarmer;
  bool _didCenterInitial = false;

  @override
  void initState() {
    super.initState();
    _startFarmsStream();
  }

  void _startFarmsStream() {
    _farmsSub = FirebaseFirestore.instance
        .collection('farmers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final farms = snapshot.docs
          .map(FarmMapItem.fromFirestore)
          .whereType<FarmMapItem>()
          .toList();

      setState(() {
        _allFarms = farms;
        _isLoading = false;
      });

      if (!_didCenterInitial && farms.isNotEmpty) {
        _didCenterInitial = true;
        _handleInitialPosition(farms);
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _handleInitialPosition(List<FarmMapItem> farms) {
    if (widget.initialFarmerId != null) {
      final found = farms.firstWhere(
        (f) => f.id == widget.initialFarmerId,
        orElse: () => farms.first,
      );
      _selectedFarmer = found;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(found.point.latitude, found.point.longitude),
          14.5,
        );
      });
    } else if (widget.location.position != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recenterToUser();
      });
    } else if (farms.isNotEmpty) {
      final first = farms.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(first.point.latitude, first.point.longitude),
          12.5,
        );
      });
    }
  }

  @override
  void dispose() {
    _farmsSub?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _userLatLng {
    final pos = widget.location.position;
    if (pos != null) {
      return LatLng(pos.latitude, pos.longitude);
    }
    return HarvesthubMapConfig.defaultLocation;
  }

  void _recenterToUser() {
    final pos = widget.location.position;
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14.0);
    } else {
      widget.location.ensureRecent().then((hasLocation) {
        if (hasLocation && mounted) {
          final updatedPos = widget.location.position;
          if (updatedPos != null) {
            _mapController.move(
              LatLng(updatedPos.latitude, updatedPos.longitude),
              14.0,
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.location.message ?? 'Location permission not granted.',
              ),
            ),
          );
        }
      });
    }
  }

  void _selectFarmer(FarmMapItem farmer) {
    setState(() => _selectedFarmer = farmer);
    _mapController.move(
      LatLng(farmer.point.latitude, farmer.point.longitude),
      14.5,
    );
  }

  List<FarmMapItem> get _filteredFarms {
    if (_searchQuery.isEmpty) return _allFarms;
    return _allFarms.where((f) {
      final match = '${f.name} ${f.area} ${f.address}'.toLowerCase();
      return match.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleFarms = _filteredFarms;

    return Scaffold(
      backgroundColor: HhColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLatLng,
                initialZoom: 13.0,
                minZoom: 4.0,
                maxZoom: 18.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, __) {
                  if (_selectedFarmer != null) {
                    setState(() => _selectedFarmer = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: HarvesthubMapConfig.osmUrl,
                  userAgentPackageName: 'com.harvesthub.customer',
                  maxZoom: 19,
                  panBuffer: 1,
                  tileUpdateTransformer: TileUpdateTransformers.throttle(
                    const Duration(milliseconds: 120),
                  ),
                ),
                MarkerLayer(
                  markers: [
                    if (widget.location.position != null)
                      Marker(
                        point: LatLng(
                          widget.location.position!.latitude,
                          widget.location.position!.longitude,
                        ),
                        width: 32,
                        height: 32,
                        child: _buildUserLocationMarker(),
                      ),
                    for (final farm in visibleFarms)
                      Marker(
                        point: LatLng(
                          farm.point.latitude,
                          farm.point.longitude,
                        ),
                        width: _selectedFarmer?.id == farm.id ? 150 : 44,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: _buildFarmMarker(farm),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopFloatingHeader(visibleFarms.length),
          ),
          if (_isLoading)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading farms...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: _selectedFarmer != null ? 220 : 36,
            child: _buildFloatingControls(),
          ),
          if (_selectedFarmer != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildFarmPreviewCard(_selectedFarmer!),
            ),
        ],
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFarmMarker(FarmMapItem farm) {
    final isSelected = _selectedFarmer?.id == farm.id;

    if (isSelected) {
      return GestureDetector(
        onTap: () => _selectFarmer(farm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: HhColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: HhColors.primary.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  farm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _selectFarmer(farm),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: HhColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: HhColors.primary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTopFloatingHeader(int count) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Material(
              color: Colors.white,
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: HhColors.text),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search nearby farms...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: HhColors.text.withValues(alpha: 0.45),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: HhColors.primary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _floatingRoundButton(
          icon: Icons.add_rounded,
          onTap: () {
            final nextZoom = (_mapController.camera.zoom + 1).clamp(4.0, 18.5);
            _mapController.move(_mapController.camera.center, nextZoom);
          },
        ),
        const SizedBox(height: 8),
        _floatingRoundButton(
          icon: Icons.remove_rounded,
          onTap: () {
            final nextZoom = (_mapController.camera.zoom - 1).clamp(4.0, 18.5);
            _mapController.move(_mapController.camera.center, nextZoom);
          },
        ),
        const SizedBox(height: 12),
        _floatingRoundButton(
          icon: Icons.my_location_rounded,
          color: HhColors.primary,
          iconColor: Colors.white,
          onTap: _recenterToUser,
        ),
      ],
    );
  }

  Widget _floatingRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = HhColors.text,
  }) {
    return Material(
      color: color,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildFarmPreviewCard(FarmMapItem farm) {
    final distance = farm.distanceKm(widget.location.position);
    final distanceStr = distance != null
        ? distanceLabel(distance)
        : 'Pickup location unavailable';

    final areaText = farm.area.isNotEmpty
        ? farm.area
        : farm.address.isNotEmpty
            ? farm.address
            : 'Organic Farm Area';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: detailPhoto(farm.coverImageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            farm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _selectedFarmer = null),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: HhColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: HhColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '$areaText • $distanceStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HhColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: HhColors.sageLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        farm.rating > 0
                            ? '★ ${farm.rating.toStringAsFixed(1)} (${farm.reviewCount} reviews)'
                            : 'No reviews yet',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    callFarmerPhone(
                      context,
                      farm.phone,
                      farmerName: farm.name,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HhColors.text,
                    side: BorderSide(
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                  label: const Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => FarmerDetailScreen(
                          farmerId: farm.id,
                          farmerName: farm.name,
                          location: widget.location,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: HhColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 15),
                  label: const Text(
                    'View products',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
