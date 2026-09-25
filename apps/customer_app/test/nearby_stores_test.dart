import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer_app/location/customer_location.dart';
import 'package:customer_app/location/nearby_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance uses kilometres and ignores missing or inactive pickups', () {
    const origin = CustomerPosition(0, 0);
    expect(const StorePickup('same', GeoPoint(0, 0)).distanceKm(origin), 0);
    expect(const StorePickup('east', GeoPoint(0, 1)).distanceKm(origin),
        closeTo(111.32, 0.1));
    expect(StorePickup.fromMap('old', {'isActive': true}), isNull);
    expect(
        StorePickup.fromMap(
            'bad', {'isActive': true, 'pickupLocation': 'Da Lat'}),
        isNull);
    expect(
        StorePickup.fromMap(
            'off', {'isActive': false, 'pickupLocation': const GeoPoint(0, 0)}),
        isNull);
    expect(compareDistances(null, 2), greaterThan(0));
    expect(compareDistances(1, null), lessThan(0));
    expect(compareDistances(null, null), 0);
  });
}
