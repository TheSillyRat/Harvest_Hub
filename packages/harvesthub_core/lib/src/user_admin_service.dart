import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

/// Result wrapper for paginated users query
class UserPageResult {
  final List<AppUser> users;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const UserPageResult({
    required this.users,
    this.lastDoc,
    required this.hasMore,
  });
}

/// Comprehensive details of a user
class UserDetailResult {
  final AppUser user;
  final FarmerProfile? farmerProfile;

  const UserDetailResult({
    required this.user,
    this.farmerProfile,
  });
}

class UserAdminService {
  final FirebaseFirestore _firestore;

  UserAdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Real-time stream of all users
  Stream<List<AppUser>> streamUsers({String? roleFilter, bool? activeFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('users');
    if (roleFilter != null && roleFilter.isNotEmpty && roleFilter != 'All') {
      query = query.where('role', isEqualTo: roleFilter.toLowerCase());
    }
    if (activeFilter != null) {
      query = query.where('isActive', isEqualTo: activeFilter);
    }
    return query.snapshots().map((s) =>
        s.docs.map((d) => AppUser.fromMap(d.data(), id: d.id)).toList());
  }

  /// Real-time stream of farmer profiles
  Stream<List<FarmerProfile>> streamFarmers() => _firestore
      .collection('farmers')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => FarmerProfile.fromMap(d.data(), id: d.id)).toList());

  /// Paginated fetch with role filtering, status filtering, and search query
  Future<UserPageResult> fetchUsersPage({
    int limit = 15,
    DocumentSnapshot? startAfter,
    String role = 'All',
    String status = 'All', // 'All', 'Active', 'Deactivated'
    String searchQuery = '',
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .orderBy('createdAt', descending: true);

    if (role == 'Customers') {
      query = query.where('role', isEqualTo: Roles.customer);
    } else if (role == 'Farmers') {
      query = query.where('role', isEqualTo: Roles.farmer);
    }

    if (status == 'Active') {
      query = query.where('isActive', isEqualTo: true);
    } else if (status == 'Deactivated') {
      query = query.where('isActive', isEqualTo: false);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    var users = snapshot.docs
        .map((d) => AppUser.fromMap(d.data(), id: d.id))
        .toList();

    // Client-side text filter if search query is provided
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      users = users.where((u) {
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.toLowerCase().contains(q);
      }).toList();
    }

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    final hasMore = snapshot.docs.length == limit;

    return UserPageResult(
      users: users,
      lastDoc: lastDoc,
      hasMore: hasMore,
    );
  }

  /// Get comprehensive user details including optional farmer profile
  Future<UserDetailResult> getUserDetails(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists || userDoc.data() == null) {
      throw StateError('User not found: $uid');
    }

    final user = AppUser.fromMap(userDoc.data()!, id: userDoc.id);
    FarmerProfile? farmer;

    if (user.role == Roles.farmer) {
      final farmerDoc = await _firestore.collection('farmers').doc(uid).get();
      if (farmerDoc.exists && farmerDoc.data() != null) {
        farmer = FarmerProfile.fromMap(farmerDoc.data()!, id: farmerDoc.id);
      }
    }

    return UserDetailResult(user: user, farmerProfile: farmer);
  }

  /// Deactivate user account with required reason
  Future<void> deactivateUser({
    required String uid,
    required String reason,
    String? role,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Deactivation reason cannot be empty');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);

    batch.update(userRef, {
      'isActive': false,
      'deactivation_reason': trimmedReason,
      'deactivationReason': trimmedReason,
      'activationNoticePending': false,
      'deactivatedAt': Timestamp.fromDate(now),
    });

    if (role == Roles.farmer) {
      final farmerRef = _firestore.collection('farmers').doc(uid);
      batch.update(farmerRef, {
        'isActive': false,
        'deactivation_reason': trimmedReason,
        'deactivationReason': trimmedReason,
        'deactivatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  /// Reactivate user account and queue pending reactivation notice
  Future<void> activateUser({
    required String uid,
    String? role,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);

    batch.update(userRef, {
      'isActive': true,
      'deactivation_reason': null,
      'deactivationReason': null,
      'activationNoticePending': true,
      'reactivatedAt': Timestamp.fromDate(now),
    });

    if (role == Roles.farmer) {
      final farmerRef = _firestore.collection('farmers').doc(uid);
      batch.update(farmerRef, {
        'isActive': true,
        'deactivation_reason': null,
        'deactivationReason': null,
        'reactivatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  /// Backward-compatible toggle method
  Future<void> setIsActive(AppUser user, bool active, {String? reason}) async {
    if (active) {
      await activateUser(uid: user.uid, role: user.role);
    } else {
      await deactivateUser(
        uid: user.uid,
        reason: reason ?? 'Deactivated by administrator',
        role: user.role,
      );
    }
  }
}
