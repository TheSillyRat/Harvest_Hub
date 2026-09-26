import 'dart:async';

import 'package:customer_app/screens/saved_screen.dart';
import 'package:customer_app/screens/product_detail_sections.dart';
import 'package:customer_app/screens/product_detail_sheet.dart';
import 'package:customer_app/widgets/save_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

class MemorySaved extends SavedItemsService {
  final events = <String, StreamController<List<String>>>{};
  final values = <String, List<String>>{};
  int writes = 0;
  Completer<void>? writeGate;
  bool failWrites = false;
  bool optimisticRemoval = false;
  String key(String uid, SavedKind kind) => '$uid/${kind.name}';
  @override
  Stream<List<String>> watch(String uid, SavedKind kind) async* {
    final k = key(uid, kind);
    final stream = events.putIfAbsent(k, () => StreamController.broadcast());
    yield List.of(values[k] ?? []);
    yield* stream.stream;
  }

  void emit(String uid, SavedKind kind, List<String> ids) {
    final k = key(uid, kind);
    values[k] = ids;
    events[k]?.add(List.of(ids));
  }

  @override
  Future<void> setSaved(
      String uid, SavedKind kind, String id, bool saved) async {
    writes++;
    final previous = List<String>.of(values[key(uid, kind)] ?? []);
    if (optimisticRemoval && !saved) {
      emit(uid, kind, List<String>.of(previous)..remove(id));
    }
    if (writeGate != null) await writeGate!.future;
    if (failWrites) {
      if (optimisticRemoval && !saved) emit(uid, kind, previous);
      throw StateError('permission-denied');
    }
    final ids = List<String>.of(values[key(uid, kind)] ?? [])..remove(id);
    if (saved) ids.insert(0, id);
    emit(uid, kind, ids);
  }

  Future<void> close() async {
    for (final stream in events.values) {
      await stream.close();
    }
  }
}

class SavedProducts extends ProductService {
  final product = ProductService.getFallbackProducts()
      .first
      .copyWith(imageUrl: '', stockQty: 0);
  @override
  Stream<Product?> watch(String id) =>
      Stream.value(id == 'missing' ? null : product.copyWith(id: id));
}

class SavedFarms extends ProductDetailsData {
  @override
  Stream<List<Map<String, dynamic>>> reviews(String id, int limit) =>
      Stream.value([]);
  @override
  Stream<Map<String, dynamic>?> store(String id) => Stream.value({
        'businessName': 'Green Farm',
        'area': 'Da Lat',
        'isActive': false,
      });
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MemorySaved service;
  late SavedItemsController saved;
  setUp(() {
    service = MemorySaved();
    saved = SavedItemsController(service: service);
  });
  tearDown(() async {
    saved.dispose();
    await service.close();
  });

  test('both collections persist toggles and reflect external changes',
      () async {
    saved.bind('a');
    await flush();
    for (final kind in SavedKind.values) {
      await saved.setSaved(kind, 'one', true);
      await flush();
      expect(saved.ids(kind), ['one']);
      service.emit('a', kind, ['two', 'one']);
      await flush();
      expect(saved.ids(kind), ['two', 'one']);
      await saved.setSaved(kind, 'one', false);
      await flush();
      expect(saved.ids(kind), ['two']);
    }
    saved.bind(null);
    expect(saved.ids(SavedKind.product), isEmpty);
    saved.bind('a');
    await flush();
    expect(saved.ids(SavedKind.product), ['two']);
    expect(saved.ids(SavedKind.farmer), ['two']);
  });

  test('duplicate taps write once and failures clear pending state', () async {
    saved.bind('a');
    await flush();
    service.writeGate = Completer<void>();
    service.failWrites = true;
    final first = saved.setSaved(SavedKind.product, 'one', true);
    final failure = expectLater(first, throwsStateError);
    await saved.setSaved(SavedKind.product, 'one', true);
    expect(service.writes, 1);
    expect(saved.pending(SavedKind.product, 'one'), isTrue);
    service.writeGate!.complete();
    await failure;
    expect(saved.pending(SavedKind.product, 'one'), isFalse);
    expect(saved.ids(SavedKind.product), isEmpty);
  });

  test('account switch isolates old stream events and in-flight writes',
      () async {
    saved.bind('a');
    await flush();
    service.writeGate = Completer<void>();
    final oldWrite = saved.setSaved(SavedKind.farmer, 'farm', true);
    saved.bind('b');
    expect(saved.ids(SavedKind.farmer), isEmpty);
    expect(saved.pending(SavedKind.farmer, 'farm'), isFalse);
    await flush();
    service.writeGate!.complete();
    await oldWrite;
    await flush();
    expect(saved.ids(SavedKind.farmer), isEmpty);
    expect(service.values['a/farmer'], ['farm']);
    saved.bind(null);
    await expectLater(
        saved.setSaved(SavedKind.product, 'one', true), throwsStateError);
  });

