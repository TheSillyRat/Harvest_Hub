import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'farm_location_picker_screen.dart';

class FarmerLocationScreen extends StatefulWidget {
  final String farmerId;
  const FarmerLocationScreen({super.key, required this.farmerId});

  @override
  State<FarmerLocationScreen> createState() => _FarmerLocationScreenState();
}

class _FarmerLocationScreenState extends State<FarmerLocationScreen> {
  bool _loading = true;
  bool _busy = false;
  GeoPoint? _savedPoint;
  String _businessName = '';
  String _area = '';

  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _addressController = TextEditingController();
  bool _resolvingAddress = false;

  static const List<Map<String, dynamic>> _presetLocations = [
    {
      'name': 'Da Lat Organic Hub',
      'address': 'Da Lat Organic Hub, Ward 3, Da Lat, Lam Dong',
      'lat': 11.940419,
      'lng': 108.458313,
      'area': 'Da Lat, Lam Dong',
    },
    {
      'name': 'Da Nang Farm Market',
      'address': 'Da Nang Farm Market, Hai Chau, Da Nang',
      'lat': 16.054407,
      'lng': 108.202167,
      'area': 'Hai Chau, Da Nang',
    },
    {
      'name': 'Saigon Green Farm Hub',
      'address': 'Saigon Green Farm Hub, Ben Nghe, District 1, Ho Chi Minh',
      'lat': 10.776889,
      'lng': 106.700897,
      'area': 'District 1, Ho Chi Minh',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFarmerLocation();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'HarvestHubFarmerApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _lookupAddress(double lat, double lng) async {
    if (mounted) setState(() => _resolvingAddress = true);
    final addr = await _reverseGeocode(lat, lng);
    if (mounted) {
      if (addr != null && addr.isNotEmpty) {
        setState(() {
          _addressController.text = addr;
          if (_area.isEmpty) {
            final parts = addr.split(',');
            if (parts.length >= 2) {
              _area = parts.sublist(parts.length - 2).join(',').trim();
            }
          }
        });
      }
      setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _loadFarmerLocation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _businessName = data['businessName'] as String? ?? '';
        _area = data['area'] as String? ?? '';
        final addr = data['address'] as String? ?? '';
        if (addr.isNotEmpty) {
          _addressController.text = addr;
        }
        final point = data['pickupLocation'];
        if (point is GeoPoint) {
          _savedPoint = point;
          _latController.text = point.latitude.toStringAsFixed(6);
          _lngController.text = point.longitude.toStringAsFixed(6);
          if (addr.isEmpty) {
            _lookupAddress(point.latitude, point.longitude);
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _syncProfileAndLocation({
    required double lat,
    required double lng,
    String? address,
    String? areaName,
    String? successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      final point = GeoPoint(lat, lng);
      var resolvedAddress = (address != null && address.trim().isNotEmpty)
          ? address.trim()
          : _addressController.text.trim();
      var resolvedArea = (areaName != null && areaName.trim().isNotEmpty)
          ? areaName.trim()
          : _area.trim();

      if (resolvedArea.isEmpty && resolvedAddress.isNotEmpty) {
        final parts = resolvedAddress.split(',');
        if (parts.length >= 2) {
          resolvedArea = parts.sublist(parts.length - 2).join(',').trim();
        }
      }

      if (mounted) {
        setState(() {
          _latController.text = lat.toStringAsFixed(6);
          _lngController.text = lng.toStringAsFixed(6);
          if (resolvedAddress.isNotEmpty) {
            _addressController.text = resolvedAddress;
          }
          if (resolvedArea.isNotEmpty) {
            _area = resolvedArea;
          }
          _savedPoint = point;
        });
      }

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .set({
        'pickupLocation': point,
        if (resolvedAddress.isNotEmpty) 'address': resolvedAddress,
        if (resolvedArea.isNotEmpty) 'area': resolvedArea,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted && resolvedAddress.isNotEmpty) {
        final auth = context.read<AuthController>();
        final user = auth.user;
        if (user != null && user.uid == widget.farmerId) {
          await auth.updateProfile(
            name: user.name,
            phone: user.phone,
            address: resolvedAddress,
          );
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.farmerId)
              .set({
            'address': resolvedAddress,
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              successMessage ?? 'Farm location & profile updated successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _busy = true);
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted) {
          _showGpsDisabledDialog();
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are required to detect GPS coordinates'),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionBlockedDialog();
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lngController.text = position.longitude.toStringAsFixed(6);
          _resolvingAddress = true;
        });
      }

      final resolvedAddr = await _reverseGeocode(position.latitude, position.longitude);

      if (mounted) {
        setState(() => _resolvingAddress = false);
      }

      await _syncProfileAndLocation(
        lat: position.latitude,
        lng: position.longitude,
        address: resolvedAddr,
        successMessage: 'Location detected & profile updated successfully!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocation() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Latitude between -90 and 90'),
        ),
      );
      return;
    }

    if (lng == null || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Longitude between -180 and 180'),
        ),
      );
      return;
    }

    await _syncProfileAndLocation(
      lat: lat,
      lng: lng,
      address: _addressController.text.trim(),
      areaName: _area,
      successMessage: 'Farm pickup address & profile saved successfully!',
    );
  }

  Future<void> _applyPreset(Map<String, dynamic> preset) async {
    final lat = preset['lat'] as double;
    final lng = preset['lng'] as double;
    final address = preset['address'] as String? ?? preset['name'] as String? ?? '';
    final area = preset['area'] as String? ?? '';
    await _syncProfileAndLocation(
      lat: lat,
      lng: lng,
      address: address,
      areaName: area,
      successMessage: 'Loaded preset "${preset['name']}" & profile updated!',
    );
  }

  Future<void> _openMapPicker() async {
    final lat = double.tryParse(_latController.text.trim()) ?? _savedPoint?.latitude ?? 11.940419;
    final lng = double.tryParse(_lngController.text.trim()) ?? _savedPoint?.longitude ?? 108.458313;

    final picked = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => FarmLocationPickerScreen(
          initialLat: lat,
          initialLng: lng,
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _latController.text = picked.latitude.toStringAsFixed(6);
        _lngController.text = picked.longitude.toStringAsFixed(6);
        _resolvingAddress = true;
      });
      final resolvedAddr = await _reverseGeocode(picked.latitude, picked.longitude);
      if (mounted) {
        setState(() => _resolvingAddress = false);
      }
      await _syncProfileAndLocation(
        lat: picked.latitude,
        lng: picked.longitude,
        address: resolvedAddr,
        successMessage: 'Pinned location applied & profile updated successfully!',
      );
    }
  }

