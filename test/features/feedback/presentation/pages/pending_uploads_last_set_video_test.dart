// FB1: «Subidas pendientes» names the exercise of a last-set video (also when
// opened from Ajustes and for rows saved by earlier builds), explains why it
// failed and, while a queued completion depends on it, offers «Volver a
// grabar» instead of «Eliminar» (which used to leave that completion failed
// with no way back).
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../trainings/presentation/pages/last_set_video_test_support.dart'
    show mockVideoPicker;

const _date = '2026-09-05';

Map<String, dynamic> _video(String id, {
  String status = 'failed',
  String? error = 'file_missing',
  String? name,
}) => {
  'id': id,
  'media_type': 'VIDEO',
  'feedback_kind': 'LAST_SET',
  'training_id': 'training-1',
  'training_exercise_id': 'te-$id',
  'exercise_id': 'ex-$id',
  'assignment_date': _date,
  'training_session_id': 'execution-1',
  'status': status,
  'last_error': ?error,
  'exercise_name': ?name,
};

class _Storage extends LocalStorage {
  Map<String, Map<String, dynamic>> cached = {};
  List<Map<String, dynamic>> uploads = const [];
  String stamp = 'owner:1:test';
  @override
  String? get sessionStamp => stamp;
  @override
  Map<String, dynamic>? getCachedMap(String key) => cached[key];
  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() =>
      [for (final row in uploads) Map<String, dynamic>.from(row)];
}

class _Queue extends Fake implements FeedbackUploadQueueService {
  _Queue(this.items);
  final List<Map<String, dynamic>> items;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final replaced = <String>[];
  final discarded = <String>[];
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => items;
  @override
  FeedbackUploadNotice? progressOf(String id) => null;
  @override
  Future<void> discard(String id) async => discarded.add(id);
  @override
  Future<String> replaceFailed(
    String id, {
    required File file,
    required String contentType,
    String? notes,
    String? expectedSession,
  }) async {
    replaced.add(id);
    return '$id-new';
  }
}

class _Sync extends Fake implements OfflineSyncService {
  _Sync(this.actions);
  final List<Map<String, dynamic>> actions;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  List<Map<String, dynamic>> get pendingActions => actions;
}

Future<({_Queue queue, AppLocalizations l10n})> _pump(
  WidgetTester tester, {
  required List<Map<String, dynamic>> items,
  List<Map<String, dynamic>> actions = const [],
  Map<String, Map<String, dynamic>> cached = const {},
  String locale = 'es',
  double width = 390,
  TextScaler? textScaler,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await sl.reset();
  final queue = _Queue(items);
  sl.registerSingleton<LocalStorage>(_Storage()
    ..cached = cached
    ..uploads = items);
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerSingleton<OfflineSyncService>(_Sync(actions));
  addTearDown(() async {
    await queue.events.close();
    await sl.reset();
  });
  // Opened from Ajustes: no exercise names are passed in.
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: const PendingUploadsPage(),
  ));
  await tester.pumpAndSettle();
  return (
    queue: queue,
    l10n: AppLocalizations.of(tester.element(find.byType(PendingUploadsPage))),
  );
}

