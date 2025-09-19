import 'package:flutter/material.dart';
import '../models/diary_entry_v2.dart';
import '../services/ai_content_service.dart';
import '../services/diary_service_v2.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final AiContentService _aiService = AiContentService.instance;

  bool _isAdviceLoading = false;
  bool _isRecipesLoading = false;
  bool _isMealPlanLoading = false;

  String _goalAdvice = 'ЗОЖ';
  String _goalMealPlan = 'ЗОЖ';
  double _calorieTarget = 2000;

  String? _adviceText;
  String? _adviceError;

  List<Map<String, dynamic>> _recipes = const <Map<String, dynamic>>[];
  String? _recipesError;

  Map<String, dynamic>? _mealPlan;
  String? _mealPlanError;

  final Set<String> _selectedProducts = <String>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<DiaryEntryV2>>(
        valueListenable: DiaryServiceV2.instance.listenable(),
        builder: (context, entries, __) {
          final theme = Theme.of(context);
          final todaySummary = DiaryServiceV2.instance
              .getNutritionSummaryForDate(DateTime.now());
          final availableProducts = _extractAvailableProducts(entries);

          if (_selectedProducts.isNotEmpty) {
            _selectedProducts
                .removeWhere((element) => !availableProducts.contains(element));
          }

          return DefaultTabController(
            length: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AI помощник',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Получайте советы, рецепты и планы питания с учётом вашего дневника.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor:
                        theme.colorScheme.primary.withValues(alpha: 0.6),
                    labelStyle: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    indicatorColor: theme.colorScheme.primary,
                    tabs: const <Tab>[
                      Tab(text: 'AI Советы'),
                      Tab(text: 'Рецепты'),
                      Tab(text: 'План питания'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _AdviceTab(
                          isConfigured: _aiService.isConfigured,
                          isLoading: _isAdviceLoading,
                          error: _adviceError,
                          adviceText: _adviceText,
                          goal: _goalAdvice,
                          onGoalChanged: (goal) =>
                              setState(() => _goalAdvice = goal),
                          onGenerate: () => _generateAdvice(todaySummary),
                          hasEntries:
                              (todaySummary['entryCount'] as int? ?? 0) > 0,
                        ),
                        _RecipesTab(
                          isConfigured: _aiService.isConfigured,
                          isLoading: _isRecipesLoading,
                          error: _recipesError,
                          recipes: _recipes,
                          availableProducts: availableProducts,
                          selectedProducts: _selectedProducts,
                          onToggleProduct: (product) {
                            setState(() {
                              if (_selectedProducts.contains(product)) {
                                _selectedProducts.remove(product);
                              } else {
                                _selectedProducts.add(product);
                              }
                            });
                          },
                          onGenerate: () => _generateRecipes(todaySummary),
                        ),
                        _MealPlanTab(
                          isConfigured: _aiService.isConfigured,
                          isLoading: _isMealPlanLoading,
                          error: _mealPlanError,
                          mealPlan: _mealPlan,
                          goal: _goalMealPlan,
                          calorieTarget: _calorieTarget,
                          onGoalChanged: (goal) =>
                              setState(() => _goalMealPlan = goal),
                          onCaloriesChanged: (value) =>
                              setState(() => _calorieTarget = value),
                          onGenerate: _generateMealPlan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateAdvice(Map<String, dynamic> summary) async {
    setState(() {
      _isAdviceLoading = true;
      _adviceError = null;
    });

    final entries = DiaryServiceV2.instance.getEntriesForDate(DateTime.now());

    try {
      final text = await _aiService.generateAdvice(
        diaryEntries: entries,
        nutritionSummary: summary,
        userGoal: _goalAdvice,
      );
      if (!mounted) return;
      setState(() => _adviceText = text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _adviceError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isAdviceLoading = false);
      }
    }
  }

  Future<void> _generateRecipes(Map<String, dynamic> summary) async {
    setState(() {
      _isRecipesLoading = true;
      _recipesError = null;
    });

    final selected = _selectedProducts.isEmpty
        ? _extractAvailableProducts(DiaryServiceV2.instance.getAllEntries())
            .take(3)
            .toList()
        : _selectedProducts.toList();

    if (selected.isEmpty) {
      setState(() {
        _isRecipesLoading = false;
        _recipesError = 'Добавьте хотя бы один продукт в дневник.';
      });
      return;
    }

    try {
      final ideas = await _aiService.generateRecipes(
        selectedProducts: selected,
        nutritionSummary: summary,
      );
      if (!mounted) return;
      setState(() => _recipes = ideas);
    } catch (error) {
      if (!mounted) return;
      setState(() => _recipesError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isRecipesLoading = false);
      }
    }
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isMealPlanLoading = true;
      _mealPlanError = null;
    });

    try {
      final plan = await _aiService.generateMealPlan(
        goal: _goalMealPlan,
        caloriesTarget: _calorieTarget.round(),
      );
      if (!mounted) return;
      setState(() => _mealPlan = plan);
    } catch (error) {
      if (!mounted) return;
      setState(() => _mealPlanError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isMealPlanLoading = false);
      }
    }
  }

  Set<String> _extractAvailableProducts(List<DiaryEntryV2> entries) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 14));
    final recentEntries = entries
        .where((entry) => entry.timestamp.isAfter(cutoff))
        .toList(growable: false);
    return recentEntries.map((entry) => entry.name).toSet();
  }
}

