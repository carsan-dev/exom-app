import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // L4b: program week/day, total sets and the photo belong to the selected
  // day; only the profile fields are shared between days.
  test('withSharedFieldsFrom keeps the day fields of this summary', () {
    const day = HomeSummaryEntity(
      trainingId: 't-day',
      programWeek: 3,
      programDay: 2,
      totalSets: 22,
      trainingThumbnailUrl: 'https://cdn/day.jpg',
      trainings: [
        HomeTrainingItemEntity(
          id: 't-day',
          name: 'Día',
          completed: false,
          thumbnailUrl: 'https://cdn/day.jpg',
        ),
      ],
    );
    const shared = HomeSummaryEntity(
      programWeek: 9,
      programDay: 9,
      totalSets: 99,
      trainingThumbnailUrl: 'https://cdn/other.jpg',
      streakDays: 12,
      clientName: 'Ana',
    );

    final merged = day.withSharedFieldsFrom(shared);

    expect(merged.programWeek, 3);
    expect(merged.programDay, 2);
    expect(merged.totalSets, 22);
    expect(merged.trainingThumbnailUrl, 'https://cdn/day.jpg');
    expect(merged.trainings.single.thumbnailUrl, 'https://cdn/day.jpg');
    expect(merged.streakDays, 12);
    expect(merged.clientName, 'Ana');
  });
}
