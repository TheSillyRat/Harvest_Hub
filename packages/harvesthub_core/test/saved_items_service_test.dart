import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  for (final kind in SavedKind.values) {
    test(
        '${kind.name} writes account-scoped server timestamps, deduplicates and removes',
        () async {
      final db = FakeFirebaseFirestore();
      final service = SavedItemsService(db: db);
      final collection =
          kind == SavedKind.product ? 'wishlists' : 'farmerFollows';
      final field = kind == SavedKind.product ? 'productId' : 'farmerId';
      await service.setSaved('a', kind, 'one', true);
      await service.setSaved('a', kind, 'one', true);
      expect(await service.watch('a', kind).first, ['one']);
      expect(await service.watch('b', kind).first, isEmpty);
      final data = (await db.doc('$collection/a/items/one').get()).data()!;
      expect(data.keys, unorderedEquals([field, 'savedAt']));
      expect(data[field], 'one');
      expect(data['savedAt'], isA<Timestamp>());
      await service.setSaved('a', kind, 'one', false);
      expect(await service.watch('a', kind).first, isEmpty);
    });

    test('${kind.name} streams newest first and reflects another device write',
        () async {
      final db = FakeFirebaseFirestore();
      final service = SavedItemsService(db: db);
      final collection =
          kind == SavedKind.product ? 'wishlists' : 'farmerFollows';
      final field = kind == SavedKind.product ? 'productId' : 'farmerId';
      final items = db.collection('$collection/a/items');
      await items.doc('old').set(
          {field: 'old', 'savedAt': Timestamp.fromMillisecondsSinceEpoch(1)});
      final snapshots = <List<String>>[];
      final subscription = service.watch('a', kind).listen(snapshots.add);
      await Future<void>.delayed(Duration.zero);
      await items.doc('new').set(
          {field: 'new', 'savedAt': Timestamp.fromMillisecondsSinceEpoch(2)});
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.first, ['old']);
      expect(snapshots.last, ['new', 'old']);
      await subscription.cancel();
    });
  }
}
