import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:hive/hive.dart';

abstract class ActiveWorkoutLocalStore {
  ActiveWorkoutHiveModel? getActiveWorkout(String exerciseId);
  Future<void> saveActiveWorkout(ActiveWorkoutHiveModel workout);
  Future<void> removeActiveWorkout(String exerciseId);
}

class ActiveWorkoutHiveModel {
  static const int typeId = 1;

  final int timedElapsedMs;
  final DateTime? timedStartedAt;
  final int? timedTotalSeconds;
  final TimedPrescription? timedPrescription;
  final String trainingId;
  final String exerciseId;
  final int currentSet;
  final int completedSets;
  final DateTime? restEndsAt;
  final double? lastWeightKg;
  final List<Map<String, dynamic>> completedSetData;
  final String? lastSetFeedbackClientUploadId;

  const ActiveWorkoutHiveModel({
    this.timedElapsedMs = 0,
    this.timedStartedAt,
    this.timedTotalSeconds,
    this.timedPrescription,
    required this.trainingId,
    required this.exerciseId,
    required this.currentSet,
    required this.completedSets,
    this.restEndsAt,
    this.lastWeightKg,
    this.completedSetData = const [],
    this.lastSetFeedbackClientUploadId,
  });

  ActiveWorkoutHiveModel copyWith({
    String? trainingId,
    String? exerciseId,
    int? currentSet,
    int? completedSets,
    Object? restEndsAt = _sentinel,
    Object? lastWeightKg = _sentinel,
    List<Map<String, dynamic>>? completedSetData,
    Object? lastSetFeedbackClientUploadId = _sentinel,
  }) {
    return ActiveWorkoutHiveModel(
      timedElapsedMs: timedElapsedMs,
      timedStartedAt: timedStartedAt,
      timedTotalSeconds: timedTotalSeconds,
      timedPrescription: timedPrescription,
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
      completedSetData: completedSetData ?? this.completedSetData,
      lastSetFeedbackClientUploadId:
          identical(lastSetFeedbackClientUploadId, _sentinel)
          ? this.lastSetFeedbackClientUploadId
          : lastSetFeedbackClientUploadId as String?,
    );
  }
}

class ActiveWorkoutHiveModelAdapter
    extends TypeAdapter<ActiveWorkoutHiveModel> {
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
      timedElapsedMs: fields[8] as int? ?? 0,
      timedStartedAt: fields[9] as DateTime?,
      timedTotalSeconds: fields[10] as int?,
      timedPrescription: TimedPrescription.tryParse(fields[11]),
      trainingId: fields[0] as String? ?? '',
      exerciseId: fields[1] as String? ?? '',
      currentSet: fields[2] as int? ?? 1,
      completedSets: fields[3] as int? ?? 0,
      restEndsAt: fields[4] as DateTime?,
      lastWeightKg: fields[5] as double?,
      completedSetData: ((fields[6] as List?) ?? const [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(),
      lastSetFeedbackClientUploadId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ActiveWorkoutHiveModel obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.lastWeightKg)
      ..writeByte(6)
      ..write(obj.completedSetData)
      ..writeByte(7)
      ..write(obj.lastSetFeedbackClientUploadId)
      ..writeByte(8)
      ..write(obj.timedElapsedMs)
      ..writeByte(9)
      ..write(obj.timedStartedAt)
      ..writeByte(10)
      ..write(obj.timedTotalSeconds)
      ..writeByte(11)
      ..write(obj.timedPrescription?.toJson());
  }
}

const _sentinel = Object();