void main() {
  for (final locale in ['es', 'en']) {
    testWidgets('$locale: a row opened from Ajustes shows the stored exercise '
        'name and a readable reason, never the identifier', (tester) async {
      final env = await _pump(tester, locale: locale,
        items: [_video('a', name: 'Sentadilla búlgara')]);
      expect(find.textContaining(env.l10n.pendingEvidenceExercise(
          'Sentadilla búlgara')), findsOneWidget);
      expect(find.textContaining('te-a'), findsNothing);
      expect(find.text(env.l10n.errorFileMissing), findsOneWidget);
    });
  }

  testWidgets('a row saved without a name takes it from the cached training',
      (tester) async {
    final env = await _pump(tester, items: [_video('a')], cached: {
      'training_detail_training-1_$_date': {
        'id': 'training-1',
        'exercises': [
          {'id': 'te-a', 'exercise': {'id': 'ex-a', 'name': 'Remo con barra'}},
        ],
      },
    });
    expect(find.textContaining(env.l10n.pendingEvidenceExercise(
        'Remo con barra')), findsOneWidget);
    expect(find.textContaining('te-a'), findsNothing);
  });

  testWidgets('a row saved without a name and no cache gets a neutral label',
      (tester) async {
    final env = await _pump(tester, items: [_video('a')]);
    expect(find.textContaining(env.l10n.pendingEvidenceExerciseUnnamed),
      findsOneWidget);
    expect(find.textContaining('te-a'), findsNothing);
    expect(find.textContaining('ex-a'), findsNothing);
  });

  testWidgets('a failed video a queued completion depends on offers «Volver '
      'a grabar» and no «Eliminar»', (tester) async {
    final env = await _pump(tester, items: [_video('a', name: 'Remo')],
      actions: [
        {
          'id': 'op-1',
          'type': 'mark_exercise_completed',
          'date': _date,
          'status': 'queued',
          'last_set_feedback_client_upload_id': 'a',
        },
      ]);
    expect(find.byKey(const Key('pending-delete-a')), findsNothing);
    final rerecord = find.byKey(const Key('pending-rerecord-a'));
    expect(rerecord, findsOneWidget);
    expect(tester.getSize(rerecord).height, greaterThanOrEqualTo(48));
    mockVideoPicker(tester, (_) async => '/tmp/again.mp4');
    await tester.ensureVisible(rerecord);
    await tester.tap(rerecord);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('last-set-video-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('last-set-video-use')));
    await tester.pumpAndSettle();
    expect(env.queue.replaced, ['a']);
    expect(env.queue.discarded, isEmpty);
  });

  testWidgets('a training completion waiting on the video also counts as a '
      'dependant', (tester) async {
    await _pump(tester, items: [_video('a', name: 'Remo')], actions: [
      {
        'id': 'op-2',
        'type': 'complete_training',
        'date': _date,
        'status': 'queued',
        'depends_on_feedback_ids': ['a'],
      },
    ]);
    expect(find.byKey(const Key('pending-delete-a')), findsNothing);
    expect(find.byKey(const Key('pending-rerecord-a')), findsOneWidget);
  });

  testWidgets('without a dependant the failed video keeps «Eliminar» and can '
      'also be recorded again', (tester) async {
    await _pump(tester, items: [_video('a', name: 'Remo')]);
    expect(find.byKey(const Key('pending-delete-a')), findsOneWidget);
    expect(find.byKey(const Key('pending-rerecord-a')), findsOneWidget);
  });

  testWidgets('other evidence keeps today\'s actions', (tester) async {
    await _pump(tester, items: [
      _video('a', status: 'queued', error: null, name: 'Remo'),
      {'id': 'img', 'media_type': 'IMAGE', 'status': 'failed'},
    ]);
    expect(find.byKey(const Key('pending-rerecord-a')), findsNothing);
    expect(find.byKey(const Key('pending-rerecord-img')), findsNothing);
    expect(find.byKey(const Key('pending-delete-img')), findsOneWidget);
  });

  // FB1 r2 (review F7): the last-set video rows at 2.0× (nonlinear) and
  // 320 dp, with a long exercise name and reason.
  for (final locale in ['es', 'en']) {
    testWidgets('$locale: 2.0× text at 320 dp keeps the rows and «Volver a '
        'grabar» inside the screen', (tester) async {
      const name = 'Sentadilla búlgara con mancuernas y pausa isométrica';
      final env = await _pump(tester, locale: locale, width: 320,
        textScaler: const AndroidNonlinearTextScaler(2.0),
        items: [
          _video('a', name: name),
          _video('b', status: 'queued', error: null, name: name),
        ],
        actions: [
          {
            'id': 'op-1',
            'type': 'mark_exercise_completed',
            'date': _date,
            'status': 'queued',
            'last_set_feedback_client_upload_id': 'a',
          },
        ]);
      expect(tester.takeException(), isNull);
      final rerecord = find.byKey(const Key('pending-rerecord-a'));
      await tester.ensureVisible(rerecord);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(rerecord);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(find.text(env.l10n.errorFileMissing), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('pending-row-b')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
