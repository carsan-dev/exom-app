import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history page keeps API metadata and derives its next page deterministically', () {
    final history = ProgressPhotoHistory(
      sessions: const [
        ProgressPhotoSession(
          id: 'same-date-a',
          sessionDate: '2026-09-16',
          isComplete: false,
          photos: [],
        ),
        ProgressPhotoSession(
          id: 'same-date-b',
          sessionDate: '2026-09-16',
          isComplete: false,
          photos: [],
        ),
      ],
      total: 41,
      page: 2,
      limit: 20,
      totalPages: 3,
    );

    expect(history.sessions.map((session) => session.id), [
      'same-date-a',
      'same-date-b',
    ]);
    expect(history.hasNextPage, isTrue);
    expect(history.nextPage, 3);
  });
}
