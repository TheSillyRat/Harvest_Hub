import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'models.dart';

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
    final doc = await db.collection('users').doc(uid).get();
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
      if (!user.isActive) {
        throw StateError('Account has been deactivated');
      }
      return user;
    } catch (_) {
      await logout();
      rethrow;
    }
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
  }) {
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
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = AppUser(
      uid: credential.user!.uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      address: address.trim(),
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );
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
            rating: 5.0,
            isActive: true,
            createdAt: user.createdAt,
          ).toMap(),
        );
      }
      await batch.commit();
      return user;
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> logout() => auth.signOut();

  void requireRole(AppUser user, String expectedRole) {
    if (user.role != expectedRole) {
      throw StateError('Account is not authorized for this application');
    }
    if (!user.isActive) {
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
}
