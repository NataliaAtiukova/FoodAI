import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry_v2.dart';
import '../services/diary_service_v2.dart';
import '../services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const double _calorieGoal = 2000;

  late ProgressSnapshot _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _snapshot = ProgressService.instance.snapshot;
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<DiaryEntryV2>>(
        valueListenable: DiaryServiceV2.instance.listenable(),
        builder: (context, _, __) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final theme = Theme.of(context);
          final weeklyData = _computeWeeklyStats();
          final weeklyAverage = weeklyData.isEmpty
              ? 0.0
              : weeklyData.map((d) => d.calories).reduce((a, b) => a + b) /
                  weeklyData.length;
          final todaySummary =
              DiaryServiceV2.instance.getNutritionSummaryForDate(DateTime.now());
          final todayTotal = (todaySummary['calories'] as double?) ?? 0;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text(
                'Progress',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _ProgressSnapshotCard(
                snapshot: _snapshot,
                onAdjustGoal: _showAdjustGoalSheet,
              ),
              const SizedBox(height: 20),
              _DailyIntakeCard(
                data: weeklyData,
                goal: _calorieGoal,
                weeklyAverage: weeklyAverage,
                todayTotal: todayTotal,
              ),
              const SizedBox(height: 20),
              _MacroDistributionCard(summary: todaySummary),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<_DailyCalories> _computeWeeklyStats() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));

    final List<_DailyCalories> data = <_DailyCalories>[];
    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final summary = DiaryServiceV2.instance.getNutritionSummaryForDate(date);
      final calories = (summary['calories'] as double?) ?? 0;
      data.add(_DailyCalories(date: date, calories: calories));
    }
    return data;
  }

  Future<void> _showAdjustGoalSheet() async {
    final theme = Theme.of(context);
    final currentController =
        TextEditingController(text: _snapshot.currentWeight.toStringAsFixed(1));
    final goalController =
        TextEditingController(text: _snapshot.goalWeight.toStringAsFixed(1));

    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Adjust Goal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current weight (kg)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: goalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Goal weight (kg)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      final current = double.tryParse(
            currentController.text.replaceAll(',', '.'),
          ) ??
          _snapshot.currentWeight;
      final goal = double.tryParse(
            goalController.text.replaceAll(',', '.'),
          ) ??
          _snapshot.goalWeight;

      final updatedWeekAgo = _snapshot.currentWeight;

      await ProgressService.instance.update(
        currentWeight: current,
        goalWeight: goal,
        weightWeekAgo: updatedWeekAgo,
        startWeight: _snapshot.startWeight,
      );

      setState(() => _snapshot = ProgressService.instance.snapshot);
    }
  }
}

class _ProgressSnapshotCard extends StatelessWidget {
  const _ProgressSnapshotCard({
    required this.snapshot,
    required this.onAdjustGoal,
  });

