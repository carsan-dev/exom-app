import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_start_countdown.dart';
import 'package:exom_app/l10n/app_localizations.dart';

void main() {
  for (final scenario in [
    'natural',
    'cancel',
    'back',
    'background',
    'stale owner',
  ]) {
    testWidgets('preparation deadline: $scenario', (tester) async {
      var now = DateTime(2026, 10, 10);
      var valid = true;
      bool? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final route = DialogRoute<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ExecutionStartCountdown(
                      now: () => now,
                      isValid: () => valid,
                    ),
                  );
                  result = await Navigator.of(context).push(route);
                  await route.completed;
                  closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('5'), findsOneWidget);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('2'), findsOneWidget);
      if (scenario == 'cancel') {
        await tester.tap(find.text('Cancel'));
      } else if (scenario == 'back') {
        await tester.binding.handlePopRoute();
      } else if (scenario == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (scenario == 'stale owner') {
        valid = false;
      } else {
        now = now.add(const Duration(seconds: 2));
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(closed, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(closed, true);
      expect(
        result,
        scenario == 'natural'
            ? true
            : scenario == 'back'
            ? null
            : false,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  for (final interruption in ['deadline', 'background']) {
    testWidgets(
      'Back during reverse transition preserves pushed workout: $interruption',
      (tester) async {
        var now = DateTime(2026, 10, 10);
        var started = false;
        late ModalRoute<void> workoutRoute;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Workout'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        workoutRoute = ModalRoute.of<void>(context)!;
                        return Scaffold(
                          body: TextButton(
                            child: const Text('Prepare'),
                            onPressed: () async {
                              final route = DialogRoute<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => ExecutionStartCountdown(
                                  now: () => now,
                                  isValid: () => true,
                                ),
                              );
                              final result = await Navigator.of(
                                context,
                              ).push(route);
                              await route.completed;
                              started = result == true;
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prepare'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        now = now.add(const Duration(milliseconds: 4900));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.binding.handlePopRoute();
        await tester.pump();
        if (interruption == 'deadline') {
          now = now.add(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 50));
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        await tester.pumpAndSettle();
        expect(workoutRoute.isCurrent, isTrue);
        expect(find.text('Prepare'), findsOneWidget);
        expect(started, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  }

  for (final interruption in [
    'deadline',
    'cancel',
    'background',
    'stale owner',
  ]) {
    testWidgets(
      'covered preparation cancels only its own route: $interruption',
      (tester) async {
        var now = DateTime(2026, 10, 11);
        var valid = true;
        var completed = false;
        var started = false;
        bool? result;
        late ModalRoute<void> workoutRoute;
        late DialogRoute<void> cover;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Workout'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        workoutRoute = ModalRoute.of<void>(context)!;
                        return Scaffold(
                          body: TextButton(
                            child: const Text('Prepare'),
                            onPressed: () async {
                              final route = DialogRoute<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => ExecutionStartCountdown(
                                  now: () => now,
                                  isValid: () => valid,
                                ),
                              );
                              result = await Navigator.of(context).push(route);
                              await route.completed;
                              completed = true;
                              started =
                                  result == true &&
                                  workoutRoute.isCurrent &&
                                  valid;
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prepare'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final cancel = tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed!;
        final context = tester.element(find.byType(ExecutionStartCountdown));
        cover = DialogRoute<void>(
          context: context,
          builder: (_) => const Dialog(child: Text('Cover')),
        );
        Navigator.of(context).push(cover);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        if (interruption == 'deadline') {
          now = now.add(const Duration(seconds: 5));
        } else if (interruption == 'cancel') {
          cancel();
        } else if (interruption == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        } else {
          valid = false;
        }
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));
        expect(cover.isCurrent, isTrue);
        expect(workoutRoute.isActive, isTrue);
        expect(completed, isTrue);
        expect(result, isFalse);
        expect(started, isFalse);
        cover.navigator!.pop();
        await tester.pumpAndSettle();
        expect(workoutRoute.isCurrent, isTrue);
        expect(find.byType(ExecutionStartCountdown), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  }

  testWidgets('large text, reduced motion and localized live semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: ExecutionStartCountdown(isValid: () => true),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Empieza en 5 segundos'), findsOneWidget);
    final animation = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(animation.duration, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}
