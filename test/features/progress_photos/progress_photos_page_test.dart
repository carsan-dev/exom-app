import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/services/managed_upload.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:exom_app/features/progress_photos/presentation/pages/progress_photos_page.dart';
import 'package:exom_app/features/progress_photos/presentation/progress_photo_queue.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late FakeRepository repository;
  late FakeQueue queue;
  late String session;
  late Directory directory;

  setUp(() async {
    repository = FakeRepository();
    queue = FakeQueue();
    session = 'account-a:1';
    directory = await Directory.systemTemp.createTemp('progress-photos-ui-');
  });
  tearDown(() => directory.delete(recursive: true));

  Widget page({
    Future<XFile?> Function(ImageSource)? picker,
    ProgressPhotoLostData? retrieveLostData,
    ProgressPhotoPickerIntentStore? pickerIntentStore,
    Duration? pollInterval,
    Key? pageKey,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProgressPhotosPage(
      key: pageKey,
      repository: repository,
      queue: queue,
      sessionStamp: () => session,
      pickImage: picker,
      retrieveLostData: retrieveLostData,
      pickerIntentStore: pickerIntentStore,
      queuePollInterval: pollInterval,
    ),
  );

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders loading, error, empty and four-view incomplete history', (tester) async {
    repository.pendingHistory = Completer<ProgressPhotoHistory>();
    await tester.pumpWidget(page());
    expect(find.text('Loading progress photos'), findsOneWidget);

    repository.pendingHistory!.completeError(StateError('offline'));
    await pumpPage(tester);
    expect(find.text('Could not load progress photos'), findsOneWidget);
    repository.pendingHistory = null;
    await tester.tap(find.text('Try again'));
    await pumpPage(tester);
    expect(find.text('No progress photo sessions yet'), findsOneWidget);

    repository.history = [sessionFor('s1', '2026-09-16', photos: [photo('front', 'FRONT')])];
    await tester.tap(find.byTooltip('Refresh progress photos'));
    await pumpPage(tester);
    expect(find.text('16 Sep 2026'), findsOneWidget);
    for (final label in ['Front', 'Left side', 'Right side', 'Back']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Incomplete session'), findsOneWidget);
    expect(find.text('Missing'), findsNWidgets(3));
  });

  testWidgets('creates incomplete sessions and queues camera or gallery selection without treating cancellation as an error', (tester) async {
    final image = File('${directory.path}/picked.jpg');
    repository.history = [
      sessionFor('one', '2026-09-15'),
      sessionFor('two', '2026-09-16'),
    ];
    final sources = <ImageSource>[];
    await tester.pumpWidget(page(picker: (source) async {
      sources.add(source);
      return source == ImageSource.camera ? XFile(image.path) : null;
    }));
    await pumpPage(tester);
    expect(find.text('15 Sep 2026'), findsOneWidget);

    expect(repository.history, hasLength(2)); // Independent incomplete sessions remain distinct.

    await tester.tap(find.text('Add Front').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Camera'));
    await pumpPage(tester);
    expect(sources, [ImageSource.camera]);
    expect(queue.enqueues.single.view, 'FRONT');

    await tester.tap(find.text('Add Left side').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Gallery'));
    await pumpPage(tester);
    expect(sources, [ImageSource.camera, ImageSource.gallery]);
    expect(queue.enqueues, hasLength(1));
  });

  testWidgets('uses shared permission recovery, explicit replacement, queue states and accessible enlargement', (tester) async {
    final image = File('${directory.path}/replacement.jpg');
    repository.history = [sessionFor('s1', '2026-09-16', photos: [photo('active', 'FRONT')])];
    queue.items = [
      pending('pending', 's1', 'LEFT', 'queued'),
      pending('syncing', 's1', 'RIGHT', 'processing'),
      pending('confirmed', 's1', 'BACK', 'completed', cleanupPending: true),
      pending('conflict', 's1', 'FRONT', 'failed', error: 'STALE_REPLACEMENT'),
    ];
    await tester.pumpWidget(page(picker: (_) async => XFile(image.path)));
    await pumpPage(tester);
    expect(find.text('Pending upload'), findsWidgets);
    expect(find.text('Synchronizing'), findsWidgets);
    expect(find.text('Confirmed; cleaning local copy'), findsWidgets);
    expect(find.text('Replacement needs review; local photo retained'), findsWidgets);

    await tester.tap(find.text('Replace Front'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Camera'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Replace active photo?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await pumpPage(tester);
    expect(queue.enqueues.last.replacesPhotoId, 'active');

    await tester.tap(find.byTooltip('Enlarge Front'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Close image'), findsOneWidget);
    await tester.tap(find.byTooltip('Close image'));
    await pumpPage(tester);

    queue.enqueues.clear();
    await tester.tap(find.text('Replace Front'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Camera'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Cancel'));
    await pumpPage(tester);
    expect(queue.enqueues, isEmpty);
  });

  testWidgets('failed uploads expose ordinary retry and informed stale-replacement recovery without recreating an upload', (tester) async {
    repository.history = [sessionFor('s1', '2026-09-16', photos: [photo('fresh-active', 'FRONT')])];
    queue.items = [
      pending('ordinary-failure', 's1', 'LEFT', 'failed', error: 'progress_photo_network_connectionError_0'),
      {
        ...pending('stale-replacement', 's1', 'FRONT', 'failed', error: 'STALE_REPLACEMENT'),
        'upload_checkpoint': {'upload_id': 'original-upload'},
      },
    ];
    await tester.pumpWidget(page());
    await pumpPage(tester);

    await tester.tap(find.text('Retry'));
    expect(queue.retried, ['ordinary-failure']);

    await tester.tap(find.text('Review replacement'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Use the current active photo?'), findsOneWidget);
    await tester.tap(find.text('Rebase replacement'));
    await pumpPage(tester);
    expect(queue.rebased, [('stale-replacement', 'fresh-active')]);
    expect(queue.discarded, isEmpty);

    await tester.tap(find.text('Discard').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Discard retained local photo?'), findsOneWidget);
    await tester.tap(find.text('Discard').last);
    expect(queue.discarded, ['stale-replacement']);
  });

  testWidgets('recovers a lost picker file only for its current owner', (tester) async {
    final image = File('${directory.path}/lost.jpg');
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async => LostDataResponse(file: XFile(image.path)),
    ));
    await pumpPage(tester);

    expect(queue.enqueues, hasLength(1));
    expect(queue.enqueues.single.view, 'FRONT');
    expect(intent.current, isNull);
  });

  testWidgets('recovered replacement requires confirmation before it is queued', (tester) async {
    final image = File('${directory.path}/lost-replacement.jpg');
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'replaces_photo_id': 'active-front',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async => LostDataResponse(file: XFile(image.path)),
    ));
    await tester.pump();

    expect(find.text('Replace active photo?'), findsOneWidget);
    expect(queue.enqueues, isEmpty);

    await tester.tap(find.text('Replace'));
    await pumpPage(tester);

    expect(queue.enqueues.single.replacesPhotoId, 'active-front');
    expect(intent.current, isNull);
  });

  testWidgets('declining a recovered replacement discards the current owner intent', (tester) async {
    final image = File('${directory.path}/lost-replacement-declined.jpg');
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'replaces_photo_id': 'active-front',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async => LostDataResponse(file: XFile(image.path)),
    ));
    await tester.pump();

    expect(find.text('Replace active photo?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpPage(tester);

    expect(queue.enqueues, isEmpty);
    expect(intent.current, isNull);
    expect(intent.clearCalls, 1);
  });

  testWidgets('recovered replacement never queues or clears A intent after switch during confirmation', (tester) async {
    final image = File('${directory.path}/lost-replacement-switch.jpg');
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'replaces_photo_id': 'active-front',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async => LostDataResponse(file: XFile(image.path)),
    ));
    await tester.pump();

    expect(find.text('Replace active photo?'), findsOneWidget);
    session = 'account-b:1';
    await tester.tap(find.text('Replace'));
    await pumpPage(tester);

    expect(queue.enqueues, isEmpty);
    expect(intent.current?['session_stamp'], 'account-a:1');
    expect(intent.clearCalls, 0);
  });

  testWidgets('retains a current owner intent when lost picker data is empty', (tester) async {
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async => LostDataResponse(),
    ));
    await pumpPage(tester);

    expect(queue.enqueues, isEmpty);
    expect(intent.current?['state'], 'recovery_required');
    expect(intent.clearCalls, 0);
  });

  testWidgets('retains intent and shows localized recovery guidance when lost-data retrieval throws', (tester) async {
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'session_stamp': 'account-a:1',
    });
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () => Future<LostDataResponse>.error(StateError('lost picker data')),
    ));
    await pumpPage(tester);

    expect(queue.enqueues, isEmpty);
    expect(intent.current?['state'], 'recovery_error');
    expect(intent.clearCalls, 0);
    expect(find.text('We could not recover the selected photo. Try selecting it again.'), findsOneWidget);
  });

  testWidgets('does not retrieve or consume A lost data while B is current', (tester) async {
    final intent = FakePickerIntentStore({
      'session_id': 'a-session',
      'civil_session_date': '2026-09-16',
      'view': 'FRONT',
      'session_stamp': 'account-a:1',
    });
    session = 'account-b:1';
    var retrieveCalls = 0;
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      retrieveLostData: () async {
        retrieveCalls++;
        return LostDataResponse();
      },
    ));
    await pumpPage(tester);

    expect(retrieveCalls, 0);
    expect(intent.current?['session_stamp'], 'account-a:1');
    expect(intent.clearCalls, 0);
  });

  testWidgets('picker and replacement confirmation never enqueue under a switched account', (tester) async {
    final image = File('${directory.path}/switch.jpg');
    repository.history = [sessionFor('a-session', '2026-09-16', photos: [photo('active', 'FRONT')])];
    final intent = FakePickerIntentStore();
    final picked = Completer<XFile?>();
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      picker: (_) => picked.future,
    ));
    await pumpPage(tester);

    await tester.tap(find.text('Add Left side'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.pump();
    session = 'account-b:1';
    picked.complete(XFile(image.path));
    await pumpPage(tester);
    expect(queue.enqueues, isEmpty);
    expect(intent.current?['session_id'], 'a-session');

    session = 'account-a:1';
    final replacementPicked = Completer<XFile?>();
    await tester.pumpWidget(page(
      pickerIntentStore: intent,
      picker: (_) => replacementPicked.future,
    ));
    await pumpPage(tester);
    await tester.tap(find.text('Replace Front'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    replacementPicked.complete(XFile(image.path));
    await tester.pump();
    expect(find.text('Replace active photo?'), findsOneWidget);
    session = 'account-b:1';
    await tester.tap(find.text('Replace'));
    await pumpPage(tester);

    expect(queue.enqueues, isEmpty);
    expect(intent.current?['session_id'], 'a-session');
  });

  testWidgets('replacement review never rebases under a switched account', (tester) async {
    repository.history = [sessionFor('a-session', '2026-09-16', photos: [photo('fresh-active', 'FRONT')])];
    queue.items = [
      {
        ...pending('stale-replacement', 'a-session', 'FRONT', 'failed', error: 'STALE_REPLACEMENT'),
        'upload_checkpoint': {'upload_id': 'original-upload'},
      },
    ];
    await tester.pumpWidget(page());
    await pumpPage(tester);
    await tester.tap(find.text('Review replacement'));
    await tester.pump();
    expect(find.text('Use the current active photo?'), findsOneWidget);
    session = 'account-b:1';
    await tester.tap(find.text('Rebase replacement'));
    await pumpPage(tester);

    expect(queue.rebased, isEmpty);
  });

  testWidgets('widget recreation isolates current pending entries and suppresses stale remote history', (tester) async {
    repository.pendingHistory = Completer<ProgressPhotoHistory>();
    queue.items = [pending('a-pending', 'a-session', 'FRONT', 'queued')];
    await tester.pumpWidget(page());
    await tester.pump();

    session = 'account-b:1';
    queue.items = [pending('b-pending', 'b-session', 'LEFT', 'queued')];
    repository.pendingHistory!.complete(ProgressPhotoHistory(
      sessions: [sessionFor('a-session', '2026-09-16')], total: 1, page: 1, limit: 20, totalPages: 1,
    ));
    await pumpPage(tester);
    expect(find.text('16 Sep 2026'), findsNothing);

    repository.pendingHistory = null;
    repository.history = [sessionFor('b-session', '2026-09-17')];
    await tester.pumpWidget(page(pageKey: const ValueKey('account-b')));
    await pumpPage(tester);
    expect(find.text('Pending upload'), findsWidgets);
  });

  testWidgets('loads page two, deduplicates history, and resets it on session switch', (tester) async {
    repository.history = [sessionFor('session-0', '2026-09-16')];
    repository.histories[1] = ProgressPhotoHistory(
      sessions: repository.history,
      total: 22,
      page: 1,
      limit: 20,
      totalPages: 2,
    );
    repository.histories[2] = ProgressPhotoHistory(
      sessions: [sessionFor('session-0', '2026-09-16'), sessionFor('page-two', '2026-09-17')],
      total: 22, page: 2, limit: 20, totalPages: 2,
    );
    await tester.pumpWidget(page(pollInterval: const Duration(milliseconds: 1)));
    await pumpPage(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('Load more'));
    await pumpPage(tester);
    expect(repository.requestedPages, containsAll([1, 2]));
    expect(find.text('17 Sep 2026'), findsOneWidget);

    session = 'account-b:1';
    repository.history = const [];
    repository.histories[1] = const ProgressPhotoHistory(
      sessions: [], total: 0, page: 1, limit: 20, totalPages: 0,
    );
    await tester.pump(const Duration(milliseconds: 5));
    await pumpPage(tester);
    expect(find.text('17 Sep 2026'), findsNothing);
  });

  testWidgets('refreshes a page-two stale replacement by its exact session before rebasing', (tester) async {
    final stale = sessionFor(
      'page-two-stale',
      '2026-09-15',
      photos: [photo('stale-active', 'FRONT')],
    );
    repository.histories[1] = ProgressPhotoHistory(
      sessions: [sessionFor('page-one', '2026-09-16')],
      total: 2,
      page: 1,
      limit: 20,
      totalPages: 2,
    );
    repository.histories[2] = ProgressPhotoHistory(
      sessions: [stale],
      total: 2,
      page: 2,
      limit: 20,
      totalPages: 2,
    );
    repository.sessionsById[stale.id] = sessionFor(
      stale.id,
      stale.sessionDate,
      photos: [photo('fresh-page-two-active', 'FRONT')],
    );
    queue.items = [
      {
        ...pending(
          'page-two-conflict',
          stale.id,
          'FRONT',
          'failed',
          error: 'STALE_REPLACEMENT',
        ),
        'queued_at': '2026-09-16T12:00:00.000Z',
        'upload_checkpoint': {
          'phase': 'completion_confirmed',
          'upload_id': 'managed-upload',
        },
      },
    ];

    await tester.pumpWidget(page());
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('Load more'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    final loadMore = find.widgetWithText(OutlinedButton, 'Load more');
    await tester.ensureVisible(loadMore);
    await tester.pump();
    await tester.tap(loadMore);
    await pumpPage(tester);
    final review = find.widgetWithText(TextButton, 'Review replacement');
    await tester.ensureVisible(review);
    await tester.pump();
    await tester.tap(review);
    await tester.pump();

    expect(repository.requestedSessionIds, [stale.id]);
    expect(find.text('Use the current active photo?'), findsOneWidget);
    await tester.tap(find.text('Rebase replacement'));
    await pumpPage(tester);
    expect(queue.rebased, [('page-two-conflict', 'fresh-page-two-active')]);
  });

  testWidgets('shows a newer actionable replacement conflict over an older completed entry', (tester) async {
    repository.history = [
      sessionFor('s1', '2026-09-16', photos: [photo('active', 'FRONT')]),
    ];
    queue.items = [
      {
        ...pending('old-completed', 's1', 'FRONT', 'completed'),
        'queued_at': '2026-09-16T10:00:00.000Z',
      },
      {
        ...pending(
          'new-conflict',
          's1',
          'FRONT',
          'failed',
          error: 'STALE_REPLACEMENT',
        ),
        'queued_at': '2026-09-16T11:00:00.000Z',
      },
    ];

    await tester.pumpWidget(page());
    await pumpPage(tester);

    expect(find.text('Replacement needs review; local photo retained'), findsOneWidget);
    await tester.tap(find.text('Review replacement'));
    await tester.pump();
    expect(find.text('Use the current active photo?'), findsOneWidget);
  });

  testWidgets('prioritizes a newer conflict over completed cleanup updated later', (tester) async {
    repository.history = [
      sessionFor('s1', '2026-09-16', photos: [photo('active', 'FRONT')]),
    ];
    queue.items = [
      {
        ...pending('old-completed', 's1', 'FRONT', 'completed'),
        'queued_at': '2026-09-16T10:00:00.000Z',
        'updated_at': '2026-09-16T12:00:00.000Z',
      },
      {
        ...pending(
          'new-conflict',
          's1',
          'FRONT',
          'failed',
          error: 'STALE_REPLACEMENT',
        ),
        'queued_at': '2026-09-16T11:00:00.000Z',
        'updated_at': '2026-09-16T11:30:00.000Z',
      },
    ];

    await tester.pumpWidget(page());
    await pumpPage(tester);

    expect(find.text('Replacement needs review; local photo retained'), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
    await tester.tap(find.text('Review replacement'));
    await tester.pump();
    expect(find.text('Use the current active photo?'), findsOneWidget);
  });

  testWidgets('orders actionable entries by immutable queued time', (tester) async {
    repository.history = [
      sessionFor('s1', '2026-09-16', photos: [photo('active', 'FRONT')]),
    ];
    queue.items = [
      {
        ...pending('new-conflict', 's1', 'FRONT', 'failed', error: 'STALE_REPLACEMENT'),
        'queued_at': '2026-09-16T11:00:00.000Z',
        'updated_at': '2026-09-16T11:30:00.000Z',
      },
      {
        ...pending('old-retry', 's1', 'FRONT', 'failed', error: 'progress_photo_network_connectionError_0'),
        'queued_at': '2026-09-16T10:00:00.000Z',
        'updated_at': '2026-09-16T12:00:00.000Z',
      },
    ];

    await tester.pumpWidget(page());
    await pumpPage(tester);

    expect(find.text('Replacement needs review; local photo retained'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('breaks equal actionable queue timestamps by stable ID', (tester) async {
    repository.history = [
      sessionFor('s1', '2026-09-16', photos: [photo('active', 'FRONT')]),
    ];
    queue.items = [
      {
        ...pending('z-conflict', 's1', 'FRONT', 'failed', error: 'STALE_REPLACEMENT'),
        'queued_at': '2026-09-16T11:00:00.000Z',
      },
      {
        ...pending('a-retry', 's1', 'FRONT', 'failed', error: 'progress_photo_network_connectionError_0'),
        'queued_at': '2026-09-16T11:00:00.000Z',
      },
    ];

    await tester.pumpWidget(page());
    await pumpPage(tester);

    expect(find.text('Replacement needs review; local photo retained'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('switching owner during load more resets pagination for the new owner', (tester) async {
    repository.histories[1] = ProgressPhotoHistory(
      sessions: [sessionFor('a-page-one', '2026-09-16')],
      total: 2,
      page: 1,
      limit: 20,
      totalPages: 2,
    );
    repository.pendingHistories[2] = Completer<ProgressPhotoHistory>();
    await tester.pumpWidget(page(pollInterval: const Duration(milliseconds: 1)));
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('Load more'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    final initialLoadMore = find.widgetWithText(OutlinedButton, 'Load more');
    await tester.ensureVisible(initialLoadMore);
    await tester.pump();
    await tester.tap(initialLoadMore);
    await tester.pump();

    session = 'account-b:1';
    repository.histories[1] = ProgressPhotoHistory(
      sessions: [sessionFor('b-page-one', '2026-09-17')],
      total: 2,
      page: 1,
      limit: 20,
      totalPages: 2,
    );
    repository.histories[2] = ProgressPhotoHistory(
      sessions: [sessionFor('b-page-two', '2026-09-18')],
      total: 2,
      page: 2,
      limit: 20,
      totalPages: 2,
    );
    repository.pendingHistories[2]!.complete(ProgressPhotoHistory(
      sessions: [sessionFor('a-page-two', '2026-09-15')],
      total: 2,
      page: 2,
      limit: 20,
      totalPages: 2,
    ));
    await tester.pump(const Duration(milliseconds: 5));
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('Load more'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    final newOwnerLoadMore = find.widgetWithText(OutlinedButton, 'Load more');
    await tester.ensureVisible(newOwnerLoadMore);
    await tester.pump();
    await tester.tap(newOwnerLoadMore);
    await pumpPage(tester);

    expect(repository.requestedPages.where((page) => page == 2), hasLength(2));
  });

  test('retains the newest 60 sessions from a 61-record descending window', () {
    final sessions = List.generate(
      61,
      (index) => sessionFor('session-$index', '2026-12-31'),
    );

    final retained = retainNewestProgressPhotoSessions(sessions, maximum: 60);

    expect(retained, hasLength(60));
    expect(retained.first.id, 'session-0');
    expect(retained.last.id, 'session-59');
    expect(retained.map((session) => session.id), isNot(contains('session-60')));
  });

  testWidgets('renders Spanish date, view and status labels from generated localizations', (tester) async {
    repository.history = [sessionFor('s1', '2026-09-16')];
    queue.items = [pending('pending', 's1', 'FRONT', 'queued')];
    await tester.pumpWidget(page(locale: const Locale('es')));
    await pumpPage(tester);

    expect(find.text('16 sept 2026'), findsOneWidget);
    expect(find.text('Frontal'), findsOneWidget);
    expect(find.text('Subida pendiente'), findsWidgets);
  });

  testWidgets('picker recovery invokes app settings over the established method channel', (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.exommethod.exom/app_settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    repository.history = [sessionFor('a-session', '2026-09-16')];
    await tester.pumpWidget(page(
      picker: (_) async => throw PlatformException(code: 'permission_denied'),
    ));
    await pumpPage(tester);
    await tester.tap(find.text('Add Front'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await pumpPage(tester);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, isNull);
  });

  testWidgets('permission retry and gallery fallback callbacks retry the expected sources', (tester) async {
    final image = File('${directory.path}/retry.jpg');
    final sources = <ImageSource>[];
    var attempts = 0;
    repository.history = [sessionFor('a-session', '2026-09-16')];
    await tester.pumpWidget(page(
      picker: (source) async {
        sources.add(source);
        if (attempts++ == 0) throw PlatformException(code: 'permission_denied');
        return XFile(image.path);
      },
    ));
    await pumpPage(tester);
    await tester.tap(find.text('Add Front'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await pumpPage(tester);
    expect(sources, [ImageSource.camera, ImageSource.camera]);

    queue.enqueues.clear();
    attempts = 0;
    sources.clear();
    await tester.tap(find.text('Add Left side'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.tap(find.text('From gallery'));
    await pumpPage(tester);
    expect(sources, [ImageSource.camera, ImageSource.gallery]);
    expect(queue.enqueues.single.view, 'LEFT');
  });

  testWidgets('permission denial opens settings recovery and account switch clears other owner history', (tester) async {
    repository.history = [sessionFor('a-session', '2026-09-16')];
    await tester.pumpWidget(page(
      picker: (_) async => throw PlatformException(code: 'permission_denied'),
      pollInterval: const Duration(milliseconds: 1),
    ));
    await pumpPage(tester);
    await tester.tap(find.text('Add Front'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Camera'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Allow camera or gallery access in Settings and try again.'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await pumpPage(tester);
    expect(queue.enqueues, isEmpty);

    session = 'account-b:1';
    repository.history = const [];
    await tester.pump();
    await tester.pump();
    await pumpPage(tester);
    expect(find.text('16 Sep 2026'), findsNothing);
    expect(find.text('No progress photo sessions yet'), findsOneWidget);
  });
}

ProgressPhotoSession sessionFor(String id, String date, {List<ProgressPhoto> photos = const []}) =>
    ProgressPhotoSession(id: id, sessionDate: date, isComplete: photos.length == 4, photos: photos);

ProgressPhoto photo(String id, String view) => ProgressPhoto(id: id, view: view, imageUrl: 'https://example.test/$id.jpg');

Map<String, dynamic> pending(String id, String sessionId, String view, String status, {bool cleanupPending = false, String? error}) => {
  'id': id,
  'session_id': sessionId,
  'view': view,
  'status': status,
  'cleanup_pending': cleanupPending,
  'last_error': error,
  'association_checkpoint': {'state': status == 'completed' ? 'confirmed' : 'pending'},
};

class FakeRepository implements ProgressPhotoRepository {
  List<ProgressPhotoSession> history = const [];
  Completer<ProgressPhotoHistory>? pendingHistory;
  final Map<int, ProgressPhotoHistory> histories = {};
  final Map<int, Completer<ProgressPhotoHistory>> pendingHistories = {};
  final Map<String, ProgressPhotoSession> sessionsById = {};
  final List<int> requestedPages = [];
  final List<String> requestedSessionIds = [];
  final List<String> createdDates = [];

  @override
  Future<ProgressPhotoHistory> getHistory({int page = 1, int limit = 20}) {
    requestedPages.add(page);
    return pendingHistories[page]?.future ??
        pendingHistory?.future ??
        Future.value(histories[page] ?? ProgressPhotoHistory(
          sessions: history,
          total: history.length,
          page: page,
          limit: limit,
          totalPages: page == 1 && histories.isNotEmpty ? 2 : 1,
        ));
  }

  @override
  Future<ProgressPhotoSession> getSession(String id) async {
    requestedSessionIds.add(id);
    final explicit = sessionsById[id];
    if (explicit != null) return explicit;
    for (final session in [
      ...history,
      ...histories.values.expand((history) => history.sessions),
    ]) {
      if (session.id == id) return session;
    }
    throw StateError('Missing session $id');
  }

  @override
  Future<ProgressPhotoSession> createSession({required String civilDate, required String operationId}) async {
    createdDates.add(civilDate);
    final created = sessionFor('created-${createdDates.length}', civilDate);
    history = [created, ...history];
    return created;
  }

  @override
  Future<ProgressPhoto> associatePhoto({required String sessionId, required String uploadId, required String view, required String operationId, String? replacesPhotoId}) => throw UnimplementedError();

  @override
  Future<ManagedUploadResult> uploadPhoto(File file, String contentType, {required ManagedUploadContext context}) => throw UnimplementedError();
}

class FakeQueue implements ProgressPhotoQueue {
  List<Map<String, dynamic>> items = [];
  final List<QueueEnqueue> enqueues = [];
  final List<String> retried = [];
  final List<(String, String)> rebased = [];
  final List<String> discarded = [];
  @override
  List<Map<String, dynamic>> get pendingItems => items;
  @override
  Future<String> enqueue({required File file, required String civilSessionDate, required String canonicalView, required String contentType, String? resolvedSessionId, String? replacesPhotoId, String? expectedSession}) async {
    enqueues.add(QueueEnqueue(canonicalView, replacesPhotoId));
    return 'queued-${enqueues.length}';
  }
  @override
  Future<void> retry(String id) async => retried.add(id);
  @override
  Future<void> rebaseReplacement(String id, String activePhotoId) async => rebased.add((id, activePhotoId));
  @override
  Future<void> discard(String id) async => discarded.add(id);
}

class QueueEnqueue {
  const QueueEnqueue(this.view, this.replacesPhotoId);
  final String view;
  final String? replacesPhotoId;
}

class FakePickerIntentStore implements ProgressPhotoPickerIntentStore {
  FakePickerIntentStore([Map<String, dynamic>? current]) : _current = current;

  Map<String, dynamic>? _current;
  int clearCalls = 0;

  @override
  Map<String, dynamic>? get current => _current == null
      ? null
      : Map<String, dynamic>.from(_current!);

  @override
  Future<void> clear() async {
    clearCalls++;
    _current = null;
  }

  @override
  Future<void> save(Map<String, dynamic> intent) async {
    _current = Map<String, dynamic>.from(intent);
  }
}
