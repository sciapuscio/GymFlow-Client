/// RM Calculator — exercise entry model
class RmExercise {
  final int? id;
  String name;      // mutable so manual mode can rename
  final int reps;
  final String blockName;
  final String blockType;

  RmExercise({
    this.id,
    required this.name,
    required this.reps,
    required this.blockName,
    required this.blockType,
  });

  factory RmExercise.fromJson(Map<String, dynamic> j) => RmExercise(
        id: j['id'] as int?,
        name: j['name'] as String,
        reps: (j['reps'] as num).toInt(),
        blockName: j['block_name'] as String? ?? '',
        blockType: j['block_type'] as String? ?? '',
      );
}

/// A persisted log entry (from history endpoint)
class RmLog {
  final String exerciseName;
  final double weightKg;
  final int reps;
  final double rmEstimated;
  final String date; // 'YYYY-MM-DD'

  const RmLog({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.rmEstimated,
    required this.date,
  });

  factory RmLog.fromJson(Map<String, dynamic> j) => RmLog(
        exerciseName: j['exercise_name'] as String,
        weightKg: double.parse(j['weight_kg'].toString()),
        reps: (j['reps'] as num).toInt(),
        rmEstimated: double.parse(j['rm_estimated'].toString()),
        date: j['date'] as String,
      );
}

/// Local input state per exercise (user fills this in)
class RmEntry {
  final RmExercise exercise;
  double weightKg;
  int reps;

  RmEntry({required this.exercise, this.weightKg = 0, required this.reps});

  /// Allows manual mode to rename the exercise.
  void overrideName(String name) => exercise.name = name;

  /// Brzycki RM estimate: weight x (36 / (37 - reps))
  double get rmEstimated {
    if (reps <= 0 || reps >= 37 || weightKg <= 0) return 0;
    return weightKg * (36 / (37 - reps));
  }

  Map<String, dynamic> toJson() => {
        'exercise_name': exercise.name,
        if (exercise.id != null) 'exercise_id': exercise.id,
        'weight_kg': weightKg,
        'reps': reps,
      };
}
