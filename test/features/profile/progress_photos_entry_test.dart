import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/features/profile/presentation/pages/profile_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile progress photos entry navigates to the authenticated route', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, _) => const Scaffold(body: ProgressPhotosEntry()),
        ),
        GoRoute(
          path: AppRoutes.progressPhotos,
          builder: (_, _) => const Scaffold(body: Text('Progress photos destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.tap(find.text('Progress photos'));
    await tester.pumpAndSettle();

    expect(find.text('Progress photos destination'), findsOneWidget);
  });
}
