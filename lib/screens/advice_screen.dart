import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final List<String> _baseTips = const <String>[
    'Старайтесь заполнять тарелку наполовину овощами или зеленью — это добавит витаминов и клетчатки.',
    'Не забывайте про воду: 1–2 стакана перед приёмом пищи помогают контролировать аппетит.',
    'Добавляйте источники белка в каждый приём пищи — так легче добирать норму и сохранять сытость.',
    'Запланируйте перекус с полезными жирными кислотами: горсть орехов или авокадо.',
    'Соблюдайте правило «половина тарелки овощей, четверть белка, четверть сложных углеводов».',
    'Готовьте заранее: порция цельнозерновых и белка в холодильнике экономит время и силы.',
  ];

  late int _tipIndex;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _tipIndex = DateTime.now().day % _baseTips.length;
  }

  void _shuffleTip() {
    setState(() {
      _tipIndex = _random.nextInt(_baseTips.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Советы по питанию',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Раздел с рекомендациями: случайные подсказки и советы на основе дневника.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                tabs: const <Tab>[
                  Tab(text: 'Случайные'),
                  Tab(text: 'По дневнику'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ValueListenableBuilder<List<DiaryEntry>>(
                  valueListenable: DiaryService.instance.listenable(),
                  builder: (context, entries, _) {
                    final totals =
                        DiaryService.instance.totalsForDay(DateTime.now());
                    final dynamicTips = _buildDynamicTips(totals);
                    final number = NumberFormat('#,##0');
                    final decimal = NumberFormat('#,##0.0');
                    String format(double value) => value % 1 == 0
                        ? number.format(value)
                        : decimal.format(value);

                    return TabBarView(
                      children: <Widget>[
                        ListView(
                          children: <Widget>[
                            _AdviceCard(
                              icon: Icons.lightbulb_outline,
                              title: 'На заметку',
                              message: _baseTips[_tipIndex],
                              trailing: FilledButton.tonalIcon(
                                onPressed: _shuffleTip,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Другой совет'),
                              ),
                            ),
                          ],
                        ),
                        ListView(
                          children: <Widget>[
                            if (totals != null)
                              _DailySummaryCard(totals: totals, format: format)
                            else
                              const _AdviceCard(
                                icon: Icons.info_outline,
                                title: 'Добавьте блюда',
                                message:
                                    'Чтобы получить персональные рекомендации, заполните дневник питания.',
                              ),
                            const SizedBox(height: 16),
                            if (dynamicTips.isEmpty)
                              const _AdviceCard(
                                icon: Icons.check_circle_outline,
                                title: 'Баланс в норме',
                                message:
                                    'Отличный баланс! Продолжайте следить за рационом и пить достаточное количество воды.',
                              )
                            else
                              ...dynamicTips.map(
                                (tip) => _AdviceCard(
                                  icon: Icons.restaurant,
                                  title: 'Совет на сегодня',
                                  message: tip,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildDynamicTips(DailyTotals? totals) {
    if (totals == null) {
      return const <String>[];
    }
    final suggestions = <String>[];

    if (totals.calories < 1200) {
      suggestions.add(
          'Вы получили менее 1200 ккал — добавьте полезный перекус с белком или сложными углеводами.');
    } else if (totals.calories > 2300) {
      suggestions.add(
          'Калорийность дня выше обычного. Подумайте о более лёгком ужине или дополнительной активности.');
    }

    if (totals.protein < totals.carbs * 0.25) {
      suggestions.add(
          'Белка заметно меньше, чем углеводов. Добавьте яйца, рыбу, творог или бобовые в один из приёмов пищи.');
    }

    if (totals.fat > totals.calories * 0.35 / 9) {
      suggestions.add(
          'Доля жиров сегодня высокая. Попробуйте заменить жареные блюда на запечённые или добавить больше овощей.');
    }

    if (suggestions.isEmpty) {
      suggestions.add(
          'Баланс по калориям и БЖУ выглядит ровно — продолжайте в том же духе и не забывайте про воду.');
    }

    return suggestions;
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.icon,
    required this.title,
    required this.message,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(icon, color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.totals, required this.format});

  final DailyTotals totals;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Итоги за сегодня',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                _SummaryMetric(
                    title: 'Калории', value: '${format(totals.calories)} ккал'),
                _SummaryMetric(
                    title: 'Белки', value: '${format(totals.protein)} г'),
                _SummaryMetric(title: 'Жиры', value: '${format(totals.fat)} г'),
                _SummaryMetric(
                    title: 'Углеводы', value: '${format(totals.carbs)} г'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
