// Redesign L5 component goldens of T0.3b (docs/plans/rediseno-app-l5-contrato-v2.md,
// sections 2.1 and 5.3): scene componentes_mensajes in dark and light at text
// scale 1.0 and 1.6 on a 390x1400 surface (taller than the L0 baseline so the
// whole scene is visible). Skeletons are
// painted static (reduced motion), so the image does not depend on the pulse.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/components_messages_golden_test.dart
//
// Scene componentes_mensajes: ExomCoachBlock, ExomReplyBlock,
// ExomInlineMessage (the four kinds), ExomTextLink (normal and danger),
// ExomEmptyState and ExomSkeleton (numeral, headline, rule, row).
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

/// Fixed fictitious data; nothing here depends on the clock.
Widget _componentesMensajes() {
  const gap = SizedBox(height: 16);
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExomCoachBlock(
          text: 'Buen trabajo esta semana. Sube un poco el peso.',
          author: 'Marta Ruiz',
          time: 'hace 2 h',
        ),
        gap,
        const Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: ExomReplyBlock(
            text: 'Revisa la técnica de la sentadilla.',
            author: 'Tu entrenador',
            time: 'ayer',
          ),
        ),
        gap,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExomInlineMessage(
                kind: ExomMessageKind.error,
                title: 'No se pudo guardar',
                body: 'Comprueba la conexión.',
                actionLabel: 'Reintentar',
                onAction: () {},
              ),
              const SizedBox(height: 8),
              const ExomInlineMessage(
                kind: ExomMessageKind.pendiente,
                title: 'Subida pendiente',
              ),
              const SizedBox(height: 8),
              const ExomInlineMessage(
                kind: ExomMessageKind.ok,
                title: 'Guardado',
              ),
              const SizedBox(height: 8),
              const ExomInlineMessage(
                kind: ExomMessageKind.info,
                title: 'Aviso',
                body: 'Los cambios se sincronizan solos.',
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ExomTextLink(label: 'Ver todo', onTap: () {}),
                  const SizedBox(width: 16),
                  ExomTextLink(label: 'Eliminar', onTap: () {}, danger: true),
                ],
              ),
            ],
          ),
        ),
        const ExomEmptyState(
          first: 'Aún no hay',
          second: 'entrenamientos',
          body: 'Cuando tu entrenador te asigne uno, aparecerá aquí.',
        ),
        const Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExomSkeleton.numeral(),
              SizedBox(height: 8),
              ExomSkeleton.headline(),
              SizedBox(height: 8),
              ExomSkeleton.rule(),
            ],
          ),
        ),
        const ExomSkeleton.row(),
        const ExomSkeleton.row(),
      ],
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'componentes_mensajes_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await pumpComponent(
          tester,
          _componentesMensajes(),
          brightness: brightness,
          textScale: scale,
          height: 1400,
          disableAnimations: true,
        );
        expectNoOverflow(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
