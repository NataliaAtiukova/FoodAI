import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/manual_food_data.dart';
import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../services/diary_service.dart';
import '../services/nutrition_service.dart';

class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  NutritionGoal _selectedGoal = NutritionGoal.healthyLifestyle;
  bool _isSaving = false;

  Future<void> _addManualFood(ManualFood food) async {
    final controller = TextEditingController(text: '100');
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
              Text(
                'Сколько граммов "${food.name}"?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'г',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(controller.text.replaceAll(',', '.'));
                  Navigator.of(context).pop(value);
                },
                child: const Text('Добавить'),
              ),
            ],
          ),
        );
      },
    );

    if (grams == null || grams <= 0 || !mounted) {
      return;
    }

    final category = await _pickDiaryCategory();
    if (category == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final ratio = grams / 100;
      final facts = NutritionFacts(
        calories: food.factsPer100g.calories * ratio,
        protein: food.factsPer100g.protein * ratio,
        fat: food.factsPer100g.fat * ratio,
        carbs: food.factsPer100g.carbs * ratio,
      );

      String advice;
      try {
        advice = await NutritionService.instance.fetchDietAdvice(
          facts,
          _selectedGoal,
          productName: food.name,
        );
      } catch (_) {
        advice = 'Добавлено вручную.';
      }

      await DiaryService.instance.addEntry(
        name: food.name,
        brand: null,
        calories: facts.calories,
        protein: facts.protein,
        fat: facts.fat,
        carbs: facts.carbs,
        goal: _selectedGoal.label,
        advice: advice,
        category: category,
        source: 'Ручной ввод',
      );

      if (!mounted) {
        return;
      }
      _showSnackBar('"${food.name}" добавлен в дневник');
    } catch (error) {
      _showSnackBar('Не удалось добавить: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<MealCategory?> _pickDiaryCategory() async {
    MealCategory selected = MealCategory.breakfast;
    return showModalBottomSheet<MealCategory>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Категория приёма пищи',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...MealCategory.values.map(
                    (category) => RadioListTile<MealCategory>(
                      value: category,
                      groupValue: selected,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selected = value);
                        }
                      },
                      title: Text(category.displayName),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat('#,##0');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ручной ввод',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NutritionGoal>(
              value: _selectedGoal,
              decoration: const InputDecoration(
                labelText: 'Цель питания',
                border: OutlineInputBorder(),
              ),
              onChanged: _isSaving
                  ? null
                  : (goal) {
                      if (goal != null) {
                        setState(() => _selectedGoal = goal);
                      }
                    },
              items: NutritionGoal.values
                  .map(
                    (goal) => DropdownMenuItem<NutritionGoal>(
                      value: goal,
                      child: Text(goal.displayName),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: kManualFoodCategories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final categoryName = kManualFoodCategories.keys.elementAt(index);
                  final foods = kManualFoodCategories[categoryName]!;
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                    child: ExpansionTile(
                      title: Text(
                        categoryName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: foods
                          .map(
                            (food) => ListTile(
                              title: Text(food.name),
                              subtitle: Text(
                                'ккал: ${number.format(food.factsPer100g.calories)} · '
                                'Б:${food.factsPer100g.protein.toStringAsFixed(1)} '
                                'Ж:${food.factsPer100g.fat.toStringAsFixed(1)} '
                                'У:${food.factsPer100g.carbs.toStringAsFixed(1)} /100г',
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: _isSaving ? null : () => _addManualFood(food),
                                child: const Text('Добавить'),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
