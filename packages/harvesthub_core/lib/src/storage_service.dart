import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  Future<String> uploadProductImage(String farmerId, File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('products/$farmerId/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      try {
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last.toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        return 'data:$mimeType;base64,${base64Encode(bytes)}';
      } catch (_) {
        return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800';
      }
    }
  }

  Future<String> uploadAvatar(String uid, File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('avatars/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      try {
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last.toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        return 'data:$mimeType;base64,${base64Encode(bytes)}';
      } catch (_) {
        return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=800';
      }
    }
  }
  Future<List<String>> uploadProductImages(String farmerId, List<File> files) async {
    final imagesToUpload = files.take(6).toList();
    final uploadTasks = imagesToUpload.map((file) => uploadProductImage(farmerId, file));
    return await Future.wait(uploadTasks);
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
