import 'package:cloud_firestore/cloud_firestore.dart';

DateTime readDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : DateTime.fromMillisecondsSinceEpoch(0);

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  const AppUser(
      {required this.uid,
      required this.name,
      required this.email,
      required this.phone,
      required this.address,
      required this.role,
      required this.isActive,
      required this.createdAt});
  factory AppUser.fromMap(Map<String, dynamic> m, {String id = ''}) => AppUser(
        uid: id,
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        address: m['address'] as String? ?? '',
        role: m['role'] as String? ?? '',
        isActive: m['isActive'] as bool? ?? false,
        createdAt: readDate(m['createdAt']),
      );
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'role': role,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
  AppUser copyWith(
          {String? uid,
          String? name,
          String? email,
          String? phone,
          String? address,
          String? role,
          bool? isActive,
          DateTime? createdAt}) =>
      AppUser(
          uid: uid ?? this.uid,
          name: name ?? this.name,
          email: email ?? this.email,
          phone: phone ?? this.phone,
          address: address ?? this.address,
          role: role ?? this.role,
          isActive: isActive ?? this.isActive,
          createdAt: createdAt ?? this.createdAt);
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
  const FarmerProfile(
      {required this.uid,
      required this.userId,
      required this.businessName,
      required this.description,
      required this.area,
      required this.rating,
      required this.isActive,
      required this.createdAt});
  factory FarmerProfile.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      FarmerProfile(
        uid: id,
        userId: m['userId'] as String? ?? '',
        businessName: m['businessName'] as String? ?? '',
        description: m['description'] as String? ?? '',
        area: m['area'] as String? ?? '',
        rating: (m['rating'] as num?)?.toDouble() ?? 0,
        isActive: m['isActive'] as bool? ?? false,
        createdAt: readDate(m['createdAt']),
      );
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'businessName': businessName,
        'description': description,
        'area': area,
        'rating': rating,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
  FarmerProfile copyWith(
          {String? uid,
          String? userId,
          String? businessName,
          String? description,
          String? area,
          double? rating,
          bool? isActive,
          DateTime? createdAt}) =>
      FarmerProfile(
          uid: uid ?? this.uid,
          userId: userId ?? this.userId,
          businessName: businessName ?? this.businessName,
          description: description ?? this.description,
          area: area ?? this.area,
          rating: rating ?? this.rating,
          isActive: isActive ?? this.isActive,
          createdAt: createdAt ?? this.createdAt);
}

