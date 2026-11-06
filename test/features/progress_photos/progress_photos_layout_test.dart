import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/features/progress_photos/presentation/pages/progress_photos_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progress_photos_page_test.dart' show FakeQueue, FakeRepository, pending, photo, sessionFor;

void main() {
  late Directory cacheDirectory;

  setUp(() {
    cacheDirectory = Directory.systemTemp.createTempSync('progress-photos-layout-');
    // The default image cache manager resolves its storage directories on
    // first use; tests have no path_provider plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cacheDirectory.path,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  testWidgets(
    'narrow screen with large text keeps photo tiles readable without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.reset);

      final repository = FakeRepository()
        ..history = [
          sessionFor('s1', '2026-09-16', photos: [photo('front', 'FRONT'), photo('left', 'LEFT')]),
        ];
      final queue = FakeQueue()
        ..items = [
          // Confirmed photo with a failed stale replacement: the tile with the
          // most actions (replace, review replacement, discard and status).
          pending('left-stale', 's1', 'LEFT', 'failed', error: 'STALE_REPLACEMENT'),
          pending('right-processing', 's1', 'RIGHT', 'processing'),
        ];

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: ProgressPhotosPage(
          repository: repository,
          queue: queue,
          sessionStamp: () => 'account-a:1',
          queuePollInterval: null,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Sincronizando'), findsWidgets); // pending tile
      expect(find.text('Pendiente'), findsWidgets); // missing tile

      final photos = find.byType(CachedNetworkImage);
      expect(photos, findsNWidgets(2));
      for (final element in photos.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThanOrEqualTo(size.width), reason: 'photo collapsed to $size');
      }

      // Short visible action labels keep the full text for assistive
      // technologies and as tooltip.
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Sustituir Frontal'), findsOneWidget);
      expect(find.bySemanticsLabel('Añadir Espalda'), findsOneWidget);
      expect(find.bySemanticsLabel('Ampliar Lateral izquierda'), findsOneWidget);
      expect(find.byTooltip('Sustituir Lateral izquierda'), findsOneWidget);
      semantics.dispose();
    },
  );
}
