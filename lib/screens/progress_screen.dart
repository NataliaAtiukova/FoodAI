import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<List<DiaryEntry>>(
          valueListenable: DiaryService.instance.listenable(),
          builder: (context, __, ___) {
            final totalsMap = DiaryService.instance.totalsByDay();
            final lineData = _buildLineData(totalsMap);
            final todayTotals =
                DiaryService.instance.totalsForDay(DateTime.now());

            return ListView(
              children: <Widget>[
                _ProgressHeader(),
                const SizedBox(height: 20),
                _CaloriesChart(data: lineData),
                const SizedBox(height: 20),
                _MacrosPieCard(totals: todayTotals),
              ],
            );
          },
        ),
      ),
    );
  }

  _LineChartData _buildLineData(Map<DateTime, DailyTotals> totalsMap) {
    final today = DateTime.now();
    final days = List<DateTime>.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });

    final spots = <FlSpot>[];
    double maxCalories = 0;
    for (var i = 0; i < days.length; i++) {
      final totals = totalsMap[days[i]];
      final calories = totals?.calories ?? 0;
      spots.add(FlSpot(i.toDouble(), calories));
      if (calories > maxCalories) {
        maxCalories = calories;
      }
    }

    return _LineChartData(days: days, spots: spots, maxCalories: maxCalories);
  }
}

class _ProgressHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Ваш прогресс',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Следите за калориями и балансом БЖУ за последнюю неделю.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _LineChartData {
  _LineChartData({
    required this.days,
    required this.spots,
    required this.maxCalories,
  });

  final List<DateTime> days;
  final List<FlSpot> spots;
  final double maxCalories;
}

class _CaloriesChart extends StatelessWidget {
  const _CaloriesChart({required this.data});

  final _LineChartData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat.E('ru_RU');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Калории за неделю',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: data.maxCalories == 0 ? 1000 : data.maxCalories * 1.2,
                  borderData: FlBorderData(show: false),
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(formatter.format(data.days[index]));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, _) {
                          if (value % 200 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(value.toStringAsFixed(0));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: data.spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacrosPieCard extends StatelessWidget {
  const _MacrosPieCard({required this.totals});

  final DailyTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totals == null || totals!.calories == 0) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Распределение БЖУ', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                  'Добавьте записи за сегодня, чтобы увидеть диаграмму.'),
            ],
          ),
        ),
      );
    }

    final protein = totals!.protein;
    final fat = totals!.fat;
    final carbs = totals!.carbs;
    final total = protein + fat + carbs;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Распределение БЖУ',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: <PieChartSectionData>[
                    PieChartSectionData(
                      value: protein,
                      color: Colors.green.shade400,
                      title: '${((protein / total) * 100).round()}%',
                      titleStyle: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: carbs,
                      color: Colors.yellow.shade600,
                      title: '${((carbs / total) * 100).round()}%',
                      titleStyle: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: fat,
                      color: Colors.orange.shade400,
                      title: '${((fat / total) * 100).round()}%',
                      titleStyle: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _Legend(color: Colors.green.shade400, label: 'Белки'),
                _Legend(color: Colors.yellow.shade600, label: 'Углеводы'),
                _Legend(color: Colors.orange.shade400, label: 'Жиры'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
