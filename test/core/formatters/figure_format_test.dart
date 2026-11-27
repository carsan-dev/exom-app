// L5-D5: single locale-aware figure helper (no thousands separator).
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<String> _format(
  WidgetTester tester,
  Locale locale,
  num value, {
  int decimalDigits = 0,
  int? maxDecimalDigits,
}) async {
  late String result;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(
        builder: (context) {
          result = formatFigure(
            context,
            value,
            decimalDigits: decimalDigits,
            maxDecimalDigits: maxDecimalDigits,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  testWidgets('es: 0 and 1 decimals use comma', (tester) async {
    const es = Locale('es');
    expect(await _format(tester, es, 7.5, decimalDigits: 1), '7,5');
    expect(await _format(tester, es, 7, decimalDigits: 1), '7,0');
    expect(await _format(tester, es, 12.4), '12');
    expect(await _format(tester, es, 0), '0');
  });

  testWidgets('en: 0 and 1 decimals use point', (tester) async {
    const en = Locale('en');
    expect(await _format(tester, en, 7.5, decimalDigits: 1), '7.5');
    expect(await _format(tester, en, 7, decimalDigits: 1), '7.0');
    expect(await _format(tester, en, 12.4), '12');
  });

  testWidgets('values >= 1000 are not grouped', (tester) async {
    expect(await _format(tester, const Locale('es'), 12345), '12345');
    expect(await _format(tester, const Locale('en'), 12345), '12345');
    expect(
      await _format(tester, const Locale('es'), 1234.5, decimalDigits: 1),
      '1234,5',
    );
    expect(
      await _format(tester, const Locale('en'), 1234.5, decimalDigits: 1),
      '1234.5',
    );
  });

  testWidgets('negatives keep the sign', (tester) async {
    expect(
      await _format(tester, const Locale('es'), -3.5, decimalDigits: 1),
      '-3,5',
    );
    expect(await _format(tester, const Locale('en'), -1200), '-1200');
  });

  testWidgets('.5 rounds as NumberFormat does with 0 decimals', (tester) async {
    expect(await _format(tester, const Locale('en'), 2.5), '3');
    expect(await _format(tester, const Locale('es'), 3.5), '4');
  });

  testWidgets('maxDecimalDigits 2: up to 2 decimals, zeros dropped', (
    tester,
  ) async {
    for (final (locale, sep) in [(const Locale('es'), ','), (const Locale('en'), '.')]) {
      Future<String> f(num v) =>
          _format(tester, locale, v, maxDecimalDigits: 2);
      expect(await f(79.8), '79${sep}8');
      expect(await f(79.85), '79${sep}85');
      expect(await f(80.0), '80');
      expect(await f(79.856), '79${sep}86');
      expect(await f(0), '0');
      expect(await f(12345.5), '12345${sep}5');
      expect(await f(-3.25), '-3${sep}25');
    }
  });

  testWidgets('default keeps the integer format', (tester) async {
    expect(await _format(tester, const Locale('es'), 79.8), '80');
  });
}
