import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/widgets/premium_locked_overlay.dart';

void main() {
  // ── PremiumLockedOverlay ──

  group('PremiumLockedOverlay', () {
    testWidgets('shows child without overlay when isLocked is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedOverlay(
              isLocked: false,
              child: Text('Visible content'),
            ),
          ),
        ),
      );

      expect(find.text('Visible content'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsNothing);
      expect(find.text('Función premium'), findsNothing);
    });

    testWidgets('shows lock overlay when isLocked is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedOverlay(
              isLocked: true,
              child: SizedBox(
                width: 400,
                height: 400,
                child: Center(child: Text('Hidden content')),
              ),
            ),
          ),
        ),
      );

      // Child is still rendered (behind blur)
      expect(find.text('Hidden content'), findsOneWidget);
      // Lock icon and premium text are shown
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      expect(find.text('Función premium'), findsOneWidget);
      expect(find.text('Disponible en el plan completo'), findsOneWidget);
    });

    testWidgets('shows custom message when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedOverlay(
              isLocked: true,
              customMessage: 'Upgrade required',
              child: SizedBox(
                width: 400,
                height: 400,
                child: Center(child: Text('Content')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Upgrade required'), findsOneWidget);
      expect(find.text('Función premium'), findsNothing);
    });
  });

  // ── PremiumLockedInline ──

  group('PremiumLockedInline', () {
    testWidgets('shows child when not locked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedInline(
              isLocked: false,
              child: Text('Macros: 2000 kcal'),
            ),
          ),
        ),
      );

      expect(find.text('Macros: 2000 kcal'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsNothing);
    });

    testWidgets('shows compact lock when locked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedInline(
              isLocked: true,
              child: Text('Macros: 2000 kcal'),
            ),
          ),
        ),
      );

      expect(find.text('Macros: 2000 kcal'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    });
  });

  // ── PremiumLockedSection ──

  group('PremiumLockedSection', () {
    testWidgets('shows child when not locked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedSection(
              isLocked: false,
              label: 'Ingredientes',
              child: Text('Arroz, pollo, brocoli'),
            ),
          ),
        ),
      );

      expect(find.text('Arroz, pollo, brocoli'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsNothing);
    });

    testWidgets('shows label with lock when locked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumLockedSection(
              isLocked: true,
              label: 'Ingredientes',
              child: SizedBox(
                width: 400,
                height: 400,
                child: Center(child: Text('Arroz, pollo, brocoli')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Arroz, pollo, brocoli'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      expect(find.text('Ingredientes — Premium'), findsOneWidget);
    });
  });

  // ── PremiumLockedPage ──

  group('PremiumLockedPage', () {
    testWidgets('shows default title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PremiumLockedPage()),
        ),
      );

      expect(
        find.text('Esta función está disponible en el plan premium'),
        findsOneWidget,
      );
      expect(
        find.text(
            'Contacta con tu entrenador para acceder al plan completo.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    });

    testWidgets('shows CTA button when callback provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumLockedPage(
              onContactTrainer: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Contactar con mi entrenador'), findsOneWidget);
      await tester.tap(find.text('Contactar con mi entrenador'));
      expect(tapped, isTrue);
    });

    testWidgets('hides CTA button when no callback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PremiumLockedPage()),
        ),
      );

      expect(find.text('Contactar con mi entrenador'), findsNothing);
    });
  });
}
