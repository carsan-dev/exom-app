import 'dart:typed_data';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

ExomThemePalette _palette(Brightness b) =>
    themeFor(b).extension<ExomThemePalette>()!;

// 1x1 transparent PNG.
final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _dated({ExomSyncState? state, VoidCallback? onTap}) => ExomRichRow(
  leading: const ExomRowLeading.date(day: '18', label: 'nov'),
  title: 'Sentadilla búlgara',
  facts: '18 nov · 19:42 · vídeo',
  status: state == null ? null : ExomSyncStatus(state: state),
  onTap: onTap,
);

Widget _iconRow() => ExomRichRow(
  leading: const ExomRowLeading.icon(Icons.restaurant),
  title: 'Plan nutricional',
  facts: 'Definición · 2.150 kcal · 5 comidas',
  status: const ExomSyncStatus(state: ExomSyncState.pendiente),
  onTap: () {},
);

void main() {
  registerTextComponentMatrix(
    'ExomRichRow with status',
    () => _dated(state: ExomSyncState.confirmada, onTap: () {}),
  );
  registerTextComponentMatrix('ExomRichRow without status', () => _dated());
  registerTextComponentMatrix('ExomRichRow icon', _iconRow);

  testWidgets('tap targets meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Column(
        children: [
          _dated(state: ExomSyncState.enviando, onTap: () {}),
          _iconRow(),
        ],
      ),
      width: 320,
    );
    await expectTapTargetGuidelines(tester);
    handle.dispose();
  });

  testWidgets('at least 72 tall with 20 start / 12 end padding and top rule', (
    tester,
  ) async {
    await pumpComponent(tester, _dated(onTap: () {}), width: 360);
    expect(
      tester.getSize(find.byType(ExomRichRow)).height,
      greaterThanOrEqualTo(72),
    );
    final surface = tester.widget<ExomRowSurface>(find.byType(ExomRowSurface));
    expect(surface.minHeight, 72);
    expect(
      surface.padding,
      const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
    );
    final leading = tester.getRect(find.byKey(const Key('exom-row-leading')));
    expect(leading.left, 20);
    expect(leading.size, const Size(56, 56));
  });

  for (final brightness in Brightness.values) {
    testWidgets('title 600 in text, facts in secondary, date box with rule '
        '(${brightness.name})', (tester) async {
      final palette = _palette(brightness);
      await pumpComponent(tester, _dated(), brightness: brightness);
      final title = tester.widget<Text>(find.text('Sentadilla búlgara'));
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, palette.textPrimary);
      final facts = tester.widget<Text>(find.text('18 nov · 19:42 · vídeo'));
      expect(facts.style?.color, palette.textSecondary);
      expect(facts.style?.fontSize, 14);
      final day = tester.widget<Text>(find.text('18'));
      expect(day.style?.fontSize, 28);
      expect(day.style?.fontWeight, FontWeight.w800);
      expect(day.style?.color, palette.textPrimary);
      final month = tester.widget<Text>(find.text('nov'));
      expect(month.style?.fontSize, 13);
      expect(month.style?.color, palette.textSecondary);
      final box = tester.widget<Container>(
        find.byKey(const Key('exom-row-leading')),
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top, BorderSide(color: palette.borderSoft, width: 1));
    });
  }

  testWidgets('icon leading: raised square with a secondary icon', (
    tester,
  ) async {
    final palette = _palette(Brightness.light);
    await pumpComponent(tester, _iconRow(), brightness: Brightness.light);
    final box = tester.widget<Container>(
      find.byKey(const Key('exom-row-leading')),
    );
    expect((box.decoration! as BoxDecoration).color, palette.surfaceElevated);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.restaurant)).color,
      palette.textSecondary,
    );
  });

  testWidgets('image leading: 56x56 cover image, decorative', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      ExomRichRow(
        leading: ExomRowLeading.image(MemoryImage(_pixel)),
        title: 'Torso · Empuje',
        facts: 'lun 16 · 51 min · Fuerza',
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.excludeFromSemantics, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('exom-row-leading'))),
      const Size(56, 56),
    );
    handle.dispose();
  });

  testWidgets('with status the status is painted under the facts', (
    tester,
  ) async {
    await pumpComponent(tester, _dated(state: ExomSyncState.confirmada));
    final facts = tester.getRect(find.text('18 nov · 19:42 · vídeo'));
    final status = tester.getRect(find.byType(ExomSyncStatus));
    expect(status.top, greaterThanOrEqualTo(facts.bottom));
  });

  testWidgets('chevron and button only when tappable; tap reaches onTap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(tester, _dated(onTap: () => taps++));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    final node = tester.getSemantics(find.byType(ExomRichRow));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains('Sentadilla búlgara'));
    expect(node.label, contains('18 nov · 19:42 · vídeo'));
    await tester.tap(find.byType(ExomRichRow));
    expect(taps, 1);

    await pumpComponent(tester, _dated());
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(
      tester.getSemantics(find.byType(ExomRichRow)).flagsCollection.isButton,
      isFalse,
    );
    handle.dispose();
  });

  testWidgets('chevron is centred on the row, not on the thumbnail', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      SingleChildScrollView(
        child: ExomRichRow(
          leading: const ExomRowLeading.icon(Icons.restaurant),
          title: 'Plan nutricional de definición para las próximas semanas',
          facts: 'Definición · 2.150 kcal · 5 comidas repartidas en el día',
          status: const ExomSyncStatus(state: ExomSyncState.pendiente),
          onTap: () {},
        ),
      ),
      width: 320,
      textScale: 1.6,
    );
    final row = tester.getRect(find.byType(ExomRichRow));
    final thumb = tester.getRect(find.byKey(const Key('exom-row-leading')));
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(row.height, greaterThan(thumb.height + 24));
    // Row content spans the padded area: 12 above and 12 below.
    final centre = (row.top + 12 + row.bottom - 12) / 2;
    expect(chevron.center.dy, closeTo(centre, 1));
    expect(thumb.top, row.top + 12);
  });
}
