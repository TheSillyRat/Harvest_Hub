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
