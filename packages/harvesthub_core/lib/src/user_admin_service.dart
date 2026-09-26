import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'models.dart';

class UserAdminService {
  final FirebaseFirestore _firestore;

  UserAdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<AppUser>> streamUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map((d) => AppUser.fromMap(d.data(), id: d.id)).toList());

  Stream<List<FarmerProfile>> streamFarmers() => _firestore
      .collection('farmers')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => FarmerProfile.fromMap(d.data(), id: d.id)).toList());

  Future<void> setIsActive(AppUser user, bool active) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(user.uid), {'isActive': active});
    if (user.role == Roles.farmer) {
      batch.update(
          _firestore.collection('farmers').doc(user.uid), {'isActive': active});
    }
    await batch.commit();
  }
}
