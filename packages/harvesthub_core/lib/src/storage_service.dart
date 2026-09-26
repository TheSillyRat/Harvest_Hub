import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage? _storage;

  StorageService({FirebaseStorage? storage}) : _storage = storage;

  FirebaseStorage get _instance => _storage ?? FirebaseStorage.instance;

  Future<String> uploadProductImage(String farmerId, File file) async {
    try {
      final ref = _instance
          .ref('products/$farmerId/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800';
    }
  }
}
