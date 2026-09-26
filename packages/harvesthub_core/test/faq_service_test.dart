import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  group('FaqService Firestore API Key Resolution', () {
    test('resolves API key from Firestore app_config/gemini doc', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('app_config').doc('gemini').set({
        'apiKey': 'AI_MOCK_FIRESTORE_KEY_XYZ999',
      });

      FaqService.setCachedApiKey('');
      final key = await FaqService.resolveApiKey(firestore: fakeFirestore);
      expect(key, equals('AI_MOCK_FIRESTORE_KEY_XYZ999'));
    });

    test('uses cached API key after initial resolution', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('app_config').doc('gemini').set({
        'apiKey': 'FIRST_KEY_RESOLVED',
      });

      FaqService.setCachedApiKey('');
      final key1 = await FaqService.resolveApiKey(firestore: fakeFirestore);
      expect(key1, equals('FIRST_KEY_RESOLVED'));

      /* Update firestore but verify cached value is retained */
      await fakeFirestore.collection('app_config').doc('gemini').set({
        'apiKey': 'SECOND_KEY_CHANGED',
      });

      final key2 = await FaqService.resolveApiKey(firestore: fakeFirestore);
      expect(key2, equals('FIRST_KEY_RESOLVED'));
    });

    test('returns empty string gracefully if doc missing', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      FaqService.setCachedApiKey('');
      final key = await FaqService.resolveApiKey(firestore: fakeFirestore);
      expect(key, isEmpty);
    });
  });
}
