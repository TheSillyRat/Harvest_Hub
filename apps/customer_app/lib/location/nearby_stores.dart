import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'customer_location.dart';

class StorePickup {
  final String farmerId;
  final GeoPoint point;
  const StorePickup(this.farmerId, this.point);

  static StorePickup? fromMap(String id, Map<String, dynamic> data) {
    final point = data['pickupLocation'];
    if (data['isActive'] != true || point is! GeoPoint) return null;
    return StorePickup(id, point);
  }

  double distanceKm(CustomerPosition customer) =>
      Geolocator.distanceBetween(customer.latitude, customer.longitude,
          point.latitude, point.longitude) /
      1000;
}

class NearbyStores {
  Stream<List<StorePickup>> watch() {
    try {
      return FirebaseFirestore.instance
          .collection('farmers')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => StorePickup.fromMap(doc.id, doc.data()))
              .whereType<StorePickup>()
              .toList());
    } catch (error) {
      return Stream.error(error);
    }
  }
}

String distanceLabel(double? km) => km == null
    ? 'Location unavailable'
    : 'About ${km < 0.1 ? '< 0.1' : km.toStringAsFixed(1)} km away';

// Unknown locations sort last, rather than being mistaken for zero distance.
int compareDistances(double? a, double? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
