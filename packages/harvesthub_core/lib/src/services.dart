import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'constants.dart';
import 'models.dart';



class StorageService {
  Future<String> uploadProductImage(String farmerId, File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('products/$farmerId/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      // Fallback sample image if Storage is not enabled on Firebase Console yet
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800';
    }
  }
}

class UserAdminService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  Stream<List<AppUser>> streamUsers() => db.collection('users').snapshots().map(
      (s) => s.docs.map((d) => AppUser.fromMap(d.data(), id: d.id)).toList());
  Stream<List<FarmerProfile>> streamFarmers() =>
      db.collection('farmers').snapshots().map((s) => s.docs
          .map((d) => FarmerProfile.fromMap(d.data(), id: d.id))
          .toList());
  Future<void> setIsActive(AppUser user, bool active) async {
    final batch = db.batch();
    batch.update(db.collection('users').doc(user.uid), {'isActive': active});
    if (user.role == Roles.farmer) {
      batch
          .update(db.collection('farmers').doc(user.uid), {'isActive': active});
    }
    await batch.commit();
  }
}

class WishlistService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      db.collection('wishlists').doc(uid).collection('items');
  Stream<Set<String>> stream(String uid) =>
      _items(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  Future<void> toggle(String uid, String id, bool saved) => saved
      ? _items(uid).doc(id).delete()
      : _items(uid).doc(id).set({'productId': id, 'savedAt': Timestamp.now()});
}

class ContactService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  Future<void> send(ContactMessage message) =>
      db.collection('contacts').add(message.toMap());
  Stream<List<ContactMessage>> stream() => db
      .collection('contacts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ContactMessage.fromMap(d.data(), id: d.id))
          .toList());
}
