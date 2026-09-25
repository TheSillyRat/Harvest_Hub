import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer_app/location/customer_location.dart';
import 'package:customer_app/location/nearby_stores.dart';
import 'package:customer_app/screens/marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class Device extends DeviceLocationSource {
  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<LocationPermission> permission() async =>
      LocationPermission.whileInUse;
  @override
  Future<CustomerPosition> current() async => const CustomerPosition(0, 0);
}

class Stores extends NearbyStores {
  @override
  Stream<List<StorePickup>> watch() => Stream.value(const [
        StorePickup('farmer_1', GeoPoint(0, 0.1)),
        StorePickup('farmer_2', GeoPoint(0, 0.01)),
      ]);
}

class Products extends ProductService {
  @override
  Stream<List<Product>> streamActiveProducts(
          {String? categoryId, String search = ''}) =>
      Stream.value(ProductService.getFallbackProducts()
          .take(2)
          .map((p) => p.copyWith(imageUrl: ''))
          .toList());
}

class Categories extends CategoryService {
  @override
  Stream<List<Category>> streamActive() => Stream.value(const [
        Category(
            id: 'vegetables',
            name: 'Vegetables',
            imageUrl: '',
            sortOrder: 1,
            isActive: true),
        Category(
            id: 'fruits',
            name: 'Fruits',
            imageUrl: '',
            sortOrder: 2,
            isActive: true),
      ]);
}

Future<void> showCatalog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final location = CustomerLocation(source: Device());
  final cart = CartController();
  addTearDown(location.dispose);
  addTearDown(cart.dispose);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: cart,
    child: MaterialApp(
        home: MarketplaceScreen(
      catalogOnly: true,
      location: location,
      nearbyStores: Stores(),
      productService: Products(),
      categoryService: Categories(),
      onOpenCart: () {},
      onOpenOrders: () {},
      onOpenProfile: () {},
    )),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'distance slider filters stores and combines with product category',
      (tester) async {
    await showCatalog(tester);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Slider>(find.byKey(const Key('distance-slider')))
            .onChanged,
        isNull);
    await tester.tap(find.text('Limit distance'));
    await tester.pumpAndSettle();
    expect(find.text('Within 10 km'), findsOneWidget);
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsOneWidget);
    expect(find.text('Heirloom Vine Tomatoes'), findsNothing);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const Key('distance-slider'));
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Within 50 km'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vegetables'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    expect(find.text('Honeycrisp Apples'), findsNothing);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('distance-slider')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('No products within 1 km'), findsOneWidget);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    expect(find.text('Honeycrisp Apples'), findsOneWidget);
  });
  testWidgets('filter sections apply category and both price sort directions',
      (tester) async {
    await showCatalog(tester);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    expect(find.text('Product category'), findsOneWidget);
    expect(find.text('Price range'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vegetables'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Honeycrisp Apples'), findsNothing);
    expect(find.text('Heirloom Vine Tomatoes'), findsOneWidget);
    for (final ascending in [true, false]) {
      await tester.tap(find.byTooltip('Filter products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All categories'));
      await tester.tap(find.byKey(const Key('price-sort')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(ascending ? 'Low to High' : 'High to Low').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      final tomato = tester.getTopLeft(find.text('Heirloom Vine Tomatoes')).dx;
      final apple = tester.getTopLeft(find.text('Honeycrisp Apples')).dx;
      expect(tomato < apple, ascending);
    }
  });
  testWidgets('Nearest asks for location and sorts products by pickup distance',
      (tester) async {
    await showCatalog(tester);
    expect(find.textContaining('km away'), findsNothing);
    await tester.tap(find.text('Nearest'));
    await tester.pumpAndSettle();
    expect(find.text('About 1.1 km away'), findsOneWidget);
    expect(find.text('About 11.1 km away'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Honeycrisp Apples')).dx,
        lessThan(tester.getTopLeft(find.text('Heirloom Vine Tomatoes')).dx));
  });
}
