import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:latlong2/latlong.dart';

class FarmLocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const FarmLocationPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<FarmLocationPickerScreen> createState() =>
      _FarmLocationPickerScreenState();
}

class _FarmLocationPickerScreenState extends State<FarmLocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedPoint;
  bool _locating = false;

  static const List<Map<String, dynamic>> _quickPresets = [
    {
      'name': 'Da Lat',
      'lat': 11.940419,
      'lng': 108.458313,
    },
    {
      'name': 'Da Nang',
      'lat': 16.054407,
      'lng': 108.202167,
    },
    {
      'name': 'Ho Chi Minh',
      'lat': 10.776889,
      'lng': 106.700897,
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPoint = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentGps() async {
    setState(() => _locating = true);
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location service')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently blocked in settings'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final newPoint = LatLng(position.latitude, position.longitude);
      setState(() => _selectedPoint = newPoint);
      _mapController.move(newPoint, 16.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _selectPreset(Map<String, dynamic> preset) {
    final point = LatLng(preset['lat'] as double, preset['lng'] as double);
    setState(() => _selectedPoint = point);
    _mapController.move(point, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Farm Location'),
        actions: [
          IconButton(
            tooltip: 'Center on Pin',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => _mapController.move(_selectedPoint, 16.0),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 15.0,
              minZoom: 4.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                setState(() => _selectedPoint = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.harvesthub.farmer_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 50,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 16, color: HhColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Tap anywhere to place pin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final p in _quickPresets)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.place, size: 14),
                        label: Text(
                          p['name'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _selectPreset(p),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 165,
            child: FloatingActionButton.small(
              heroTag: 'myGpsFab',
              backgroundColor: Colors.white,
              foregroundColor: HhColors.primary,
              onPressed: _locating ? null : _moveToCurrentGps,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.pin_drop,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pinned Coordinates',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HhColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: HhColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final point = GeoPoint(
                            _selectedPoint.latitude,
                            _selectedPoint.longitude,
                          );
                          Navigator.pop(context, point);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
