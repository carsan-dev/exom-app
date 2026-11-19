// The cache marker of the «Progreso» view only works while the repository the
// app registers is also a MetricsHistorySource: the bloc checks that type at
// runtime. A future decorator that hides it would silently drop the marker.
import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/repositories/metrics_repository_impl.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _RemoteDataSource extends Fake implements MetricsRemoteDataSource {}

void main() {
  test('MetricsRepositoryImpl, registered as MetricsRepository, is also a '
      'MetricsHistorySource', () {
    // injection_container registers MetricsRepositoryImpl as
    // MetricsRepository; the full container needs native plugins, so the
    // concrete type is asserted instead.
    final MetricsRepository repository = MetricsRepositoryImpl(
      _RemoteDataSource(),
    );
    expect(repository, isA<MetricsHistorySource>());
  });
}
