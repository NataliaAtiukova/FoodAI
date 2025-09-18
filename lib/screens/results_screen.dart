import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../models/vision_prediction.dart';
import '../services/diary_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.analysis,
    required this.goal,
    this.imagePath,
    this.predictions,
    required this.source,
  });

  final NutritionAnalysis analysis;
  final NutritionGoal goal;
  final String? imagePath;
  final List<VisionPrediction>? predictions;
  final String source;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  MealCategory _selectedCategory = MealCategory.breakfast;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final facts = widget.analysis.result.facts;
      await DiaryService.instance.addEntry(
        name: widget.analysis.result.name,
        calories: facts.calories,
        protein: facts.protein,
        fat: facts.fat,
        carbs: facts.carbs,
        goal: widget.goal.label,
        advice: widget.analysis.advice,
        category: _selectedCategory,
        source: widget.source,
        imagePath: widget.imagePath,
        labels: widget.predictions
            ?.map((prediction) =>
                '${prediction.label} (${prediction.confidencePercent()})')
            .toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено в дневник.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = widget.analysis.result.facts;
    final numberFormat = NumberFormat('#,##0.0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ блюда'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.analysis.result.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.imagePath != null && File(widget.imagePath!).existsSync()) ...<Widget>[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(widget.imagePath!),
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _MacroCard(
                            title: 'Калории',
                            value: '${numberFormat.format(facts.calories)} ккал',
                          ),
                          _MacroCard(
                            title: 'Белки',
                            value: '${numberFormat.format(facts.protein)} г',
                          ),
                          _MacroCard(
                            title: 'Жиры',
                            value: '${numberFormat.format(facts.fat)} г',
                          ),
                          _MacroCard(
                            title: 'Углеводы',
                            value: '${numberFormat.format(facts.carbs)} г',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MealCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Категория приёма пищи',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: MealCategory.values
                    .map(
                      (category) => DropdownMenuItem<MealCategory>(
                        value: category,
                        child: Text(category.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Icons.bolt,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Совет FoodAI',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.analysis.advice,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.predictions != null && widget.predictions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: widget.predictions!
                        .take(8)
                        .map(
                          (prediction) => Chip(
                            label: Text(
                              '${prediction.label} · ${prediction.confidencePercent()}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Сохранить в дневник'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
