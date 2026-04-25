import 'package:hive/hive.dart';

abstract class ActiveWorkoutLocalStore {
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId);
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout);
  Future<void> removeActiveWorkout(String exerciseId);
}

class ActiveWorkoutHiveModel {
  static const int typeId = 1;

  final String trainingId;
  final String exerciseId;
  final int currentSet;
  final int completedSets;
  final DateTime? restEndsAt;
  final double? lastWeightKg;

  const ActiveWorkoutHiveModel({
    required this.trainingId,
    required this.exerciseId,
    required this.currentSet,
    required this.completedSets,
    this.restEndsAt,
    this.lastWeightKg,
  });

  ActiveWorkoutHiveModel copyWith({
    String? trainingId,
    String? exerciseId,
    int? currentSet,
    int? completedSets,
    Object? restEndsAt = _sentinel,
    Object? lastWeightKg = _sentinel,
  }) {
    return ActiveWorkoutHiveModel(
      trainingId: trainingId ?? this.trainingId,
      exerciseId: exerciseId ?? this.exerciseId,
      currentSet: currentSet ?? this.currentSet,
      completedSets: completedSets ?? this.completedSets,
      restEndsAt: identical(restEndsAt, _sentinel)
          ? this.restEndsAt
          : restEndsAt as DateTime?,
      lastWeightKg: identical(lastWeightKg, _sentinel)
          ? this.lastWeightKg
          : lastWeightKg as double?,
    );
  }
}

class ActiveWorkoutHiveModelAdapter extends TypeAdapter<ActiveWorkoutHiveModel> {
  @override
  final int typeId = ActiveWorkoutHiveModel.typeId;

  @override
  ActiveWorkoutHiveModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }

    return ActiveWorkoutHiveModel(
      trainingId: fields[0] as String? ?? '',
      exerciseId: fields[1] as String? ?? '',
      currentSet: fields[2] as int? ?? 1,
      completedSets: fields[3] as int? ?? 0,
      restEndsAt: fields[4] as DateTime?,
      lastWeightKg: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ActiveWorkoutHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.trainingId)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.currentSet)
      ..writeByte(3)
      ..write(obj.completedSets)
      ..writeByte(4)
      ..write(obj.restEndsAt)
      ..writeByte(5)
      ..write(obj.lastWeightKg);
  }
}

const _sentinel = Object();
