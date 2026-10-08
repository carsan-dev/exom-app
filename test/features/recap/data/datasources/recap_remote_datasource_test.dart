import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/recap/data/datasources/recap_remote_datasource.dart';
import 'package:exom_app/features/recap/data/repositories/recap_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecapAdapter implements HttpClientAdapter {
  _RecapAdapter(this.recap);

  final Map<String, Object?> recap;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.path == '/recaps/my'
            ? {'data': [recap], 'total': 1, 'page': 1, 'limit': 20}
            : recap,
        'timestamp': '2026-10-08T12:00:00.000Z',
      }),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const keys = [
    'published_coach_summary',
    'published_changes',
    'published_next_week_goals',
  ];
  const cases = <String, List<String?>>{
    'full': ['Resumen ñ', 'Cambios', 'Objetivos'],
    'partial': ['Resumen ñ', null, 'Objetivos'],
    'null': [null, null, null],
    'absent legacy': [null, null, null],
  };

  for (final entry in cases.entries) {
    test('${entry.key} publication survives serialized detail and list', () async {
      final adapter = _RecapAdapter({
        'id': 'recap-1',
        'week_start_date': '2026-10-05T00:00:00.000Z',
        'week_end_date': '2026-10-11T00:00:00.000Z',
        'created_at': '2026-10-05T09:15:30.123Z',
        'reviewed_at': '2026-10-08T10:20:30.456Z',
        'client_feedback_sent_at': '2026-10-08T10:21:30.000Z',
        'client_feedback_read_at': '2026-10-08T10:22:30.000Z',
        'status': 'REVIEWED',
        'client_feedback_text': 'Legacy feedback',
        'training_sessions': 3,
        'general_notes': 'Client notes',
        if (entry.key != 'absent legacy')
          for (var i = 0; i < keys.length; i++) keys[i]: entry.value[i],
      });
      final api = ApiClient(
        useAuth: false,
        baseUrl: 'https://exom.test.invalid/api/v1',
      );
      api.dio.httpClientAdapter = adapter;
      addTearDown(() => api.dio.close(force: true));
      final repository = RecapRepositoryImpl(RecapRemoteDataSourceImpl(api));
      final detail = await repository.getMyRecapById('recap-1');
      final list = await repository.getMyRecaps();
      for (final recap in [detail, list.single]) {
        expect([
          recap.publishedCoachSummary,
          recap.publishedChanges,
          recap.publishedNextWeekGoals,
        ], entry.value);
        expect(recap.id, 'recap-1');
        expect(recap.status, 'REVIEWED');
        expect(recap.clientFeedbackText, 'Legacy feedback');
        expect(recap.trainingSessions, 3);
        expect(recap.generalNotes, 'Client notes');
        final dates = [
          recap.weekStartDate, recap.weekEndDate, recap.createdAt,
          recap.reviewedAt, recap.clientFeedbackSentAt, recap.clientFeedbackReadAt,
        ];
        expect(dates, [
          DateTime.utc(2026, 10, 5),
          DateTime.utc(2026, 10, 11),
          DateTime.utc(2026, 10, 5, 9, 15, 30, 123),
          DateTime.utc(2026, 10, 8, 10, 20, 30, 456),
          DateTime.utc(2026, 10, 8, 10, 21, 30),
          DateTime.utc(2026, 10, 8, 10, 22, 30),
        ]);
        expect(dates.every((date) => date != null && date.isUtc), isTrue);
      }
      expect(adapter.requests.map((request) => request.uri.toString()).toList(), [
        'https://exom.test.invalid/api/v1/recaps/my/recap-1',
        'https://exom.test.invalid/api/v1/recaps/my',
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.queryParameters, isEmpty);
      }
    });
  }
}
