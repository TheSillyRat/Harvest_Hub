import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

List<String> generateSearchKeywords(String name) {
  final keywords = <String>{};
  final clean = name.trim().toLowerCase();
  if (clean.isEmpty) return [];

  keywords.add(clean);

  for (int i = 1; i <= clean.length && i <= 30; i++) {
    final sub = clean.substring(0, i).trim();
    if (sub.isNotEmpty) keywords.add(sub);
  }

  final words = clean.split(RegExp(r'\s+'));
  for (final word in words) {
    if (word.isEmpty) continue;
    keywords.add(word);
    for (int i = 1; i <= word.length && i <= 20; i++) {
      final sub = word.substring(0, i);
      if (sub.isNotEmpty) keywords.add(sub);
    }
  }

  keywords.removeWhere((k) => k.isEmpty);
  return keywords.toList();
}

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
  final String avatarUrl;
  final String? deactivationReason;
  final bool activationNoticePending;
  final DateTime? deactivatedAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.avatarUrl = '',
    this.deactivationReason,
    this.activationNoticePending = false,
    this.deactivatedAt,
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
      avatarUrl: map['avatarUrl'] as String? ?? map['imageUrl'] as String? ?? '',
      deactivationReason: map['deactivation_reason'] as String? ??
          map['deactivationReason'] as String?,
      activationNoticePending: map['activationNoticePending'] as bool? ??
          map['activation_notice_pending'] as bool? ??
          false,
      deactivatedAt:
          map['deactivatedAt'] != null ? readDate(map['deactivatedAt']) : null,
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
      'avatarUrl': avatarUrl,
      'deactivation_reason': deactivationReason,
      'deactivationReason': deactivationReason,
      'activationNoticePending': activationNoticePending,
      if (deactivatedAt != null)
        'deactivatedAt': Timestamp.fromDate(deactivatedAt!),
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
    String? avatarUrl,
    String? deactivationReason,
    bool? activationNoticePending,
    DateTime? deactivatedAt,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      activationNoticePending:
          activationNoticePending ?? this.activationNoticePending,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
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
  final String avatarUrl;
  final String? deactivationReason;
  final String? operatingHours;
  final List<String>? operatingDays;

  const FarmerProfile({
    required this.uid,
    required this.userId,
    required this.businessName,
    required this.description,
    required this.area,
    required this.rating,
    required this.isActive,
    required this.createdAt,
    this.avatarUrl = '',
    this.deactivationReason,
    this.operatingHours,
    this.operatingDays,
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
      avatarUrl: map['avatarUrl'] as String? ?? map['imageUrl'] as String? ?? '',
      deactivationReason: map['deactivation_reason'] as String? ??
          map['deactivationReason'] as String?,
      operatingHours: map['operatingHours'] as String? ??
          map['operating_hours'] as String?,
      operatingDays: (map['operatingDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (map['operating_days'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
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
      'avatarUrl': avatarUrl,
      'deactivation_reason': deactivationReason,
      'deactivationReason': deactivationReason,
      if (operatingHours != null) 'operatingHours': operatingHours,
      if (operatingDays != null) 'operatingDays': operatingDays,
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
    String? avatarUrl,
    String? deactivationReason,
    String? operatingHours,
    List<String>? operatingDays,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      operatingHours: operatingHours ?? this.operatingHours,
      operatingDays: operatingDays ?? this.operatingDays,
    );
  }
}

class FarmerScheduleStatus {
  final bool isOpenToday;
  final bool isOpenTomorrow;
  final String statusBadge;
  final String nextOpenText;
  final Color badgeColor;
  final Color textColor;

  const FarmerScheduleStatus({
    required this.isOpenToday,
    this.isOpenTomorrow = false,
    required this.statusBadge,
    required this.nextOpenText,
    required this.badgeColor,
    required this.textColor,
  });

  static FarmerScheduleStatus calculate({
    List<dynamic>? operatingDays,
    String? operatingHours,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    const dayCodes = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayCode = dayCodes[current.weekday - 1];

    final days = operatingDays
        ?.map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final effectiveDays = (days != null && days.isNotEmpty)
        ? days
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final isOpenToday = effectiveDays.contains(todayCode);

    final tomorrow = current.add(const Duration(days: 1));
    final tomorrowCode = dayCodes[tomorrow.weekday - 1];
    final isOpenTomorrow = effectiveDays.contains(tomorrowCode);

    if (isOpenToday) {
      return FarmerScheduleStatus(
        isOpenToday: true,
        isOpenTomorrow: isOpenTomorrow,
        statusBadge: 'Open Today',
        nextOpenText: 'Open for pickup',
        badgeColor: const Color(0xFFE8F5E9),
        textColor: const Color(0xFF2E7D32),
      );
    }

    String nextDay = '';
    for (int i = 1; i <= 7; i++) {
      final checkWeekday = (current.weekday - 1 + i) % 7;
      final checkCode = dayCodes[checkWeekday];
      if (effectiveDays.contains(checkCode)) {
        nextDay = checkCode;
        break;
      }
    }

    final nextText =
        nextDay.isNotEmpty ? 'Opens $nextDay' : 'Temporarily Closed';

    return FarmerScheduleStatus(
      isOpenToday: false,
      isOpenTomorrow: isOpenTomorrow,
      statusBadge: 'Closed Today',
      nextOpenText: nextText,
      badgeColor: const Color(0xFFFBE9E7),
      textColor: const Color(0xFFD32F2F),
    );
  }

  static List<String> getSlotsForOperatingHours(
    String? operatingHours, {
    List<dynamic>? operatingSlots,
  }) {
    if (operatingSlots != null && operatingSlots.isNotEmpty) {
      final list = <String>[];
      for (final s in operatingSlots) {
        if (s is Map) {
          final from = s['from']?.toString().trim();
          final to = s['to']?.toString().trim();
          if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
            list.add('$from – $to');
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    final raw = (operatingHours ?? '07:00 - 18:00').trim();
    final parts = raw
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      return parts;
    }

    final match = RegExp(
            r'(\d{1,2})(?:[:hH](\d{2}))?\s*[-–—]\s*(\d{1,2})(?:[:hH](\d{2}))?')
        .firstMatch(raw);
    if (match == null) {
      return const ['07:00 – 10:00', '15:00 – 18:00'];
    }

    final startH = int.tryParse(match.group(1) ?? '7') ?? 7;
    final startM = int.tryParse(match.group(2) ?? '0') ?? 0;
    final endH = int.tryParse(match.group(3) ?? '18') ?? 18;
    final endM = int.tryParse(match.group(4) ?? '0') ?? 0;

    final startTotalMin = startH * 60 + startM;
    final endTotalMin = endH * 60 + endM;
    final diffMin = endTotalMin - startTotalMin;

    if (diffMin <= 180) {
      final sStr =
          '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
      final eStr =
          '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
      return ['$sStr – $eStr'];
    }

    final step = diffMin > 360 ? 180 : (diffMin > 240 ? 150 : 120);
    final slots = <String>[];
    int cur = startTotalMin;
    while (cur < endTotalMin) {
      int next = cur + step;
      if (next > endTotalMin || (endTotalMin - next) < 60) {
        next = endTotalMin;
      }
      final sH = cur ~/ 60;
      final sM = cur % 60;
      final eH = next ~/ 60;
      final eM = next % 60;
      final sStr =
          '${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}';
      final eStr =
          '${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}';
      slots.add('$sStr – $eStr');
      cur = next;
    }
    return slots;
  }

  static bool isSlotAvailableToday(String slotStr, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final match = RegExp(
            r'(\d{1,2})(?:[:hH](\d{2}))?\s*[-–—]\s*(\d{1,2})(?:[:hH](\d{2}))?')
        .firstMatch(slotStr);
    if (match == null) {
      if (slotStr == 'morning_07_10') {
        return current.isBefore(DateTime(current.year, current.month, current.day, 7, 0));
      } else if (slotStr == 'afternoon_15_18') {
        return current.isBefore(DateTime(current.year, current.month, current.day, 15, 0));
      }
      return true;
    }
    final startH = int.tryParse(match.group(1) ?? '0') ?? 0;
    final startM = int.tryParse(match.group(2) ?? '0') ?? 0;
    final slotStart = DateTime(current.year, current.month, current.day, startH, startM);
    return current.isBefore(slotStart);
  }
}

class Category {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;
  final int maxPurchaseLimit;

  const Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    this.maxPurchaseLimit = 20,
  });

  factory Category.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Category(
      id: id,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? false,
      maxPurchaseLimit: (map['maxPurchaseLimit'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'maxPurchaseLimit': maxPurchaseLimit,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    int? maxPurchaseLimit,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      maxPurchaseLimit: maxPurchaseLimit ?? this.maxPurchaseLimit,
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
  final String? videoUrl;
  final bool isActive;
  final String? deactivationReason;
  final bool deactivatedByAdmin;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> searchKeywords;

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
    this.videoUrl,
    required this.isActive,
    this.deactivationReason,
    this.deactivatedByAdmin = false,
    this.rating = 0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.searchKeywords = const [],
  });

  bool get isEdited => updatedAt.difference(createdAt).inSeconds.abs() > 2;

  String get dateStatusText {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    if (isEdited) {
      return 'Last edited: ${format.format(updatedAt)}';
    } else {
      return 'Created: ${format.format(createdAt)}';
    }
  }

  String get formattedCreatedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get formattedUpdatedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(updatedAt);

  factory Product.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final name = map['name'] as String? ?? '';
    return Product(
      id: id,
      farmerId: map['farmerId'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      name: name,
      categoryId: map['categoryId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? '',
      stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
      imageUrl: map['imageUrl'] as String? ?? '',
      imageUrls: (map['imageUrls'] is List)
          ? (map['imageUrls'] as List).whereType<String>().toList()
          : const [],
      videoUrl: map['videoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? false,
      deactivationReason: map['deactivationReason'] as String?,
      deactivatedByAdmin: map['deactivatedByAdmin'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
      searchKeywords: (map['searchKeywords'] is List)
          ? (map['searchKeywords'] as List).whereType<String>().toList()
          : generateSearchKeywords(name),
    );
  }

  /// Keep the cover first, remove duplicates, and show at most six photos.
  List<String> get galleryImages => <String>{
        for (final url in [imageUrl, ...imageUrls])
          if (url.trim().isNotEmpty) url.trim(),
      }.take(6).toList(growable: false);

  /* Optional gallery/review fields are read-only here so existing Farmer edits
   * cannot reset them when saving the original product form.
   */
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
      'imageUrls': imageUrls,
      if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
      'isActive': isActive,
      'deactivationReason': deactivationReason,
      'deactivatedByAdmin': deactivatedByAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'searchKeywords': searchKeywords.isNotEmpty
          ? searchKeywords
          : generateSearchKeywords(name),
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
    String? videoUrl,
    bool? isActive,
    String? deactivationReason,
    bool? deactivatedByAdmin,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? searchKeywords,
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
      videoUrl: videoUrl ?? this.videoUrl,
      isActive: isActive ?? this.isActive,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      deactivatedByAdmin: deactivatedByAdmin ?? this.deactivatedByAdmin,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      searchKeywords: searchKeywords ?? this.searchKeywords,
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

  factory CartItem.fromProduct(Product product, int qty) {
    return CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      unit: product.unit,
      imageUrl: product.imageUrl,
      farmerId: product.farmerId,
      farmerName: product.farmerName,
      qty: qty,
    );
  }

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
  final double? latitude;
  final double? longitude;
  final String? operatingHours;
  final String? marketName;
  final String? cancellationReason;

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
    this.latitude,
    this.longitude,
    this.operatingHours,
    this.marketName,
    this.cancellationReason,
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
      latitude: (map['latitude'] as num?)?.toDouble() ??
          (map['market_snapshot']?['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble() ??
          (map['market_snapshot']?['longitude'] as num?)?.toDouble(),
      operatingHours: map['operatingHours'] as String? ??
          (map['market_snapshot']?['operating_hours'] as String?),
      marketName: map['marketName'] as String? ??
          (map['market_snapshot']?['market_name'] as String?),
      cancellationReason: map['cancellationReason'] as String? ??
          map['cancellation_reason'] as String?,
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (operatingHours != null) 'operatingHours': operatingHours,
      if (marketName != null) 'marketName': marketName,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'market_snapshot': {
        'market_name': marketName ?? farmerName,
        'address': address,
        'latitude': latitude ?? 11.9404,
        'longitude': longitude ?? 108.4583,
        'operating_hours': operatingHours ?? '07:00 - 18:00',
      },
    };
  }

  PickupWindow get pickupWindow {
    final date = pickupDate;
    final slotStr = pickupSlot.trim();

    int startHour = 7;
    int startMinute = 0;
    int endHour = 10;
    int endMinute = 0;

    if (slotStr == 'morning_07_10') {
      startHour = 7;
      startMinute = 0;
      endHour = 10;
      endMinute = 0;
    } else if (slotStr == 'afternoon_15_18') {
      startHour = 15;
      startMinute = 0;
      endHour = 18;
      endMinute = 0;
    } else {
      final rangeRegex =
          RegExp(r'(\d{1,2})(?:[:hH](\d{2}))?\s*[-–—]\s*(\d{1,2})(?:[:hH](\d{2}))?');
      final match = rangeRegex.firstMatch(slotStr) ??
          (operatingHours != null
              ? rangeRegex.firstMatch(operatingHours!)
              : null);
      if (match != null) {
        startHour = int.tryParse(match.group(1) ?? '7') ?? 7;
        startMinute = int.tryParse(match.group(2) ?? '0') ?? 0;
        endHour = int.tryParse(match.group(3) ?? '10') ?? 10;
        endMinute = int.tryParse(match.group(4) ?? '0') ?? 0;
      }
    }

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
    var end = DateTime(
      date.year,
      date.month,
      date.day,
      endHour,
      endMinute,
    );
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    } else if (end.isAtSameMomentAs(start)) {
      end = start.add(const Duration(hours: 3));
    }
    return PickupWindow(start: start, end: end);
  }

  bool get isPendingOverdue {
    if (status != OrderStatus.pending && status != 'Pending') return false;
    return DateTime.now().isAfter(pickupWindow.end);
  }

  bool get isPendingHalfTimeWarning {
    if (status != OrderStatus.pending && status != 'Pending') return false;
    return DateTime.now().isAfter(pickupWindow.halfTimeWarning);
  }

  bool get isPendingTwoThirdsWarning {
    if (status != OrderStatus.pending && status != 'Pending') return false;
    return DateTime.now().isAfter(pickupWindow.twoThirdsTimeWarning);
  }

  bool get isPending6hWarning => isPendingHalfTimeWarning;

  bool get isPending10hWarning => isPendingTwoThirdsWarning;

  Duration get remainingPendingDuration {
    if (status != OrderStatus.pending && status != 'Pending') return Duration.zero;
    final diff = pickupWindow.end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isOverdueNoShow {
    if (status != OrderStatus.readyForPickup &&
        status != 'ready_for_pickup' &&
        status != 'Ready for Pickup') {
      return false;
    }
    return DateTime.now().isAfter(pickupWindow.end);
  }

  bool get isConfirmedPrepTime {
    if (status != OrderStatus.confirmed && status != 'Confirmed') return false;
    final now = DateTime.now();
    return now.isAfter(pickupWindow.prepReminderTime) && now.isBefore(pickupWindow.start);
  }

  bool get isConfirmedLatePrep {
    if (status != OrderStatus.confirmed && status != 'Confirmed') return false;
    final now = DateTime.now();
    return now.isAfter(pickupWindow.start) && now.isBefore(pickupWindow.halfTimeWarning);
  }

  bool get isConfirmedCriticalDelay {
    if (status != OrderStatus.confirmed && status != 'Confirmed') return false;
    final now = DateTime.now();
    return now.isAfter(pickupWindow.halfTimeWarning) && now.isBefore(pickupWindow.end);
  }

  bool get isConfirmedUnfulfilled {
    if (status != OrderStatus.confirmed && status != 'Confirmed') return false;
    return DateTime.now().isAfter(pickupWindow.end);
  }

  bool get isConfirmedWarning =>
      isConfirmedPrepTime || isConfirmedLatePrep || isConfirmedCriticalDelay || isConfirmedUnfulfilled;

  bool get isOverduePending {
    if (status != OrderStatus.pending && status != 'Pending') {
      return false;
    }
    return DateTime.now().isAfter(pickupWindow.halfTimeWarning);
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
    double? latitude,
    double? longitude,
    String? operatingHours,
    String? marketName,
    String? cancellationReason,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      operatingHours: operatingHours ?? this.operatingHours,
      marketName: marketName ?? this.marketName,
      cancellationReason: cancellationReason ?? this.cancellationReason,
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
  final bool showInAppPopup;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.targetId,
    required this.isRead,
    required this.createdAt,
    this.showInAppPopup = true,
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
      showInAppPopup: map['showInAppPopup'] as bool? ?? true,
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
      'showInAppPopup': showInAppPopup,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? targetId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DelayedOrderLog {
  final String id;
  final String orderId;
  final String farmerId;
  final String farmerName;
  final String customerId;
  final String customerName;
  final int total;
  final int itemCount;
  final DateTime createdAt;
  final DateTime cancelledAt;
  final String reason;

  const DelayedOrderLog({
    required this.id,
    required this.orderId,
    required this.farmerId,
    required this.farmerName,
    required this.customerId,
    required this.customerName,
    required this.total,
    required this.itemCount,
    required this.createdAt,
    required this.cancelledAt,
    this.reason = 'Unconfirmed after 12 hours',
  });

  factory DelayedOrderLog.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return DelayedOrderLog(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      farmerId: map['farmerId'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      total: (map['total'] as num?)?.toInt() ?? 0,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      createdAt: readDate(map['createdAt']),
      cancelledAt: readDate(map['cancelledAt']),
      reason: map['reason'] as String? ?? 'Unconfirmed after 12 hours',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'customerId': customerId,
      'customerName': customerName,
      'total': total,
      'itemCount': itemCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'cancelledAt': Timestamp.fromDate(cancelledAt),
      'reason': reason,
    };
  }
}

class PickupWindow {
  final DateTime start;
  final DateTime end;

  const PickupWindow({required this.start, required this.end});

  Duration get duration => end.difference(start);

  DateTime get prepReminderTime => start.subtract(const Duration(minutes: 30));

  DateTime get halfTimeWarning =>
      start.add(Duration(milliseconds: (duration.inMilliseconds * 0.5).round()));

  DateTime get twoThirdsTimeWarning =>
      start.add(Duration(milliseconds: (duration.inMilliseconds * (2.0 / 3.0)).round()));
}
