// L5-B3 «Ajustes» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-B3 and
// §3.0): D14-3 inline confirmations and errors next to the control (theme
// applied; a switch that fails goes back with its message, M8); D17-1 and
// L5-D29 confirmation sheets for «Borrar caché» (always, with the amber notice
// when a circuit is unfinished) and «Eliminar cuenta» (not dismissible, typed
// word); CC 11 (a sheet closes on a router location change without acting);
// the pending uploads counter read from the queue; the «solo visual» skin and
// the common criteria CC 3, CC 4 and D13 (no lime ink in light).
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/theme/wcag_contrast.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import '../../../challenges/challenges_test_support.dart'
    show expectNoBrokenWords, expectParagraphContrast, findTextCi;
import 'settings_scene.dart';

const _sheetPanel = Key('exom-sheet-panel');
const _clearCache = Key('settings-clear-cache');
const _clearConfirm = Key('settings-clear-cache-confirm');
const _clearCancel = Key('settings-clear-cache-cancel');
const _circuitWarning = Key('settings-clear-cache-circuit-warning');
const _deleteLink = Key('settings-delete-account');
const _deleteField = Key('settings-delete-account-field');
const _deleteConfirm = Key('settings-delete-account-confirm');
const _deleteCancel = Key('settings-delete-account-cancel');
const _credits = Key('settings-credits');
const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

Key _notice(String target) => ValueKey('settings-notice-$target');

/// Value painted by the square switch of the row keyed [rowKey].
bool _switchValue(WidgetTester tester, String rowKey) => tester
    .widget<ExomSquareSwitch>(
      find.descendant(
        of: find.byKey(Key(rowKey)),
        matching: find.byType(ExomSquareSwitch),
      ),
    )
    .value;

Future<void> _openClearCache(WidgetTester tester) async {
  await revealInSettings(tester, find.byKey(_clearCache));
  await tester.tap(find.byKey(_clearCache));
  await tester.pumpAndSettle();
}

Future<void> _openDeleteAccount(WidgetTester tester) async {
  await revealInSettings(tester, find.byKey(_deleteLink));
  await tester.tap(find.byKey(_deleteLink));
  await tester.pumpAndSettle();
}

Future<void> _openCredits(WidgetTester tester) async {
  await revealInSettings(tester, find.byKey(_credits));
  await tester.tap(find.byKey(_credits));
  await tester.pumpAndSettle();
}

/// Mocks the url_launcher channel so every launch answers [launched].
void _mockLauncher(WidgetTester tester, {required bool launched}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_urlChannel, (
    call,
  ) async {
    if (call.method == 'launch') return launched;
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _urlChannel,
      null,
    ),
  );
}

