import 'package:customer_app/location/customer_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class FakeDevice extends DeviceLocationSource {
  bool enabled = true;
  LocationPermission granted = LocationPermission.whileInUse;
  bool fail = false;
  int reads = 0;
  int requests = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<LocationPermission> permission() async => granted;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<CustomerPosition> current() async {
    reads++;
    if (fail) throw StateError('GPS timeout');
    return const CustomerPosition(11.94, 108.45, accuracyMeters: 500);
  }
}

void main() {
  test('location is requested on demand and accepts approximate coordinates',
      () async {
    final device = FakeDevice();
    final location = CustomerLocation(source: device);
    addTearDown(location.dispose);
    expect(device.reads, 0);
    expect(await location.locate(), isTrue);
    expect(location.position!.accuracyMeters, 500);
    device.fail = true;
    expect(await location.locate(), isFalse);
    expect(location.position, isNull);
    expect(location.issue, LocationIssue.unavailable);
    expect(location.loading, isFalse);
  });
  test('disabled services and denied permissions do not read GPS', () async {
    final device = FakeDevice()..enabled = false;
    final location = CustomerLocation(source: device);
    addTearDown(location.dispose);
    expect(await location.locate(), isFalse);
    expect(location.issue, LocationIssue.disabled);
    device.enabled = true;
    device.granted = LocationPermission.denied;
    expect(await location.locate(), isFalse);
    expect(location.issue, LocationIssue.denied);
    expect(device.requests, 1);
    device.granted = LocationPermission.deniedForever;
    expect(await location.locate(), isFalse);
    expect(location.issue, LocationIssue.blocked);
    expect(device.requests, 1);
    expect(device.reads, 0);
  });
}
