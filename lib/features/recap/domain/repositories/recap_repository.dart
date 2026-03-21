import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

abstract class RecapRepository {
  Future<List<RecapEntity>> getMyRecaps();
  Future<RecapEntity> createRecap(Map<String, dynamic> data);
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data);
  Future<void> submitRecap(String id);
}
