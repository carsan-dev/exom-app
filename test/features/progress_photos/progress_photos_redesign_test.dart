// L5-F1 «Fotos de progreso» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-F1;
// sketch f-resto.html, frames f1-lista, f1-origen, f1-visor, f1-vacio and
// f1-carga-error). Presentation only: the queue and the repository are the
// fakes of progress_photos_page_test.dart and every call into them is the
// same as before.
//
// The three interaction changes approved in L5-D21:
//   (1) «Nueva sesión» is a pinned footer with the lime button (no FAB), in
//       the list, empty, loading and error states;
//   (2) «Añadir» / «Sustituir» open a straight sheet (no AlertDialog) with the
//       view and date as kicker, «Cámara», «Galería» and «Cancelar»;
//   (3) no magnifier over the photos; tapping the photo still opens the viewer.
// Plus the skin: two-line headline, «Última sesión», numbered sessions, 3:4
// photos at column width, actions as 48 dp links, skeleton, inline error,
// empty state, and large text (CC 3).
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../core/widgets/expect_no_lime_ink.dart';
import 'progress_photos_page_test.dart' show FakeRepository;
import 'progress_photos_redesign_scene.dart';

const _newSession = Key('progress-photos-new-session');
const _footer = Key('progress-photos-footer');

Finder get _list => find.byKey(const Key('progress-photos-scroll'));

/// The scrollable of the page body (not the footer's own scroll view).
Finder get _bodyScrollable =>
    find.descendant(of: _list, matching: find.byType(Scrollable)).first;

