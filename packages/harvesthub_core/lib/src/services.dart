import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'constants.dart';
import 'models.dart';

class AuthService {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : auth = auth ?? FirebaseAuth.instance,
        db = db ?? FirebaseFirestore.instance;
  Stream<User?> authStateChanges() => auth.authStateChanges();
  Future<AppUser> readUser(String uid) async {
    final doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) throw StateError('Hồ sơ tài khoản chưa được thiết lập');
    return AppUser.fromMap(doc.data()!, id: uid);
  }

  Future<AppUser> login(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    try {
      final user = await readUser(credential.user!.uid);
      if (!user.isActive) throw StateError('Tài khoản đã bị khóa');
      return user;
    } catch (_) {
      await logout();
      rethrow;
    }
  }

  Future<AppUser> registerCustomer(
          {required String name,
          required String email,
          required String phone,
          required String address,
          required String password}) =>
      _register(
          name: name,
          email: email,
          phone: phone,
          address: address,
          password: password,
          role: Roles.customer);
  Future<AppUser> registerFarmer(
          {required String name,
          required String email,
          required String phone,
          required String address,
          required String password,
          required String businessName,
          required String description,
          required String area}) =>
      _register(
          name: name,
          email: email,
          phone: phone,
          address: address,
          password: password,
          role: Roles.farmer,
          businessName: businessName,
          description: description,
          area: area);
  Future<AppUser> _register(
      {required String name,
      required String email,
      required String phone,
      required String address,
      required String password,
      required String role,
      String businessName = '',
      String description = '',
      String area = ''}) async {
    final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = AppUser(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        role: role,
        isActive: true,
        createdAt: DateTime.now());
    try {
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), user.toMap());
      if (role == Roles.farmer) {
        batch.set(
            db.collection('farmers').doc(user.uid),
            FarmerProfile(
                    uid: user.uid,
                    userId: user.uid,
                    businessName: businessName.trim(),
                    description: description.trim(),
                    area: area.trim(),
                    rating: 5,
                    isActive: true,
                    createdAt: user.createdAt)
                .toMap());
      }
      await batch.commit();
      return user;
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> logout() => auth.signOut();
  void requireRole(AppUser user, String expected) {
    if (user.role != expected) {
      throw StateError('Tài khoản không dùng được trên ứng dụng này');
    }
    if (!user.isActive) throw StateError('Tài khoản đã bị khóa');
  }

  Future<void> updateProfile(String uid,
          {required String name,
          required String phone,
          required String address}) =>
      db.collection('users').doc(uid).update({
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim()
      });
}

class ProductService {
  final FirebaseFirestore db;
  ProductService({FirebaseFirestore? db})
      : db = db ?? FirebaseFirestore.instance;
  Stream<List<Product>> _stream(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((s) =>
          s.docs.map((d) => Product.fromMap(d.data(), id: d.id)).toList());
  Stream<List<Product>> streamActiveProducts(
      {String? categoryId, String search = ''}) {
    Query<Map<String, dynamic>> q =
        db.collection('products').where('isActive', isEqualTo: true);
    if (categoryId != null) q = q.where('categoryId', isEqualTo: categoryId);
    return _stream(q).map((items) => items
        .where(
            (p) => p.name.toLowerCase().contains(search.toLowerCase().trim()))
        .toList());
  }

  Stream<List<Product>> streamByFarmer(String farmerId) => _stream(db
      .collection('products')
      .where('farmerId', isEqualTo: farmerId)
      .orderBy('createdAt', descending: true));
  Stream<List<Product>> streamAll() => _stream(db.collection('products'));
  Stream<Product?> watch(String id) => db
      .collection('products')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Product.fromMap(d.data()!, id: d.id) : null);
  Future<Product?> get(String id) async {
    final d = await db.collection('products').doc(id).get();
    return d.exists ? Product.fromMap(d.data()!, id: d.id) : null;
  }

