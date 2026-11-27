import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:get_it/get_it.dart';

/// Period of a shopping list: the week of the Dietas row and of the calendar
/// export, or the month of the calendar export.
enum ShoppingListPeriodKind { week, month }

/// What a set of marks belongs to: the period and the chosen alternatives.
/// Marks of another period or another choice are not shown (L5-D25).
class ShoppingListScope {
  const ShoppingListScope({
    required this.periodStart,
    required this.kind,
    required this.selectionSignature,
  });

  final DateTime periodStart;
  final ShoppingListPeriodKind kind;
  final String selectionSignature;

  String get periodStartValue =>
      '${periodStart.year.toString().padLeft(4, '0')}-'
      '${periodStart.month.toString().padLeft(2, '0')}-'
      '${periodStart.day.toString().padLeft(2, '0')}';
}

/// Owner of the marks: the signed-in user in this environment, captured when
/// the list opens. A write for another owner than the current one is dropped.
class ShoppingListOwner {
  const ShoppingListOwner({required this.id, required this.environment});

  final String id;
  final String environment;
}

/// Marks of the shopping list kept on this device (L5-D25, exception EX-Q4
/// of the L5 contract v2): **one** entry per owner and environment in the
/// existing preferences box, written and read only through
/// [LocalStorage.saveSetting] / [LocalStorage.getSetting]. No Hive model,
/// no new box, nothing in the cache box («Borrar caché» does not touch it).
///
/// Key: `shopping_list_checked:` + base64 of `[1, environment, ownerId]` (the
/// scoping pattern of the progress-photo picker intent). Value:
/// `{format_version: 1, owner_id, environment, period_start, period_kind,
/// selection_signature, checked: [product ids]}`. A value whose owner,
/// environment, format, period or selection does not match reads as no
/// marks, and the next write replaces it: that is how the marks clear when
/// the period or the alternatives change. Without an owner (signed out or
/// switching) nothing is read or written. Logging out keeps the entry for its
/// owner; another user cannot read it (other key and owner check).
class ShoppingListChecksStore {
  ShoppingListChecksStore(this._storage);

  final LocalStorage _storage;

  /// The store over the app's [LocalStorage], or null when there is none
  /// (isolated widget tests): the marks then live only on the screen.
  static ShoppingListChecksStore? fromLocator() =>
      GetIt.I.isRegistered<LocalStorage>()
      ? ShoppingListChecksStore(GetIt.I<LocalStorage>())
      : null;

  static const int formatVersion = 1;
  static const String keyPrefix = 'shopping_list_checked';

  static String storageKey(ShoppingListOwner owner) {
    final scope = base64Url.encode(
      utf8.encode(jsonEncode([formatVersion, owner.environment, owner.id])),
    );
    return '$keyPrefix:$scope';
  }

  /// Stable summary of the chosen alternatives: the selection key of each
  /// meal with alternatives and the chosen meal id, in a fixed order, hashed.
  static String selectionSignature(Iterable<WeeklyMealSelection> selections) {
    final lines =
        selections.map((s) => '${s.key}=${s.selectedMealId}').toList()..sort();
    return sha256.convert(utf8.encode(lines.join('\n'))).toString();
  }

  /// Id of a product of the list, stable between builds of the same list:
  /// the builder's ingredient key (catalogue id, or the normalised name when
  /// there is none) and the unit, since one ingredient can give one item per
  /// unit.
  static String productId(ShoppingListItem item) =>
      '${item.ingredientKey}|${item.unit ?? ''}';

  /// The signed-in owner, or null without a session.
  ShoppingListOwner? currentOwner() {
    final id = _storage.ownerId;
    if (id == null || id.isEmpty) return null;
    return ShoppingListOwner(id: id, environment: _storage.environment);
  }

  bool _isCurrent(ShoppingListOwner owner) {
    final current = currentOwner();
    return current != null &&
        current.id == owner.id &&
        current.environment == owner.environment;
  }

  /// Marks of [owner] for [scope]; empty when there are none, they belong to
  /// something else or the entry has an unexpected shape. Never throws.
  Set<String> read(ShoppingListOwner owner, ShoppingListScope scope) {
    if (!_isCurrent(owner)) return const {};
    try {
      final value = _storage.getSetting<Object?>(storageKey(owner));
      if (value is! Map) return const {};
      final checked = value['checked'];
      if (value['format_version'] != formatVersion ||
          value['owner_id'] != owner.id ||
          value['environment'] != owner.environment ||
          value['period_start'] != scope.periodStartValue ||
          value['period_kind'] != scope.kind.name ||
          value['selection_signature'] != scope.selectionSignature ||
          checked is! List ||
          checked.any((id) => id is! String)) {
        return const {};
      }
      return checked.cast<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Replaces the entry of [owner] with [checked] for [scope]. Returns false
  /// (and writes nothing) when [owner] is no longer the signed-in user or
  /// the session changes around the write; storage errors are swallowed (the
  /// marks stay on the screen).
  ///
  /// Known, accepted edge: if the session changes after the put but before
  /// the task ends, `sessionTask` re-checks the guard and this returns false
  /// although the entry was already stored. It is harmless: the data goes
  /// under the key of [owner] (no cross attribution) and the owner's next
  /// write replaces it; the false only tells the screen "not confirmed".
  Future<bool> write(
    ShoppingListOwner owner,
    ShoppingListScope scope,
    Set<String> checked,
  ) async {
    if (!_isCurrent(owner)) return false;
    try {
      await _storage.sessionTask(() async {
        // Same turn as the put: no session can change in between.
        if (!_isCurrent(owner)) throw const LocalSessionChanged();
        await _storage.saveSetting(storageKey(owner), {
          'format_version': formatVersion,
          'owner_id': owner.id,
          'environment': owner.environment,
          'period_start': scope.periodStartValue,
          'period_kind': scope.kind.name,
          'selection_signature': scope.selectionSignature,
          'checked': checked.toList()..sort(),
        });
      });
      return true;
    } on LocalSessionChanged {
      return false;
    } catch (_) {
      return false;
    }
  }
}
