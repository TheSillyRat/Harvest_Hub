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

  test('normalizeSearchString converts to lowercase and strips Vietnamese diacritics', () {
    expect(normalizeSearchString('Đà Lạt'), equals('da lat'));
    expect(normalizeSearchString('Ba Vì Dairy Farm'), equals('ba vi dairy farm'));
    expect(normalizeSearchString('Anh Ba Rau Củ'), equals('anh ba rau cu'));
    expect(normalizeSearchString('Nông Trại Hữu Cơ'), equals('nong trai huu co'));
  });

  test('FarmMapItem matchesQuery searches across name, farmerName, area, address, pickupAddress, description, and phone', () {
    const farm = FarmMapItem(
      id: 'f_dalat',
      name: 'Nông Trại Đà Lạt',
      farmerName: 'Minh Lâm Nguyễn',
      area: 'Lâm Đồng',
      address: '12 Hồ Tùng Mậu, Phường 3, Đà Lạt',
      pickupAddress: 'Điểm nhận hàng trung tâm Đà Lạt',
      description: 'Rau củ quả hữu cơ tươi ngon',
      coverImageUrl: '',
      phone: '0903123481',
      rating: 4.9,
      reviewCount: 25,
      point: GeoPoint(11.9404, 108.4583),
    );

    /* Test exact name match */
    expect(farm.matchesQuery('Nông Trại'), isTrue);

    /* Test unaccented search query matching accented name */
    expect(farm.matchesQuery('da lat'), isTrue);
    expect(farm.matchesQuery('nong trai'), isTrue);

    /* Test searching farmer name without accents */
    expect(farm.matchesQuery('minh lam'), isTrue);

    /* Test searching area and address */
    expect(farm.matchesQuery('lam dong'), isTrue);
    expect(farm.matchesQuery('ho tung mau'), isTrue);

    /* Test searching pickup address */
    expect(farm.matchesQuery('trung tam'), isTrue);

    /* Test searching description */
    expect(farm.matchesQuery('rau cu'), isTrue);

    /* Test multi-word query across fields */
    expect(farm.matchesQuery('minh lam da lat'), isTrue);

    /* Test searching by phone digits */
    expect(farm.matchesQuery('0903'), isTrue);

    /* Test non-matching query */
    expect(farm.matchesQuery('Ha Noi Milk'), isFalse);
  });
}
