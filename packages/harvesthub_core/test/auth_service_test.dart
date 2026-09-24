import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  test('farmer registration creates matching Auth/user/farmer identities', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    final service = AuthService(auth: auth, db: db);
    final user = await service.registerFarmer(name: 'Nông dân', email: 'farmer@harvesthub.app',
      phone: '0900000000', address: 'Đà Lạt', password: 'Farmer@123', businessName: 'Vườn Xanh',
      description: 'Nông sản địa phương', area: 'Đà Lạt');
    expect(auth.currentUser!.uid, user.uid);
    expect((await db.doc('users/${user.uid}').get()).data()!['role'], Roles.farmer);
    expect((await db.doc('farmers/${user.uid}').get()).data()!['businessName'], 'Vườn Xanh');
    expect(() => service.requireRole(user, Roles.customer), throwsStateError);
    expect(() => service.requireRole(user.copyWith(isActive: false), Roles.farmer), throwsStateError);
    await service.updateProfile(user.uid, name: 'Tên mới', phone: '0911111111', address: 'Lâm Đồng');
    expect((await service.readUser(user.uid)).name, 'Tên mới');
    await service.logout();
    expect(auth.currentUser, isNull);
  });
  test('customer registration never creates a farmer profile', () async {
    final db = FakeFirebaseFirestore();
    final service = AuthService(auth: MockFirebaseAuth(), db: db);
    final user = await service.registerCustomer(name: 'Khách', email: 'customer@harvesthub.app',
      phone: '0900000000', address: 'Đà Lạt', password: 'Customer@123');
    expect(user.role, Roles.customer);
    expect((await db.collection('farmers').get()).docs, isEmpty);
  });
}
