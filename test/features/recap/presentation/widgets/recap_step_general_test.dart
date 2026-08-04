import 'package:exom_app/features/recap/presentation/widgets/recap_step_general.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores stress rating as a 1 to 5 value', () {
    expect(stressLevelFromRatingIndex(0), 1);
    expect(stressLevelFromRatingIndex(3), 4);
    expect(stressLevelFromRatingIndex(4), 5);
  });
}
