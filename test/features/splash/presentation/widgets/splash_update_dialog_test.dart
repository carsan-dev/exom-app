// L5-D3 · update notices (contract L5-D3, d-acceso.html «Arranque y
// actualización»): still dialogs, radius 4, a single lime action; when the
// store cannot be opened the error shows inside the dialog (it used to be a
// SnackBar behind it).
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/splash/presentation/widgets/splash_update_dialog.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long the dialog waits for the store before showing the error.
const _storeTimeout = Duration(seconds: 5);

Future<void> _open(
  WidgetTester tester, {
  required bool blocking,
  required Future<bool> Function() openStore,
  ValueChanged<bool?>? onResult,
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final result = await showSplashUpdateDialog(
                  context,
                  title: 'Actualización necesaria',
                  message: 'Actualiza la app para continuar.',
                  blocking: blocking,
                  openStore: openStore,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('blocking (${brightness.name}): one lime action, radius 4, '
        'store error inline', (tester) async {
      var attempts = 0;
      await _open(
        tester,
        blocking: true,
        brightness: brightness,
        openStore: () async {
          attempts++;
          return false;
        },
      );
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(4));
      expect(find.byType(ExomPrimaryButton), findsOneWidget);
      expect(find.byType(ExomTextLink), findsNothing);
      expect(
        find.text('No se pudo abrir la tienda de aplicaciones.'),
        findsNothing,
      );

      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      final inline = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ExomInlineMessage),
      );
      expect(inline, findsOneWidget);
      expect(
        tester.widget<ExomInlineMessage>(inline).kind,
        ExomMessageKind.error,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('No se pudo abrir la tienda de aplicaciones.'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      // The dialog stays (blocking) and «Actualizar» retries.
      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(AlertDialog), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }

  testWidgets('recommended: «Actualizar» lime, «Continuar» a quiet link; '
      'a failed store keeps the dialog with the error', (tester) async {
    bool? result;
    await _open(
      tester,
      blocking: false,
      openStore: () async => false,
      onResult: (value) => result = value,
    );
    expect(find.byType(ExomPrimaryButton), findsOneWidget);
    expect(find.byType(ExomTextLink), findsOneWidget);
    await tester.tap(find.byType(ExomPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(ExomInlineMessage), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.byType(ExomTextLink));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('recommended: an opened store closes the dialog and continues', (
    tester,
  ) async {
    bool? result;
    await _open(
      tester,
      blocking: false,
      openStore: () async => true,
      onResult: (value) => result = value,
    );
    await tester.tap(find.byType(ExomPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  // Review follow-up 3: a store that never answers must not trap the user.
  // The wait has a timeout; then the error shows inline and «Actualizar»
  // retries. A recommended update also keeps «Continuar» usable meanwhile.
  bool busy(WidgetTester tester) =>
      tester.widget<ExomPrimaryButton>(find.byType(ExomPrimaryButton)).busy;

  testWidgets('recommended: «Continuar» stays usable while the store is '
      'pending', (tester) async {
    bool? result;
    await _open(
      tester,
      blocking: false,
      openStore: () => Completer<bool>().future,
      onResult: (value) => result = value,
    );
    await tester.tap(find.byType(ExomPrimaryButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(busy(tester), isTrue);
    expect(
      tester.widget<ExomTextLink>(find.byType(ExomTextLink)).onTap,
      isNotNull,
    );
    await tester.tap(find.byType(ExomTextLink));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
    // The store wait times out later without touching the closed dialog.
    await tester.pump(_storeTimeout);
  });

  for (final blocking in const [false, true]) {
    final kind = blocking ? 'required' : 'recommended';
    testWidgets('$kind: a store that never answers times out, shows the '
        'error inline and can be retried', (tester) async {
      var attempts = 0;
      await _open(
        tester,
        blocking: blocking,
        openStore: () {
          attempts++;
          return Completer<bool>().future;
        },
      );
      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(attempts, 1);
      expect(busy(tester), isTrue);
      expect(find.byType(ExomInlineMessage), findsNothing);

      await tester.pump(_storeTimeout);
      await tester.pump();
      expect(busy(tester), isFalse);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('No se pudo abrir la tienda de aplicaciones.'),
        ),
        findsOneWidget,
      );
      if (!blocking) {
        expect(
          tester.widget<ExomTextLink>(find.byType(ExomTextLink)).onTap,
          isNotNull,
        );
      }

      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(attempts, 2);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pump(_storeTimeout);
      await tester.pump();
      expect(busy(tester), isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }
}
