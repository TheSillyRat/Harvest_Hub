import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'constants.dart';

export 'auth_service.dart';
export 'marketplace_service.dart';
import 'models.dart';

class StorageService {
  Future<String> uploadProductImage(String farmerId, File file) async {
    try {
      final ref = FirebaseStorage.instance.ref(
          'products/$farmerId/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      // Fallback sample image if Storage is not enabled on Firebase Console yet
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800';
    }
  }
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
      const Category(
          id: 'vegetables',
          name: 'Rau củ',
          imageUrl: '',
          sortOrder: 1,
          isActive: true),
      const Category(
          id: 'fruits',
          name: 'Trái cây',
          imageUrl: '',
          sortOrder: 2,
          isActive: true),
      const Category(
          id: 'dairy',
          name: 'Sữa & trứng',
          imageUrl: '',
          sortOrder: 3,
          isActive: true),
      const Category(
          id: 'grains',
          name: 'Ngũ cốc',
          imageUrl: '',
          sortOrder: 4,
          isActive: true),
      const Category(
          id: 'herbs',
          name: 'Rau thơm',
          imageUrl: '',
          sortOrder: 5,
          isActive: true),
      const Category(
          id: 'organic',
          name: 'Hữu cơ',
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
      description:
          'Chuyên cung cấp các loại rau củ quả tươi ngon từ vùng đất Đà Lạt',
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
      description:
          'Cung cấp sữa tươi sạch và các nông sản cao cấp từ vùng Ba Vì',
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
        name: 'Cải ngọt',
        categoryId: 'vegetables',
        description: 'Rau cải ngọt rau xanh sạch không hóa chất',
        price: 18000,
        unit: 'bó',
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
        name: 'Táo Fuji',
        categoryId: 'fruits',
        description: 'Táo Fuji giòn ngọt đậm vị',
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
        name: 'Húng quế',
        categoryId: 'herbs',
        description: 'Rau thơm húng quế gia vị',
        price: 8000,
        unit: 'bó',
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
        name: 'Sữa tươi chai',
        categoryId: 'dairy',
        description: 'Sữa tươi nguyên chất thanh trùng Ba Vì',
        price: 32000,
        unit: 'chai',
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
        name: 'Trứng gà ta',
        categoryId: 'dairy',
        description: 'Trứng gà ta thả vườn thơm ngon',
        price: 45000,
        unit: 'vỉ',
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
        name: 'Chuối sứ',
        categoryId: 'fruits',
        description: 'Chuối sứ chín cây ngọt tự nhiên',
        price: 25000,
        unit: 'nải',
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
        name: 'Gạo ST25',
        categoryId: 'grains',
        description: 'Gạo ngon nhất thế giới ST25 hạt dẻo thơm',
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
