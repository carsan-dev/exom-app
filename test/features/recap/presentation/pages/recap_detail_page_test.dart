import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/pages/recap_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bloc/recap_bloc_test.dart'
    show RecapTestRepository, recapTestBloc, recapFixture;

Future<RecapTestRepository> pumpRecapPage(
  WidgetTester tester, {
  Map<String, Object?> extra = const {},
}) async {
  final repository = RecapTestRepository();
  sl.registerSingleton<LocalStorage>(LocalStorage());
  sl.registerFactory<RecapBloc>(() => recapTestBloc(repository));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const RecapDetailPage(recapId: 'A'),
    ),
  );
  await tester.pump();
  repository.details['A']!.complete(recapFixture(extra: extra));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return repository;
}

void main() {
  tearDown(() async => sl.reset());
  testWidgets(
    'publication only is visible and never marks legacy feedback read',
    (tester) async {
      final repository = await pumpRecapPage(tester);
      expect(find.text('Resumen del coach'), findsOneWidget);
      expect(find.text('Resumen publicado A'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(repository.readCalls, isEmpty);
      expect(find.text('Comentario de tu entrenador'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'publication remains visible across independent legacy read update',
    (tester) async {
      final repository = await pumpRecapPage(
        tester,
        extra: {
          'client_feedback_text': 'Legacy con publicación',
          'published_changes': 'Cambios confirmados',
        },
      );
      expect(find.text('Resumen publicado A'), findsOneWidget);
      expect(repository.readCalls, ['A']);
      repository.readResult.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Resumen publicado A'), findsOneWidget);
      expect(find.text('Cambios confirmados'), findsOneWidget);
      expect(repository.readCalls, ['A']);
      expect(find.textContaining('PRIVATE'), findsNothing);
    },
  );

  testWidgets('unread legacy feedback still marks read once independently', (
    tester,
  ) async {
    final repository = await pumpRecapPage(
      tester,
      extra: {
        'client_feedback_text': 'Comentario legacy',
        'published_coach_summary': null,
      },
    );
    expect(find.text('Comentario legacy'), findsOneWidget);
    expect(repository.readCalls, ['A']);
    repository.readResult.complete();
    await tester.pump();
    await tester.pump();
    expect(repository.readCalls, ['A']);
    expect(find.text('Resumen del coach'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
