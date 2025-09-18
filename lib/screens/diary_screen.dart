import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../models/meal_category.dart';
import '../services/diary_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.onAddFood});

  final VoidCallback onAddFood;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final Set<MealCategory> _expanded = MealCategory.values.toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<Box<DiaryEntry>>(
          valueListenable: DiaryService.instance.listenable(),
          builder: (context, box, _) {
            final grouped = DiaryService.instance.entriesByCategory(normalizedToday);
            final totals = DiaryService.instance.totalsForDay(normalizedToday);
            final hasEntries = grouped.values.any((list) => list.isNotEmpty);
            final timeFormat = DateFormat.Hm();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Мой дневник',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: widget.onAddFood,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить еду'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final category in MealCategory.values)
                    _CategorySection(
                      category: category,
                      entries: grouped[category] ?? const <DiaryEntry>[],
                      expanded: _expanded.contains(category),
                      onToggle: () {
                        setState(() {
                          if (_expanded.contains(category)) {
                            _expanded.remove(category);
                          } else {
                            _expanded.add(category);
                          }
                        });
                      },
                      timeFormat: timeFormat,
                    ),
                  if (!hasEntries)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Пока нет записей. Добавьте блюдо из раздела Home.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Итоги за день',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (totals != null)
                    _TotalsCard(totals: totals)
                  else
                    _EmptyTotalsCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat('#,##0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          _Metric(title: 'Калории', value: '${number.format(totals.calories)} ккал'),
          _Metric(title: 'Белки', value: '${number.format(totals.protein)} г'),
          _Metric(title: 'Жиры', value: '${number.format(totals.fat)} г'),
          _Metric(title: 'Углеводы', value: '${number.format(totals.carbs)} г'),
        ],
      ),
    );
  }
}

class _EmptyTotalsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        'Нет данных за сегодня. Добавьте блюдо, чтобы увидеть сводку.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.entries,
    required this.expanded,
    required this.onToggle,
    required this.timeFormat,
  });

  final MealCategory category;
  final List<DiaryEntry> entries;
  final bool expanded;
  final VoidCallback onToggle;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: (_) => onToggle(),
          title: Text(
            category.displayName,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: entries.isEmpty
              ? <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Нет записей в этой категории.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ]
              : entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DiaryEntryTile(entry: entry, timeFormat: timeFormat),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _DiaryEntryTile extends StatelessWidget {
  const _DiaryEntryTile({required this.entry, required this.timeFormat});

  final DiaryEntry entry;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = timeFormat.format(entry.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _EntryAvatar(path: entry.imagePath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (entry.brand != null && entry.brand!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      entry.brand!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${entry.calories.toStringAsFixed(0)} ккал · $timeText',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Источник: ${entry.source}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Б:${entry.protein.toStringAsFixed(0)}г · Ж:${entry.fat.toStringAsFixed(0)}г · У:${entry.carbs.toStringAsFixed(0)}г',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_outlined),
              onPressed: () => _editNote(context, entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => DiaryService.instance.deleteEntry(entry.id),
            ),
          ],
        ),
        if (entry.labels != null && entry.labels!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entry.labels!
                .map((label) => Chip(
                      label: Text(label),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        if (entry.note != null && entry.note!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(entry.note!, style: theme.textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }

  Future<void> _editNote(BuildContext context, DiaryEntry entry) async {
    final controller = TextEditingController(text: entry.note);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Заметка',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Сохранить заметку'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await DiaryService.instance.updateNote(entry.id, result.isEmpty ? null : result);
    }
  }
}

class _EntryAvatar extends StatelessWidget {
  const _EntryAvatar({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (path != null && File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(path!),
          height: 60,
          width: 60,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
