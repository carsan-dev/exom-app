// Characterisation tests for mealSyncState: they pin the current behaviour
// (written after the implementation, so they start green) and kill the
// mutants found in review: failed/uploading mapped to pending, first action
// winning instead of the last, variant ids ignored.
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _date = '2026-11-18';

Map<String, dynamic> _action(
  String mealId, {
  String type = 'mark_meal_completed',
  String date = _date,
  String? status,
}) => {
  'type': type,
  'meal_id': mealId,
  'date': date,
  'status': ?status,
};

ExomSyncState? _state(
  List<Map<String, dynamic>> actions, {
  Set<String> mealIds = const {'m-1'},
  String date = _date,
}) => mealSyncState(ownedActions: actions, date: date, mealIds: mealIds);

void main() {
  test('no actions: nothing to show', () {
    expect(_state(const []), isNull);
  });

  test('a queued action without a known status is pending', () {
    expect(_state([_action('m-1')]), ExomSyncState.pendiente);
    expect(
      _state([_action('m-1', status: 'pending')]),
      ExomSyncState.pendiente,
    );
  });

  test('uploading is sending', () {
    expect(
      _state([_action('m-1', status: 'uploading')]),
      ExomSyncState.enviando,
    );
  });

  test('failed is failed', () {
    expect(_state([_action('m-1', status: 'failed')]), ExomSyncState.fallida);
  });

  test('unmark actions count too', () {
    expect(
      _state([_action('m-1', type: 'unmark_meal_completed', status: 'failed')]),
      ExomSyncState.fallida,
    );
  });

  test('the last action of the list wins', () {
    expect(
      _state([
        _action('m-1', status: 'failed'),
        _action('m-1', type: 'unmark_meal_completed', status: 'uploading'),
      ]),
      ExomSyncState.enviando,
    );
    expect(
      _state([
        _action('m-1', status: 'uploading'),
        _action('m-1', type: 'unmark_meal_completed'),
      ]),
      ExomSyncState.pendiente,
    );
    expect(
      _state([
        _action('m-1'),
        _action('m-1', type: 'unmark_meal_completed', status: 'failed'),
      ]),
      ExomSyncState.fallida,
    );
  });

  test('an action on any variant id of the meal matches', () {
    const ids = {'m-1', 'm-1-b', 'm-1-c'};
    expect(
      _state([_action('m-1-c', status: 'failed')], mealIds: ids),
      ExomSyncState.fallida,
    );
    expect(
      _state([_action('m-1-b', status: 'uploading')], mealIds: ids),
      ExomSyncState.enviando,
    );
    // Without the variant ids the same action is not about this meal.
    expect(_state([_action('m-1-c', status: 'failed')]), isNull);
  });

  test('the last action wins across the meal and its variants', () {
    const ids = {'m-1', 'm-1-b'};
    expect(
      _state([
        _action('m-1', status: 'failed'),
        _action('m-1-b', type: 'unmark_meal_completed', status: 'uploading'),
      ], mealIds: ids),
      ExomSyncState.enviando,
    );
  });

  test('actions of another day, type or meal are ignored', () {
    expect(_state([_action('m-1', date: '2026-11-17')]), isNull);
    expect(_state([_action('m-1', type: 'save_metric')]), isNull);
    expect(_state([_action('other')]), isNull);
    // Ignored actions do not hide a matching earlier one.
    expect(
      _state([
        _action('m-1', status: 'failed'),
        _action('m-1', date: '2026-11-17', status: 'uploading'),
        _action('other', status: 'uploading'),
        _action('m-1', type: 'other_type', status: 'uploading'),
      ]),
      ExomSyncState.fallida,
    );
  });
}
