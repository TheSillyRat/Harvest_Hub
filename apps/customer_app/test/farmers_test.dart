import 'package:customer_app/location/customer_location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer_app/screens/farmers_screen.dart';
import 'package:customer_app/screens/marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import 'browsing_test.dart' show DisabledLocation, TestCategories;
import 'nearby_browsing_test.dart' show Products, Stores;

class Farms extends FarmersData {
  @override
  Stream<List<FarmerListing>> watch() => Stream.value(const [
    FarmerListing('a', {'businessName': 'Green Farm', 'rating': 4.5, 'reviewCount': 8}),
    FarmerListing('b', {'businessName': 'River Farm', 'area': 'Hanoi'}),
  ]);
}

class RankedFarms extends FarmersData {
  @override
  Stream<List<FarmerListing>> watch() => Stream.value(const [
    FarmerListing('a', {'businessName': 'Alpha Farm', 'rating': 3.0}),
    FarmerListing('b', {'businessName': 'Beta Farm', 'rating': 4.9, 'pickupLocation': GeoPoint(0, .1)}),
    FarmerListing('c', {'businessName': 'Close Farm', 'rating': 4.0, 'pickupLocation': GeoPoint(0, .01)}),
  ]);
}

void main() {
  testWidgets('farm sorting uses rating and distance with missing coordinates last', (tester) async {
    final location = CustomerLocation()
      ..position = const CustomerPosition(0, 0)
      ..locatedAt = DateTime.now();
    addTearDown(location.dispose);
    await tester.pumpWidget(MaterialApp(home: FarmersScreen(location: location, data: RankedFarms())));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Farm'), findsOneWidget);
    await tester.tap(find.text('Top rated'));
    await tester.pumpAndSettle();
    expect(find.text('Beta Farm'), findsOneWidget);
    expect(find.text('Alpha Farm'), findsNothing);
    await tester.tap(find.text('Nearest'));
    await tester.pumpAndSettle();
    expect(find.text('Close Farm'), findsOneWidget);
    expect(find.text('Alpha Farm'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('gallery keeps cover first, removes duplicates and limits to six', () {
    final product = ProductService.getFallbackProducts().first.copyWith(
      imageUrl: 'cover', imageUrls: [' cover ', '', 'a', 'b', 'c', 'd', 'e', 'f']);
    expect(product.galleryImages, ['cover', 'a', 'b', 'c', 'd', 'e']);
    expect(product.toMap().containsKey('imageUrls'), false);
  });

  testWidgets('farms without coordinates remain visible and searchable', (tester) async {
    final location = CustomerLocation(source: DisabledLocation());
    addTearDown(location.dispose);
    await tester.pumpWidget(MaterialApp(home: FarmersScreen(location: location, data: Farms())));
    await tester.pumpAndSettle();
    expect(find.text('Green Farm'), findsOneWidget);
    expect(find.text('View products'), findsWidgets);
    expect(find.textContaining('4.5'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hanoi');
    await tester.pumpAndSettle();
    expect(find.text('Green Farm'), findsNothing);
    expect(find.text('River Farm'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No farms match your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('farm product page excludes products owned by another farm', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final location = CustomerLocation(source: DisabledLocation());
    final cart = CartController();
    addTearDown(location.dispose);
    addTearDown(cart.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: cart,
      child: MaterialApp(home: MarketplaceScreen(
        farmerId: 'farmer_1', farmerName: 'Green Farm', catalogOnly: true,
        location: location, nearbyStores: Stores(), productService: Products(),
        categoryService: TestCategories(), onOpenCart: () {},
        onOpenOrders: () {}, onOpenProfile: () {},
      ))));
    await tester.pumpAndSettle();
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    expect(find.text('Honeycrisp Apples'), findsNothing);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
