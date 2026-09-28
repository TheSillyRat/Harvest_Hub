import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'models.dart';
import 'notification_service.dart';

FirebaseAuth? _safeAuth() {
  try {
    return FirebaseAuth.instance;
  } catch (_) {
    return null;
  }
}

FirebaseFirestore? _safeFirestore() {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

class AuthService {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth,
        _db = db;

  FirebaseAuth get auth => _auth ?? _safeAuth() ?? FirebaseAuth.instance;
  FirebaseFirestore get db => _db ?? _safeFirestore() ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() {
    try {
      final a = _auth ?? _safeAuth();
      if (a == null) return const Stream.empty();
      return a.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<AppUser> readUser(String uid) async {
    final doc = await db
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 15));
    if (!doc.exists) {
      final currentUser = auth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        final profile = AppUser(
          uid: uid,
          name: currentUser.displayName?.isNotEmpty == true
              ? currentUser.displayName!
              : 'Customer',
          email: currentUser.email ?? '',
          phone: '',
          address: '',
          role: Roles.customer,
          isActive: true,
          createdAt: DateTime.now(),
        );
        try {
          await db.collection('users').doc(uid).set(profile.toMap());
        } catch (_) {}
        return profile;
      }
      throw StateError('User profile does not exist');
    }
    return AppUser.fromMap(doc.data()!, id: uid);
  }

  Future<AppUser> login(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      final user = await readUser(credential.user!.uid);
      if (user.status == 'banned' || user.violationStrikes >= 3) {
        throw StateError('Your account has been suspended due to repeated category violations.');
      }
      if (!user.isActive && user.status != 'pending_approval') {
        final reason = user.deactivationReason?.trim();
        final msg = (reason != null && reason.isNotEmpty)
            ? 'Account deactivated. Reason: $reason'
            : 'Account deactivated. Please contact support.';
        throw StateError(msg);
      }
      return user;
    } catch (_) {
      await logout();
      rethrow;
    }
  }

  Future<void> clearActivationNotice(String uid) async {
    try {
      await db.collection('users').doc(uid).update({
        'activationNoticePending': false,
      });
    } catch (_) {}
  }

  Future<AppUser> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) {
    return _register(
      name: name,
      email: email,
      phone: phone,
      address: address,
      password: password,
      role: Roles.customer,
    );
  }

  Future<AppUser> registerFarmer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
    required String businessName,
    required String description,
    required String area,
    List<String> registeredCategoryIds = const [],
  }) {
    if (registeredCategoryIds.isEmpty) {
      throw ArgumentError('Please select at least one business category.');
    }
    return _register(
      name: name,
      email: email,
      phone: phone,
      address: address,
      password: password,
      role: Roles.farmer,
      businessName: businessName,
      description: description,
      area: area,
      registeredCategoryIds: registeredCategoryIds,
    );
  }

  Future<AppUser> _register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
    required String role,
    String businessName = '',
    String description = '',
    String area = '',
    List<String> registeredCategoryIds = const [],
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await auth
        .createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        )
        .timeout(const Duration(seconds: 10));
    final isFarmer = role == Roles.farmer;
    final user = AppUser(
      uid: credential.user!.uid,
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      address: address.trim(),
      role: role,
      isActive: !isFarmer,
      status: isFarmer ? 'pending_approval' : 'active',
      registeredCategoryIds: registeredCategoryIds,
      violationStrikes: 0,
      createdAt: DateTime.now(),
    );
    try {
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), user.toMap());
      if (isFarmer) {
        batch.set(
          db.collection('farmers').doc(user.uid),
          FarmerProfile(
            uid: user.uid,
            userId: user.uid,
            businessName: businessName.trim(),
            description: description.trim(),
            area: area.trim(),
            rating: 5.0,
            isActive: false,
            approvalStatus: 'pending_approval',
            registeredCategoryIds: registeredCategoryIds,
            violationStrikes: 0,
            createdAt: user.createdAt,
          ).toMap(),
        );

        // Many-to-many relationship: farmer_categories collection
        for (final catId in registeredCategoryIds) {
          final docRef =
              db.collection('farmer_categories').doc('${user.uid}_$catId');
          batch.set(docRef, {
            'farmerId': user.uid,
            'categoryId': catId,
            'createdAt': Timestamp.fromDate(user.createdAt),
          });
        }
      }
      await batch.commit().timeout(const Duration(seconds: 8));
      try {
        final roleLabel = isFarmer ? 'Farmer' : 'Customer';
        final displayName = isFarmer && businessName.trim().isNotEmpty
            ? businessName.trim()
            : user.name;
        await NotificationService()
            .sendNotification(
              userId: 'all_admins',
              title: isFarmer
                  ? 'New Farmer Pending Approval'
                  : 'New Customer Registered',
              body:
                  '$displayName has registered as a $roleLabel and is awaiting category approval.',
              type: 'new_user',
              targetId: user.uid,
              showInAppPopup: true,
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      return user;
    } catch (_) {
      try {
        await credential.user?.delete().timeout(const Duration(seconds: 4));
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> logout() => auth.signOut();

  void requireRole(AppUser user, String expectedRole) {
    if (user.role != expectedRole) {
      throw StateError('Account is not authorized for this application');
    }
    if (user.status == 'banned' || user.violationStrikes >= 3) {
      throw StateError('Your account has been suspended due to repeated category violations.');
    }
    if (!user.isActive && user.status != 'pending_approval') {
      throw StateError('Account has been deactivated');
    }
  }

  Future<void> updateProfile(
    String uid, {
    required String name,
    required String phone,
    required String address,
  }) {
    return db.collection('users').doc(uid).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    });
  }

  Future<void> updateFarmerProfile(
    String uid, {
    required String businessName,
    required String address,
    String? avatarUrl,
    String? name,
    String? phone,
    String? description,
    String? area,
  }) async {
    final batch = db.batch();
    final userUpdates = <String, dynamic>{
      'address': address.trim(),
    };
    if (name != null && name.trim().isNotEmpty) {
      userUpdates['name'] = name.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      userUpdates['phone'] = phone.trim();
    }
    if (avatarUrl != null) {
      userUpdates['avatarUrl'] = avatarUrl.trim();
    }
    batch.update(db.collection('users').doc(uid), userUpdates);

    final farmerUpdates = <String, dynamic>{
      'businessName': businessName.trim(),
    };
    if (avatarUrl != null) {
      farmerUpdates['avatarUrl'] = avatarUrl.trim();
    }
    if (description != null) {
      farmerUpdates['description'] = description.trim();
    }
    if (area != null) {
      farmerUpdates['area'] = area.trim();
    }
    batch.set(
      db.collection('farmers').doc(uid),
      farmerUpdates,
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
