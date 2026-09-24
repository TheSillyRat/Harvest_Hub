import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'models.dart';

class ProductService {
  final FirebaseFirestore db;

  ProductService({FirebaseFirestore? db})
      : db = db ?? FirebaseFirestore.instance;

  Stream<List<Product>> streamActiveProducts({
    String? categoryId,
    String search = '',
  }) {
    Query<Map<String, dynamic>> query =
        db.collection('products').where('isActive', isEqualTo: true);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), id: doc.id))
          .where((product) {
        if (search.trim().isEmpty) return true;
        final queryText = search.trim().toLowerCase();
        return product.name.toLowerCase().contains(queryText) ||
            product.farmerName.toLowerCase().contains(queryText) ||
            product.description.toLowerCase().contains(queryText);
      }).toList();

      if (items.isEmpty && search.isEmpty && categoryId == null) {
        return getFallbackProducts();
      }
      return items;
    }).handleError((_) => getFallbackProducts(categoryId: categoryId, search: search));
  }

  Stream<Product?> watch(String id) {
    return db.collection('products').doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        return getFallbackProducts().firstWhere(
          (p) => p.id == id,
          orElse: () => getFallbackProducts().first,
        );
      }
      return Product.fromMap(doc.data()!, id: doc.id);
    }).handleError((_) {
      return getFallbackProducts().firstWhere(
        (p) => p.id == id,
        orElse: () => getFallbackProducts().first,
      );
    });
  }

  Future<Product?> get(String id) async {
    try {
      final doc = await db.collection('products').doc(id).get();
      if (doc.exists) {
        return Product.fromMap(doc.data()!, id: doc.id);
      }
    } catch (_) {}
    return getFallbackProducts().firstWhere(
      (p) => p.id == id,
      orElse: () => getFallbackProducts().first,
    );
  }

  static List<Product> getFallbackProducts({
    String? categoryId,
    String search = '',
  }) {
    final all = <Product>[
      Product(
        id: 'prod_1',
        farmerId: 'farmer_1',
        farmerName: 'Green Valley Organic Farm',
        name: 'Heirloom Vine Tomatoes',
        categoryId: 'cat_veg',
        description:
            'Naturally ripened, sweet and juicy heirloom tomatoes harvested fresh at sunrise. Perfect for salads and sauces.',
        price: 450,
        unit: 'kg',
        stockQty: 45,
        imageUrl:
            'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_2',
        farmerId: 'farmer_2',
        farmerName: 'Highland Orchard',
        name: 'Honeycrisp Apples',
        categoryId: 'cat_fruit',
        description:
            'Crisp, refreshing sweet apples grown in cool mountain air without synthetic chemical pesticides.',
        price: 620,
        unit: 'kg',
        stockQty: 80,
        imageUrl:
            'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_3',
        farmerId: 'farmer_1',
        farmerName: 'Green Valley Organic Farm',
        name: 'Crisp Butterhead Lettuce',
        categoryId: 'cat_veg',
        description:
            'Tender, hydroponic organic butterhead lettuce with buttery soft leaves and exceptional freshness.',
        price: 350,
        unit: 'head',
        stockQty: 30,
        imageUrl:
            'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_4',
        farmerId: 'farmer_3',
        farmerName: 'Golden Fields Agronomy',
        name: 'Organic Sweet Corn',
        categoryId: 'cat_grain',
        description:
            'Plump golden kernels full of natural sugars. Shucked fresh daily from certified sustainable pastures.',
        price: 1800,
        unit: 'crate',
        stockQty: 25,
        imageUrl:
            'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_5',
        farmerId: 'farmer_4',
        farmerName: 'Meadow Brook Botanicals',
        name: 'Aromatic Sweet Basil',
        categoryId: 'cat_herb',
        description:
            'Freshly clipped Italian sweet basil with intense aroma and culinary essential oils.',
        price: 280,
        unit: 'bunch',
        stockQty: 40,
        imageUrl:
            'https://images.unsplash.com/photo-1618164436241-4473940d1f5c?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_6',
        farmerId: 'farmer_5',
        farmerName: 'Pinecrest Apiary',
        name: 'Wildflower Mountain Honey',
        categoryId: 'cat_dairy',
        description:
            'Raw, unfiltered artisan honey gathered by free-foraging bees in highland wildflower meadows.',
        price: 1250,
        unit: 'jar',
        stockQty: 20,
        imageUrl:
            'https://images.unsplash.com/photo-1587049352846-4a222e784d38?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_7',
        farmerId: 'farmer_2',
        farmerName: 'Highland Orchard',
        name: 'Sweet Ruby Strawberries',
        categoryId: 'cat_fruit',
        description:
            'Deep red, fragrant strawberries with rich natural sweetness, picked at peak maturity.',
        price: 850,
        unit: 'box',
        stockQty: 18,
        imageUrl:
            'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_8',
        farmerId: 'farmer_3',
        farmerName: 'Golden Fields Agronomy',
        name: 'Whole Grain Rolled Oats',
        categoryId: 'cat_grain',
        description:
            'Thick-cut, stone-milled whole oats packed with dietary fiber and wholesome natural energy.',
        price: 520,
        unit: 'bag',
        stockQty: 50,
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    return all.where((product) {
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          product.categoryId != categoryId) {
        return false;
      }
      if (search.trim().isNotEmpty) {
        final queryText = search.trim().toLowerCase();
        return product.name.toLowerCase().contains(queryText) ||
            product.farmerName.toLowerCase().contains(queryText) ||
            product.description.toLowerCase().contains(queryText);
      }
      return true;
    }).toList();
  }
}

