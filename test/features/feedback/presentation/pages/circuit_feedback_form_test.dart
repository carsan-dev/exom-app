import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targets = [
    FeedbackExerciseTarget(
      key: 'training-exercise-1',
      exerciseId: 'exercise-1',
      exerciseName: 'Sentadilla',
    ),
    FeedbackExerciseTarget(
      key: 'training-exercise-2',
      exerciseId: 'exercise-2',
      exerciseName: 'Remo',
    ),
  ];

  Widget buildSubject({
    required CircuitFeedbackEnqueue enqueue,
    VoidCallback? onQueued,
  }) {
    return MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CircuitFeedbackForm(
            circuitName: 'Circuito A',
            targets: targets,
            enqueue: enqueue,
            onQueued: onQueued,
          ),
        ),
      ),
    );
  }

  testWidgets('queues one video and note for every selected exercise', (
    tester,
  ) async {
    final uploads = <CircuitFeedbackUpload>[];
    var queued = false;
    await tester.pumpWidget(
      buildSubject(
        enqueue: (upload) async => uploads.add(upload),
        onQueued: () => queued = true,
      ),
    );
    await tester.pumpAndSettle();

    final disabledButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('send-circuit-feedback')),
    );
    expect(disabledButton.onPressed, isNull);

    final pickers = tester
        .widgetList<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
        .toList();
    pickers[0].onFileSelected(File('sentadilla.mp4'));
    pickers[1].onFileSelected(File('remo.mov'));
    await tester.pump();

    final notes = find.byType(TextFormField);
    await tester.enterText(notes.at(0), 'Vista lateral');
    await tester.enterText(notes.at(1), 'Última serie');
    await tester.ensureVisible(
      find.byKey(const ValueKey('send-circuit-feedback')),
    );
    await tester.tap(find.byKey(const ValueKey('send-circuit-feedback')));
    await tester.pumpAndSettle();

    expect(uploads, hasLength(2));
    expect(uploads[0].target.exerciseId, 'exercise-1');
    expect(uploads[0].notes, 'Vista lateral');
    expect(uploads[1].target.exerciseId, 'exercise-2');
    expect(uploads[1].notes, 'Última serie');
    expect(queued, isTrue);
  });

  testWidgets('keeps failed exercise selected after partial queue failure', (
    tester,
  ) async {
    final uploads = <CircuitFeedbackUpload>[];
    await tester.pumpWidget(
      buildSubject(
        enqueue: (upload) async {
          uploads.add(upload);
          if (upload.target.exerciseId == 'exercise-2') {
            throw Exception('copy failed');
          }
        },
      ),
    );
    await tester.pumpAndSettle();

    final pickers = tester
        .widgetList<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
        .toList();
    pickers[0].onFileSelected(File('sentadilla.mp4'));
    pickers[1].onFileSelected(File('remo.mp4'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('send-circuit-feedback')),
    );
    await tester.tap(find.byKey(const ValueKey('send-circuit-feedback')));
    await tester.pumpAndSettle();

    final updatedPickers = tester
        .widgetList<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
        .toList();
    expect(uploads, hasLength(2));
    expect(updatedPickers[0].selectedFile, isNull);
    expect(updatedPickers[1].selectedFile?.path, 'remo.mp4');
    expect(find.text('No se pudo subir el feedback.'), findsOneWidget);
  });
}