Future<void> _openSheetFor(WidgetTester tester, String tooltip) async {
  final action = find.byTooltip(tooltip).first;
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('(1) «Nueva sesión» is a pinned footer, not a FAB', () {
    final states = <String, FakeRepository Function()>{
      'list': listRepository,
      'empty': FakeRepository.new,
      'loading': loadingRepository,
      'error': ErrorRepository.new,
    };
    for (final MapEntry(key: name, value: repository) in states.entries) {
      testWidgets('in the $name state', (tester) async {
        await pumpPhotosScene(tester, repository: repository());
        expect(find.byType(FloatingActionButton), findsNothing);
        final button = find.byKey(_newSession);
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: find.byType(ExomPinnedFooter), matching: button),
          findsOneWidget,
        );
        expect(find.descendant(of: _list, matching: button), findsNothing);
        expect(tester.widget<ExomPrimaryButton>(button).onPressed, isNotNull);
        expect(find.text('NUEVA SESIÓN'), findsOneWidget);
        // The only lime of the screen.
        expect(find.byType(ExomPrimaryButton), findsOneWidget);
      });
    }

    testWidgets('opens the date picker as the FAB did', (tester) async {
      await pumpPhotosScene(tester);
      await tester.tap(find.byKey(_newSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets(
      'stays put while the list scrolls and never covers «Cargar más» '
      '(320 dp, 1.6x Android)',
      (tester) async {
        await pumpPhotosScene(
          tester,
          width: 320,
          height: 640,
          textScaler: const AndroidNonlinearTextScaler(1.6),
        );
        final footerTop = tester.getTopLeft(find.byKey(_footer)).dy;
        await tester.scrollUntilVisible(
          find.text('Cargar más'),
          300,
          scrollable: _bodyScrollable,
        );
        await tester.drag(_bodyScrollable, const Offset(0, -2000));
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(_footer)).dy, footerTop);
        final loadMore = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Cargar más'),
        );
        expect(loadMore.bottom, lessThanOrEqualTo(footerTop));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('(2) the image source is a straight sheet', () {
    testWidgets('«Añadir» opens a sheet with kicker, title and three actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPhotosScene(tester);
      await _openSheetFor(tester, 'Añadir Espalda');
      expect(find.byType(AlertDialog), findsNothing);
      final panel = find.byKey(const Key('exom-sheet-panel'));
      expect(panel, findsOneWidget);
      Finder inSheet(Finder f) => find.descendant(of: panel, matching: f);
      expect(
        inSheet(find.widgetWithText(ExomKicker, 'ESPALDA · 18 NOV 2026')),
        findsOneWidget,
      );
      expect(
        inSheet(find.text('ELIGE EL ORIGEN DE LA IMAGEN')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Elige el origen de la imagen'),
        findsOneWidget,
      );
      expect(inSheet(find.text('CÁMARA')), findsOneWidget);
      expect(inSheet(find.text('GALERÍA')), findsOneWidget);
      expect(
        inSheet(find.widgetWithText(ExomQuietButton, 'Cancelar')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('«Sustituir» opens the same sheet', (tester) async {
      await pumpPhotosScene(tester);
      await _openSheetFor(tester, 'Sustituir Frontal');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
      expect(find.text('FRONTAL · 18 NOV 2026'), findsOneWidget);
    });

    testWidgets('choosing «Cámara» picks from the camera', (tester) async {
      final sources = <ImageSource>[];
      await pumpPhotosScene(
        tester,
        picker: (source) async {
          sources.add(source);
          return null;
        },
      );
      await _openSheetFor(tester, 'Añadir Espalda');
      await tester.tap(find.text('CÁMARA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sources, [ImageSource.camera]);
      expect(find.byKey(const Key('exom-sheet-panel')), findsNothing);
    });

    for (final how in ['Cancelar', 'tap outside', 'location change']) {
      testWidgets('$how closes it without choosing a source or queueing', (
        tester,
      ) async {
        final queue = listQueue();
        var picks = 0;
        final router = await pumpPhotosScene(
          tester,
          queue: queue,
          picker: (_) async {
            picks++;
            return null;
          },
        );
        await _openSheetFor(tester, 'Añadir Espalda');
        expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
        switch (how) {
          case 'Cancelar':
            await tester.tap(find.widgetWithText(ExomQuietButton, 'Cancelar'));
          case 'tap outside':
            await tester.tapAt(const Offset(20, 20));
          default:
            router.go('/other');
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('exom-sheet-panel')), findsNothing);
        expect(picks, 0);
        expect(queue.enqueues, isEmpty);
      });
    }
  });

  group('(3) no magnifier over the photos', () {
    testWidgets('no zoom icon; tapping the photo opens the viewer', (
      tester,
    ) async {
      await pumpPhotosScene(tester);
      expect(find.byIcon(ExomIcons.zoomIn), findsNothing);
      await tester.tap(find.byTooltip('Ampliar Frontal').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viewer = find.byKey(const Key('progress-photos-viewer'));
      expect(viewer, findsOneWidget);
      expect(
        find.descendant(of: viewer, matching: find.byType(InteractiveViewer)),
        findsOneWidget,
      );
      // Minimal bar: X of 48, the view in Barlow and the session date.
      final close = find.byTooltip('Cerrar imagen');
      final closeSize = tester.getSize(close);
      expect(closeSize.width, greaterThanOrEqualTo(48));
      expect(closeSize.height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: viewer, matching: find.text('FRONTAL')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: viewer, matching: find.text('18 nov 2026')),
        findsOneWidget,
      );
      expect(find.byType(AppBar), findsOneWidget); // only the page's bar
      await tester.tap(close);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(viewer, findsNothing);
    });
  });

  group('skin', () {
    testWidgets('list: headline, last session, numbered sessions, links', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPhotosScene(tester, height: 2400);
      expect(
        find.widgetWithText(ExomTwoLineHeadline, 'MIRA ATRÁS.'),
        findsOneWidget,
      );
      expect(find.text('SIGUE ADELANTE.'), findsOneWidget);
      expect(find.text('Última sesión: 18 nov 2026'), findsOneWidget);
      final headers = tester
          .widgetList<ExomNumberedSectionHeader>(
            find.byType(ExomNumberedSectionHeader),
          )
          .toList();
      expect(headers.map((h) => (h.n, h.title)), [
        (1, '18 nov 2026'),
        (2, '4 nov 2026'),
      ]);
      // Actions are text links with a 48 dp target and the full label.
      expect(find.byType(TextButton), findsNothing);
      final links = find.byType(ExomTextLink);
      expect(links, findsWidgets);
      for (final element in links.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
      expect(find.bySemanticsLabel('Añadir Espalda'), findsWidgets);
      expect(find.bySemanticsLabel('Sustituir Frontal'), findsWidgets);
      // «Añadir» carries the plus icon of the sketch; «Sustituir» none.
      expect(
        find.descendant(
          of: find.widgetWithText(ExomTextLink, 'Añadir').first,
          matching: find.byIcon(ExomIcons.add),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ExomTextLink, 'Sustituir').first,
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('photos are 3:4 at the full width of their column', (
      tester,
    ) async {
      await pumpPhotosScene(tester);
      final photo = find.byKey(const Key('progress-photo-s1-FRONT'));
      final size = tester.getSize(photo);
      expect(size.height / size.width, closeTo(4 / 3, 0.01));
      final column = tester.getSize(
        find.byKey(const Key('progress-photo-view-s1-FRONT')),
      );
      expect(size.width, column.width);
      // Two columns at 390 dp and 1.0x (sketch `.f-views`).
      final left = tester.getTopLeft(
        find.byKey(const Key('progress-photo-view-s1-FRONT')),
      );
      final right = tester.getTopLeft(
        find.byKey(const Key('progress-photo-view-s1-LEFT')),
      );
      expect(right.dy, left.dy);
      expect(right.dx, greaterThan(left.dx));
    });

    testWidgets('one column when the text grows (1.6x)', (tester) async {
      await pumpPhotosScene(tester, textScale: 1.6);
      final left = tester.getTopLeft(
        find.byKey(const Key('progress-photo-view-s1-FRONT')),
      );
      final right = tester.getTopLeft(
        find.byKey(const Key('progress-photo-view-s1-LEFT')),
      );
      expect(right.dx, left.dx);
      expect(right.dy, greaterThan(left.dy));
    });

    testWidgets('empty: two-line headline and the existing sentence', (
      tester,
    ) async {
      await pumpPhotosScene(tester, repository: FakeRepository());
      final empty = find.byType(ExomEmptyState);
      expect(empty, findsOneWidget);
      final widget = tester.widget<ExomEmptyState>(empty);
      expect((widget.first, widget.second), ('Sin fotos.', 'Todavía.'));
      expect(widget.body, 'Aún no hay sesiones de fotos de progreso');
      expect(find.textContaining('Última sesión'), findsNothing);
    });

    testWidgets('loading: skeleton with the current text as its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPhotosScene(tester, repository: loadingRepository());
      expect(find.byType(ExomSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.bySemanticsLabel('Cargando fotos de progreso'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('error: inline message with «Reintentar» that reloads', (
      tester,
    ) async {
      final repository = ErrorRepository();
      await pumpPhotosScene(tester, repository: repository);
      final message = find.byType(ExomInlineMessage);
      expect(message, findsOneWidget);
      final widget = tester.widget<ExomInlineMessage>(message);
      expect(widget.kind, ExomMessageKind.error);
      expect(widget.title, 'No se pudieron cargar las fotos de progreso');
      expect(widget.actionLabel, 'Reintentar');
      final before = repository.requestedPages.length;
      await tester.tap(find.widgetWithText(ExomTextLink, 'Reintentar'));
      await tester.pump();
      expect(repository.requestedPages.length, before + 1);
    });

    testWidgets('light theme: no lime ink', (tester) async {
      await pumpPhotosScene(tester, brightness: Brightness.light);
      expectNoLimeInk(tester);
    });
  });

  group('large text (CC 3)', () {
    const cases = [(320.0, 1.3), (320.0, 1.6), (360.0, 1.6)];
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in cases) {
        testWidgets(
          '${locale.languageCode} ${width.toInt()}dp ${scale}x Android: '
          'list and sheet without overflow',
          (tester) async {
            await pumpPhotosScene(
              tester,
              locale: locale,
              width: width,
              height: 640,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expect(tester.takeException(), isNull);
            // The source sheet, opened from the first session.
            await _openSheetFor(
              tester,
              locale.languageCode == 'es' ? 'Añadir Espalda' : 'Add Back',
            );
            expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(
              find.widgetWithText(
                ExomQuietButton,
                locale.languageCode == 'es' ? 'Cancelar' : 'Cancel',
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            // The whole list, step by step.
            for (var i = 0; i < 30; i++) {
              await tester.drag(_bodyScrollable, const Offset(0, -250));
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
            expect(find.byKey(_newSession), findsOneWidget);
          },
        );
      }
      for (final (name, repository) in <(String, FakeRepository Function())>[
        ('empty', FakeRepository.new),
        ('loading', loadingRepository),
        ('error', ErrorRepository.new),
      ]) {
        testWidgets(
          '${locale.languageCode} 320dp 1.6x Android: $name without overflow',
          (tester) async {
            await pumpPhotosScene(
              tester,
              repository: repository(),
              locale: locale,
              width: 320,
              height: 640,
              textScaler: const AndroidNonlinearTextScaler(1.6),
            );
            expect(tester.takeException(), isNull);
            expect(find.byKey(_newSession), findsOneWidget);
          },
        );
      }
    }

    testWidgets('2.0x: everything reachable by scrolling', (tester) async {
      await pumpPhotosScene(tester, width: 320, height: 640, textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Cargar más'),
        250,
        scrollable: _bodyScrollable,
        maxScrolls: 200,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_newSession), findsOneWidget);
    });
  });
}
