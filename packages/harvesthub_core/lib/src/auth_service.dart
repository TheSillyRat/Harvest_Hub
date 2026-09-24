import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'models.dart';

class AuthService {
  final FirebaseAuth auth;
  final FirebaseFirestore db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : auth = auth ?? FirebaseAuth.instance,
        db = db ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => auth.authStateChanges();

  Future<AppUser> readUser(String uid) async {
    final doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
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