void main() {
  group('D14-3: inline confirmations next to the control', () {
    testWidgets('choosing «Oscuro» confirms in line under the theme control, '
        'without a SnackBar, in the text colour (D19)', (tester) async {
      await pumpSettingsScene(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('settings-theme-control')),
          matching: find.text('Oscuro'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final notice = find.byKey(_notice('theme'));
      expect(notice, findsOneWidget);
      final message = tester.widget<ExomInlineMessage>(notice);
      expect(message.kind, ExomMessageKind.ok);
      expect(message.title, 'Tema Oscuro aplicado');
      // A system confirmation: text colour with a check, never lime (D19).
      final icon = tester.widget<Icon>(
        find.descendant(of: notice, matching: find.byType(Icon)),
      );
      expect(
        icon.color,
        tester.element(notice).exomPalette.textPrimary,
      );
    });

    testWidgets('units and language confirm in line under their control', (
      tester,
    ) async {
      await pumpSettingsScene(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('settings-units-control')),
          matching: find.text('Imperial'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ExomInlineMessage>(find.byKey(_notice('units'))).title,
        'Unidades Imperial aplicadas',
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('settings-language-control')),
          matching: find.text('English'),
        ),
      );
      await tester.pumpAndSettle();
      // One message at a time: the last control touched.
      expect(find.byKey(_notice('units')), findsNothing);
      expect(find.byKey(_notice('language')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('M8: a switch answers at once and goes back if it fails', () {
    testWidgets('the reminder switch flips before the write ends, then goes '
        'back with the error next to its row', (tester) async {
      final scene = await pumpSettingsScene(tester);
      const row = 'settings-last-set-reminder-switch';
      scene.storage
        ..failingKeys.add('last_set_video_reminder_enabled')
        ..gate = Completer<void>();
      await revealInSettings(tester, find.byKey(const Key(row)));
      expect(_switchValue(tester, row), isTrue);

      await tester.tap(find.byKey(const Key(row)));
      await tester.pump();
      // Immediate response, before the write (< 100 ms).
      expect(_switchValue(tester, row), isFalse);

      scene.storage.gate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_switchValue(tester, row), isTrue);
      expect(
        scene.storage.settings.containsKey('last_set_video_reminder_enabled'),
        isFalse,
      );
      final notice = find.byKey(_notice('lastSetReminder'));
      expect(notice, findsOneWidget);
      final message = tester.widget<ExomInlineMessage>(notice);
      expect(message.kind, ExomMessageKind.error);
      expect(message.title, 'No se pudo desactivar. Sigue activado.');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('push notifications that cannot be turned off go back on, '
        'restore the preference and say so next to the row', (tester) async {
      // No Firebase app in tests: FirebaseMessaging fails after the save.
      final scene = await pumpSettingsScene(tester);
      const row = 'settings-push-switch';
      await revealInSettings(tester, find.byKey(const Key(row)));
      expect(_switchValue(tester, row), isTrue);

      await tester.tap(find.byKey(const Key(row)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_switchValue(tester, row), isTrue);
      expect(scene.storage.settings['push_notifications_enabled'], isTrue);
      final message = tester.widget<ExomInlineMessage>(
        find.byKey(_notice('push')),
      );
      expect(message.kind, ExomMessageKind.error);
      expect(
        message.title,
        'No se pudieron desactivar las notificaciones push. Sigue activado.',
      );
      // The row can be used again (not stuck busy).
      final switchRow = tester.widget<ExomSwitchRow>(find.byKey(const Key(row)));
      expect(switchRow.onChanged, isNotNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the reminder keeps its meaning: on = true, same key '
        '(L5-D23)', (tester) async {
      final storage = SceneStorage(uploads: sceneUploads());
      storage.settings['last_set_video_reminder_enabled'] = false;
      await pumpSettingsScene(tester, storage: storage);
      const row = 'settings-last-set-reminder-switch';
      await revealInSettings(tester, find.byKey(const Key(row)));
      expect(_switchValue(tester, row), isFalse);

      await tester.tap(find.byKey(const Key(row)));
      await tester.pumpAndSettle();

      expect(_switchValue(tester, row), isTrue);
      expect(storage.settings['last_set_video_reminder_enabled'], isTrue);
      expect(find.byKey(_notice('lastSetReminder')), findsNothing);
    });
  });

  group('L5-D29: «Borrar caché» always asks in a straight sheet', () {
    testWidgets('without an active circuit it opens the sheet and clears '
        'nothing until confirmed', (tester) async {
      final scene = await pumpSettingsScene(tester);
      await _openClearCache(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_sheetPanel), findsOneWidget);
      expect(findTextCi('¿Borrar la caché local?'), findsOneWidget);
      expect(
        find.text(
          'Se borrarán los datos guardados en este móvil para usar EXOM sin '
          'conexión. Volverán a descargarse cuando tengas conexión.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_circuitWarning), findsNothing);
      expect(scene.storage.clears, 0);

      await tester.tap(find.byKey(_clearConfirm));
      await tester.pumpAndSettle();

      expect(find.byKey(_sheetPanel), findsNothing);
      expect(scene.storage.clears, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<ExomInlineMessage>(find.byKey(_notice('clearCache'))).title,
        'Caché sin conexión borrada correctamente',
      );
    });

    testWidgets('with an unfinished circuit the sheet adds the amber notice', (
      tester,
    ) async {
      final storage = SceneStorage(activeCircuit: true);
      await pumpSettingsScene(tester, storage: storage);
      await _openClearCache(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_sheetPanel), findsOneWidget);
      final warning = tester.widget<ExomInlineMessage>(
        find.byKey(_circuitWarning),
      );
      expect(warning.kind, ExomMessageKind.pendiente);
      expect(
        warning.title,
        'Tienes un circuito sin terminar en este dispositivo. Si borras la '
        'caché, se perderá su progreso y no podrás retomarlo.',
      );
      expect(storage.clears, 0);
    });

    final dismissals = <String, Future<void> Function(WidgetTester)>{
      'Cancelar': (tester) => tester.tap(find.byKey(_clearCancel)),
      'tap outside': (tester) => tester.tapAt(const Offset(195, 20)),
      'drag down': (tester) => tester.drag(
        find.byKey(const Key('exom-sheet-handle')),
        const Offset(0, 600),
      ),
      'back': (tester) async {
        await tester.binding.handlePopRoute();
      },
    };
    for (final entry in dismissals.entries) {
      testWidgets('closing it with ${entry.key} clears nothing', (
        tester,
      ) async {
        final scene = await pumpSettingsScene(
          tester,
          storage: SceneStorage(activeCircuit: true),
        );
        await _openClearCache(tester);
        expect(find.byKey(_sheetPanel), findsOneWidget);

        await entry.value(tester);
        await tester.pumpAndSettle();

        expect(find.byKey(_sheetPanel), findsNothing);
        expect(scene.storage.clears, 0);
        expect(find.byKey(_notice('clearCache')), findsNothing);
      });
    }

    testWidgets('if the session changes while the sheet is open, confirming '
        'clears nothing', (tester) async {
      final scene = await pumpSettingsScene(
        tester,
        storage: SceneStorage(activeCircuit: true),
      );
      await _openClearCache(tester);
      scene.storage.stamp = 'uid-b:2:test';

      await tester.tap(find.byKey(_clearConfirm));
      await tester.pumpAndSettle();

      expect(scene.storage.clears, 0);
      expect(find.byKey(_notice('clearCache')), findsNothing);
    });
  });

  group('R14: «Eliminar cuenta» in a sheet that cannot be dismissed', () {
    testWidgets('opens as a sheet, not an AlertDialog, with the typed word; '
        '«Eliminar cuenta» stays disabled until the word matches', (
      tester,
    ) async {
      final scene = await pumpSettingsScene(tester);
      await _openDeleteAccount(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_sheetPanel), findsOneWidget);
      expect(findTextCi('¿Eliminar tu cuenta?'), findsOneWidget);
      ExomSecondaryButton confirm() =>
          tester.widget<ExomSecondaryButton>(find.byKey(_deleteConfirm));
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byKey(_deleteField), 'ELIMINA');
      await tester.pump();
      expect(confirm().onPressed, isNull);

      // Same rule as before: trimmed and compared upper case.
      await tester.enterText(find.byKey(_deleteField), ' eliminar ');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      await tester.tap(find.byKey(_deleteConfirm));
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsNothing);
      expect(scene.auth.events, hasLength(1));
      expect(scene.auth.events.single, isA<AuthAccountDeletionRequested>());
    });

    testWidgets('«Cancelar» closes it without deleting', (tester) async {
      final scene = await pumpSettingsScene(tester);
      await _openDeleteAccount(tester);
      await tester.tap(find.byKey(_deleteCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsNothing);
      expect(scene.auth.events, isEmpty);
    });

    testWidgets('tap outside, drag and back do not close it', (tester) async {
      final scene = await pumpSettingsScene(tester);
      await _openDeleteAccount(tester);

      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsOneWidget);

      await tester.drag(find.byKey(_sheetPanel), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsOneWidget);

      expect(
        tester.widget<ExomSecondaryButton>(find.byKey(_deleteConfirm)).onPressed,
        isNull,
      );
      expect(scene.auth.events, isEmpty);
    });

    testWidgets('a failed deletion is reported in line under the link', (
      tester,
    ) async {
      final scene = await pumpSettingsScene(tester);
      await revealInSettings(tester, find.byKey(_deleteLink));
      scene.auth.emitState(const AuthLoading());
      await tester.pump();
      scene.auth.emitState(const AuthError('boom'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final message = tester.widget<ExomInlineMessage>(
        find.byKey(_notice('deleteAccount')),
      );
      expect(message.kind, ExomMessageKind.error);
      expect(message.title, 'No se pudo eliminar la cuenta. Inténtalo de nuevo.');
    });

    testWidgets('the account-deleted SnackBar text is onError on the error '
        'background, not textPrimary', (tester) async {
      final scene = await pumpSettingsScene(tester);
      await revealInSettings(tester, find.byKey(_deleteLink));
      scene.auth.emitState(const AuthAccountDeleted());
      await tester.pumpAndSettle();

      final snackBar = find.byType(SnackBar);
      expect(snackBar, findsOneWidget);
      final context = tester.element(snackBar);
      final onError = Theme.of(context).colorScheme.onError;
      final background = context.exomPalette.error;
      final text = tester.widget<Text>(
        find.descendant(of: snackBar, matching: find.byType(Text)),
      );
      expect(text.style?.color, onError);
      expect(text.style?.color, isNot(context.exomPalette.textPrimary));
      expect(contrastRatio(onError, background), greaterThanOrEqualTo(4.5));
    });
  });

  group('CC 11: a sheet closes on a router location change without acting', () {
    testWidgets('«¿Borrar la caché local?»', (tester) async {
      final scene = await pumpSettingsScene(
        tester,
        storage: SceneStorage(activeCircuit: true),
      );
      await _openClearCache(tester);
      expect(find.byKey(_sheetPanel), findsOneWidget);

      scene.router.go('/other');
      await tester.pumpAndSettle();

      expect(find.byKey(_sheetPanel), findsNothing);
      expect(find.text('Otra'), findsOneWidget);
      expect(scene.storage.clears, 0);
    });

    testWidgets('«¿Eliminar tu cuenta?» (even though not dismissible)', (
      tester,
    ) async {
      final scene = await pumpSettingsScene(tester);
      await _openDeleteAccount(tester);
      await tester.enterText(find.byKey(_deleteField), 'ELIMINAR');
      await tester.pump();

      scene.router.go('/other');
      await tester.pumpAndSettle();

      expect(find.byKey(_sheetPanel), findsNothing);
      expect(scene.auth.events, isEmpty);
    });

    testWidgets('«Créditos»', (tester) async {
      final scene = await pumpSettingsScene(tester);
      await _openCredits(tester);
      expect(find.byKey(_sheetPanel), findsOneWidget);

      scene.router.go('/other');
      await tester.pumpAndSettle();

      expect(find.byKey(_sheetPanel), findsNothing);
    });
  });

  group('links that do not open say so in line', () {
    testWidgets('privacy policy: error under the group, with «Reintentar»', (
      tester,
    ) async {
      _mockLauncher(tester, launched: false);
      await pumpSettingsScene(tester);
      const row = Key('settings-privacy-policy');
      await revealInSettings(tester, find.byKey(row));
      await tester.tap(find.byKey(row));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final message = tester.widget<ExomInlineMessage>(
        find.byKey(_notice('links')),
      );
      expect(message.kind, ExomMessageKind.error);
      expect(message.actionLabel, 'Reintentar');
    });

    testWidgets('credits: the GitHub link error stays inside the sheet', (
      tester,
    ) async {
      _mockLauncher(tester, launched: false);
      await pumpSettingsScene(tester);
      await _openCredits(tester);
      await tester.tap(find.byKey(const Key('settings-credits-github')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_sheetPanel),
          matching: find.text('No se pudo abrir el perfil de GitHub.'),
        ),
        findsOneWidget,
      );
    });
  });

  group('«Subidas pendientes» counter (read only)', () {
    testWidgets('counts what the pending uploads page lists, in amber', (
      tester,
    ) async {
      final scene = await pumpSettingsScene(tester);
      final uploadsBefore = sceneUploads();
      const counter = Key('settings-pending-uploads-count');
      await revealInSettings(tester, find.byKey(counter));

      final status = tester.widget<ExomSyncStatus>(
        find.descendant(
          of: find.byKey(counter),
          matching: find.byType(ExomSyncStatus),
        ),
      );
      expect(status.state, ExomSyncState.pendiente);
      expect(status.label, '2');
      expect(scene.storage.queueReads, greaterThan(0));
      // Reading never rewrites the queue.
      expect(scene.storage.uploads, uploadsBefore);
    });

    testWidgets('does not count completed (nor dismissed) uploads: queued + '
        'failed + completed shows 2', (tester) async {
      await pumpSettingsScene(
        tester,
        storage: SceneStorage(
          uploads: [
            {'id': 'a', 'status': 'queued', 'media_type': 'VIDEO'},
            {'id': 'b', 'status': 'failed', 'media_type': 'VIDEO'},
            {'id': 'c', 'status': 'completed', 'media_type': 'VIDEO'},
            {
              'id': 'd',
              'status': 'completed',
              'media_type': 'VIDEO',
              'dismissed': true,
            },
          ],
        ),
      );
      const counter = Key('settings-pending-uploads-count');
      await revealInSettings(tester, find.byKey(counter));
      final status = tester.widget<ExomSyncStatus>(
        find.descendant(
          of: find.byKey(counter),
          matching: find.byType(ExomSyncStatus),
        ),
      );
      expect(status.label, '2');
    });

    testWidgets('no counter when only completed uploads remain', (
      tester,
    ) async {
      await pumpSettingsScene(
        tester,
        storage: SceneStorage(
          uploads: [
            {'id': 'c', 'status': 'completed', 'media_type': 'VIDEO'},
          ],
        ),
      );
      await revealInSettings(
        tester,
        find.byKey(const Key('settings-pending-uploads')),
      );
      expect(find.byKey(const Key('settings-pending-uploads-count')),
          findsNothing);
    });

    testWidgets('no counter when nothing is pending', (tester) async {
      await pumpSettingsScene(tester, storage: SceneStorage());
      await revealInSettings(
        tester,
        find.byKey(const Key('settings-pending-uploads')),
      );
      expect(find.byKey(const Key('settings-pending-uploads-count')),
          findsNothing);
    });
  });

  group('solo visual', () {
    testWidgets('segmented controls, square switches, numbered groups, '
        'secondary logout and a red delete link', (tester) async {
      await pumpSettingsScene(tester, height: 6000);

      expect(find.byType(ExomSegmentedControl<ThemeMode>), findsOneWidget);
      expect(find.byType(ExomSwitchRow), findsNWidgets(3));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ExomNumberedSectionHeader), findsNWidgets(6));
      expect(
        find.byWidgetPredicate(
          (w) => w is ExomSecondaryButton && w.label == 'Cerrar sesión',
        ),
        findsOneWidget,
      );
      final link = tester.widget<ExomTextLink>(find.byKey(_deleteLink));
      expect(link.danger, isTrue);
      expect(link.label, 'Eliminar cuenta');
      expect(find.byType(Card), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('large text (CC 3)', () {
    for (final (width, scale) in const [
      (320.0, 1.3),
      (320.0, 1.6),
      (360.0, 1.6),
    ]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('es'), Locale('en')]) {
          testWidgets('no overflow nor broken words: ${width.toInt()} dp, '
              '$scale, ${brightness.name}, ${locale.languageCode}', (
            tester,
          ) async {
            await pumpSettingsScene(
              tester,
              width: width,
              height: 7000,
              brightness: brightness,
              locale: locale,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expect(tester.takeException(), isNull);
            expectNoBrokenWords(tester);
          });
        }
      }
    }

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('sheets at 320 dp and 1.6, ${locale.languageCode}', (
        tester,
      ) async {
        await pumpSettingsScene(
          tester,
          storage: SceneStorage(activeCircuit: true),
          width: 320,
          height: 700,
          locale: locale,
          textScaler: const AndroidNonlinearTextScaler(1.6),
        );
        await _openClearCache(tester);
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
        await tester.tap(find.byKey(_clearCancel));
        await tester.pumpAndSettle();
        await _openDeleteAccount(tester);
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
      });
    }

    testWidgets('2.0x on a 360 dp screen scrolls to the end', (tester) async {
      await pumpSettingsScene(
        tester,
        width: 360,
        height: 780,
        textScaler: const AndroidNonlinearTextScaler(2.0),
      );
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(_deleteLink), 400,
          scrollable: list);
      await tester.drag(list, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byKey(_deleteLink).hitTestable(), findsOneWidget);
    });
  });

  group('themes and accessibility (CC 4, D13)', () {
    for (final brightness in Brightness.values) {
      testWidgets('page guidelines, ${brightness.name}', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSettingsScene(tester, brightness: brightness);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        tester.view.physicalSize = const Size(390, 6000);
        await tester.pumpAndSettle();
        // Text by identity on the rows, headers, link and button. The
        // segmented controls are left to textContrastGuideline above and to
        // their component test: the selected label sits on a sliding fill
        // that is not its ancestor, which this helper cannot see.
        final background = tester
            .element(find.byType(Scaffold).first)
            .exomPalette
            .background;
        for (final scope in [
          find.byType(ExomRowSurface),
          find.byType(ExomNumberedSectionHeader),
          find.byType(ExomTextLink),
          find.byType(ExomSecondaryButton),
        ]) {
          expectParagraphContrast(tester, scope, fallback: background);
        }
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        semantics.dispose();
      });

      testWidgets('sheets: tap targets, contrast and lime, ${brightness.name}',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSettingsScene(
          tester,
          brightness: brightness,
          storage: SceneStorage(activeCircuit: true),
        );
        await _openClearCache(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expectParagraphContrast(
          tester,
          find.byKey(_sheetPanel),
          fallback: tester.element(find.byKey(_sheetPanel)).exomPalette.surface,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await tester.tap(find.byKey(_clearCancel));
        await tester.pumpAndSettle();

        await _openDeleteAccount(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expectParagraphContrast(
          tester,
          find.byKey(_sheetPanel),
          fallback: tester.element(find.byKey(_sheetPanel)).exomPalette.surface,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        semantics.dispose();
      });
    }
  });
}
