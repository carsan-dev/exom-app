import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/rest_timer_inline.dart';
import 'package:exom_app/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: SizedBox(width: 360, height: 600, child: child)),
  );
}

void main() {
  testWidgets('renders title, countdown and skip button', (tester) async {
    final restEndsAt = DateTime.now().add(const Duration(seconds: 30));
    var skipped = false;

    await tester.pumpWidget(
      _wrap(
        RestTimerInline(
          totalSeconds: 30,
          restEndsAt: restEndsAt,
          subtitle: 'Serie 2 / 3',
          onSkip: () => skipped = true,
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('Descanso'), findsOneWidget);
    expect(find.text('Serie 2 / 3'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);

    final countdown = find
        .byWidgetPredicate((w) => w is Text && int.tryParse(w.data ?? '') != null)
        .evaluate()
        .map((e) => (e.widget as Text).data!)
        .toList();
    expect(countdown, isNotEmpty);
    final remaining = int.parse(countdown.first);
    expect(remaining, inInclusiveRange(28, 30));

    await tester.tap(find.text('Saltar'));
    await tester.pump();
    expect(skipped, isTrue);
  });

  testWidgets('calls onFinished when restEndsAt is already in the past',
      (tester) async {
    final restEndsAt = DateTime.now().subtract(const Duration(seconds: 1));
    var finished = false;

    await tester.pumpWidget(
      _wrap(
        RestTimerInline(
          totalSeconds: 30,
          restEndsAt: restEndsAt,
          onSkip: () {},
          onFinished: () => finished = true,
        ),
      ),
    );

    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets('omits subtitle when null', (tester) async {
    final restEndsAt = DateTime.now().add(const Duration(seconds: 10));

    await tester.pumpWidget(
      _wrap(
        RestTimerInline(
          totalSeconds: 10,
          restEndsAt: restEndsAt,
          onSkip: () {},
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('Descanso'), findsOneWidget);
    expect(find.byType(Text), findsAtLeast(2));
  });
}