  Future<void> create(Product p) =>
      db.collection('products').doc().set(p.toMap());
  Future<void> update(Product p, {DateTime? expectedUpdatedAt}) => db.runTransaction((tx) async {
    final ref = db.collection('products').doc(p.id);
    final current = await tx.get(ref);
    if (!current.exists) throw StateError('Sản phẩm không còn tồn tại');
    if (expectedUpdatedAt != null && readDate(current.data()!['updatedAt']) != expectedUpdatedAt) {
      throw StateError('Sản phẩm hoặc tồn kho đã thay đổi. Mở lại form trước khi lưu');
    }
    tx.update(ref, p.copyWith(updatedAt: DateTime.now()).toMap());
  });
  Future<void> delete(String id) => setActive(id, false);
  Future<void> setActive(String id, bool active) => db
      .collection('products')
      .doc(id)
      .update({'isActive': active, 'updatedAt': Timestamp.now()});
  Future<void> updateStock(String id, int qty) {
    if (qty < 0) throw ArgumentError('Tồn kho không hợp lệ');
    return db
        .collection('products')
        .doc(id)
        .update({'stockQty': qty, 'updatedAt': Timestamp.now()});
  }
}

class StorageService {
  Future<String> uploadProductImage(String farmerId, File file) async {
    final ref = FirebaseStorage.instance
        .ref('products/$farmerId/${DateTime.now().microsecondsSinceEpoch}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
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
        if (!productDoc.exists) throw StateError('Sản phẩm không còn tồn tại');
        final current = Product.fromMap(productDoc.data()!, id: product.id);
        final totalQty = qty + (cartDoc.data()?['qty'] as num? ?? 0).toInt();
        if (!current.isActive || qty <= 0 || totalQty > current.stockQty) {
          throw StateError('Tồn kho không đủ');
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
        throw StateError('Tồn kho không đủ');
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

class CategoryService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  Stream<List<Category>> streamAll() =>
      db.collection('categories').orderBy('sortOrder').snapshots().map((s) =>
          s.docs.map((d) => Category.fromMap(d.data(), id: d.id)).toList());
  Stream<List<Category>> streamActive() =>
      streamAll().map((items) => items.where((c) => c.isActive).toList());
  Future<void> save(Category c) => db
      .collection('categories')
      .doc(c.id.isEmpty ? null : c.id)
      .set(c.toMap());
  Future<void> delete(String id) =>
      db.collection('categories').doc(id).update({'isActive': false});
}

class UserAdminService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  Stream<List<AppUser>> streamUsers() => db.collection('users').snapshots().map(
      (s) => s.docs.map((d) => AppUser.fromMap(d.data(), id: d.id)).toList());
  Stream<List<FarmerProfile>> streamFarmers() =>
      db.collection('farmers').snapshots().map((s) => s.docs
          .map((d) => FarmerProfile.fromMap(d.data(), id: d.id))
          .toList());
  Future<void> setIsActive(AppUser user, bool active) async {
    final batch = db.batch();
    batch.update(db.collection('users').doc(user.uid), {'isActive': active});
    if (user.role == Roles.farmer) {
      batch
          .update(db.collection('farmers').doc(user.uid), {'isActive': active});
    }
    await batch.commit();
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
      const Category(id: 'vegetables', name: 'Rau củ', imageUrl: '', sortOrder: 1, isActive: true),
      const Category(id: 'fruits', name: 'Trái cây', imageUrl: '', sortOrder: 2, isActive: true),
      const Category(id: 'dairy', name: 'Sữa & trứng', imageUrl: '', sortOrder: 3, isActive: true),
      const Category(id: 'grains', name: 'Ngũ cốc', imageUrl: '', sortOrder: 4, isActive: true),
      const Category(id: 'herbs', name: 'Rau thơm', imageUrl: '', sortOrder: 5, isActive: true),
      const Category(id: 'organic', name: 'Hữu cơ', imageUrl: '', sortOrder: 6, isActive: true),
    ];

    for (final c in categories) {
      await db.collection('categories').doc(c.id).set(c.toMap());
    }

    final now = DateTime.now();

    final adminUser = AppUser(
      uid: 'admin_demo_id',
      name: 'Quản trị HarvestHub',
      email: 'admin@harvesthub.app',
      phone: '0900000000',
      address: 'Hà Nội',
      role: Roles.admin,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(adminUser.uid).set(adminUser.toMap());

    final f1User = AppUser(
      uid: 'farmer1_demo_id',
      name: 'Nguyễn Văn Nông 1',
      email: 'farmer1@harvesthub.app',
      phone: '0911111111',
      address: 'Đà Lạt, Lâm Đồng',
      role: Roles.farmer,
      isActive: true,
      createdAt: now,
    );
    final f1Profile = FarmerProfile(
      uid: f1User.uid,
      userId: f1User.uid,
      businessName: 'Vườn Xanh Đà Lạt',
      description: 'Chuyên cung cấp các loại rau củ quả tươi ngon từ vùng đất Đà Lạt',
      area: 'Đà Lạt',
      rating: 5,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(f1User.uid).set(f1User.toMap());
    await db.collection('farmers').doc(f1User.uid).set(f1Profile.toMap());

    final f2User = AppUser(
      uid: 'farmer2_demo_id',
      name: 'Trần Thị Nông 2',
      email: 'farmer2@harvesthub.app',
      phone: '0922222222',
      address: 'Ba Vì, Hà Nội',
      role: Roles.farmer,
      isActive: true,
      createdAt: now,
    );
    final f2Profile = FarmerProfile(
      uid: f2User.uid,
      userId: f2User.uid,
      businessName: 'Trại Sữa Ba Vì',
      description: 'Cung cấp sữa tươi sạch và các nông sản cao cấp từ vùng Ba Vì',
      area: 'Ba Vì',
      rating: 5,
      isActive: true,
      createdAt: now,
    );
    await db.collection('users').doc(f2User.uid).set(f2User.toMap());
    await db.collection('farmers').doc(f2User.uid).set(f2Profile.toMap());

    final cUser = AppUser(
      uid: 'customer_demo_id',
      name: 'Lê Văn Khách',
      email: 'customer@harvesthub.app',
      phone: '0933333333',
      address: 'Cầu Giấy, Hà Nội',
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
        name: 'Cà chua bi',
        categoryId: 'vegetables',
        description: 'Cà chua bi hữu cơ mọng nước tươi hái tại vườn',
        price: 35000,
        unit: 'kg',
        stockQty: 30,
        imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p2',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Cải ngọt',
        categoryId: 'vegetables',
        description: 'Rau cải ngọt rau xanh sạch không hóa chất',
        price: 18000,
        unit: 'bó',
        stockQty: 40,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p3',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Táo Fuji',
        categoryId: 'fruits',
        description: 'Táo Fuji giòn ngọt đậm vị',
        price: 55000,
        unit: 'kg',
        stockQty: 25,
        imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p4',
        farmerId: f1User.uid,
        farmerName: f1Profile.businessName,
        name: 'Húng quế',
        categoryId: 'herbs',
        description: 'Rau thơm húng quế gia vị',
        price: 8000,
        unit: 'bó',
        stockQty: 50,
        imageUrl: 'https://images.unsplash.com/photo-1608683286701-bc8499252327?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p5',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Sữa tươi chai',
        categoryId: 'dairy',
        description: 'Sữa tươi nguyên chất thanh trùng Ba Vì',
        price: 32000,
        unit: 'chai',
        stockQty: 20,
        imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p6',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Trứng gà ta',
        categoryId: 'dairy',
        description: 'Trứng gà ta thả vườn thơm ngon',
        price: 45000,
        unit: 'vỉ',
        stockQty: 15,
        imageUrl: 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p7',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Chuối sứ',
        categoryId: 'fruits',
        description: 'Chuối sứ chín cây ngọt tự nhiên',
        price: 25000,
        unit: 'nải',
        stockQty: 18,
        imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p8',
        farmerId: f2User.uid,
        farmerName: f2Profile.businessName,
        name: 'Gạo ST25',
        categoryId: 'grains',
        description: 'Gạo ngon nhất thế giới ST25 hạt dẻo thơm',
        price: 28000,
        unit: 'kg',
        stockQty: 100,
        imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500',
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
