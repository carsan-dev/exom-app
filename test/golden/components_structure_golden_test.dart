// Redesign L5 component goldens for T0.3a «Estructura y filas»
// (docs/plans/rediseno-app-l5-contrato-v2.md, sections 2.1 and 5.3), in dark
// and light at text scale 1.0 and 1.6 on the 390x844 surface of the L0
// baseline. Kept apart from components_golden_test.dart so the batches of the
// base can add their scenes in parallel.
//
// Same platform rules as redesign_baseline_golden_test.dart: generated on
// Windows with the bundled fonts (loadRedesignFonts), so regenerate on the same
// OS with:
//   flutter test --update-goldens test/golden/components_structure_golden_test.dart
//
// Scenes:
//  * componentes_estructura: ExomBand, ExomFlatRow, ExomValueRow,
//    ExomSwitchRow (on, off, busy, error), ExomFeatureBlock and ExomRichRow
//    (date, icon and image, with sync status). Taller than the 844 baseline
//    surface so that nothing is cut at 1.6x.
//  * componentes_estructura_listas: ExomIndexList, ExomAccordion (open and
//    closed) and ExomNoticeRow (unread and read).
//  * componentes_estructura_hoja: the confirmation variant of showExomSheet
//    (title, body and pinned actions) open over a plain page.
@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_accordion.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_notice_row.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/widgets/exom_component_harness.dart';

void _noop() {}

// Solid 1x1 olive PNG: ExomRowLeading.image paints it cover-fitted, a flat
// photo stand-in that needs no asset (decoded before the golden is taken).
final Uint8List _photoBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xC8, 0xAE, 0xF2, 0xFF,
  0x0F, 0x00, 0x04, 0xBC, 0x02, 0x34, 0xCB, 0x67, 0x24, 0x5A, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
final MemoryImage _photo = MemoryImage(_photoBytes);

void _noopBool(bool _) {}

/// Fixed fictitious data; nothing depends on the clock or the locale beyond
/// the already formatted strings.
Widget _estructura() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ExomBand(
          kicker: 'Ajustes',
          child: ExomFlatRowGroup(
            children: const [
              ExomFlatRow(
                leading: Icon(ExomIcons.diet),
                title: 'Definición · 2.150 kcal',
                subtitles: ['1 de 4 comidas hechas'],
                onTap: _noop,
              ),
              ExomValueRow(label: 'Versión', value: '1.3.0'),
              ExomSwitchRow(
                label: 'Notificaciones push',
                value: true,
                onChanged: _noopBool,
              ),
              ExomSwitchRow(
                label: 'Recordar el vídeo de la última serie',
                value: false,
                onChanged: _noopBool,
              ),
              ExomSwitchRow(label: 'Sonido al acabar el descanso', value: true),
              ExomSwitchRow(
                label: 'Avisos de tu entrenador',
                value: false,
                onChanged: _noopBool,
                errorText: 'No se ha podido guardar. Inténtalo otra vez.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ExomFeatureBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 20),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExomKicker('Jueves 19 · elegido'),
                ),
              ),
              SizedBox(height: 8),
              ExomRichRow(
                leading: ExomRowLeading.date(day: '18', label: 'nov'),
                title: 'Sentadilla búlgara',
                facts: '18 nov · 19:42 · vídeo',
                status: ExomSyncStatus(state: ExomSyncState.confirmada),
                onTap: _noop,
              ),
              ExomRichRow(
                leading: ExomRowLeading.icon(ExomIcons.diet),
                title: 'Plan nutricional',
                facts: 'Definición · 2.150 kcal · 5 comidas',
                status: ExomSyncStatus(state: ExomSyncState.pendiente),
                onTap: _noop,
              ),
              ExomRichRow(
                leading: ExomRowLeading.image(_photo),
                title: 'Foto de progreso · frente',
                facts: '18 nov · 19:40',
                status: ExomSyncStatus(state: ExomSyncState.enviando),
                onTap: _noop,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _listas() {
  return const SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 16),
        ExomIndexList(
          items: [
            ExomIndexItem(title: 'Actualizar peso y medidas', onTap: _noop),
            ExomIndexItem(
              title: 'Fotos de progreso',
              icon: ExomIcons.forward,
              status: '3 nuevas',
              onTap: _noop,
            ),
          ],
        ),
        SizedBox(height: 24),
        ExomFlatRowGroup(
          children: [
            ExomAccordion(
              number: 1,
              initiallyOpen: true,
              title: '¿Qué pasa si entreno sin conexión?',
              body: _AccordionBody(
                'Cada serie se guarda en este móvil y se envía sola cuando '
                'vuelve la conexión.',
              ),
            ),
            ExomAccordion(
              number: 2,
              title: '¿Cómo cambio mi dieta?',
              body: _AccordionBody('Escribe a tu entrenador desde Feedback.'),
            ),
          ],
        ),
        SizedBox(height: 24),
        ExomFlatRowGroup(
          children: [
            ExomNoticeRow(
              title: 'Tu entrenador ha respondido',
              body:
                  '«Buen trabajo en la búlgara. La semana que viene subimos '
                  'a 65 kg.»',
              time: '10:42',
              unread: true,
              onTap: _noop,
            ),
            ExomNoticeRow(
              title: 'Nuevo plan de dieta',
              body: 'Definición · 2.150 kcal, desde el lunes 23.',
              time: 'Ayer',
              onTap: _noop,
            ),
          ],
        ),
      ],
    ),
  );
}

class _AccordionBody extends StatelessWidget {
  const _AccordionBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge);
}

/// The confirmation variant of [showExomSheet] over a plain page.
Widget _hoja() {
  return Builder(
    builder: (context) => Center(
      child: TextButton(
        key: const Key('open-sheet'),
        onPressed: () => showExomSheet<bool>(
          context: context,
          title: 'Descartar la serie',
          body: 'Se borrarán las repeticiones y el peso de esta serie.',
          actions: [
            Builder(
              builder: (sheetContext) => FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Descartar'),
              ),
            ),
            Builder(
              builder: (sheetContext) => TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
        child: const Text('Abrir'),
      ),
    ),
  );
}

typedef _Scene = ({
  Widget Function() build,
  double height1,
  double height16,
  bool opensSheet,
});

void main() {
  final scenes = <String, _Scene>{
    'componentes_estructura': (
      build: _estructura,
      height1: 900,
      height16: 1250,
      opensSheet: false,
    ),
    'componentes_estructura_listas': (
      build: _listas,
      height1: 844,
      height16: 1100,
      opensSheet: false,
    ),
    'componentes_estructura_hoja': (
      build: _hoja,
      height1: 844,
      height16: 844,
      opensSheet: true,
    ),
  };
  for (final MapEntry(key: slug, value: scene) in scenes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.6]) {
        final name =
            '${slug}_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
        testWidgets('golden $name', (tester) async {
          await pumpComponent(
            tester,
            scene.build(),
            brightness: brightness,
            textScale: scale,
            height: scale == 1.0 ? scene.height1 : scene.height16,
          );
          await tester.runAsync(
            () => precacheImage(_photo, tester.element(find.byType(Scaffold))),
          );
          await tester.pump();
          if (scene.opensSheet) {
            await tester.tap(find.byKey(const Key('open-sheet')));
            await tester.pumpAndSettle();
          }
          // The busy switch's indeterminate indicator is a dot at its first
          // frame: advance a fixed time so the arc shows (deterministic).
          await tester.pump(const Duration(milliseconds: 400));
          expectNoOverflow(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
