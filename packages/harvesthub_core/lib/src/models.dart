import 'package:cloud_firestore/cloud_firestore.dart';

DateTime readDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return AppUser(
      uid: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      role: map['role'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FarmerProfile {
  final String uid;
  final String userId;
  final String businessName;
  final String description;
  final String area;
  final double rating;
  final bool isActive;
  final DateTime createdAt;

  const FarmerProfile({
    required this.uid,
    required this.userId,
    required this.businessName,
    required this.description,
    required this.area,
    required this.rating,
    required this.isActive,
    required this.createdAt,
  });

  factory FarmerProfile.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return FarmerProfile(
      uid: id,
      userId: map['userId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      area: map['area'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] as bool? ?? false,
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessName': businessName,
      'description': description,
      'area': area,
      'rating': rating,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FarmerProfile copyWith({
    String? uid,
    String? userId,
    String? businessName,
    String? description,
    String? area,
    double? rating,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return FarmerProfile(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      area: area ?? this.area,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory Category.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Category(
      id: id,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Product {
  final String id;
  final String farmerId;
  final String farmerName;
  final String name;
  final String categoryId;
  final String description;
  final int price;
  final String unit;
  final int stockQty;
  final String imageUrl;
  final List<String> imageUrls;
  final bool isActive;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.price,
    required this.unit,
    required this.stockQty,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.isActive,
    this.rating = 0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Product(
      id: id,
      farmerId: map['farmerId'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      name: map['name'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? '',
      stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
      imageUrl: map['imageUrl'] as String? ?? '',
      imageUrls: (map['imageUrls'] is List)
          ? (map['imageUrls'] as List).whereType<String>().toList()
          : const [],
      isActive: map['isActive'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }

  /// Keep the cover first, remove duplicates, and show at most six photos.
  List<String> get galleryImages => <String>{
        for (final url in [imageUrl, ...imageUrls])
          if (url.trim().isNotEmpty) url.trim(),
      }.take(6).toList(growable: false);

  // Optional gallery/review fields are read-only here so existing Farmer edits
  // cannot reset them when saving the original product form.
  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'farmerName': farmerName,
      'name': name,
      'categoryId': categoryId,
      'description': description,
      'price': price,
      'unit': unit,
      'stockQty': stockQty,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Product copyWith({
    String? id,
    String? farmerId,
    String? farmerName,
    String? name,
    String? categoryId,
    String? description,
    int? price,
    String? unit,
    int? stockQty,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isActive,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      stockQty: stockQty ?? this.stockQty,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CartItem {
  final String productId;
  final String name;
  final int price;
  final String unit;
  final String imageUrl;
  final String farmerId;
  final String farmerName;
  final int qty;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.unit,
    required this.imageUrl,
    required this.farmerId,
    required this.farmerName,
    required this.qty,
  });

  factory CartItem.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return CartItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      farmerId: map['farmerId'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
    );
  }

  factory CartItem.fromProduct(Product p, int qty) {
    return CartItem(
      productId: p.id,
      name: p.name,
      price: p.price,
      unit: p.unit,
      imageUrl: p.imageUrl,
      farmerId: p.farmerId,
      farmerName: p.farmerName,
      qty: qty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'unit': unit,
      'imageUrl': imageUrl,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'qty': qty,
    };
  }

  CartItem copyWith({
    String? productId,
    String? name,
    int? price,
    String? unit,
    String? imageUrl,
    String? farmerId,
    String? farmerName,
    int? qty,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      qty: qty ?? this.qty,
    );
  }

  int get subtotal => price * qty;
}

class OrderItem {
  final String productId;
  final String name;
  final int price;
  final String unit;
  final String imageUrl;
  final int qty;
  final int subtotal;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.unit,
    required this.imageUrl,
    required this.qty,
    required this.subtotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return OrderItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'unit': unit,
      'imageUrl': imageUrl,
      'qty': qty,
      'subtotal': subtotal,
    };
  }
}

class FarmOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String farmerId;
  final String farmerName;
  final List<OrderItem> items;
  final String address;
  final String pickupSlot;
  final DateTime pickupDate;
  final int total;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FarmOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.farmerId,
    required this.farmerName,
    required this.items,
    required this.address,
    required this.pickupSlot,
    required this.pickupDate,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmOrder.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return FarmOrder(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      farmerId: map['farmerId'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      items: (map['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      address: map['address'] as String? ?? '',
      pickupSlot: map['pickupSlot'] as String? ?? '',
      pickupDate: readDate(map['pickupDate']),
      total: (map['total'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'items': items.map((e) => e.toMap()).toList(),
      'address': address,
      'pickupSlot': pickupSlot,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'total': total,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FarmOrder copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? farmerId,
    String? farmerName,
    List<OrderItem>? items,
    String? address,
    String? pickupSlot,
    DateTime? pickupDate,
    int? total,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmOrder(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      items: items ?? this.items,
      address: address ?? this.address,
      pickupSlot: pickupSlot ?? this.pickupSlot,
      pickupDate: pickupDate ?? this.pickupDate,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ContactMessage {
  final String id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final DateTime createdAt;
  final String sourceApp;

  const ContactMessage({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.createdAt,
    required this.sourceApp,
  });

  factory ContactMessage.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return ContactMessage(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: readDate(map['createdAt']),
      sourceApp: map['sourceApp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'sourceApp': sourceApp,
    };
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? targetId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return AppNotification(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      targetId: map['targetId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'targetId': targetId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

