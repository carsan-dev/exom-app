import 'dart:async';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/recap/data/models/recap_model.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';
import 'package:exom_app/features/recap/domain/usecases/create_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/get_my_recaps_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/get_recap_detail_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/mark_recap_feedback_read_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/submit_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/update_recap_usecase.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic owned repository; no Firebase, HTTP or Hive boxes are initialized.
class RecapTestRepository implements RecapRepository {
  final details = <String, Completer<RecapEntity>>{};
  final readResult = Completer<void>();
  final readCalls = <String>[];
  final sessionKeys = <String?>[];
  final writes = <String>[];
  @override
  Future<RecapEntity> getMyRecapById(String id) {
    sessionKeys.add(LocalStorage.requestSessionKey);
    return details.putIfAbsent(id, Completer<RecapEntity>.new).future;
  }

  @override
  Future<void> markFeedbackRead(String id) {
    sessionKeys.add(LocalStorage.requestSessionKey);
    readCalls.add(id);
    return readResult.future;
  }

  @override
  Future<List<RecapEntity>> getMyRecaps() async => [];
  @override
  Future<RecapEntity> createRecap(Map<String, dynamic> data) async {
    writes.add('create');
    return recapFixture();
  }

  @override
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data) async {
    writes.add('update:$id');
    return recapFixture(id: id);
  }

  @override
  Future<void> submitRecap(String id) async {
    writes.add('submit:$id');
  }
}

RecapBloc recapTestBloc(RecapTestRepository repository) => RecapBloc(
  getMyRecapsUseCase: GetMyRecapsUseCase(repository),
  createRecapUseCase: CreateRecapUseCase(repository),
  updateRecapUseCase: UpdateRecapUseCase(repository),
  submitRecapUseCase: SubmitRecapUseCase(repository),
  getRecapDetailUseCase: GetRecapDetailUseCase(repository),
  markRecapFeedbackReadUseCase: MarkRecapFeedbackReadUseCase(repository),
);

RecapModel recapFixture({
  String id = 'A',
  Map<String, Object?> extra = const {},
}) => RecapModel.fromJson({
  'id': id,
  'week_start_date': '2026-10-05',
  'week_end_date': '2026-10-11',
  'created_at': '2026-10-05',
  'status': 'REVIEWED',
  'published_coach_summary': 'Resumen publicado $id',
  'draft_coach_summary': 'PRIVATE DRAFT',
  'admin_comments': 'PRIVATE NOTE',
  ...extra,
});

Future<void> flushRecapEvents() => Future<void>.delayed(Duration.zero);

