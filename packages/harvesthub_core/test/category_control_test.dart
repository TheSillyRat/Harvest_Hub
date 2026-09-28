import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('Farmer Category Control & Violation Strikes Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ProductService productService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      productService = ProductService(db: fakeFirestore);
    });

    test('FarmerCategory model serializes and deserializes correctly', () {
      final now = DateTime.now();
      final fc = FarmerCategory(
        id: 'fc_1',
        farmerId: 'farmer_123',
        categoryId: 'cat_vegetables',
        createdAt: now,
      );

      final map = fc.toMap();
      expect(map['farmerId'], 'farmer_123');
      expect(map['categoryId'], 'cat_vegetables');

      final reconstructed = FarmerCategory.fromMap(map, id: 'fc_1');
      expect(reconstructed.id, 'fc_1');
      expect(reconstructed.farmerId, 'farmer_123');
      expect(reconstructed.categoryId, 'cat_vegetables');
    });

    test('Product isDeactivated and isCategoryViolation helper properties work', () {
      final now = DateTime.now();
      final activeProduct = Product(
        id: 'p1',
        farmerId: 'f1',
        farmerName: 'Farmer One',
        name: 'Carrot',
        categoryId: 'cat_veg',
        description: 'Fresh carrot',
        price: 15000,
        unit: 'kg',
        stockQty: 50,
        imageUrl: 'https://example.com/carrot.jpg',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      expect(activeProduct.isDeactivated, isFalse);
      expect(activeProduct.isCategoryViolation, isFalse);

      final violatingProduct = activeProduct.copyWith(
        isActive: false,
        deactivationReason: 'SAI_DANH_MUC_DANG_KY',
      );
      expect(violatingProduct.isDeactivated, isTrue);
      expect(violatingProduct.isCategoryViolation, isTrue);
    });

    test('addProduct automatically deactivates product and increments strikes if category is not registered', () async {
      final now = DateTime.now();
      await fakeFirestore.collection('users').doc('farmer_test_1').set({
        'name': 'Farmer Green',
        'email': 'green@farmer.com',
        'phone': '0912345678',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': true,
        'violationStrikes': 0,
        'registeredCategoryIds': ['cat_vegetables', 'cat_fruits'],
        'createdAt': Timestamp.now(),
      });

      await fakeFirestore.collection('farmers').doc('farmer_test_1').set({
        'userId': 'farmer_test_1',
        'businessName': 'Green Farm',
        'area': 'Da Lat',
        'rating': 5.0,
        'isActive': true,
        'violationStrikes': 0,
        'registeredCategoryIds': ['cat_vegetables', 'cat_fruits'],
        'createdAt': Timestamp.now(),
      });

      final product = Product(
        id: 'new_prod_1',
        farmerId: 'farmer_test_1',
        farmerName: 'Farmer Green',
        name: 'Pork meat',
        categoryId: 'cat_meat',
        description: 'Fresh meat',
        price: 90000,
        unit: 'kg',
        stockQty: 20,
        imageUrl: 'https://example.com/meat.jpg',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final prodId = await productService.addProduct(product);

      final prodDoc = await fakeFirestore.collection('products').doc(prodId).get();
      expect(prodDoc.data()!['isActive'], isFalse);
      expect(prodDoc.data()!['deactivationReason'], 'SAI_DANH_MUC_DANG_KY');
      expect(prodDoc.data()!['deactivatedByAdmin'], isTrue);

      final userDoc = await fakeFirestore.collection('users').doc('farmer_test_1').get();
      expect(userDoc.data()!['violationStrikes'], 1);

      final farmerDoc = await fakeFirestore.collection('farmers').doc('farmer_test_1').get();
      expect(farmerDoc.data()!['violationStrikes'], 1);
    });

    test('addProduct keeps product active when category is in registeredCategoryIds', () async {
      final now = DateTime.now();
      await fakeFirestore.collection('users').doc('farmer_valid_1').set({
        'name': 'Farmer Da Lat',
        'email': 'dalat@farmer.com',
        'phone': '0988776655',
        'address': 'Da Lat',
        'role': Roles.farmer,
        'isActive': true,
        'violationStrikes': 0,
        'registeredCategoryIds': ['cat_vegetables'],
        'createdAt': Timestamp.now(),
      });

      final validProduct = Product(
        id: 'valid_prod_1',
        farmerId: 'farmer_valid_1',
        farmerName: 'Farmer Da Lat',
        name: 'Broccoli',
        categoryId: 'cat_vegetables',
        description: 'Green broccoli',
        price: 25000,
        unit: 'kg',
        stockQty: 30,
        imageUrl: 'https://example.com/broccoli.jpg',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final prodId = await productService.addProduct(validProduct);

      final prodDoc = await fakeFirestore.collection('products').doc(prodId).get();
      expect(prodDoc.data()!['isActive'], isTrue);
      expect(prodDoc.data()!['deactivationReason'], isNull);

      final userDoc = await fakeFirestore.collection('users').doc('farmer_valid_1').get();
      expect(userDoc.data()!['violationStrikes'], 0);
    });
  });
}