class _AdviceTab extends StatelessWidget {
  const _AdviceTab({
    required this.isConfigured,
    required this.isLoading,
    required this.error,
    required this.adviceText,
    required this.goal,
    required this.onGoalChanged,
    required this.onGenerate,
    required this.hasEntries,
  });

  final bool isConfigured;
  final bool isLoading;
  final String? error;
  final String? adviceText;
  final String goal;
  final ValueChanged<String> onGoalChanged;
  final VoidCallback onGenerate;
  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        if (!isConfigured)
          const _InfoBanner(
            icon: Icons.info_outline,
            message:
                'AI советы работают и без ключей, но для YandexGPT или ChatGPT укажите токены через --dart-define.',
          ),
        _GoalSelector(
          label: 'Цель питания',
          value: goal,
          onChanged: onGoalChanged,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isLoading ? null : onGenerate,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.psychology_outlined),
          label: Text(isLoading ? 'Анализ…' : 'Сгенерировать рекомендации'),
        ),
        const SizedBox(height: 16),
        if (!hasEntries)
          const _InfoBanner(
            icon: Icons.restaurant_menu,
            message:
                'За сегодня нет записей. Добавьте блюда, чтобы получить персональные советы.',
            tone: InfoTone.muted,
          ),
        if (error != null)
          _InfoBanner(
            icon: Icons.error_outline,
            message: error!,
            tone: InfoTone.error,
          )
        else if (adviceText != null)
          _AdviceCard(text: adviceText!),
      ],
    );
  }
}

class _RecipesTab extends StatelessWidget {
  const _RecipesTab({
    required this.isConfigured,
    required this.isLoading,
    required this.error,
    required this.recipes,
    required this.availableProducts,
    required this.selectedProducts,
    required this.onToggleProduct,
    required this.onGenerate,
  });

  final bool isConfigured;
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> recipes;
  final Set<String> availableProducts;
  final Set<String> selectedProducts;
  final ValueChanged<String> onToggleProduct;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: <Widget>[
        if (!isConfigured)
          const _InfoBanner(
            icon: Icons.info_outline,
            message:
                'Чтобы улучшить рецепты, добавьте ключи YandexGPT или OpenAI. Без них будут использоваться встроенные рекомендации.',
          ),
        Text(
          'Выберите продукты из дневника',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (availableProducts.isEmpty)
          const _InfoBanner(
            icon: Icons.restaurant,
            message:
                'Добавьте блюда в дневник за последние две недели, чтобы получить рецепты.',
            tone: InfoTone.muted,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableProducts
                .map(
                  (product) => FilterChip(
                    label: Text(product),
                    selected: selectedProducts.contains(product),
                    onSelected: (_) => onToggleProduct(product),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isLoading ? null : onGenerate,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.menu_book_outlined),
          label: Text(isLoading ? 'Генерация…' : 'Подобрать рецепты'),
        ),
        const SizedBox(height: 16),
        if (error != null)
          _InfoBanner(
            icon: Icons.error_outline,
            message: error!,
            tone: InfoTone.error,
          )
        else if (recipes.isNotEmpty)
          ...recipes.map((recipe) => _RecipeCard(recipe: recipe)),
      ],
    );
  }
}