void main() {
  late RecapTestRepository repository;
  late RecapBloc bloc;
  LocalAuthSession? session;
  setUp(() {
    session = const LocalAuthSession(uid: 'synthetic-A', generation: 1);
    sl.registerSingleton<LocalStorage>(
      LocalStorage(currentSession: () => session),
    );
    repository = RecapTestRepository();
    bloc = recapTestBloc(repository);
  });
  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  test(
    'detail and feedback use the canonical uid:generation transport zone',
    () async {
      bloc.add(const RecapDetailRequested('A'));
      await flushRecapEvents();
      repository.details['A']!.complete(
        recapFixture(extra: {'client_feedback_text': 'Legacy'}),
      );
      await flushRecapEvents();
      bloc.add(const RecapFeedbackMarkReadRequested('A'));
      await flushRecapEvents();
      expect(repository.sessionKeys, ['synthetic-A:1', 'synthetic-A:1']);
      repository.readResult.complete();
      await flushRecapEvents();
      final recap = (bloc.state as RecapDetailLoaded).recap;
      expect(recap.clientFeedbackReadAt, isNotNull);
      expect(recap.publishedCoachSummary, 'Resumen publicado A');
    },
  );

  test(
    'legacy create, save, update, submit and list flows remain intact',
    () async {
      bloc.add(const RecapCreateRequested());
      await flushRecapEvents();
      expect(bloc.state, isA<RecapFormActive>());
      bloc.add(const RecapSaveRequested());
      await flushRecapEvents();
      expect(bloc.state, isA<RecapListLoaded>());
      bloc.add(const RecapSubmitRequested(recapId: 'A'));
      await flushRecapEvents();
      expect(bloc.state, isA<RecapSubmitted>());
      expect(repository.writes, ['create', 'update:A', 'submit:A']);
    },
  );

  test('signed-out detail does not start a request', () async {
    session = null;
    bloc.add(const RecapDetailRequested('A'));
    await flushRecapEvents();
    expect(repository.details, isEmpty);
  });

  test('late detail A cannot replace the more recent detail B', () async {
    bloc.add(const RecapDetailRequested('A'));
    await flushRecapEvents();
    bloc.add(const RecapDetailRequested('B'));
    await flushRecapEvents();
    repository.details['B']!.complete(recapFixture(id: 'B'));
    await flushRecapEvents();
    repository.details['A']!.complete(recapFixture());
    await flushRecapEvents();
    expect((bloc.state as RecapDetailLoaded).recap.id, 'B');
  });

  test('late detail errors cannot replace newer successful detail', () async {
    bloc.add(const RecapDetailRequested('A'));
    await flushRecapEvents();
    bloc.add(const RecapDetailRequested('B'));
    await flushRecapEvents();
    repository.details['B']!.complete(recapFixture(id: 'B'));
    await flushRecapEvents();
    repository.details['A']!.completeError(StateError('old response'));
    await flushRecapEvents();
    expect(bloc.state, isA<RecapDetailLoaded>());
  });

  for (final identity in ['account', 'generation', 'logout']) {
    test('late detail after $identity change is not emitted', () async {
      bloc.add(const RecapDetailRequested('A'));
      await flushRecapEvents();
      session = switch (identity) {
        'account' => const LocalAuthSession(uid: 'synthetic-B', generation: 2),
        'generation' => const LocalAuthSession(
          uid: 'synthetic-A',
          generation: 2,
        ),
        _ => null,
      };
      repository.details['A']!.complete(recapFixture());
      await flushRecapEvents();
      expect(bloc.state, isNot(isA<RecapDetailLoaded>()));
      expect(repository.readCalls, isEmpty);
    });
  }

  test('late feedback completion cannot resurrect A over detail B', () async {
    bloc.add(const RecapDetailRequested('A'));
    await flushRecapEvents();
    repository.details['A']!.complete(
      recapFixture(extra: {'client_feedback_text': 'Legacy'}),
    );
    await flushRecapEvents();
    bloc.add(const RecapFeedbackMarkReadRequested('A'));
    await flushRecapEvents();
    bloc.add(const RecapDetailRequested('B'));
    await flushRecapEvents();
    repository.details['B']!.complete(recapFixture(id: 'B'));
    await flushRecapEvents();
    repository.readResult.complete();
    await flushRecapEvents();
    expect((bloc.state as RecapDetailLoaded).recap.id, 'B');
  });

  test('feedback from a displayed previous session is not sent', () async {
    bloc.add(const RecapDetailRequested('A'));
    await flushRecapEvents();
    repository.details['A']!.complete(
      recapFixture(extra: {'client_feedback_text': 'Legacy'}),
    );
    await flushRecapEvents();
    session = const LocalAuthSession(uid: 'synthetic-A', generation: 2);
    bloc.add(const RecapFeedbackMarkReadRequested('A'));
    await flushRecapEvents();
    repository.readResult.complete();
    await flushRecapEvents();
    expect(repository.readCalls, isEmpty);
    expect(
      (bloc.state as RecapDetailLoaded).recap.clientFeedbackReadAt,
      isNull,
    );
  });

  for (final identity in ['account', 'generation', 'logout']) {
    test(
      'late feedback completion after $identity change does not update UI',
      () async {
        bloc.add(const RecapDetailRequested('A'));
        await flushRecapEvents();
        repository.details['A']!.complete(
          recapFixture(extra: {'client_feedback_text': 'Legacy'}),
        );
        await flushRecapEvents();
        bloc.add(const RecapFeedbackMarkReadRequested('A'));
        await flushRecapEvents();
        session = switch (identity) {
          'account' => const LocalAuthSession(
            uid: 'synthetic-B',
            generation: 2,
          ),
          'generation' => const LocalAuthSession(
            uid: 'synthetic-A',
            generation: 2,
          ),
          _ => null,
        };
        repository.readResult.complete();
        await flushRecapEvents();
        expect(
          (bloc.state as RecapDetailLoaded).recap.clientFeedbackReadAt,
          isNull,
        );
      },
    );
  }
}
