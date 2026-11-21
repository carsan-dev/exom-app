// L5-C2 (D14-2, CC 11): «Elegir archivo» opens a straight EXOM sheet with the
// two sources as a numbered index; the sheet closes on a router location change
// without opening the picker.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class _Picks {
  final calls = <(ImageSource, bool)>[];
  final selected = <File>[];
  XFile? result;

  Future<XFile?> pick(ImageSource source, {required bool video}) async {
    calls.add((source, video));
    return result;
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Picks picks, {
  String mediaType = 'IMAGE',
  bool videoOnly = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: FeedbackMediaPicker(
              selectedFile: null,
              mediaType: mediaType,
              videoOnly: videoOnly,
              isUploading: false,
              onMediaTypeChanged: (_) {},
              onFileSelected: picks.selected.add,
              pick: picks.pick,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(FeedbackMediaPicker)));

void main() {
  testWidgets('choose file opens an EXOM sheet with a numbered index', (
    tester,
  ) async {
    final picks = _Picks()..result = XFile('picked.jpg');
    await _pump(tester, picks);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const Key('feedback-pick-file')));
    await tester.pumpAndSettle();
    final camera = find.text(l10n.feedbackFromCamera.toUpperCase());
    expect(camera, findsOneWidget);
    expect(ModalRoute.of(tester.element(camera)), isA<ExomSheetRoute<Object?>>());
    expect(
      find.descendant(
        of: find.byType(ExomIndexList),
        matching: find.text(l10n.feedbackFromGallery.toUpperCase()),
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text(l10n.feedbackFromGallery.toUpperCase()));
    await tester.pumpAndSettle();
    expect(picks.calls, [(ImageSource.gallery, false)]);
    expect(picks.selected.single.path, 'picked.jpg');
    expect(find.byType(ExomIndexList), findsNothing);
  });

  testWidgets('video mode picks a video from the chosen source', (
    tester,
  ) async {
    final picks = _Picks()..result = XFile('clip.mp4');
    await _pump(tester, picks, mediaType: 'VIDEO', videoOnly: true);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const Key('feedback-pick-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.feedbackFromCamera.toUpperCase()));
    await tester.pumpAndSettle();
    expect(picks.calls, [(ImageSource.camera, true)]);
    expect(picks.selected.single.path, 'clip.mp4');
  });

  testWidgets('cancel closes the sheet without picking', (tester) async {
    final picks = _Picks();
    await _pump(tester, picks);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const Key('feedback-pick-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(ExomIndexList), findsNothing);
    expect(picks.calls, isEmpty);
    expect(picks.selected, isEmpty);
  });

  testWidgets('sheet closes on a router location change without picking '
      '(CC 11)', (tester) async {
    final picks = _Picks()..result = XFile('never.jpg');
    final router = await _pump(tester, picks);
    await tester.tap(find.byKey(const Key('feedback-pick-file')));
    await tester.pumpAndSettle();
    expect(find.byType(ExomIndexList), findsOneWidget);
    router.go('/other');
    await tester.pumpAndSettle();
    expect(find.byType(ExomIndexList), findsNothing);
    expect(find.text('Otra'), findsOneWidget);
    expect(picks.calls, isEmpty);
    expect(picks.selected, isEmpty);
  });

  testWidgets('sheet closes when a route is pushed over the live page, and '
      'nothing is picked (CC 11)', (tester) async {
    final picks = _Picks()..result = XFile('never.jpg');
    final router = await _pump(tester, picks);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const Key('feedback-pick-file')));
    await tester.pumpAndSettle();
    final camera = find.textContaining(
      RegExp(l10n.feedbackFromCamera, caseSensitive: false),
      skipOffstage: false,
    );
    expect(camera, findsOneWidget);
    unawaited(router.push('/other'));
    await tester.pumpAndSettle();
    expect(find.text('Otra'), findsOneWidget);
    // The page is alive under the pushed route; its sheet is gone.
    expect(
      find.byType(FeedbackMediaPicker, skipOffstage: false),
      findsOneWidget,
    );
    expect(camera, findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackMediaPicker), findsOneWidget);
    expect(camera, findsNothing);
    expect(picks.calls, isEmpty);
    expect(picks.selected, isEmpty);
  });
}