  final ProgressSnapshot snapshot;
  final VoidCallback onAdjustGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat('#,##0.0');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.track_changes_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Your Progress Snapshot',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: <Widget>[
              _MetricTile(
                label: 'Current Weight',
                value: '${number.format(snapshot.currentWeight)} kg',
              ),
              _MetricTile(
                label: 'Goal Weight',
                value: '${number.format(snapshot.goalWeight)} kg',
              ),
              _MetricTile(
                label: 'Weekly Change',
                value: _formatChange(snapshot.weeklyChange),
                emphasize: true,
              ),
              _MetricTile(
                label: 'Total Lost',
                value: _formatTotalLost(snapshot.totalLost),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: onAdjustGoal,
            child: const Text('Adjust Goal'),
          ),
        ],
      ),
    );
  }

  String _formatChange(double change) {
    if (change == 0) return '0 kg';
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} kg';
  }

  String _formatTotalLost(double lost) {
    final sign = lost >= 0 ? '' : '+';
    return '$sign${lost.toStringAsFixed(1)} kg';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasize
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DailyIntakeCard extends StatelessWidget {
  const _DailyIntakeCard({
    required this.data,
    required this.goal,
    required this.weeklyAverage,
    required this.todayTotal,
  });

  final List<_DailyCalories> data;
  final double goal;
  final double weeklyAverage;
  final double todayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return const _EmptyCard(
        title: 'Daily Calorie Intake',
        message: 'Добавьте записи в дневник, чтобы увидеть прогресс.',
      );
    }

    final maxY = data.map((d) => d.calories).fold(goal, (max, value) {
      return value > max ? value : max;
    });
    final double chartMax = (maxY + 250).clamp(500, 4000);

    return _CardContainer(
      title: 'Daily Calorie Intake',
      subtitle: 'Last 7 Days Average: ${weeklyAverage.toStringAsFixed(0)} kcal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: chartMax,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black.withValues(alpha: 0.75),
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${data[spot.x.toInt()].label}\n${spot.y.toStringAsFixed(0)} kcal',
                            const TextStyle(color: Colors.white),
                          ),
                        )
                        .toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 500,
                      getTitlesWidget: (value, _) {
                        if (value % 1000 != 0) return const SizedBox();
                        return Text(value.toInt().toString());
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(data[index].shortLabel);
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData:
                    const FlGridData(show: true, horizontalInterval: 500),
                borderData: FlBorderData(show: false),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: data
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.calories,
                            ))
                        .toList(),
                    isCurved: true,
                    barWidth: 4,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(horizontalLines: <HorizontalLine>[
                  HorizontalLine(
                    y: goal,
                    color: theme.colorScheme.tertiary,
                    dashArray: const <int>[4, 4],
                    strokeWidth: 2,
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.centerRight,
                      style: theme.textTheme.labelSmall,
                      labelResolver: (line) => 'Goal: ${goal.toStringAsFixed(0)}',
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Goal: ${goal.toStringAsFixed(0)} kcal   ·   Today: ${todayTotal.toStringAsFixed(0)} kcal',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            todayTotal > goal
                ? 'Слегка выше цели. Попробуйте уменьшить калории на ужин.'
                : 'Отличный прогресс! Продолжайте придерживаться выбранного плана.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MacroDistributionCard extends StatelessWidget {
  const _MacroDistributionCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protein = (summary['protein'] as double?) ?? 0;
    final fat = (summary['fat'] as double?) ?? 0;
    final carbs = (summary['carbs'] as double?) ?? 0;
    final total = protein + fat + carbs;

    if (total <= 0) {
      return const _EmptyCard(
        title: 'Macronutrient Distribution',
        message: 'Запишите приём пищи, чтобы увидеть распределение БЖУ.',
      );
    }

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        color: Colors.green.shade400,
        value: protein,
        title: '${_percentage(protein, total)}%\nProtein',
        radius: 70,
        titleStyle: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orange.shade300,
        value: carbs,
        title: '${_percentage(carbs, total)}%\nCarbs',
        radius: 70,
        titleStyle: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.amber.shade600,
        value: fat,
        title: '${_percentage(fat, total)}%\nFats',
        radius: 70,
        titleStyle: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    ];

    final caloriesValue = (summary['calories'] as double?) ?? 0;
    final caloriesText =
        caloriesValue % 1 == 0 ? caloriesValue.toStringAsFixed(0) : caloriesValue.toStringAsFixed(1);

    return _CardContainer(
      title: 'Macronutrient Distribution',
      subtitle: 'Today\'s Intake: $caloriesText kcal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 50,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total Macros: 100% · Recommended: P30 / C50 / F20',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            protein / total > 0.35
                ? 'Белка чуть больше нормы — отличный выбор для восстановления.'
                : 'Хороший баланс сегодня, продолжайте в том же духе.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _percentage(double value, double total) {
    if (total == 0) return '0';
    return ((value / total) * 100).round().toString();
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DailyCalories {
  const _DailyCalories({required this.date, required this.calories});

  final DateTime date;
  final double calories;

  String get label => DateFormat('EEEE').format(date);

  String get shortLabel => DateFormat('EE').format(date);
}
