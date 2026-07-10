import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('week period is Monday through Sunday', () {
    final start = mondayFor(DateTime(2026, 7, 10));
    expect(start, DateTime(2026, 7, 6));
    expect(start.add(const Duration(days: 6)), DateTime(2026, 7, 12));
  });

  test('month period uses natural month including leap February', () {
    final date = DateTime(2028, 2, 15);
    expect(monthStartFor(date), DateTime(2028, 2, 1));
    expect(monthEndFor(date), DateTime(2028, 2, 29));
  });

  test('filenames identify a month or an exact weekly range', () {
    expect(
      dietExportFilename(
        shoppingList: false,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
        calendarMonth: true,
      ),
      'menu_2026-07.pdf',
    );
    expect(
      dietExportFilename(
        shoppingList: true,
        start: DateTime(2026, 7, 6),
        end: DateTime(2026, 7, 12),
        calendarMonth: false,
      ),
      'lista_compra_2026-07-06_2026-07-12.pdf',
    );
  });
}
