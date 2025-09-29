import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/advice_entry.dart';
import '../models/meal_plan_entry.dart';
import '../models/recipe_entry.dart';

class AdviceCard extends StatelessWidget {
  const AdviceCard({super.key, required this.entry, required this.onDelete});

  final AdviceEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = entry.text.split(RegExp(r'\n|\r')).where((line) {
      final trimmed = line.trim();
      return trimmed.isNotEmpty;
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🤖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('d MMMM, HH:mm', 'ru').format(entry.createdAt),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('• '),
                    Expanded(
                      child: Text(
                        line.replaceFirst(RegExp(r'^[-•\d\.\) ]+'), ''),
                        style: theme.textTheme.bodyMedium,
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

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.entry, required this.onDelete});

  final RecipeEntry entry;
  final VoidCallback onDelete;

  Map<String, dynamic> get _payload {
    try {
      return jsonDecode(entry.text) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'description': entry.text};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = _payload;
    final description = (payload['description'] ?? '') as String;
    final ingredients = (payload['ingredients'] ?? '') as String;
    final macros = (payload['macros'] ?? '') as String;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('d MMMM HH:mm', 'ru')
                            .format(entry.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (ingredients.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const TagLabel(text: 'Ингредиенты'),
              const SizedBox(height: 4),
              Text(ingredients, style: theme.textTheme.bodyMedium),
            ],
            if (macros.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const TagLabel(text: 'Пищевая ценность'),
              const SizedBox(height: 4),
              Text(macros, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class MealPlanCard extends StatelessWidget {
  const MealPlanCard({super.key, required this.entry, required this.onDelete});

  final MealPlanEntry entry;
  final VoidCallback onDelete;

  Map<String, dynamic> get _payload {
    try {
      return jsonDecode(entry.text) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = _payload;
    final days = (payload['days'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 16,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('d MMMM HH:mm', 'ru').format(entry.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        children: days.isEmpty
            ? <Widget>[
                Text(
                  'Не удалось разобрать план питания. Попробуйте сгенерировать снова.',
                  style: theme.textTheme.bodyMedium,
                ),
              ]
            : days
                .map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: MealDayTile(day: day),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class MealDayTile extends StatelessWidget {
  const MealDayTile({super.key, required this.day});

  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meals = (day['meals'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          (day['day'] ?? 'День') as String,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...meals.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    (meal['title'] ?? '') as String,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meal['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        meal['description'] as String,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (meal['calories'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${meal['calories']} ккал',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TagLabel extends StatelessWidget {
  const TagLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder(
      {super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
