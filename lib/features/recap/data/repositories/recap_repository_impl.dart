import 'package:exom_app/features/recap/data/datasources/recap_remote_datasource.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';

class RecapRepositoryImpl implements RecapRepository {
  final RecapRemoteDataSource _remoteDataSource;

  const RecapRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<RecapEntity>> getMyRecaps() => _remoteDataSource.getMyRecaps();

  @override
  Future<RecapEntity> getMyRecapById(String id) =>
      _remoteDataSource.getMyRecapById(id);

  @override
  Future<RecapEntity> createRecap(Map<String, dynamic> data) =>
      _remoteDataSource.createRecap(data);

  @override
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data) =>
      _remoteDataSource.updateRecap(id, data);

  @override
  Future<void> submitRecap(String id) => _remoteDataSource.submitRecap(id);

  @override
  Future<void> markFeedbackRead(String id) =>
      _remoteDataSource.markFeedbackRead(id);
}
