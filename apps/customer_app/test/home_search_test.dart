import 'dart:async';
import 'package:customer_app/location/customer_location.dart';
import 'package:customer_app/location/nearby_stores.dart';
import 'package:customer_app/screens/home_landing_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class MockLocationSource extends DeviceLocationSource {
  @override
  Future<bool> isEnabled() async => false;
}

class MockProductService extends ProductService {
  final List<Product> mockProducts;
  MockProductService(this.mockProducts);

  @override
  Stream<List<Product>> streamActiveProducts({String? categoryId, String search = ''}) {
    return Stream.value(mockProducts);
  }
}

class MockCategoryService extends CategoryService {
  @override
  Stream<List<Category>> streamActive() => Stream.value([]);
}

class MockNearbyStores extends NearbyStores {
  @override
  Stream<List<StorePickup>> watch() => Stream.value([]);
}

class MockCartController extends CartController {}

class MockAuthController extends AuthController {
  @override
  AppUser? get user => AppUser(
        uid: 'test_customer',
        name: 'Test Customer',
        email: 'test@example.com',
        phone: '0901234567',
        address: 'Hanoi',
        role: Roles.customer,
        isActive: true,
        createdAt: DateTime(2026),
      );
}

void main() {
  testWidgets('home search field stays on home and filters produce directly without jumping to Products tab', (tester) async {
    final location = CustomerLocation(source: MockLocationSource());
    addTearDown(location.dispose);

    final cart = MockCartController();
    addTearDown(cart.dispose);

    final auth = MockAuthController();
    addTearDown(auth.dispose);

    final mockProducts = [
      Product(
        id: 'p_apple',
        farmerId: 'f1',
        farmerName: 'Green Farm',
        name: 'Organic Honeycrisp Apple',
        categoryId: 'fruits',
        description: 'Crisp and sweet fresh apples',
        price: 350,
        unit: 'kg',
        stockQty: 50,
        imageUrl: '',
        imageUrls: [],
        isActive: true,
        rating: 4.8,
        reviewCount: 12,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        searchKeywords: ['apple', 'honeycrisp'],
      ),
      Product(
        id: 'p_spinach',
        farmerId: 'f2',
        farmerName: 'Valley Farm',
        name: 'Fresh Spinach',
        categoryId: 'vegetables',
        description: 'Leafy green vegetables',
        price: 200,
        unit: 'bunch',
        stockQty: 25,
        imageUrl: '',
        imageUrls: [],
        isActive: true,
        rating: 4.5,
        reviewCount: 8,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        searchKeywords: ['spinach', 'vegetables'],
      ),
    ];

    int navigatedTab = -1;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<CartController>.value(value: cart),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CustomerHomeLandingTab(
              location: location,
              onNavigateTab: (idx) => navigatedTab = idx,
              onSelectCategory: (_) {},
              productService: MockProductService(mockProducts),
              categoryService: MockCategoryService(),
              nearbyStores: MockNearbyStores(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Search TextField is present
    final searchFinder = find.byType(TextField);
    expect(searchFinder, findsOneWidget);

    // Tapping the search bar should NOT trigger onNavigateTab
    await tester.tap(searchFinder);
    await tester.pump();
    expect(navigatedTab, -1, reason: 'Tapping search must not navigate away from Home');

    // Enter search text "apple"
    await tester.enterText(searchFinder, 'apple');
    await tester.pump();

    // Confirm navigatedTab is still -1
    expect(navigatedTab, -1);

    // Results header and matching product should be shown
    expect(find.text('Results for "apple"'), findsOneWidget);
    expect(find.text('Organic Honeycrisp Apple'), findsOneWidget);
    expect(find.text('Fresh Spinach'), findsNothing);

    // Clear search
    final clearButton = find.byIcon(Icons.close_rounded);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pump();

    // After clearing, search results header disappears
    expect(find.text('Results for "apple"'), findsNothing);
  });
}
