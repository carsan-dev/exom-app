import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _es = {
  ExomSyncState.guardadaEnMovil: 'Guardada en este móvil',
  ExomSyncState.pendiente: 'Pendiente de sincronizar',
  ExomSyncState.enviando: 'Enviando',
  ExomSyncState.confirmada: 'Confirmada',
  ExomSyncState.fallida: 'No se pudo sincronizar',
};

const _en = {
  ExomSyncState.guardadaEnMovil: 'Saved on this phone',
  ExomSyncState.pendiente: 'Waiting to sync',
  ExomSyncState.enviando: 'Sending',
  ExomSyncState.confirmada: 'Confirmed',
  ExomSyncState.fallida: 'Could not sync',
};

const _icons = {
  ExomSyncState.guardadaEnMovil: ExomIcons.phone,
  ExomSyncState.pendiente: ExomIcons.time,
  ExomSyncState.enviando: ExomIcons.upload,
  ExomSyncState.confirmada: ExomIcons.check,
  ExomSyncState.fallida: ExomIcons.error,
};

Widget _all() => Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final state in ExomSyncState.values)
        ExomSyncStatus(key: ValueKey(state), state: state),
    ],
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('icon + text + token colour per state (${brightness.name})', (
      tester,
    ) async {
      await pumpComponent(tester, _all(), brightness: brightness);
      final theme = themeFor(brightness);
      final palette = theme.extension<ExomThemePalette>()!;
      final semantic = theme.extension<ExomSemanticPalette>()!;
      final expectedColour = {
        ExomSyncState.guardadaEnMovil: palette.textSecondary,
        ExomSyncState.pendiente: semantic.warning,
        ExomSyncState.enviando: palette.textSecondary,
        ExomSyncState.confirmada: palette.textPrimary,
        ExomSyncState.fallida: palette.error,
      };
      for (final state in ExomSyncState.values) {
        final scope = find.byKey(ValueKey(state));
        final text = tester.widget<Text>(
          find.descendant(of: scope, matching: find.text(_es[state]!)),
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: scope, matching: find.byType(Icon)),
        );
        expect(icon.icon, _icons[state], reason: '$state never colour alone');
        expect(text.style?.color, expectedColour[state], reason: '$state');
        expect(icon.color, expectedColour[state], reason: '$state');
      }
      // The five states stay distinguishable without colour: five distinct
      // icons and five distinct texts.
      expect(_icons.values.toSet().length, ExomSyncState.values.length);
      expect(_es.values.toSet().length, ExomSyncState.values.length);
      // Confirmed is never lime (plan §6).
      final confirmed = tester.widget<Text>(find.text('Confirmada'));
      expect(confirmed.style?.color, isNot(AppColors.primary));
      expect(confirmed.style?.color, isNot(palette.primary));
    });
  }

  testWidgets('English strings', (tester) async {
    await pumpComponent(tester, _all(), locale: const Locale('en'));
    for (final text in _en.values) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('semantics label is the status text', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(tester, _all());
    expect(find.bySemanticsLabel('Pendiente de sincronizar'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wraps at 320 dp and 1.6x without overflow', (tester) async {
    await pumpComponent(tester, _all(), width: 320, textScale: 1.6);
    expectNoOverflow(tester);
  });
}
