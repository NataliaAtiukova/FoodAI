import 'package:flutter/material.dart';

import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../models/search_food_item.dart';
import '../services/diary_service.dart';
import '../services/nutrition_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  NutritionGoal _selectedGoal = NutritionGoal.healthyLifestyle;
  bool _isLoading = false;
  bool _isAdding = false;
  List<SearchFoodItem> _results = const <SearchFoodItem>[];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _results = const <SearchFoodItem>[]);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final items = await NutritionService.instance.searchFoods(query);
      if (!mounted) {
        return;
      }
      setState(() => _results = items);
    } catch (error) {
      _showSnackBar('Ошибка поиска: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addFood(SearchFoodItem item) async {
    final category = await _pickCategory();
    if (category == null) {
      return;
    }

    setState(() => _isAdding = true);
    try {
      final analysis = await NutritionService.instance.analyzeWithAdvice(
        item.name,
        _selectedGoal,
      );
      final facts = analysis.result.facts;
      await DiaryService.instance.addEntry(
        name: analysis.result.name,
        calories: facts.calories,
        protein: facts.protein,
        fat: facts.fat,
        carbs: facts.carbs,
        goal: _selectedGoal.label,
        advice: analysis.advice,
        category: category,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Добавлено в дневник');
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } on DietAdviceException catch (e) {
      _showSnackBar(e.message);
    } catch (error) {
      _showSnackBar('Не удалось добавить: $error');
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<MealCategory?> _pickCategory() async {
    MealCategory selected = MealCategory.breakfast;
    return showModalBottomSheet<MealCategory>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        if (value == null) {
                          return;
                        }
                        setModalState(() => selected = value);
                      },
                      title: Text(category.displayName),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Добавить'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Поиск блюд',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Например: куриная грудка',
                suffixIcon: IconButton(
                  onPressed: _isLoading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NutritionGoal>(
              value: _selectedGoal,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGoal = value);
                }
              },
              decoration: InputDecoration(
                labelText: 'Цель питания',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: NutritionGoal.values
                  .map(
                    (goal) => DropdownMenuItem<NutritionGoal>(
                      value: goal,
                      child: Text(goal.displayName),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Начните ввод, чтобы найти нужное блюдо.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      leading: item.thumbnailUrl != null
                          ? CircleAvatar(backgroundImage: NetworkImage(item.thumbnailUrl!))
                          : const CircleAvatar(child: Icon(Icons.restaurant_outlined)),
                      title: Text(item.name),
                      subtitle: item.brand == null || item.brand!.isEmpty
                          ? null
                          : Text(item.brand!),
                      trailing: FilledButton.tonal(
                        onPressed: _isAdding ? null : () => _addFood(item),
                        child: const Text('Добавить'),
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