class Category {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;
  const Category(
      {required this.id,
      required this.name,
      required this.imageUrl,
      required this.sortOrder,
      required this.isActive});
  factory Category.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      Category(
        id: id,
        name: m['name'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: m['isActive'] as bool? ?? false,
      );
  Map<String, dynamic> toMap() => {
        'name': name,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };
  Category copyWith(
          {String? id,
          String? name,
          String? imageUrl,
          int? sortOrder,
          bool? isActive}) =>
      Category(
          id: id ?? this.id,
          name: name ?? this.name,
          imageUrl: imageUrl ?? this.imageUrl,
          sortOrder: sortOrder ?? this.sortOrder,
          isActive: isActive ?? this.isActive);
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
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Product(
      {required this.id,
      required this.farmerId,
      required this.farmerName,
      required this.name,
      required this.categoryId,
      required this.description,
      required this.price,
      required this.unit,
      required this.stockQty,
      required this.imageUrl,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  factory Product.fromMap(Map<String, dynamic> m, {String id = ''}) => Product(
        id: id,
        farmerId: m['farmerId'] as String? ?? '',
        farmerName: m['farmerName'] as String? ?? '',
        name: m['name'] as String? ?? '',
        categoryId: m['categoryId'] as String? ?? '',
        description: m['description'] as String? ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        unit: m['unit'] as String? ?? '',
        stockQty: (m['stockQty'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String? ?? '',
        isActive: m['isActive'] as bool? ?? false,
        createdAt: readDate(m['createdAt']),
        updatedAt: readDate(m['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
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
  Product copyWith(
          {String? id,
          String? farmerId,
          String? farmerName,
          String? name,
          String? categoryId,
          String? description,
          int? price,
          String? unit,
          int? stockQty,
          String? imageUrl,
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Product(
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
          isActive: isActive ?? this.isActive,
          createdAt: createdAt ?? this.createdAt,
          updatedAt: updatedAt ?? this.updatedAt);
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
  const CartItem(
      {required this.productId,
      required this.name,
      required this.price,
      required this.unit,
      required this.imageUrl,
      required this.farmerId,
      required this.farmerName,
      required this.qty});
  factory CartItem.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      CartItem(
        productId: m['productId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        unit: m['unit'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        farmerId: m['farmerId'] as String? ?? '',
        farmerName: m['farmerName'] as String? ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'unit': unit,
        'imageUrl': imageUrl,
        'farmerId': farmerId,
        'farmerName': farmerName,
        'qty': qty,
      };
  CartItem copyWith(
          {String? productId,
          String? name,
          int? price,
          String? unit,
          String? imageUrl,
          String? farmerId,
          String? farmerName,
          int? qty}) =>
      CartItem(
          productId: productId ?? this.productId,
          name: name ?? this.name,
          price: price ?? this.price,
          unit: unit ?? this.unit,
          imageUrl: imageUrl ?? this.imageUrl,
          farmerId: farmerId ?? this.farmerId,
          farmerName: farmerName ?? this.farmerName,
          qty: qty ?? this.qty);
  int get subtotal => price * qty;
  factory CartItem.fromProduct(Product p, int qty) => CartItem(
      productId: p.id,
      name: p.name,
      price: p.price,
      unit: p.unit,
      imageUrl: p.imageUrl,
      farmerId: p.farmerId,
      farmerName: p.farmerName,
      qty: qty);
}

class OrderItem {
  final String productId;
  final String name;
  final int price;
  final String unit;
  final String imageUrl;
  final int qty;
  final int subtotal;
  const OrderItem(
      {required this.productId,
      required this.name,
      required this.price,
      required this.unit,
      required this.imageUrl,
      required this.qty,
      required this.subtotal});
  factory OrderItem.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      OrderItem(
        productId: m['productId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        unit: m['unit'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'unit': unit,
        'imageUrl': imageUrl,
        'qty': qty,
        'subtotal': subtotal,
      };
  OrderItem copyWith(
          {String? productId,
          String? name,
          int? price,
          String? unit,
          String? imageUrl,
          int? qty,
          int? subtotal}) =>
      OrderItem(
          productId: productId ?? this.productId,
          name: name ?? this.name,
          price: price ?? this.price,
          unit: unit ?? this.unit,
          imageUrl: imageUrl ?? this.imageUrl,
          qty: qty ?? this.qty,
          subtotal: subtotal ?? this.subtotal);
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
  const FarmOrder(
      {required this.id,
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
      required this.updatedAt});
  factory FarmOrder.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      FarmOrder(
        id: id,
        customerId: m['customerId'] as String? ?? '',
        customerName: m['customerName'] as String? ?? '',
        customerPhone: m['customerPhone'] as String? ?? '',
        farmerId: m['farmerId'] as String? ?? '',
        farmerName: m['farmerName'] as String? ?? '',
        items: (m['items'] as List? ?? [])
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        address: m['address'] as String? ?? '',
        pickupSlot: m['pickupSlot'] as String? ?? '',
        pickupDate: readDate(m['pickupDate']),
        total: (m['total'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? '',
        createdAt: readDate(m['createdAt']),
        updatedAt: readDate(m['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
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
  FarmOrder copyWith(
          {String? id,
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
          DateTime? updatedAt}) =>
      FarmOrder(
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
          updatedAt: updatedAt ?? this.updatedAt);
}

class ContactMessage {
  final String id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final DateTime createdAt;
  final String sourceApp;
  const ContactMessage(
      {required this.id,
      required this.name,
      required this.email,
      required this.subject,
      required this.message,
      required this.createdAt,
      required this.sourceApp});
  factory ContactMessage.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      ContactMessage(
        id: id,
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        subject: m['subject'] as String? ?? '',
        message: m['message'] as String? ?? '',
        createdAt: readDate(m['createdAt']),
        sourceApp: m['sourceApp'] as String? ?? '',
      );
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
        'createdAt': Timestamp.fromDate(createdAt),
        'sourceApp': sourceApp,
      };
  ContactMessage copyWith(
          {String? id,
          String? name,
          String? email,
          String? subject,
          String? message,
          DateTime? createdAt,
          String? sourceApp}) =>
      ContactMessage(
          id: id ?? this.id,
          name: name ?? this.name,
          email: email ?? this.email,
          subject: subject ?? this.subject,
          message: message ?? this.message,
          createdAt: createdAt ?? this.createdAt,
          sourceApp: sourceApp ?? this.sourceApp);
}
