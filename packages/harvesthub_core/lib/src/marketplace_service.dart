import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Category;

import 'models.dart';

FirebaseFirestore? _safeFirestore() {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

List<String> _getCategoryAliases(String categoryId) {
  final lower = categoryId.toLowerCase();
  if (lower == 'vegetables' || lower == 'cat_veg') {
    return ['vegetables', 'cat_veg'];
  }
  if (lower == 'fruits' || lower == 'cat_fruit') {
    return ['fruits', 'cat_fruit'];
  }
  if (lower == 'grains' || lower == 'cat_grain') {
    return ['grains', 'cat_grain'];
  }
  if (lower == 'herbs' || lower == 'cat_herb') {
    return ['herbs', 'cat_herb'];
  }
  if (lower == 'dairy' || lower == 'cat_dairy') {
    return ['dairy', 'cat_dairy'];
  }
  if (lower == 'organic' || lower == 'cat_organic') {
    return ['organic', 'cat_organic'];
  }
  return [categoryId];
}

class ProductService {
  final FirebaseFirestore? _db;
  static final List<Product> _memoryProducts = List<Product>.from(
    getFallbackProducts(),
  );
  static final StreamController<List<Product>> _productsStream =
      StreamController<List<Product>>.broadcast();

  ProductService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore? get db => _db ?? _safeFirestore();

  Stream<List<Product>> streamProductsByFarmer(String farmerId) {
    final firestore = db;
    if (firestore == null) {
      return _streamFarmerMemory(farmerId);
    }
    try {
      return firestore
          .collection('products')
          .where('farmerId', isEqualTo: farmerId)
          .snapshots()
          .map((snapshot) {
            final fsProducts = snapshot.docs
                .map((doc) => Product.fromMap(doc.data(), id: doc.id))
                .toList();
            final mem = _memoryProducts
                .where((p) => p.farmerId == farmerId || farmerId.isEmpty)
                .toList();
            final combined = <Product>[];
            final seenIds = <String>{};
            for (final p in [...fsProducts, ...mem]) {
              if (seenIds.add(p.id)) {
                combined.add(p);
              }
            }
            return combined;
          })
          .handleError((_) => _streamFarmerMemory(farmerId));
    } catch (_) {
      return _streamFarmerMemory(farmerId);
    }
  }

  Stream<List<Product>> _streamFarmerMemory(String farmerId) async* {
    List<Product> filter(List<Product> list) {
      return list
          .where((p) => farmerId.isEmpty || p.farmerId == farmerId)
          .toList();
    }

    yield filter(_memoryProducts);
    yield* _productsStream.stream.map(filter);
  }

  Future<String> addProduct(Product product) async {
    final now = DateTime.now();
    final firestore = db;
    final newId = product.id.isNotEmpty
        ? product.id
        : 'prod_${now.millisecondsSinceEpoch}';

    final finalProduct = product.copyWith(
      id: newId,
      createdAt: now,
      updatedAt: now,
    );

    if (firestore != null) {
      try {
        final docRef = firestore.collection('products').doc(newId);
        await docRef.set(finalProduct.toMap());
      } catch (_) {}
    }

    _memoryProducts.removeWhere((p) => p.id == newId);
    _memoryProducts.insert(0, finalProduct);
    _productsStream.add(List<Product>.from(_memoryProducts));
    return newId;
  }

  Future<void> updateProduct(Product product) async {
    final now = DateTime.now();
    final updated = product.copyWith(updatedAt: now);
    final firestore = db;

    if (firestore != null) {
      try {
        await firestore
            .collection('products')
            .doc(product.id)
            .update(updated.toMap());
      } catch (_) {}
    }

    final index = _memoryProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _memoryProducts[index] = updated;
    } else {
      _memoryProducts.insert(0, updated);
    }
    _productsStream.add(List<Product>.from(_memoryProducts));
  }

  Future<void> deleteProduct(String productId) async {
    final firestore = db;
    if (firestore != null) {
      try {
        await firestore.collection('products').doc(productId).delete();
      } catch (_) {}
    }

    _memoryProducts.removeWhere((p) => p.id == productId);
    _productsStream.add(List<Product>.from(_memoryProducts));
  }

  Future<void> updateStock(String productId, int newStock) async {
    final validStock = newStock < 0 ? 0 : newStock;
    final now = DateTime.now();
    final firestore = db;

    if (firestore != null) {
      try {
        await firestore.collection('products').doc(productId).update({
          'stockQty': validStock,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (_) {}
    }

    final index = _memoryProducts.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _memoryProducts[index] = _memoryProducts[index].copyWith(
        stockQty: validStock,
        updatedAt: now,
      );
    }
    _productsStream.add(List<Product>.from(_memoryProducts));
  }

  Stream<List<Product>> streamActiveProducts({
    String? categoryId,
    String search = '',
  }) {
    final firestore = db;
    if (firestore == null) {
      return Stream.error(StateError('Product data is unavailable'));
    }
    Query<Map<String, dynamic>> query = firestore
        .collection('products')
        .where('isActive', isEqualTo: true);
    if (categoryId != null && categoryId.isNotEmpty) {
      final aliases = _getCategoryAliases(categoryId);
      query = aliases.length == 1
          ? query.where('categoryId', isEqualTo: aliases.first)
          : query.where('categoryId', whereIn: aliases);
    }
    return query.snapshots().map((snapshot) {
      final term = search.trim().toLowerCase();
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), id: doc.id))
          .where(
            (product) =>
                term.isEmpty ||
                product.name.toLowerCase().contains(term) ||
                product.farmerName.toLowerCase().contains(term) ||
                product.description.toLowerCase().contains(term),
          )
          .toList();
    });
  }

  Stream<Product?> watch(String id) {
    final firestore = db;
    if (firestore == null) {
      return Stream.error(StateError('Product data is unavailable'));
    }
    return firestore
        .collection('products')
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Product.fromMap(doc.data()!, id: doc.id) : null,
        );
  }

  Future<Product?> get(String id) async {
    final firestore = db;
    if (firestore == null) throw StateError('Product data is unavailable');
    final doc = await firestore.collection('products').doc(id).get();
    return doc.exists ? Product.fromMap(doc.data()!, id: doc.id) : null;
  }

  static List<Product> getFallbackProducts({
    String? categoryId,
    String search = '',
  }) {
    final aliases = (categoryId != null && categoryId.isNotEmpty)
        ? _getCategoryAliases(categoryId)
        : null;

    final all = <Product>[
      Product(
        id: 'prod_1',
        farmerId: 'farmer_1',
        farmerName: 'Green Valley Organic Farm',
        name: 'Heirloom Vine Tomatoes',
        categoryId: 'vegetables',
        description: 'Naturally ripened, sweet and juicy heirloom tomatoes harvested fresh at sunrise. Perfect for salads and sauces.',
        price: 450,
        unit: 'kg',
        stockQty: 45,
        imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_2',
        farmerId: 'farmer_2',
        farmerName: 'Highland Orchard',
        name: 'Honeycrisp Apples',
        categoryId: 'fruits',
        description: 'Crisp, refreshing sweet apples grown in cool mountain air without synthetic chemical pesticides.',
        price: 620,
        unit: 'kg',
        stockQty: 80,
        imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_3',
        farmerId: 'farmer_1',
        farmerName: 'Green Valley Organic Farm',
        name: 'Crisp Butterhead Lettuce',
        categoryId: 'vegetables',
        description: 'Tender, hydroponic organic butterhead lettuce with buttery soft leaves and exceptional freshness.',
        price: 350,
        unit: 'head',
        stockQty: 30,
        imageUrl: 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_4',
        farmerId: 'farmer_3',
        farmerName: 'Golden Fields Agronomy',
        name: 'Organic Sweet Corn',
        categoryId: 'grains',
        description: 'Plump golden kernels full of natural sugars. Shucked fresh daily from certified sustainable pastures.',
        price: 1800,
        unit: 'crate',
        stockQty: 25,
        imageUrl: 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_5',
        farmerId: 'farmer_4',
        farmerName: 'Meadow Brook Botanicals',
        name: 'Aromatic Sweet Basil',
        categoryId: 'herbs',
        description: 'Freshly clipped Italian sweet basil with intense aroma and culinary essential oils.',
        price: 280,
        unit: 'bunch',
        stockQty: 40,
        imageUrl: 'https://images.unsplash.com/photo-1618164436241-4473940d1f5c?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_6',
        farmerId: 'farmer_5',
        farmerName: 'Pinecrest Apiary',
        name: 'Wildflower Mountain Honey',
        categoryId: 'dairy',
        description: 'Raw, unfiltered artisan honey gathered by free-foraging bees in highland wildflower meadows.',
        price: 1250,
        unit: 'jar',
        stockQty: 20,
        imageUrl: 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_7',
        farmerId: 'farmer_2',
        farmerName: 'Highland Orchard',
        name: 'Sweet Ruby Strawberries',
        categoryId: 'fruits',
        description: 'Deep red, fragrant strawberries with rich natural sweetness, picked at peak maturity.',
        price: 850,
        unit: 'box',
        stockQty: 18,
        imageUrl: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 'prod_8',
        farmerId: 'farmer_3',
        farmerName: 'Golden Fields Agronomy',
        name: 'Whole Grain Rolled Oats',
        categoryId: 'grains',
        description: 'Thick-cut, stone-milled whole oats packed with dietary fiber and wholesome natural energy.',
        price: 520,
        unit: 'bag',
        stockQty: 50,
        imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    return all.where((product) {
      if (aliases != null && !aliases.contains(product.categoryId)) {
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
  final FirebaseFirestore? _db;

  CategoryService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore? get db => _db ?? _safeFirestore();

  Stream<List<Category>> streamActive() {
    final firestore = db;
    if (firestore == null) {
      return Stream.error(StateError('Categories are unavailable'));
    }
    return firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => Category.fromMap(doc.data(), id: doc.id))
              .toList();
          items.sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
          return items;
        });
  }

  static List<Category> getFallbackCategories() {
    return const [
      Category(
        id: 'vegetables',
        name: 'Vegetables',
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=300&q=80',
        sortOrder: 1,
        isActive: true,
      ),
      Category(
        id: 'fruits',
        name: 'Juicy Fruits',
        imageUrl: 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&w=300&q=80',
        sortOrder: 2,
        isActive: true,
      ),
      Category(
        id: 'grains',
        name: 'Grains & Nuts',
        imageUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&w=300&q=80',
        sortOrder: 3,
        isActive: true,
      ),
      Category(
        id: 'herbs',
        name: 'Herbs & Spices',
        imageUrl: 'https://images.unsplash.com/photo-1509358271058-acd22cc93898?auto=format&fit=crop&w=300&q=80',
        sortOrder: 4,
        isActive: true,
      ),
      Category(
        id: 'dairy',
        name: 'Dairy & Honey',
        imageUrl: 'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?auto=format&fit=crop&w=300&q=80',
        sortOrder: 5,
        isActive: true,
      ),
      Category(
        id: 'organic',
        name: 'Organic',
        imageUrl: 'https://images.unsplash.com/photo-1618164436241-4473940d1f5c?auto=format&fit=crop&w=300&q=80',
        sortOrder: 6,
        isActive: true,
      ),
    ];
  }
}

class CartService {
  final FirebaseFirestore? _db;
  final Map<String, List<CartItem>> _memoryCarts = {};
  final StreamController<List<CartItem>> _memoryStream =
      StreamController<List<CartItem>>.broadcast();

  CartService({FirebaseFirestore? db}) : _db = db;

  FirebaseFirestore? get db => _db ?? _safeFirestore();

  CollectionReference<Map<String, dynamic>>? _items(String uid) {
    return db?.collection('carts').doc(uid).collection('items');
  }

  Stream<List<CartItem>> stream(String uid) {
    final collection = _items(uid);
    if (collection == null) {
      return _memoryStream.stream.map((_) => _memoryCarts[uid] ?? []);
    }
    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CartItem.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<void> add(String uid, Product product, int qty) async {
    final collection = _items(uid);
    if (collection == null) {
      final list = _memoryCarts.putIfAbsent(uid, () => []);
      final idx = list.indexWhere((i) => i.productId == product.id);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(qty: list[idx].qty + qty);
      } else {
        list.add(
          CartItem(
            productId: product.id,
            name: product.name,
            price: product.price,
            unit: product.unit,
            imageUrl: product.imageUrl,
            farmerId: product.farmerId,
            farmerName: product.farmerName,
            qty: qty,
          ),
        );
      }
      _memoryStream.add(list);
      return;
    }
    final itemRef = collection.doc(product.id);
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
    final collection = _items(uid);
    if (collection == null) {
      final list = _memoryCarts[uid] ?? [];
      if (qty <= 0) {
        list.removeWhere((i) => i.productId == productId);
      } else {
        final idx = list.indexWhere((i) => i.productId == productId);
        if (idx >= 0) {
          list[idx] = list[idx].copyWith(qty: qty);
        }
      }
      _memoryStream.add(list);
      return;
    }
    if (qty <= 0) {
      await remove(uid, productId);
      return;
    }
    await collection.doc(productId).update({'qty': qty});
  }

  Future<void> remove(String uid, String productId) async {
    final collection = _items(uid);
    if (collection == null) {
      final list = _memoryCarts[uid] ?? [];
      list.removeWhere((i) => i.productId == productId);
      _memoryStream.add(list);
      return;
    }
    await collection.doc(productId).delete();
  }

  Future<void> clear(String uid) async {
    final collection = _items(uid);
    if (collection == null) {
      _memoryCarts.remove(uid);
      _memoryStream.add([]);
      return;
    }
    final docs = await collection.get();
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

  int get quantity => items.fold(0, (total, item) => total + item.qty);

  int get itemCount => quantity;

  int get total =>
      items.fold(0, (total, item) => total + (item.price * item.qty));

  void bind(String? newUid) {
    if (newUid == uid) return;
    _subscription?.cancel();
    uid = newUid;
    items = [];
    if (newUid != null) {
      _subscription = service
          .stream(newUid)
          .listen(
            (data) {
              items = data;
              notifyListeners();
            },
            onError: (_) {
              notifyListeners();
            },
          );
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
        items.add(
          CartItem(
            productId: product.id,
            name: product.name,
            price: product.price,
            unit: product.unit,
            imageUrl: product.imageUrl,
            farmerId: product.farmerId,
            farmerName: product.farmerName,
            qty: qty,
          ),
        );
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

  Future<void> clearAll() async {
    items.clear();
    notifyListeners();
    if (uid != null) {
      try {
        await service.clear(uid!).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
