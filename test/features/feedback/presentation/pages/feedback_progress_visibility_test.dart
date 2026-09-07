import 'dart:async';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../services/feedback_upload_queue_service_test.dart';

class ScreenRepository extends FakeFeedbackRepository {
  final history = Completer<List<FeedbackEntity>>();
  @override
  Future<List<FeedbackEntity>> getMyFeedback() => history.future;
}

class ScreenStorage extends FakeFeedbackQueueStorage {
  ScreenStorage(super.queue);
  @override
  bool get hasUnattributedData => false;
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'upload progress stays visible while loading and scrolling in ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(400, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ScreenRepository();
        final storage = ScreenStorage([
          {'id': 'visible', 'status': 'uploading'},
        ]);
        final queue = FeedbackUploadQueueService(
          repo,
          storage,
          FakeOfflineSyncService(storage),
          isAuthenticated: () => false,
        );
        sl.registerSingleton<FeedbackUploadQueueService>(queue);
        sl.registerFactory<FeedbackBloc>(
          () => FeedbackBloc(
            getMyFeedbackUseCase: GetMyFeedbackUseCase(repo),
            createFeedbackUseCase: CreateFeedbackUseCase(repo),
            uploadFeedbackMediaUseCase: UploadFeedbackMediaUseCase(repo),
          ),
        );
        addTearDown(() async {
          await sl.reset();
          await queue.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FeedbackPage(),
          ),
        );
        await tester.pump();
        expect(find.byType(FeedbackUploadStatus).hitTestable(), findsOneWidget);
        repo.history.complete([]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final top = tester.getTopLeft(find.byType(FeedbackUploadStatus));
        expect(
          top.dy,
          lessThan(
            tester
                .getTopLeft(
                  find.widgetWithText(ElevatedButton, 'Enviar feedback'),
                )
                .dy,
          ),
        );
        // Drag the page margin so the notes field does not consume the gesture.
        await tester.dragFrom(
          tester.getTopRight(find.byType(ListView)) + const Offset(-4, 100),
          const Offset(0, -300),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .pixels,
          greaterThan(0),
        );
        expect(tester.getTopLeft(find.byType(FeedbackUploadStatus)), top);
        expect(
          find.byType(LinearProgressIndicator).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