  test('stream failure can be retried without clearing the other collection',
      () async {
    saved.bind('a');
    await flush();
    service.emit('a', SavedKind.farmer, ['farm']);
    service.events['a/product']!.addError(StateError('offline'));
    await flush();
    expect(saved.failed(SavedKind.product), isTrue);
    await expectLater(
        saved.setSaved(SavedKind.product, 'one', true), throwsStateError);
    saved.retry(SavedKind.product);
    await flush();
    expect(saved.failed(SavedKind.product), isFalse);
    expect(saved.loaded(SavedKind.product), isTrue);
    expect(saved.ids(SavedKind.farmer), ['farm']);
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: saved,
        child: MaterialApp(theme: harvestHubTheme(), home: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('heart and follow buttons synchronize and expose action labels',
      (tester) async {
    saved.bind('a');
    await mount(
        tester,
        const Scaffold(
            body: Column(children: [
          SaveButton(kind: SavedKind.product, itemId: 'one'),
          SaveButton(kind: SavedKind.product, itemId: 'one'),
          SaveButton(kind: SavedKind.farmer, itemId: 'farm'),
        ])));
    await tester.tap(find.byTooltip('Save to wishlist').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from wishlist'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Follow farm'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    await tester.tap(find.byTooltip('Unfollow farm'));
    await tester.pumpAndSettle();
    expect(saved.ids(SavedKind.farmer), isEmpty);
  });

  testWidgets('failed save shows feedback and leaves heart available to retry',
      (tester) async {
    saved.bind('a');
    service.failWrites = true;
    await mount(
        tester,
        const Scaffold(
            body: SaveButton(kind: SavedKind.product, itemId: 'one')));
    await tester.tap(find.byTooltip('Save to wishlist'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save this change. Please try again.'),
        findsOneWidget);
    expect(find.byTooltip('Save to wishlist'), findsOneWidget);
    expect(saved.ids(SavedKind.product), isEmpty);
  });

  testWidgets(
      'saved list supports sold-out products and removal of unavailable entries',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service.values['a/product'] = ['one', 'missing'];
    service.values['a/farmer'] = ['farm'];
    saved.bind('a');
    await mount(
        tester, SavedScreen(products: SavedProducts(), details: SavedFarms()));
    expect(find.text('Wishlist (2)'), findsOneWidget);
    expect(find.text('Out of stock · Saved for later'), findsOneWidget);
    expect(find.text('Unavailable product'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from wishlist').last);
    await tester.pumpAndSettle();
    expect(find.text('Wishlist (1)'), findsOneWidget);
    await tester.tap(find.text('Following (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Green Farm'), findsOneWidget);
    expect(find.text('No longer available'), findsOneWidget);
    await tester.tap(find.byTooltip('Unfollow farm'));
    await tester.pumpAndSettle();
    expect(find.text('Discover farms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved page distinguishes loading failure from empty and retries',
      (tester) async {
    saved.bind('a');
    await mount(tester, const SavedScreen());
    expect(find.text('A little room for favorites'), findsOneWidget);
    service.events['a/product']!.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load your saved items'), findsOneWidget);
    expect(find.text('A little room for favorites'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Explore products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist opens product details with the same saved state',
      (tester) async {
    service.values['a/product'] = ['one'];
    saved.bind('a');
    await mount(
        tester, SavedScreen(products: SavedProducts(), details: SavedFarms()));
    await tester.tap(find.text('Heirloom Vine Tomatoes'));
    await tester.pumpAndSettle();
    expect(find.text('Product details'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ProductDetailSheet),
            matching: find.byTooltip('Remove from wishlist')),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close product details'));
    await tester.pumpAndSettle();
    expect(find.text('Wishlist (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rejected removal restores the row and reports error after its button unmounts',
      (tester) async {
    service.values['a/product'] = ['one'];
    service.optimisticRemoval = true;
    service.failWrites = true;
    service.writeGate = Completer<void>();
    saved.bind('a');
    await mount(
        tester, SavedScreen(products: SavedProducts(), details: SavedFarms()));
    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(find.text('Wishlist (0)'), findsOneWidget);
    service.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Wishlist (1)'), findsOneWidget);
    expect(find.text('Could not save this change. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved page fits a small phone with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service.values['a/product'] = ['one'];
    saved.bind('a');
    await mount(
        tester,
        MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child:
                SavedScreen(products: SavedProducts(), details: SavedFarms())));
    expect(find.text('Wishlist (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
