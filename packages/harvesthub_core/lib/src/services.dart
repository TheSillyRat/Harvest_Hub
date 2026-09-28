import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';

export 'auth_service.dart';
export 'marketplace_service.dart';
import 'models.dart';


class CategoryService {
  final FirebaseFirestore db;
  CategoryService({FirebaseFirestore? db})
      : db = db ?? FirebaseFirestore.instance;
  Stream<List<Category>> streamAll() =>
      db.collection('categories').orderBy('sortOrder').snapshots().map((s) =>
          s.docs.map((d) => Category.fromMap(d.data(), id: d.id)).toList());
  Stream<List<Category>> streamActive() => db
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => Category.fromMap(d.data(), id: d.id)).toList());
  Future<void> save(Category c) => db
      .collection('categories')
      .doc(c.id.isEmpty ? null : c.id)
      .set(c.toMap());
  Future<void> delete(String id) =>
      db.collection('categories').doc(id).update({'isActive': false});
  static List<Category> getFallbackCategories() => const [
        Category(
          id: 'vegetables',
          name: 'Vegetables',
          imageUrl: '',
          sortOrder: 1,
          isActive: true,
        ),
        Category(
          id: 'fruits',
          name: 'Fresh Fruits',
          imageUrl: '',
          sortOrder: 2,
          isActive: true,
        ),
        Category(
          id: 'grains',
          name: 'Grains & Cereals',
          imageUrl: '',
          sortOrder: 3,
          isActive: true,
        ),
        Category(
          id: 'herbs',
          name: 'Herbs & Spices',
          imageUrl: '',
          sortOrder: 4,
          isActive: true,
        ),
        Category(
          id: 'dairy',
          name: 'Dairy & Eggs',
          imageUrl: '',
          sortOrder: 5,
          isActive: true,
        ),
      ];
}

class CartService {
  final FirebaseFirestore db;
  CartService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      db.collection('carts').doc(uid).collection('items');
  Stream<List<CartItem>> stream(String uid) => _items(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => CartItem.fromMap(d.data())).toList());
  Future<void> add(String uid, Product product, int qty) =>
      db.runTransaction((tx) async {
        final productDoc =
            await tx.get(db.collection('products').doc(product.id));
        final cartDoc = await tx.get(_items(uid).doc(product.id));
        if (!productDoc.exists) throw StateError('Product no longer exists');
        final current = Product.fromMap(productDoc.data()!, id: product.id);
        final totalQty = qty + (cartDoc.data()?['qty'] as num? ?? 0).toInt();
        if (!current.isActive || qty <= 0 || totalQty > current.stockQty) {
          throw StateError('Insufficient stock available');
        }
        tx.set(
            cartDoc.reference, CartItem.fromProduct(current, totalQty).toMap());
      });
  Future<void> changeQty(String uid, String id, int qty) async {
    if (qty <= 0) {
      await remove(uid, id);
      return;
    }
    await db.runTransaction((tx) async {
      final p = await tx.get(db.collection('products').doc(id));
      if (!p.exists ||
          p.data()!['isActive'] != true ||
          (p.data()!['stockQty'] as num) < qty) {
        throw StateError('Insufficient stock available');
      }
      tx.update(_items(uid).doc(id), {'qty': qty});
    });
  }

  Future<void> remove(String uid, String id) => _items(uid).doc(id).delete();
  Future<void> clear(String uid) async {
    final docs = await _items(uid).get();
    for (final d in docs.docs) {
      await d.reference.delete();
    }
  }
}



class WishlistService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      db.collection('wishlists').doc(uid).collection('items');
  Stream<Set<String>> stream(String uid) =>
      _items(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  Future<void> toggle(String uid, String id, bool saved) => saved
      ? _items(uid).doc(id).delete()
      : _items(uid).doc(id).set({'productId': id, 'savedAt': Timestamp.now()});
}

class ContactService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  Future<void> send(ContactMessage message) =>
      db.collection('contacts').add(message.toMap());
  Stream<List<ContactMessage>> stream() => db
      .collection('contacts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ContactMessage.fromMap(d.data(), id: d.id))
          .toList());
}