class _MealPlanTab extends StatelessWidget {
  const _MealPlanTab({
    required this.isConfigured,
    required this.isLoading,
    required this.error,
    required this.mealPlan,
    required this.goal,
    required this.calorieTarget,
    required this.onGoalChanged,
    required this.onCaloriesChanged,
    required this.onGenerate,
  });

  final bool isConfigured;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? mealPlan;
  final String goal;
  final double calorieTarget;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<double> onCaloriesChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: <Widget>[
        if (!isConfigured)
          const _InfoBanner(
            icon: Icons.info_outline,
            message:
                'План питания можно улучшить с помощью внешних моделей. Добавьте ключи, чтобы получить более точные рекомендации.',
          ),
        _GoalSelector(
          label: 'Цель недели',
          value: goal,
          onChanged: onGoalChanged,
        ),
        const SizedBox(height: 16),
        Text(
          'Целевая калорийность: ${calorieTarget.round()} ккал/день',
          style: theme.textTheme.bodyLarge,
        ),
        Slider(
          value: calorieTarget,
          min: 1200,
          max: 3500,
          divisions: 23,
          label: '${calorieTarget.round()} ккал',
          onChanged: onCaloriesChanged,
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : onGenerate,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.calendar_month_outlined),
          label: Text(isLoading ? 'Генерация…' : 'Сформировать план'),
        ),
        const SizedBox(height: 16),
        if (error != null)
          _InfoBanner(
            icon: Icons.error_outline,
            message: error!,
            tone: InfoTone.error,
          )
        else if (mealPlan != null)
          _MealPlanView(mealPlan: mealPlan!),
      ],
    );
  }
}

class _GoalSelector extends StatelessWidget {
  const _GoalSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _goals = <String>[
    'Похудение',
    'Набор массы',
    'ЗОЖ'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: _goals
              .map(
                (goal) => DropdownMenuItem<String>(
                  value: goal,
                  child: Text(goal),
                ),
              )
              .toList(),
          onChanged: (goal) {
            if (goal != null) {
              onChanged(goal);
            }
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Map<String, dynamic> recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = recipe['title']?.toString() ?? 'Рецепт';
    final description = recipe['description']?.toString() ?? '';
    final ingredients = recipe['ingredients']?.toString() ?? '';
    final macros = recipe['macros']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (ingredients.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Ингредиенты',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(ingredients, style: theme.textTheme.bodyMedium),
            ],
            if (macros.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                macros,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealPlanView extends StatelessWidget {
  const _MealPlanView({required this.mealPlan});

  final Map<String, dynamic> mealPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = mealPlan['days'] as List<dynamic>? ?? const <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...days.whereType<Map<String, dynamic>>().map((day) {
          final dayTitle = day['day']?.toString() ?? '';
          final meals = day['meals'] as List<dynamic>? ?? const <dynamic>[];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    dayTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...meals.whereType<Map<String, dynamic>>().map((meal) {
                    final title = meal['title']?.toString() ?? 'Приём пищи';
                    final description = meal['description']?.toString() ?? '';
                    final calories = meal['calories'];
                    final caloriesText = calories is num
                        ? '${calories.round()} ккал'
                        : (calories?.toString() ?? '');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (caloriesText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                caloriesText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                description,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

enum InfoTone { normal, muted, error }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    this.tone = InfoTone.normal,
  });

  final IconData icon;
  final String message;
  final InfoTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color background;
    Color textColor;

    switch (tone) {
      case InfoTone.muted:
        background = colorScheme.surface.withValues(alpha: 0.35);
        textColor = colorScheme.onSurfaceVariant;
        break;
      case InfoTone.error:
        background = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        break;
      case InfoTone.normal:
        background = colorScheme.secondaryContainer.withValues(alpha: 0.35);
        textColor = colorScheme.onSecondaryContainer;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
