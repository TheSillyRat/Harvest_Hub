import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum SavedKind { product, farmer }

class SavedItemsService {
  final FirebaseFirestore? _db;
  SavedItemsService({FirebaseFirestore? db}) : _db = db;

  CollectionReference<Map<String, dynamic>> _items(
          String uid, SavedKind kind) =>
      (_db ?? FirebaseFirestore.instance)
          .collection(kind == SavedKind.product ? 'wishlists' : 'farmerFollows')
          .doc(uid)
          .collection('items');

  Stream<List<String>> watch(String uid, SavedKind kind) async* {
    yield* _items(uid, kind)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Future<void> setSaved(
      String uid, SavedKind kind, String id, bool saved) async {
    final ref = _items(uid, kind).doc(id);
    if (!saved) {
      await ref.delete();
      return;
    }
    await ref.set({
      kind == SavedKind.product ? 'productId' : 'farmerId': id,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _SavedState {
  List<String> ids = [];
  bool loaded = false;
  bool failed = false;
  final Set<String> pending = {};
  StreamSubscription<List<String>>? subscription;
}

/// One account-scoped source of truth shared by cards, details and saved lists.
class SavedItemsController extends ChangeNotifier {
  final SavedItemsService _service;
  SavedItemsController({SavedItemsService? service})
      : _service = service ?? SavedItemsService();

  final _states = {for (final kind in SavedKind.values) kind: _SavedState()};
  String? _uid;
  int _generation = 0;
  bool _disposed = false;
  String? get userId => _uid;
  bool get signedIn => _uid != null;
  List<String> ids(SavedKind kind) => List.unmodifiable(_states[kind]!.ids);
  bool loaded(SavedKind kind) => _states[kind]!.loaded;
  bool failed(SavedKind kind) => _states[kind]!.failed;
  bool contains(SavedKind kind, String id) => _states[kind]!.ids.contains(id);
  bool pending(SavedKind kind, String id) =>
      _states[kind]!.pending.contains(id);

  void bind(String? uid) {
    if (_uid == uid || _disposed) return;
    _uid = uid;
    _generation++;
    for (final kind in SavedKind.values) {
      _states[kind]!.subscription?.cancel();
      _states[kind] = _SavedState();
      if (uid != null) _listen(kind);
    }
    notifyListeners();
  }

  void _listen(SavedKind kind) {
    final uid = _uid;
    if (uid == null) return;
    final state = _states[kind]!;
    final generation = _generation;
    state.subscription = _service.watch(uid, kind).listen((ids) {
      if (_disposed || generation != _generation || _states[kind] != state) {
        return;
      }
      state.ids = ids;
      state.loaded = true;
      state.failed = false;
      notifyListeners();
    }, onError: (Object error) {
      if (_disposed || generation != _generation || _states[kind] != state) {
        return;
      }
      state.failed = true;
      notifyListeners();
    });
  }

  void retry(SavedKind kind) {
    final previous = _states[kind]!;
    if (previous.pending.isNotEmpty) return;
    previous.subscription?.cancel();
    _states[kind] = _SavedState();
    _listen(kind);
    notifyListeners();
  }

  Future<void> setSaved(SavedKind kind, String id, bool saved) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to save your favorites.');
    final state = _states[kind]!;
    if (!state.loaded || state.failed) {
      throw StateError('Your saved items could not be loaded. Please retry.');
    }
    if (!state.pending.add(id)) return;
    final generation = _generation;
    notifyListeners();
    try {
      // Firestore snapshots provide live local updates and rollback on rejection.
      await _service.setSaved(uid, kind, id, saved);
    } finally {
      if (!_disposed && generation == _generation && _states[kind] == state) {
        state.pending.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final state in _states.values) {
      state.subscription?.cancel();
    }
    super.dispose();
  }
}
