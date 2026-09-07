import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../services/feedback_upload_queue_service_test.dart' as fixtures;
import 'feedback_progress_visibility_test.dart' as screen;

void main() {
  for (final locale in ['es', 'en']) {
    testWidgets(
      'offline history has friendly message and preserves queued retry in $locale',
      (tester) async {
        final repository = screen.ScreenRepository();
        final storage = screen.ScreenStorage([
          {'id': 'retained', 'status': 'queued', 'file_path': 'preserved.mp4'},
        ]);
        final queue = FeedbackUploadQueueService(
          repository,
          storage,
          fixtures.FakeOfflineSyncService(storage),
          isAuthenticated: () => false,
        );
        sl.registerSingleton<FeedbackUploadQueueService>(queue);
        sl.registerFactory<FeedbackBloc>(
          () => FeedbackBloc(
            getMyFeedbackUseCase: GetMyFeedbackUseCase(repository),
            createFeedbackUseCase: CreateFeedbackUseCase(repository),
            uploadFeedbackMediaUseCase: UploadFeedbackMediaUseCase(repository),
          ),
        );
        addTearDown(() async {
          await sl.reset();
          await queue.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: locale == 'es' ? AppTheme.light : AppTheme.dark,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FeedbackPage(),
          ),
        );
        await tester.pump();
        repository.history.completeError(
          DioException(
            requestOptions: RequestOptions(path: '/feedback/my'),
            type: DioExceptionType.connectionError,
            error: const SocketException('Failed host lookup: api.exom.test'),
            message:
                'The connection errored: Failed host lookup: api.exom.test',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(
            locale == 'es'
                ? 'Sin conexión a internet. Tus evidencias pendientes siguen guardadas.'
                : 'No internet connection. Your pending evidence is still saved.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Failed host lookup'), findsNothing);
        expect(
          find.text(locale == 'es' ? 'Reintentar' : 'Retry').hitTestable(),
          findsOneWidget,
        );
        expect(storage.queue.single, {
          'id': 'retained',
          'status': 'queued',
          'file_path': 'preserved.mp4',
        });
      },
    );
  }
  test('permission denial stays a server error rather than offline', () async {
    final repository = screen.ScreenRepository();
    final bloc = FeedbackBloc(
      getMyFeedbackUseCase: GetMyFeedbackUseCase(repository),
      createFeedbackUseCase: CreateFeedbackUseCase(repository),
      uploadFeedbackMediaUseCase: UploadFeedbackMediaUseCase(repository),
    );
    addTearDown(bloc.close);
    final failure = bloc.stream.firstWhere((state) => state is FeedbackError);
    bloc.add(const FeedbackLoadRequested());
    await Future<void>.delayed(Duration.zero);
    repository.history.completeError(
      const ApiException(statusCode: 403, message: 'Permission denied'),
    );
    final state = await failure as FeedbackError;
    expect(state.message, 'Permission denied');
  });
}
