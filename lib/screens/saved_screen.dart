import 'package:flutter/material.dart';

import '../models/advice_entry.dart';
import '../models/meal_plan_entry.dart';
import '../models/recipe_entry.dart';
import '../services/ai_history_service.dart';
import '../widgets/ai_cards.dart';

enum SavedFilter { advice, recipes, plans }

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final AiHistoryService _history = AiHistoryService.instance;
  SavedFilter _currentFilter = SavedFilter.advice;

  @override
  void initState() {
    super.initState();
    _history.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Сохранённое',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Просматривайте советы, рецепты и планы питания, сохранённые офлайн. '
              'Можно пересмотреть или удалить ненужные материалы.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<SavedFilter>(
              segments: const <ButtonSegment<SavedFilter>>[
                ButtonSegment(
                  value: SavedFilter.advice,
                  icon: Text('🤖'),
                  label: Text('Советы'),
                ),
                ButtonSegment(
                  value: SavedFilter.recipes,
                  icon: Text('🍽️'),
                  label: Text('Рецепты'),
                ),
                ButtonSegment(
                  value: SavedFilter.plans,
                  icon: Text('📅'),
                  label: Text('Планы'),
                ),
              ],
              selected: <SavedFilter>{_currentFilter},
              onSelectionChanged: (selection) {
                setState(() => _currentFilter = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentFilter) {
      case SavedFilter.advice:
        return ValueListenableBuilder<List<AdviceEntry>>(
          valueListenable: _history.adviceListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.psychology_alt_outlined,
                message: 'Здесь появятся советы, сохранённые после генерации.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AdviceCard(
                  entry: entry,
                  onDelete: () => _confirmDelete(
                    onConfirm: () => _history.deleteAdvice(entry.id),
                  ),
                );
              },
            );
          },
        );
      case SavedFilter.recipes:
        return ValueListenableBuilder<List<RecipeEntry>>(
          valueListenable: _history.recipeListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.restaurant_outlined,
                message:
                    'Сохраняйте рецепты из вкладки AI, чтобы вернуться к ним позже.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return RecipeCard(
                  entry: entry,
                  onDelete: () => _confirmDelete(
                    onConfirm: () => _history.deleteRecipe(entry.id),
                  ),
                );
              },
            );
          },
        );
      case SavedFilter.plans:
        return ValueListenableBuilder<List<MealPlanEntry>>(
          valueListenable: _history.mealPlanListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.event_note_outlined,
                message: 'Планы питания появятся здесь после генерации.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return MealPlanCard(
                  entry: entry,
                  onDelete: () => _confirmDelete(
                    onConfirm: () => _history.deleteMealPlan(entry.id),
                  ),
                );
              },
            );
          },
        );
    }
  }

  Future<void> _confirmDelete(
      {required Future<void> Function() onConfirm}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить запись?'),
          content: const Text('Действие нельзя отменить.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await onConfirm();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Удалено.')),
        );
    }
  }
}
