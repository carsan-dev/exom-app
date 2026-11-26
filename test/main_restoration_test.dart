// P-E3b-1 r2: the app's restoration scope must not cost an empty frame at the
// hand-off from the bootstrap splash. On a device the restoration data comes
// back from the engine through a platform channel (asynchronously); the test
// binding answers synchronously, so this file installs a manager that answers
// like the engine does.
import 'dart:async';

import 'package:exom_app/features/trainings/presentation/widgets/pending_last_set_restoration.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out the root bucket only once [answer] completes, as the engine
/// does through `flutter/restoration`; afterwards it is synchronous, like the
/// real manager once it holds the data.
class _EngineLikeRestorationManager extends TestRestorationManager {
  final Completer<void> answer = Completer<void>();

  @override
  Future<RestorationBucket?> get rootBucket {
    if (answer.isCompleted) return super.rootBucket;
    return answer.future.then((_) => super.rootBucket);
  }
}

class _EngineLikeBinding extends AutomatedTestWidgetsFlutterBinding {
  late _EngineLikeRestorationManager manager;

  @override
  TestRestorationManager createRestorationManager() =>
      manager = _EngineLikeRestorationManager();
}

const _app = Key('app');
const _splash = Key('splash');

/// Stands for `ExomBootstrapApp`: it has already drawn the first frame when
/// the app is mounted.
Widget _bootstrapSplash() => const Directionality(
  textDirection: TextDirection.ltr,
  child: ColoredBox(
    color: Color(0xFF101010),
    child: SizedBox.expand(key: _splash),
  ),
);

void main() {
  final binding = _EngineLikeBinding();

  testWidgets('control: a root scope mounted after the splash without the '
      'data draws an empty frame until the engine answers', (tester) async {
    await tester.pumpWidget(_bootstrapSplash());
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: 'exom',
        child: SizedBox(key: _app),
      ),
    );
    // What r1 did: the frame after the splash has neither the splash nor
    // the app (`SizedBox.shrink`).
    expect(find.byKey(_splash), findsNothing);
    expect(find.byKey(_app), findsNothing);

    binding.manager.answer.complete();
    await tester.idle();
    await tester.pump();
    expect(find.byKey(_app), findsOneWidget);
  });

  testWidgets('with the data preloaded before runApp, the first frame after '
      'the splash is the app, with restoration', (tester) async {
    await tester.pumpWidget(_bootstrapSplash());
    final preload = RestorationDataPreload.start();
    expect(preload.isReady, isFalse);
    binding.manager.answer.complete();
    await tester.idle();
    expect(preload.isReady, isTrue);
    expect(await preload.ready(), isTrue);

    await tester.pumpWidget(
      const BoundedRestorationScope(
        restorationReady: true,
        child: SizedBox(key: _app),
      ),
    );
    expect(find.byKey(_app), findsOneWidget);
    final context = tester.element(find.byKey(_app));
    expect(RestorationScope.maybeOf(context), isNotNull);
    expect(PendingLastSetRestoration.maybeOf(context), isNotNull);
  });

  testWidgets('an engine that never answers: after the cap the app starts '
      'without restoration, never an empty frame; the store still works in '
      'memory', (tester) async {
    await tester.pumpWidget(_bootstrapSplash());
    final preload = RestorationDataPreload.start();
    final ready = preload.ready(cap: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 299));
    var settled = false;
    unawaited(ready.then((_) => settled = true));
    await tester.idle();
    expect(settled, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await ready, isFalse);

    await tester.pumpWidget(
      const BoundedRestorationScope(
        restorationReady: false,
        child: SizedBox(key: _app),
      ),
    );
    expect(find.byKey(_app), findsOneWidget);
    final context = tester.element(find.byKey(_app));
    expect(RestorationScope.maybeOf(context), isNull);
    final store = PendingLastSetRestoration.maybeOf(context)!;
    const entry = PendingLastSetEntry(
      ownerId: 'owner',
      environment: 'test',
      trainingId: 't',
      trainingExerciseId: 'te',
      assignmentDate: '2026-11-18',
      sessionId: null,
      setNumber: 3,
      reps: 9,
      seconds: null,
      weightKg: 82.5,
      rir: 2,
      skipped: false,
    );
    store.write(entry);
    expect(store.entryFor('owner', 'test'), entry);
  });
}
