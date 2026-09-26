import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

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
  double? _accuracy;

  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  static const List<Map<String, dynamic>> _presetLocations = [
    {
      'name': 'Da Lat Organic Hub',
      'lat': 11.940419,
      'lng': 108.458313,
      'area': 'Da Lat, Lam Dong',
    },
    {
      'name': 'Da Nang Farm Market',
      'lat': 16.054407,
      'lng': 108.202167,
      'area': 'Hai Chau, Da Nang',
    },
    {
      'name': 'Saigon Green Farm Hub',
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
    super.dispose();
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
        final point = data['pickupLocation'];
        if (point is GeoPoint) {
          _savedPoint = point;
          _latController.text = point.latitude.toStringAsFixed(6);
          _lngController.text = point.longitude.toStringAsFixed(6);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
          _accuracy = position.accuracy;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location detected! Accuracy: ±${position.accuracy.toStringAsFixed(1)}m. Tap Save to apply.',
            ),
          ),
        );
      }
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

    setState(() => _busy = true);
    try {
      final point = GeoPoint(lat, lng);
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .update({
        'pickupLocation': point,
        'updatedAt': Timestamp.now(),
      });

      setState(() => _savedPoint = point);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Farm GPS coordinates saved! Customers can now calculate travel distance.',
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

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _latController.text = (preset['lat'] as double).toStringAsFixed(6);
      _lngController.text = (preset['lng'] as double).toStringAsFixed(6);
      _accuracy = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded preset: ${preset['name']}. Tap Save to apply.'),
      ),
    );
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

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map viewer')),
          );
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
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
                                  if (_area.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _area,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: HhColors.muted,
                                      ),
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
                        const Text(
                          'GPS Coordinates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        HhTextField(
                          controller: _latController,
                          label: 'Latitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        HhTextField(
                          controller: _lngController,
                          label: 'Longitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                        if (_accuracy != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Estimated GPS Accuracy: ±${_accuracy!.toStringAsFixed(1)} meters',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HhColors.primary,
                              fontWeight: FontWeight.w500,
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 18),
                                label: const Text(
                                  'Detect GPS Location',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _openGoogleMaps,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Maps'),
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
