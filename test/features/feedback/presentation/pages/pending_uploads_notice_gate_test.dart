import 'dart:async';

import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Queue extends Fake implements FeedbackUploadQueueService {
  @override
  Stream<FeedbackUploadNotice> get notices => const Stream.empty();
  @override
  List<Map<String, dynamic>> get pendingItems => [
        {'id': 'item-1', 'exercise_id': 'squat', 'status': 'failed'},
      ];
  @override
  FeedbackUploadNotice? progressOf(String id) => null;
}

class _Storage extends LocalStorage {
  @override
  String? get sessionStamp => 'owner:1:test';
}

class _Sync extends Fake implements OfflineSyncService {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  List<Map<String, dynamic>> get pendingActions => [];
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorage>(_Storage());
    sl.registerSingleton<FeedbackUploadQueueService>(_Queue());
    sl.registerSingleton<OfflineSyncService>(_Sync());
  });
  tearDown(() async => sl.reset());

  late GlobalKey<ScaffoldMessengerState> messengerKey;
  late GlobalKey<NavigatorState> navKey;

  Future<void> pumpApp(WidgetTester tester, {bool accessible = false}) async {
    if (accessible) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    messengerKey = GlobalKey<ScaffoldMessengerState>();
    navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('home')),
    ));
  }

  Future<void> openUploads(WidgetTester tester) async {
    unawaited(navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const PendingUploadsPage()),
    ));
    await tester.pumpAndSettle();
  }

  void notice(String message) => FeedbackNoticeSnackBars.show(
        messengerKey.currentState!,
        message: message,
      );

  testWidgets('no notice is shown while uploads page is the current route',
      (tester) async {
    await pumpApp(tester);
    await openUploads(tester);
    notice('failure');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('notice is shown outside the page and when another route is '
      'on top of it', (tester) async {
    await pumpApp(tester);
    notice('on home');
    await tester.pumpAndSettle();
    expect(find.text('on home'), findsOneWidget);
    messengerKey.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await openUploads(tester);
    unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('other route')),
    )));
    await tester.pumpAndSettle();
    notice('over other route');
    await tester.pumpAndSettle();
    expect(find.text('over other route'), findsOneWidget);
  });

  testWidgets('entering closes the open notice and the queued ones, not '
      'foreign SnackBars', (tester) async {
    await pumpApp(tester);
    notice('feedback 1');
    notice('feedback 2');
    messengerKey.currentState!.showSnackBar(
      const SnackBar(content: Text('foreign'), persist: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('feedback 1'), findsOneWidget);

    await openUploads(tester);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('feedback 1'), findsNothing);
    expect(find.text('feedback 2'), findsNothing);
    expect(find.text('foreign'), findsOneWidget);
  });

  testWidgets('no notice while the delete sheet opened from the page is on '
      'top', (tester) async {
    await pumpApp(tester);
    await openUploads(tester);
    await tester.tap(find.byKey(const Key('pending-delete-item-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending-delete-confirm')), findsOneWidget);
    notice('over sheet');
    await tester.pumpAndSettle();
    expect(find.text('over sheet'), findsNothing);
    await tester.tap(find.text(AppLocalizations.of(
      tester.element(find.byType(PendingUploadsPage)),
    ).cancel));
    await tester.pumpAndSettle();
    notice('after sheet');
    await tester.pumpAndSettle();
    expect(find.text('after sheet'), findsNothing);
  });

  testWidgets('entering with accessibleNavigation does not throw',
      (tester) async {
    await pumpApp(tester, accessible: true);
    notice('feedback 1');
    await tester.pumpAndSettle();
    await openUploads(tester);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('feedback 1'), findsNothing);
  });
}