class SeedService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  SeedService({FirebaseFirestore? db, FirebaseAuth? auth})
      : db = db ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  Future<void> run() async {
    final fruitsDoc = await db.collection('categories').doc('fruits').get();
    if (fruitsDoc.exists) return;

    final categories = [
      const Category(
          id: 'vegetables',
          name: 'Vegetables',
          imageUrl: '',
          sortOrder: 1,
          isActive: true),
      const Category(
          id: 'fruits',
          name: 'Fruits',
          imageUrl: '',
          sortOrder: 2,
          isActive: true),
      const Category(
          id: 'dairy',
          name: 'Dairy & Eggs',
          imageUrl: '',
          sortOrder: 3,
          isActive: true),
      const Category(
          id: 'grains',
          name: 'Grains & Cereals',
          imageUrl: '',
          sortOrder: 4,
          isActive: true),
      const Category(
          id: 'herbs',
          name: 'Herbs & Spices',
          imageUrl: '',
          sortOrder: 5,
          isActive: true),
      const Category(
          id: 'organic',
          name: 'Organic',
          imageUrl: '',
          sortOrder: 6,
          isActive: true),
    ];

    for (final c in categories) {
      await db.collection('categories').doc(c.id).set(c.toMap());
    }

    final now = DateTime.now();

    final adminUser = AppUser(
      uid: 'admin_demo_id',
      name: 'HarvestHub Administrator',
      email: 'admin@harvesthub.app',
      phone: '0900000000',
      address: 'Central Admin Office, Hanoi',
      role: Roles.admin,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(adminUser.uid).set(adminUser.toMap());

    final f1User = AppUser(
      uid: 'farmer1_demo_id',
      name: 'John Dalat',
      email: 'farmer1@harvesthub.app',
      phone: '0911111111',
      address: 'Da Lat, Lam Dong',
      role: Roles.farmer,
      isActive: true,
      createdAt: now,
    );
    final f1Profile = FarmerProfile(
      uid: f1User.uid,
      userId: f1User.uid,
      businessName: 'Green Valley Da Lat',
      description:
          'Specializing in fresh, certified organic vegetables and produce harvested daily.',
      area: 'Da Lat',
      rating: 5,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(f1User.uid).set(f1User.toMap());
    await db.collection('farmers').doc(f1User.uid).set(f1Profile.toMap());

    final f2User = AppUser(
      uid: 'farmer2_demo_id',
      name: 'Sarah Ba Vi',
      email: 'farmer2@harvesthub.app',
      phone: '0922222222',
      address: 'Ba Vi, Hanoi',
      role: Roles.farmer,
      isActive: true,
      createdAt: now,
    );
    final f2Profile = FarmerProfile(
      uid: f2User.uid,
      userId: f2User.uid,
      businessName: 'Ba Vi Fresh Dairy Farm',
      description:
          'Supplying fresh organic pasteurized milk and farm produce from Ba Vi pastures.',
      area: 'Ba Vi',
      rating: 5,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(f2User.uid).set(f2User.toMap());
    await db.collection('farmers').doc(f2User.uid).set(f2Profile.toMap());

    final cUser = AppUser(
      uid: 'customer_demo_id',
      name: 'Alex Smith',
      email: 'customer@harvesthub.app',
      phone: '0933333333',
      address: 'Cau Giay, Hanoi',
      role: Roles.customer,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(cUser.uid).set(cUser.toMap());

    final products = [
      Product(
        id: 'p1',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Cherry Tomatoes',
        categoryId: 'vegetables',
        description: 'Juicy organic cherry tomatoes harvested fresh from the garden.',
        price: 35000,
        unit: 'kg',
        stockQty: 30,
        imageUrl:
            'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p2',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Fresh Spinach',
        categoryId: 'vegetables',
        description: 'Crisp pesticide-free organic leafy green spinach.',
        price: 18000,
        unit: 'bunch',
        stockQty: 40,
        imageUrl:
            'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p3',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Fuji Apples',
        categoryId: 'fruits',
        description: 'Crisp and sweet Fuji apples, rich in flavor and vitamins.',
        price: 55000,
        unit: 'kg',
        stockQty: 25,
        imageUrl:
            'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p4',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Sweet Basil',
        categoryId: 'herbs',
        description: 'Aromatic fresh sweet basil for cooking and salads.',
        price: 8000,
        unit: 'bunch',
        stockQty: 50,
        imageUrl:
            'https://images.unsplash.com/photo-1608683286701-bc8499252327?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p5',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Pure Fresh Milk Bottle',
        categoryId: 'dairy',
        description: 'Pure whole pasteurized fresh milk from Ba Vi.',
        price: 32000,
        unit: 'bottle',
        stockQty: 20,
        imageUrl:
            'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p6',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Farm Fresh Eggs',
        categoryId: 'dairy',
        description: 'Nutritious free-range farm fresh organic eggs.',
        price: 45000,
        unit: 'tray',
        stockQty: 15,
        imageUrl:
            'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p7',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Organic Bananas',
        categoryId: 'fruits',
        description: 'Naturally tree-ripened organic sweet bananas.',
        price: 25000,
        unit: 'bunch',
        stockQty: 18,
        imageUrl:
            'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p8',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'ST25 Jasmine Rice',
        categoryId: 'grains',
        description: 'Award-winning fragrant ST25 organic jasmine rice.',
        price: 28000,
        unit: 'kg',
        stockQty: 100,
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final p in products) {
      await db.collection('products').doc(p.id).set(p.toMap());
    }
  }
}
