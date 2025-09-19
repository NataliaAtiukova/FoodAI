import 'package:shared_preferences/shared_preferences.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.currentWeight,
    required this.goalWeight,
    required this.startWeight,
    required this.weightWeekAgo,
  });

  final double currentWeight;
  final double goalWeight;
  final double startWeight;
  final double weightWeekAgo;

  double get totalLost => (startWeight - currentWeight).toDouble();

  double get weeklyChange => (currentWeight - weightWeekAgo).toDouble();

  ProgressSnapshot copyWith({
    double? currentWeight,
    double? goalWeight,
    double? startWeight,
    double? weightWeekAgo,
  }) {
    return ProgressSnapshot(
      currentWeight: currentWeight ?? this.currentWeight,
      goalWeight: goalWeight ?? this.goalWeight,
      startWeight: startWeight ?? this.startWeight,
      weightWeekAgo: weightWeekAgo ?? this.weightWeekAgo,
    );
  }
}

class ProgressService {
  ProgressService._();

  static final ProgressService instance = ProgressService._();

  static const String _currentWeightKey = 'progress_current_weight';
  static const String _goalWeightKey = 'progress_goal_weight';
  static const String _startWeightKey = 'progress_start_weight';
  static const String _weekAgoWeightKey = 'progress_week_ago_weight';

  ProgressSnapshot? _snapshot;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();

    final current = _prefs!.getDouble(_currentWeightKey) ?? 75;
    final goal = _prefs!.getDouble(_goalWeightKey) ?? 70;
    final start = _prefs!.getDouble(_startWeightKey) ?? current + 2;
    final weekAgo = _prefs!.getDouble(_weekAgoWeightKey) ?? current + 0.5;

    _snapshot = ProgressSnapshot(
      currentWeight: current,
      goalWeight: goal,
      startWeight: start,
      weightWeekAgo: weekAgo,
    );
  }

  ProgressSnapshot get snapshot {
    final value = _snapshot;
    if (value == null) {
      throw StateError('ProgressService.init() должен быть вызван до snapshot');
    }
    return value;
  }

  Future<void> update({
    double? currentWeight,
    double? goalWeight,
    double? startWeight,
    double? weightWeekAgo,
  }) async {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('ProgressService не инициализирован');
    }

    final updated = snapshot.copyWith(
      currentWeight: currentWeight,
      goalWeight: goalWeight,
      startWeight: startWeight,
      weightWeekAgo: weightWeekAgo,
    );

    _snapshot = updated;

    await Future.wait(<Future<bool>>[
      prefs.setDouble(_currentWeightKey, updated.currentWeight),
      prefs.setDouble(_goalWeightKey, updated.goalWeight),
      prefs.setDouble(_startWeightKey, updated.startWeight),
      prefs.setDouble(_weekAgoWeightKey, updated.weightWeekAgo),
    ]);
  }
}
