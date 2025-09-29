import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/advice_entry.dart';
import '../models/meal_plan_entry.dart';
import '../models/recipe_entry.dart';
import '../services/ai_content_service.dart';
import '../services/ai_history_service.dart';
import '../services/diary_service_v2.dart';
import '../widgets/ai_cards.dart';

enum AiRequestType { advice, recipes, mealPlan }

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiContentService _aiService = AiContentService.instance;
  final AiHistoryService _historyService = AiHistoryService.instance;

  AiRequestType _selectedType = AiRequestType.advice;
  bool _isLoading = false;
  String? _errorMessage;

  String _adviceGoal = 'ЗОЖ';
  final Set<String> _selectedProducts = <String>{};
  String _mealPlanGoal = 'ЗОЖ';
  double _mealPlanCalories = 2000;

  @override
  void initState() {
    super.initState();
    _historyService.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableProducts = _collectRecentProducts();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AI помощник',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Получайте советы, рецепты и планы питания c помощью YandexGPT '
              'или встроенных подборок. Все результаты сохраняются офлайн.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<AiRequestType>(
              segments: const <ButtonSegment<AiRequestType>>[
                ButtonSegment(
                  value: AiRequestType.advice,
                  label: Text('Советы'),
                  icon: Text('🤖'),
                ),
                ButtonSegment(
                  value: AiRequestType.recipes,
                  label: Text('Рецепты'),
                  icon: Text('🍽️'),
                ),
                ButtonSegment(
                  value: AiRequestType.mealPlan,
                  label: Text('Планы'),
                  icon: Text('📅'),
                ),
              ],
              selected: <AiRequestType>{_selectedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedType = selection.first;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildControls(theme, availableProducts),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _handleGenerate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.auto_awesome),
              label:
                  Text(_isLoading ? 'Генерация…' : 'Сгенерировать результат'),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.error_outline,
                tone: InfoBannerTone.error,
                message: _errorMessage!,
              ),
            ],
            if (!_aiService.isConfigured) ...<Widget>[
              const SizedBox(height: 12),
              const _InfoBanner(
                icon: Icons.info_outline,
                tone: InfoBannerTone.muted,
                message:
                    'Ключи YandexGPT не настроены. Используются офлайн-шаблоны.',
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme, Set<String> availableProducts) {
    switch (_selectedType) {
      case AiRequestType.advice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Цель питания', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _adviceGoal,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                    value: 'ЗОЖ', child: Text('Здоровый образ жизни')),
                DropdownMenuItem(value: 'Похудение', child: Text('Похудение')),
                DropdownMenuItem(
                    value: 'Набор массы', child: Text('Набор мышечной массы')),
                DropdownMenuItem(value: 'Баланс', child: Text('Баланс КБЖУ')),
              ],
              onChanged: (value) =>
                  setState(() => _adviceGoal = value ?? _adviceGoal),
            ),
          ],
        );
      case AiRequestType.recipes:
        final hasProducts = availableProducts.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Выберите продукты из дневника',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!hasProducts)
              const _InfoBanner(
                icon: Icons.restaurant,
                message:
                    'Добавьте продукты в дневник за последние 14 дней, чтобы сформировать рецепты.',
                tone: InfoBannerTone.muted,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableProducts
                    .map(
                      (product) => FilterChip(
                        label: Text(product),
                        selected: _selectedProducts.contains(product),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedProducts.add(product);
                            } else {
                              _selectedProducts.remove(product);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      case AiRequestType.mealPlan:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Цель питания', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _mealPlanGoal,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                    value: 'ЗОЖ', child: Text('Здоровый образ жизни')),
                DropdownMenuItem(value: 'Похудение', child: Text('Похудение')),
                DropdownMenuItem(
                    value: 'Набор массы', child: Text('Набор массы')),
                DropdownMenuItem(value: 'Баланс', child: Text('Баланс КБЖУ')),
              ],
              onChanged: (value) =>
                  setState(() => _mealPlanGoal = value ?? _mealPlanGoal),
            ),
            const SizedBox(height: 16),
            Text('Целевая калорийность', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Slider(
              value: _mealPlanCalories,
              min: 1200,
              max: 3500,
              divisions: 23,
              label: '${_mealPlanCalories.round()} ккал',
              onChanged: (value) => setState(() => _mealPlanCalories = value),
            ),
          ],
        );
    }
  }

  Widget _buildResultsList() {
    switch (_selectedType) {
      case AiRequestType.advice:
        return ValueListenableBuilder<List<AdviceEntry>>(
          valueListenable: _historyService.adviceListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.tips_and_updates_outlined,
                message: 'Сгенерируйте первый совет, чтобы увидеть результат.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AdviceCard(
                  entry: entry,
                  onDelete: () => _historyService.deleteAdvice(entry.id),
                );
              },
            );
          },
        );
      case AiRequestType.recipes:
        return ValueListenableBuilder<List<RecipeEntry>>(
          valueListenable: _historyService.recipeListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.restaurant_menu,
                message:
                    'Пока нет рецептов. Выберите продукты и сгенерируйте идеи.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return RecipeCard(
                  entry: entry,
                  onDelete: () => _historyService.deleteRecipe(entry.id),
                );
              },
            );
          },
        );
      case AiRequestType.mealPlan:
        return ValueListenableBuilder<List<MealPlanEntry>>(
          valueListenable: _historyService.mealPlanListenable,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.calendar_today_outlined,
                message:
                    'Создайте план питания, он сохранится и будет доступен офлайн.',
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return MealPlanCard(
                  entry: entry,
                  onDelete: () => _historyService.deleteMealPlan(entry.id),
                );
              },
            );
          },
        );
    }
  }

  Future<void> _handleGenerate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_selectedType) {
        case AiRequestType.advice:
          await _generateAdvice();
          break;
        case AiRequestType.recipes:
          await _generateRecipes();
          break;
        case AiRequestType.mealPlan:
          await _generateMealPlan();
          break;
      }
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAdvice() async {
    final summary =
        DiaryServiceV2.instance.getNutritionSummaryForDate(DateTime.now());
    final entries = DiaryServiceV2.instance.getEntriesForDate(DateTime.now());

    final result = await _aiService.generateAdvice(
      diaryEntries: entries,
      nutritionSummary: summary,
      userGoal: _adviceGoal,
    );

    await _historyService.saveAdvice(result);
    _showSnack('Совет сохранён');
  }

  Future<void> _generateRecipes() async {
    final products = _selectedProducts.isNotEmpty
        ? _selectedProducts.toList()
        : _collectRecentProducts().take(3).toList();

    if (products.isEmpty) {
      throw Exception('Не найдено продуктов для формирования рецептов.');
    }

    final summary =
        DiaryServiceV2.instance.getNutritionSummaryForDate(DateTime.now());

    final recipes = await _aiService.generateRecipes(
      selectedProducts: products,
      nutritionSummary: summary,
    );

    if (recipes.isEmpty) {
      throw Exception('AI не вернул рецепт. Попробуйте ещё раз.');
    }

    await _historyService.saveRecipes(recipes);
    _showSnack('Рецепты сохранены');
  }

  Future<void> _generateMealPlan() async {
    final plan = await _aiService.generateMealPlan(
      goal: _mealPlanGoal,
      caloriesTarget: _mealPlanCalories.round(),
    );

    await _historyService.saveMealPlan(
      title:
          '$_mealPlanGoal · ${_mealPlanCalories.round()} ккал · ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      payload: plan,
    );
    _showSnack('План питания сохранён');
  }

  Set<String> _collectRecentProducts() {
    final entries = DiaryServiceV2.instance.getAllEntries();
    if (entries.isEmpty) return <String>{};

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 14));
    final recent = entries.where((entry) => entry.timestamp.isAfter(cutoff));
    return recent.map((entry) => entry.name).toSet();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum InfoBannerTone { normal, muted, error }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    this.tone = InfoBannerTone.normal,
  });

  final IconData icon;
  final String message;
  final InfoBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color background;
    Color foreground;
    switch (tone) {
      case InfoBannerTone.muted:
        background =
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
        foreground = theme.colorScheme.onSurfaceVariant;
        break;
      case InfoBannerTone.error:
        background = theme.colorScheme.errorContainer;
        foreground = theme.colorScheme.onErrorContainer;
        break;
      case InfoBannerTone.normal:
        background =
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.35);
        foreground = theme.colorScheme.onSecondaryContainer;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
