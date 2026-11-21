// L4 unit 2: Fotos de progreso on the V4 system. The six upload states of plan
// §6 must be told apart without colour (icon + distinct text + semantics) and
// no text may be smaller than 13 logical px. Presentation only: the queue and
// the repository are the fakes of progress_photos_page_test.dart.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/presentation/pages/progress_photos_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progress_photos_page_test.dart'
    show FakeQueue, FakeRepository, pending, photo, sessionFor;

/// state -> (view, session, expected icon). One tile per state.
typedef _Expected = ({String session, String view, IconData icon});

const _expected = <String, _Expected>{
  'pending': (session: 's1', view: 'FRONT', icon: ExomIcons.time),
  'synchronizing': (
    session: 's1',
    view: 'LEFT',
    icon: ExomIcons.syncing,
  ),
  'confirmed': (session: 's1', view: 'RIGHT', icon: ExomIcons.check),
  'cleanupPending': (
    session: 's1',
    view: 'BACK',
    icon: ExomIcons.cleaning,
  ),
  'failed': (session: 's2', view: 'FRONT', icon: ExomIcons.error),
  'conflict': (session: 's2', view: 'LEFT', icon: ExomIcons.syncProblem),
};

Key _statusKey(String session, String view) =>
    Key('upload-status-$session-$view');

List<String> _labels(AppLocalizations l10n) => [
  l10n.progressPhotosPending,
  l10n.progressPhotosSynchronizing,
  l10n.progressPhotosConfirmed,
  l10n.progressPhotosConfirmedCleanup,
  l10n.progressPhotosFailed,
  l10n.progressPhotosConflict,
];

/// Every painted text run with its effective font size. Icon glyphs are not
/// text and are skipped.
List<({String text, double size})> _textRuns(WidgetTester tester) {
  final runs = <({String text, double size})>[];
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        final text = span.text;
        final isIcon =
            (style?.fontFamily?.contains('MaterialIcons') ?? false) ||
            (style?.fontFamily?.contains('Lucide') ?? false);
        if (text != null && text.trim().isNotEmpty && !isIcon) {
          runs.add((text: text, size: style?.fontSize ?? 14.0));
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    visit(richText.text, null);
  }
  return runs;
}

void _expectNoTextBelow13(WidgetTester tester) {
  final runs = _textRuns(tester);
  expect(runs, isNotEmpty);
  final small = runs.where((run) => run.size < 13).toList();
  expect(
    small,
    isEmpty,
    reason:
        'text below 13 logical px: ${small.map((r) => '"${r.text}" ${r.size}').join(', ')}',
  );
}

void main() {
  late Directory cacheDirectory;
  late FakeRepository repository;
  late FakeQueue queue;

  setUp(() {
    cacheDirectory = Directory.systemTemp.createTempSync('progress-states-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cacheDirectory.path,
        );
    repository = FakeRepository()
      ..history = [
        sessionFor('s1', '2026-11-04'),
        sessionFor('s2', '2026-10-21', photos: [photo('s2-left', 'LEFT')]),
      ];
    queue = FakeQueue()
      ..items = [
        pending('p-pending', 's1', 'FRONT', 'queued'),
        pending('p-sync', 's1', 'LEFT', 'processing'),
        pending('p-ok', 's1', 'RIGHT', 'completed'),
        pending('p-clean', 's1', 'BACK', 'completed', cleanupPending: true),
        pending('p-failed', 's2', 'FRONT', 'failed', error: 'network'),
        pending(
          'p-conflict',
          's2',
          'LEFT',
          'failed',
          error: 'STALE_REPLACEMENT',
        ),
      ];
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 2400),
    double textScale = 1.0,
    ThemeData? theme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ProgressPhotosPage(
          repository: repository,
          queue: queue,
          sessionStamp: () => 'account-a:1',
          queuePollInterval: null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ProgressPhotosPage)));

  group('text size floor (13 px)', () {
    testWidgets('all six upload states, dark theme', (tester) async {
      await mount(tester);
      expect(tester.takeException(), isNull);
      _expectNoTextBelow13(tester);
    });

    testWidgets('all six upload states, light theme', (tester) async {
      await mount(tester, theme: AppTheme.light);
      _expectNoTextBelow13(tester);
    });

    testWidgets('empty history', (tester) async {
      repository.history = const [];
      queue.items = [];
      await mount(tester);
      expect(find.text(l10n(tester).progressPhotosEmpty), findsOneWidget);
      _expectNoTextBelow13(tester);
    });

    testWidgets('load error', (tester) async {
      final failing = Completer<ProgressPhotoHistory>();
      repository.pendingHistory = failing;
      await mount(tester);
      failing.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n(tester).progressPhotosLoadError), findsOneWidget);
      _expectNoTextBelow13(tester);
    });

    testWidgets('320 dp wide at 1.3x text keeps states readable', (
      tester,
    ) async {
      await mount(tester, size: const Size(320, 3200), textScale: 1.3);
      expect(tester.takeException(), isNull);
      _expectNoTextBelow13(tester);
    });
  });

  group('upload states without colour', () {
    testWidgets('each state shows its own icon and its own text', (
      tester,
    ) async {
      await mount(tester);
      final text = l10n(tester);
      final labels = _labels(text);
      expect(labels.toSet(), hasLength(6), reason: 'labels must differ');
      final icons = _expected.values.map((e) => e.icon).toSet();
      expect(icons, hasLength(6), reason: 'icons must differ');

      final byState = {
        'pending': text.progressPhotosPending,
        'synchronizing': text.progressPhotosSynchronizing,
        'confirmed': text.progressPhotosConfirmed,
        'cleanupPending': text.progressPhotosConfirmedCleanup,
        'failed': text.progressPhotosFailed,
        'conflict': text.progressPhotosConflict,
      };
      for (final entry in _expected.entries) {
        final status = find.byKey(
          _statusKey(entry.value.session, entry.value.view),
        );
        expect(status, findsOneWidget, reason: 'status of ${entry.key}');
        expect(
          find.descendant(of: status, matching: find.byIcon(entry.value.icon)),
          findsOneWidget,
          reason: 'icon of ${entry.key}',
        );
        expect(
          find.descendant(of: status, matching: find.text(byState[entry.key]!)),
          findsOneWidget,
          reason: 'text of ${entry.key}',
        );
      }
    });

    testWidgets('each state is announced by its own semantics label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      for (final label in _labels(l10n(tester))) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'semantics label "$label"',
        );
      }
      semantics.dispose();
    });

    testWidgets('a tile without queue item shows no upload status', (
      tester,
    ) async {
      await mount(tester);
      expect(find.byKey(_statusKey('s2', 'RIGHT')), findsNothing);
      expect(find.byKey(_statusKey('s2', 'BACK')), findsNothing);
    });
  });
}