class CategoryService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Stream<List<Category>> streamActive() {
    return db
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Category.fromMap(doc.data(), id: doc.id))
          .toList();
      if (items.isEmpty) {
        return getFallbackCategories();
      }
      return items;
    }).handleError((_) => getFallbackCategories());
  }

  static List<Category> getFallbackCategories() {
    return const [
      Category(
        id: 'cat_veg',
        name: 'Vegetables',
        imageUrl:
            'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=300&q=80',
        sortOrder: 1,
        isActive: true,
      ),
      Category(
        id: 'cat_fruit',
        name: 'Juicy Fruits',
        imageUrl:
            'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&w=300&q=80',
        sortOrder: 2,
        isActive: true,
      ),
      Category(
        id: 'cat_grain',
        name: 'Grains & Nuts',
        imageUrl:
            'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&w=300&q=80',
        sortOrder: 3,
        isActive: true,
      ),
      Category(
        id: 'cat_herb',
        name: 'Herbs & Spices',
        imageUrl:
            'https://images.unsplash.com/photo-1509358271058-acd22cc93898?auto=format&fit=crop&w=300&q=80',
        sortOrder: 4,
        isActive: true,
      ),
      Category(
        id: 'cat_dairy',
        name: 'Dairy & Honey',
        imageUrl:
            'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?auto=format&fit=crop&w=300&q=80',
        sortOrder: 5,
        isActive: true,
      ),
    ];
  }
}

class CartService {
  final FirebaseFirestore db;

  CartService({FirebaseFirestore? db})
      : db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String uid) {
    return db.collection('carts').doc(uid).collection('items');
  }

  Stream<List<CartItem>> stream(String uid) {
    return _items(uid).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartItem.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<void> add(String uid, Product product, int qty) async {
    final itemRef = _items(uid).doc(product.id);
    final doc = await itemRef.get();
    if (doc.exists) {
      final current = CartItem.fromMap(doc.data()!, id: product.id);
      final newQty = current.qty + qty;
      await itemRef.update({'qty': newQty});
    } else {
      final newItem = CartItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        unit: product.unit,
        imageUrl: product.imageUrl,
        farmerId: product.farmerId,
        farmerName: product.farmerName,
        qty: qty,
      );
      await itemRef.set(newItem.toMap());
    }
  }

  Future<void> changeQty(String uid, String productId, int qty) async {
    if (qty <= 0) {
      await remove(uid, productId);
      return;
    }
    await _items(uid).doc(productId).update({'qty': qty});
  }

  Future<void> remove(String uid, String productId) async {
    await _items(uid).doc(productId).delete();
  }

  Future<void> clear(String uid) async {
    final docs = await _items(uid).get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
  }
}

class CartController extends ChangeNotifier {
  final CartService service = CartService();
  String? uid;
  List<CartItem> items = [];
  StreamSubscription<List<CartItem>>? _subscription;

  int get quantity =>
      items.fold(0, (total, item) => total + item.qty);

  int get total =>
      items.fold(0, (total, item) => total + (item.price * item.qty));

  void bind(String? newUid) {
    if (newUid == uid) return;
    _subscription?.cancel();
    uid = newUid;
    items = [];
    if (newUid != null) {
      _subscription = service.stream(newUid).listen((data) {
        items = data;
        notifyListeners();
      }, onError: (_) {
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> addToCart(Product product, [int qty = 1]) async {
    if (uid == null) {
      final index = items.indexWhere((i) => i.productId == product.id);
      if (index >= 0) {
        final existing = items[index];
        items[index] = existing.copyWith(qty: existing.qty + qty);
      } else {
        items.add(CartItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          unit: product.unit,
          imageUrl: product.imageUrl,
          farmerId: product.farmerId,
          farmerName: product.farmerName,
          qty: qty,
        ));
      }
      notifyListeners();
      return;
    }
    await service.add(uid!, product, qty);
  }

  Future<void> updateQuantity(String productId, int qty) async {
    if (uid == null) {
      if (qty <= 0) {
        items.removeWhere((i) => i.productId == productId);
      } else {
        final index = items.indexWhere((i) => i.productId == productId);
        if (index >= 0) {
          items[index] = items[index].copyWith(qty: qty);
        }
      }
      notifyListeners();
      return;
    }
    await service.changeQty(uid!, productId, qty);
  }

  Future<void> removeItem(String productId) async {
    if (uid == null) {
      items.removeWhere((i) => i.productId == productId);
      notifyListeners();
      return;
    }
    await service.remove(uid!, productId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
