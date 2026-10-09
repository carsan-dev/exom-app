import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/pages/recap_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bloc/recap_bloc_test.dart'
    show RecapTestRepository, recapTestBloc, recapFixture;

Future<RecapBloc> pumpRecapDetail(
  WidgetTester tester,
  RecapTestRepository repository,
  LocalStorage storage,
) async {
  sl.registerSingleton<LocalStorage>(storage);
  final bloc = recapTestBloc(repository);
  sl.registerFactory<RecapBloc>(() => bloc);
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
  return bloc;
}

Future<RecapTestRepository> pumpRecapPage(
  WidgetTester tester, {
  Map<String, Object?> extra = const {},
}) async {
  final repository = RecapTestRepository();
  await pumpRecapDetail(tester, repository, LocalStorage());
  repository.details['A']!.complete(recapFixture(extra: extra));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return repository;
}

void main() {
  tearDown(() async => sl.reset());

  void expectSignedOutError(WidgetTester tester, RecapBloc bloc) {
    expect(bloc.state, isA<RecapDetailError>());
    expect(find.text('No se pudo cargar el recap'), findsOneWidget);
    expect(find.text('Inicia sesión para ver el recap.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(ShimmerCard), findsNothing);
    expect(find.text('Resumen del coach'), findsNothing);
    expect(find.textContaining('Resumen publicado'), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  testWidgets('signed-out detail and retries render a terminal safe error', (
    tester,
  ) async {
    final repository = RecapTestRepository();
    final bloc = await pumpRecapDetail(
      tester,
      repository,
      LocalStorage(currentSession: () => null),
    );
    await tester.pump();
    expectSignedOutError(tester, bloc);

    for (var retry = 0; retry < 2; retry++) {
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expectSignedOutError(tester, bloc);
    }
    expect(repository.details, isEmpty);
    expect(repository.sessionKeys, isEmpty);
    expect(repository.readCalls, isEmpty);
    expect(repository.writes, isEmpty);
  });

  testWidgets('signed-out request replaces previous recap and retries stay safe', (
    tester,
  ) async {
    LocalAuthSession? session = const LocalAuthSession(
      uid: 'synthetic-A',
      generation: 1,
    );
    final repository = RecapTestRepository();
    final bloc = await pumpRecapDetail(
      tester,
      repository,
      LocalStorage(currentSession: () => session),
    );
    repository.details['A']!.complete(recapFixture());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Resumen publicado A'), findsOneWidget);

    session = null;
    bloc.add(const RecapDetailRequested('A'));
    await tester.pump();
    await tester.pump();
    expectSignedOutError(tester, bloc);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expectSignedOutError(tester, bloc);
    expect(repository.details.keys, ['A']);
    expect(repository.sessionKeys, ['synthetic-A:1']);
    expect(repository.readCalls, isEmpty);
    expect(repository.writes, isEmpty);
  });

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
