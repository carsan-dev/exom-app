import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trainingFooterBottomPadding', () {
    test('adds navigation bar inset on Android button navigation', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 48,
          systemGestureInset: 24,
        ),
        64,
      );
    });

    test('keeps current inset on Android gesture navigation', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 24,
          systemGestureInset: 24,
        ),
        24,
      );
    });

    test('keeps base margin on Android without bottom insets', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.android,
          navigationInset: 0,
          systemGestureInset: 0,
        ),
        16,
      );
    });

    test('ignores navigation insets on iOS', () {
      expect(
        trainingFooterBottomPadding(
          platform: TargetPlatform.iOS,
          navigationInset: 34,
          systemGestureInset: 34,
        ),
        16,
      );
    });
  });
}
