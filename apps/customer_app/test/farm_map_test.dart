import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer_app/location/customer_location.dart';
import 'package:customer_app/screens/farm_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TileUpdateTransformers exists', () {
    expect(TileUpdateTransformers.throttle, isNotNull);
  });
  test('FarmMapItem calculates distance in kilometers correctly', () {
    const origin = CustomerPosition(0, 0);
    const itemAtOrigin = FarmMapItem(
      id: 'f1',
      name: 'Origin Farm',
      area: 'Center',
      address: '0, 0',
      coverImageUrl: '',
      phone: '0123456789',
      rating: 4.8,
      reviewCount: 10,
      point: GeoPoint(0, 0),
    );

    const itemEast = FarmMapItem(
      id: 'f2',
      name: 'East Farm',
      area: 'East',
      address: '0, 1',
      coverImageUrl: '',
      phone: '0123456789',
      rating: 5.0,
      reviewCount: 5,
      point: GeoPoint(0, 1),
    );

    expect(itemAtOrigin.distanceKm(origin), 0.0);
    expect(itemEast.distanceKm(origin), closeTo(111.32, 0.1));
    expect(itemAtOrigin.distanceKm(null), isNull);
  });
}
