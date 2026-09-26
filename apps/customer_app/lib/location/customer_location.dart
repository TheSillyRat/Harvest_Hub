import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class CustomerPosition {
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  const CustomerPosition(this.latitude, this.longitude,
      {this.accuracyMeters = 0});
}

// Kept in Customer so Farmer does not need the location plugin or new models.
class DeviceLocationSource {
  Future<bool> isEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  Future<CustomerPosition> current() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return CustomerPosition(position.latitude, position.longitude,
        accuracyMeters: position.accuracy);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

enum LocationIssue { disabled, denied, blocked, unavailable }

class CustomerLocation extends ChangeNotifier {
  final DeviceLocationSource source;
  CustomerLocation({DeviceLocationSource? source})
      : source = source ?? DeviceLocationSource();

  static const freshFor = Duration(minutes: 10);

  CustomerPosition? position;
  DateTime? locatedAt;
  LocationIssue? issue;
  bool loading = false;
  bool _disposed = false;
  Future<bool>? _pending;

  bool get isFresh =>
      position != null &&
      locatedAt != null &&
      DateTime.now().difference(locatedAt!) < freshFor;

  /// Reuses the last fix for 10 minutes so repeated toggles do not call GPS.
  Future<bool> ensureRecent() {
    if (isFresh) return Future.value(true);
    return _pending ??= locate(keepPrevious: position != null).whenComplete(() {
      _pending = null;
    });
  }

  String? get message => switch (issue) {
        LocationIssue.disabled => 'Turn on location services, then try again.',
        LocationIssue.denied =>
          'Location permission was denied. You can still browse all products.',
        LocationIssue.blocked =>
          'Allow location in app settings, then try again.',
        LocationIssue.unavailable =>
          'Could not get your location. Please try again.',
        null => null,
      };

  Future<bool> locate({bool keepPrevious = false}) async {
    if (loading || _disposed) return position != null;
    final previous = position;
    loading = true;
    issue = null;
    if (!keepPrevious) position = null;
    notifyListeners();
    try {
      if (!await source.isEnabled()) {
        issue = LocationIssue.disabled;
        return false;
      }
      var permission = await source.permission();
      if (permission == LocationPermission.denied) {
        permission = await source.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        issue = LocationIssue.blocked;
        return false;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        issue = LocationIssue.denied;
        return false;
      }
      final result =
          await source.current().timeout(const Duration(seconds: 25));
      if (!result.latitude.isFinite ||
          !result.longitude.isFinite ||
          result.latitude.abs() > 90 ||
          result.longitude.abs() > 180) {
        throw StateError('Invalid location');
      }
      if (_disposed) return false;
      position = result;
      locatedAt = DateTime.now();
      return true;
    } catch (_) {
      if (keepPrevious && previous != null) {
        position = previous;
        return true;
      }
      issue = LocationIssue.unavailable;
      return false;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> openSettings() async {
    try {
      if (issue == LocationIssue.disabled) {
        await source.openLocationSettings();
      } else {
        await source.openAppSettings();
      }
    } catch (_) {
      issue = LocationIssue.unavailable;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
