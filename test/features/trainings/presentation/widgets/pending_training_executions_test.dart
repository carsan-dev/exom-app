import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/models/training_execution_discard.dart';
import 'package:exom_app/features/trainings/presentation/widgets/pending_training_executions.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingStorage extends LocalStorage {
  String owner = 'owner-A';
  String stamp = 'owner-A:1';
  final entries = <Map<String, dynamic>>[
    {'id': 'full-session-123456789', 'training_id': 'strength',
      'training_name': 'Fuerza', 'assignment_date': '2026-09-05', 'status': 'conflict'},
    {'id': 'other-session', 'training_id': 'strength',
      'training_name': 'Fuerza', 'assignment_date': '2026-09-05', 'status': 'pending-sync'},
  ];
  @override
  String? get ownerId => owner;
  @override
  String? get sessionStamp => stamp;
  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() => entries;
}

class DiscardHarness {
  final storage = PendingStorage();
  final inspected = <TrainingExecutionDiscardRequest>[];
  final discarded = <TrainingExecutionDiscardRequest>[];
  TrainingExecutionDiscardReason inspection = TrainingExecutionDiscardReason.eligible;
  TrainingExecutionDiscardReason outcome = TrainingExecutionDiscardReason.discarded;

  Widget app({Brightness brightness = Brightness.light}) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: PendingTrainingExecutions(
      storage: storage,
      onSelect: (_, _) {},
      inspectDiscard: (request) {
        inspected.add(request);
        return TrainingExecutionDiscardResult(inspection);
      },
      discard: (request) async {
        discarded.add(request);
        if (outcome == TrainingExecutionDiscardReason.discarded) {
          storage.entries.removeWhere((entry) => entry['id'] == request.executionId);
        }
        return TrainingExecutionDiscardResult(outcome);
      },
    ))),
  );
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pending-discard-full-session-123456789')));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('confirmation identifies exact session; cancel does nothing ($brightness)', (tester) async {
      final h = DiscardHarness();
      await tester.pumpWidget(h.app(brightness: brightness));
      await tester.pumpAndSettle();
      expect(h.inspected, isEmpty, reason: 'render does not inspect, sync or discard');
      await openDialog(tester);
      expect(find.text('Entrenamiento: Fuerza\nFecha: 2026-09-05\nID de sesión: full-session-123456789'), findsOneWidget);
      expect(find.textContaining('cierre pendiente, RPE y nota no se enviarán'), findsOneWidget);
      expect(find.textContaining('no es un borrado físico permanente'), findsOneWidget);
      expect(h.discarded, isEmpty);
      await tester.tap(find.byKey(const Key('pending-discard-cancel')));
      await tester.pumpAndSettle();
      expect(h.discarded, isEmpty);
      expect(h.storage.entries, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirmation submits captured identity and only target disappears', (tester) async {
    final h = DiscardHarness();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await openDialog(tester);
    h.storage.entries.first['training_id'] = 'mutated-after-inspection';
    await tester.tap(find.byKey(const Key('pending-discard-confirm')));
    await tester.pumpAndSettle();
    final request = h.discarded.single;
    expect(identical(request, h.inspected.single), isTrue);
    expect((request.ownerId, request.sessionStamp, request.executionId, request.trainingId, request.date),
      ('owner-A', 'owner-A:1', 'full-session-123456789', 'strength', '2026-09-05'));
    expect(find.byKey(const Key('pending-discard-full-session-123456789')), findsNothing);
    expect(find.byKey(const Key('pending-discard-other-session')), findsOneWidget);
    expect(find.textContaining('Sesión local descartada'), findsOneWidget);
  });

  for (final reason in [TrainingExecutionDiscardReason.inFlight,
      TrainingExecutionDiscardReason.unsentDependencies,
      TrainingExecutionDiscardReason.unknownOwnership,
      TrainingExecutionDiscardReason.confirmed]) {
    testWidgets('typed inspection refuses $reason without confirmation or mutation', (tester) async {
      final h = DiscardHarness()..inspection = reason;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await openDialog(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('No se puede descartar'), findsOneWidget);
      expect(h.discarded, isEmpty);
      expect(h.storage.entries, hasLength(2));
    });
  }

  for (final switchOwner in [true, false]) {
    testWidgets('account/session change during confirmation fails safely ($switchOwner)', (tester) async {
      final h = DiscardHarness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await openDialog(tester);
      if (switchOwner) h.storage.owner = 'owner-B';
      h.storage.stamp = 'new-generation';
      await tester.tap(find.byKey(const Key('pending-discard-confirm')));
      await tester.pumpAndSettle();
      expect(h.discarded, isEmpty);
      expect(find.textContaining('ha cambiado la cuenta o la sesión'), findsOneWidget);
      expect(h.storage.entries, hasLength(2));
    });
  }

  for (final reason in [TrainingExecutionDiscardReason.identityMismatch,
      TrainingExecutionDiscardReason.inFlight,
      TrainingExecutionDiscardReason.unsentDependencies,
      TrainingExecutionDiscardReason.staleSession,
      TrainingExecutionDiscardReason.storageFailure]) {
    testWidgets('command recheck race $reason shows message and retains both cards', (tester) async {
      final h = DiscardHarness()..outcome = reason;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('pending-discard-confirm')));
      await tester.pumpAndSettle();
      expect(h.discarded, hasLength(1));
      expect(identical(h.inspected.single, h.discarded.single), isTrue);
      expect(find.byKey(const Key('pending-discard-result')), findsOneWidget);
      expect(find.byKey(const Key('pending-discard-full-session-123456789')), findsOneWidget);
      expect(find.byKey(const Key('pending-discard-other-session')), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  }

  testWidgets('conflict card identifies full session and offers scoped discard', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PendingTrainingExecutions(
        storage: PendingStorage(), onSelect: (_, _) {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('full-session-123456789'), findsOneWidget);
    expect(find.byKey(const Key('pending-discard-full-session-123456789')), findsOneWidget);
  });
}
