// L5-E8 (L5-D25, exception EX-Q4): the marks of the shopping list in the
// existing preferences box (`settings_box`), through
// `LocalStorage.saveSetting` / `getSetting` only, on a real Hive store.
import 'dart:convert';
import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/services/shopping_list_checks_store.dart';
import 'package:exom_app/features/diets/services/weekly_shopping_list_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _env = 'https://test.exom.invalid';

ShoppingListScope _scope({
  DateTime? start,
  ShoppingListPeriodKind kind = ShoppingListPeriodKind.week,
  String signature = 'sig',
}) => ShoppingListScope(
  periodStart: start ?? DateTime(2026, 11, 16),
  kind: kind,
  selectionSignature: signature,
);

void main() {
  late Directory directory;
  LocalAuthSession? current;
  late LocalStorage storage;
  late ShoppingListChecksStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-shopping-checks-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    await Hive.openBox('settings_box');
    current = const LocalAuthSession(uid: 'A', generation: 1);
    storage = LocalStorage(currentSession: () => current, environment: _env);
    store = ShoppingListChecksStore(storage);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('key: own prefix + base64 of [1, environment, owner]; one per owner', () {
    final owner = store.currentOwner()!;
    final scope = base64Url.encode(utf8.encode(jsonEncode([1, _env, 'A'])));
    expect(
      ShoppingListChecksStore.storageKey(owner),
      'shopping_list_checked:$scope',
    );
  });

  test('value shape and round trip in settings_box', () async {
    final owner = store.currentOwner()!;
    expect(await store.write(owner, _scope(), {'id:x|g', 'id:y|g'}), isTrue);
    final raw = Hive.box('settings_box').get(
      ShoppingListChecksStore.storageKey(owner),
    );
    expect(raw, {
      'format_version': 1,
      'owner_id': 'A',
      'environment': _env,
      'period_start': '2026-11-16',
      'period_kind': 'week',
      'selection_signature': 'sig',
      'checked': ['id:x|g', 'id:y|g'],
    });
    expect(store.read(owner, _scope()), {'id:x|g', 'id:y|g'});
    // Nothing in the cache box: «Borrar caché» does not touch the marks.
    expect(Hive.box('cache_box').isEmpty, isTrue);
  });

  test('another period, kind or selection reads as no marks; the next '
      'write replaces the single entry', () async {
    final owner = store.currentOwner()!;
    await store.write(owner, _scope(), {'id:x|g'});
    expect(store.read(owner, _scope(start: DateTime(2026, 11, 23))), isEmpty);
    expect(
      store.read(owner, _scope(kind: ShoppingListPeriodKind.month)),
      isEmpty,
    );
    expect(store.read(owner, _scope(signature: 'other')), isEmpty);
    await store.write(owner, _scope(signature: 'other'), {'id:z|g'});
    expect(store.read(owner, _scope()), isEmpty);
    expect(store.read(owner, _scope(signature: 'other')), {'id:z|g'});
    final keys = Hive.box('settings_box').keys.where(
      (k) => '$k'.startsWith('shopping_list_checked:'),
    );
    expect(keys, hasLength(1));
  });

  test('B cannot read A; A keeps hers; logout keeps the entry', () async {
    await store.write(store.currentOwner()!, _scope(), {'id:x|g'});
    current = null;
    expect(store.currentOwner(), isNull);
    current = const LocalAuthSession(uid: 'B', generation: 2);
    final b = store.currentOwner()!;
    expect(store.read(b, _scope()), isEmpty);
    await store.write(b, _scope(), {'id:y|g'});
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(store.read(store.currentOwner()!, _scope()), {'id:x|g'});
  });

  test('a forged entry under A\'s key with another owner reads as none', () async {
    final owner = store.currentOwner()!;
    await storage.saveSetting(ShoppingListChecksStore.storageKey(owner), {
      'format_version': 1,
      'owner_id': 'B',
      'environment': _env,
      'period_start': '2026-11-16',
      'period_kind': 'week',
      'selection_signature': 'sig',
      'checked': ['id:x|g'],
    });
    expect(store.read(owner, _scope()), isEmpty);
  });

  test('another environment reads as none', () async {
    await store.write(store.currentOwner()!, _scope(), {'id:x|g'});
    final other = ShoppingListChecksStore(
      LocalStorage(currentSession: () => current, environment: 'other'),
    );
    expect(other.read(other.currentOwner()!, _scope()), isEmpty);
  });

  test('session changed before the write: nothing is written', () async {
    final a = store.currentOwner()!;
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(await store.write(a, _scope(), {'id:x|g'}), isFalse);
    expect(Hive.box('settings_box').isEmpty, isTrue);
  });

  test('session changes after the put: write returns false although the '
      'data of A is stored under her own key', () async {
    final a = store.currentOwner()!;
    final box = Hive.box('settings_box');
    // Hive notifies after the put; the session flips before the task ends.
    final sub = box.watch().listen(
      (_) => current = const LocalAuthSession(uid: 'B', generation: 2),
    );
    addTearDown(sub.cancel);
    expect(await store.write(a, _scope(), {'id:x|g'}), isFalse);
    // The put did happen, and only under A's key: no cross attribution.
    expect(box.keys.length, 1);
    expect(current?.uid, 'B');
    current = const LocalAuthSession(uid: 'A', generation: 3);
    expect(store.read(store.currentOwner()!, _scope()), {'id:x|g'});
    current = const LocalAuthSession(uid: 'B', generation: 2);
    expect(store.read(store.currentOwner()!, _scope()), isEmpty);
  });

  test('same owner, new session generation: the write is still hers', () async {
    final a = store.currentOwner()!;
    current = const LocalAuthSession(uid: 'A', generation: 2);
    expect(await store.write(a, _scope(), {'id:x|g'}), isTrue);
  });

  test('unknown format or unexpected shape: no marks, no exception', () async {
    final owner = store.currentOwner()!;
    final key = ShoppingListChecksStore.storageKey(owner);
    await store.write(owner, _scope(), {'id:x|g'});
    final valid = Map<String, Object?>.from(
      Hive.box('settings_box').get(key) as Map,
    );
    for (final broken in <Object?>[
      {...valid, 'format_version': 2},
      {...valid, 'format_version': '1'},
      {...valid, 'checked': 'id:x|g'},
      {...valid, 'checked': [1]},
      {...valid}..remove('period_kind'),
      'text',
      42,
      [1, 2],
    ]) {
      await Hive.box('settings_box').put(key, broken);
      expect(store.read(owner, _scope()), isEmpty, reason: '$broken');
    }
  });

  test('selection signature: stable, order-free, sensitive to the choice', () {
    WeeklyMealSelection pick(int day, String meal, String chosen) =>
        WeeklyMealSelection(
          date: DateTime(2026, 11, day),
          parentMealId: meal,
          selectedMealId: chosen,
        );
    final a = [pick(16, 'm1', 'm1'), pick(18, 'm2', 'v2')];
    final sig = ShoppingListChecksStore.selectionSignature(a);
    expect(ShoppingListChecksStore.selectionSignature(a.reversed), sig);
    expect(
      ShoppingListChecksStore.selectionSignature([
        pick(16, 'm1', 'm1'),
        pick(18, 'm2', 'm2'),
      ]),
      isNot(sig),
    );
  });

  test('product ids: stable across builds and unique per item', () {
    MealIngredientEntity ing(String id, String name, String unit) =>
        MealIngredientEntity(id: id, name: name, quantity: 1, unit: unit);
    final period = DietPeriodEntity(
      start: DateTime(2026, 11, 16),
      end: DateTime(2026, 11, 22),
      days: [
        for (final day in [16, 17])
          DietPeriodDayEntity(
            date: DateTime(2026, 11, day),
            diet: DietEntity(
              id: 'd$day',
              name: 'D',
              meals: [
                MealEntity(
                  id: 'm$day',
                  type: 'LUNCH',
                  name: 'M',
                  nutritionalBadges: const [],
                  variants: const [],
                  ingredients: [
                    ing('i-rice', 'Arroz', 'g'),
                    ing('i-egg', 'Huevo', 'unit'),
                    ing('i-egg', 'Huevo', 'g'),
                    ing('', 'Sal', 'to_taste'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
    List<String> ids() => const WeeklyShoppingListBuilder()
        .build(week: period, locale: 'es')
        .map(ShoppingListChecksStore.productId)
        .toList();
    final first = ids();
    expect(ids(), first);
    expect(first.toSet(), hasLength(first.length));
  });
}
