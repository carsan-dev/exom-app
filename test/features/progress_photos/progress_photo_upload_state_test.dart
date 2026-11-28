// L4 unit 2: the upload state of a photo tile is derived only from the queue
// item the page already reads (no network call, nothing written), with the
// same rules the page applied before the redesign.
import 'package:exom_app/features/progress_photos/presentation/progress_photo_upload_state.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item(
  String status, {
  bool cleanupPending = false,
  String? error,
}) => {
  'id': 'q1',
  'status': status,
  'cleanup_pending': cleanupPending,
  'last_error': error,
};

void main() {
  test('no queue item means no upload state', () {
    expect(progressPhotoUploadState(null), isNull);
  });

  test('staging and queued are pending', () {
    expect(
      progressPhotoUploadState(_item('staging')),
      ProgressPhotoUploadState.pending,
    );
    expect(
      progressPhotoUploadState(_item('queued')),
      ProgressPhotoUploadState.pending,
    );
  });

  test('an unknown status falls back to pending', () {
    expect(
      progressPhotoUploadState(_item('something-new')),
      ProgressPhotoUploadState.pending,
    );
  });

  test('processing is synchronizing', () {
    expect(
      progressPhotoUploadState(_item('processing')),
      ProgressPhotoUploadState.synchronizing,
    );
  });

  test('completed is confirmed, or cleanup pending while the copy remains', () {
    expect(
      progressPhotoUploadState(_item('completed')),
      ProgressPhotoUploadState.confirmed,
    );
    expect(
      progressPhotoUploadState(_item('completed', cleanupPending: true)),
      ProgressPhotoUploadState.cleanupPending,
    );
  });

  test('failed is failed, or conflict when the replacement went stale', () {
    expect(
      progressPhotoUploadState(_item('failed', error: 'network')),
      ProgressPhotoUploadState.failed,
    );
    expect(
      progressPhotoUploadState(_item('failed', error: 'STALE_REPLACEMENT')),
      ProgressPhotoUploadState.conflict,
    );
    expect(
      progressPhotoUploadState(_item('failed', error: 'HTTP 409')),
      ProgressPhotoUploadState.conflict,
    );
  });

  test('a stale replacement is a conflict whatever the queue status', () {
    expect(
      progressPhotoUploadState(_item('queued', error: 'STALE_REPLACEMENT')),
      ProgressPhotoUploadState.conflict,
    );
  });
}