  Future<void> _openGoogleMaps() async {
    final lat = double.tryParse(_latController.text.trim()) ?? _savedPoint?.latitude;
    final lng = double.tryParse(_lngController.text.trim()) ?? _savedPoint?.longitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates available to open in Maps')),
      );
      return;
    }

    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      final launchedGeo = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (!launchedGeo) {
        final launchedWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!launchedWeb && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map viewer')),
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable Location (GPS) on your device to automatically detect your farm coordinates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionBlockedDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Permission Blocked'),
        content: const Text(
          'Location permission has been permanently denied. Please grant location access in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Geolocator.openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = _savedPoint != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm GPS Location'),
      ),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isConfigured
                                    ? HhColors.primary.withValues(alpha: 0.1)
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.share_location,
                                size: 36,
                                color: isConfigured
                                    ? HhColors.primary
                                    : Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _businessName.isNotEmpty
                                        ? _businessName
                                        : 'Farm Pickup Hub',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_addressController.text.isNotEmpty || _area.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _addressController.text.isNotEmpty
                                          ? _addressController.text
                                          : _area,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: HhColors.muted,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isConfigured
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isConfigured
                                            ? Colors.green.shade300
                                            : Colors.orange.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isConfigured
                                              ? Icons.check_circle
                                              : Icons.warning_amber_rounded,
                                          size: 14,
                                          color: isConfigured
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isConfigured
                                              ? 'GPS CONFIGURED'
                                              : 'LOCATION NOT CONFIGURED',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isConfigured
                                                ? Colors.green.shade800
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your GPS location is shared with buyers so the Customer App can calculate driving distance and display your farm on nearby market lists.',
                          style: TextStyle(
                            fontSize: 13,
                            color: HhColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _latController.text.isNotEmpty
                                  ? Icons.place
                                  : Icons.location_searching,
                              size: 20,
                              color: HhColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _latController.text.isNotEmpty
                                  ? 'Farm Pickup Address'
                                  : 'GPS Coordinates',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_latController.text.isNotEmpty) ...[
                          HhTextField(
                            controller: _addressController,
                            label: 'Pickup Address',
                            maxLines: 2,
                          ),
                          if (_resolvingAddress) ...[
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Resolving address from coordinates...',
                                  style: TextStyle(fontSize: 12, color: HhColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No coordinates selected yet. Tap "Pin on Map" or "Detect GPS" to locate your farm.',
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: HhColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _openMapPicker,
                                icon: const Icon(Icons.pin_drop, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Pin on Map',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _busy ? null : _detectGpsLocation,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Detect GPS',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _openGoogleMaps,
                              child: const Icon(Icons.map_outlined, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        HhButton(
                          label: 'Save Farm Location',
                          busy: _busy,
                          onPressed: _saveLocation,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final lat = double.tryParse(_latController.text.trim()) ?? _savedPoint?.latitude;
                    final lng = double.tryParse(_lngController.text.trim()) ?? _savedPoint?.longitude;
                    if (lat == null || lng == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.map_outlined, size: 18, color: HhColors.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Farm Location Preview',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _openMapPicker,
                                    icon: const Icon(Icons.edit_location_alt, size: 16),
                                    label: const Text(
                                      'Change Pin',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 180,
                              child: FlutterMap(
                                key: ValueKey('$lat-$lng'),
                                options: MapOptions(
                                  initialCenter: LatLng(lat, lng),
                                  initialZoom: 15.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.none,
                                  ),
                                  onTap: (_, __) => _openMapPicker(),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.harvesthub.farmer_app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 44,
                                        height: 44,
                                        alignment: Alignment.topCenter,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hub_outlined, size: 18, color: HhColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Demo Hub Presets',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Quickly test location on emulators using predefined coordinates:',
                          style: TextStyle(fontSize: 12, color: HhColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in _presetLocations)
                              ActionChip(
                                avatar: const Icon(Icons.location_on, size: 16),
                                label: Text(preset['name'] as String),
                                onPressed: () => _applyPreset(preset),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
