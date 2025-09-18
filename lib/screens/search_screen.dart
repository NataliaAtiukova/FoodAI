import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
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
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  NutritionGoal _selectedGoal = NutritionGoal.healthyLifestyle;
  bool _isLoading = false;
  bool _isBarcodeLoading = false;
  bool _isAdding = false;
  List<SearchFoodItem> _results = const <SearchFoodItem>[];

  @override
  void dispose() {
    _controller.dispose();
    _barcodeController.dispose();
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

  Future<void> _searchBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      _showSnackBar('Введите штрихкод.');
      return;
    }

    setState(() => _isBarcodeLoading = true);
    try {
      final result =
          await NutritionService.instance.fetchFoodByBarcode(barcode);
      if (!mounted) {
        return;
      }
      if (result == null) {
        _showSnackBar('Продукт не найден по штрихкоду.');
        return;
      }

      final grams = await _askPortion(result.name);
      if (grams == null) {
        return;
      }

      final category = await _pickCategory();
      if (category == null) {
        return;
      }

      setState(() => _isAdding = true);

      try {
        final ratio = grams / 100;
        final scaledFacts = NutritionFacts(
          calories: result.facts.calories * ratio,
          protein: result.facts.protein * ratio,
          fat: result.facts.fat * ratio,
          carbs: result.facts.carbs * ratio,
        );
        String advice;
        try {
          advice = await NutritionService.instance.fetchDietAdvice(
            scaledFacts,
            _selectedGoal,
            productName: result.name,
          );
        } catch (_) {
          advice = 'Добавлено по штрихкоду.';
        }

        await DiaryService.instance.addEntry(
          name: result.name,
          brand: result.brand,
          calories: scaledFacts.calories,
          protein: scaledFacts.protein,
          fat: scaledFacts.fat,
          carbs: scaledFacts.carbs,
          goal: _selectedGoal.label,
          advice: advice,
          category: category,
          source: 'Search',
        );
        if (!mounted) {
          return;
        }
        _showSnackBar('Добавлено в дневник');
      } finally {
        if (mounted) {
          setState(() => _isAdding = false);
        }
      }
    } catch (error) {
      _showSnackBar('Ошибка поиска штрихкода: $error');
    } finally {
      if (mounted) {
        setState(() => _isBarcodeLoading = false);
      }
    }
  }

  Future<void> _addFood(SearchFoodItem item) async {
    final category = await _pickCategory();
    if (category == null) {
      return;
    }

    NutritionAnalysis? analysis;
    NutritionFacts? facts;
    double grams = 100;

    if (item.factsPer100g != null) {
      final value = await _askPortion(item.name);
      if (value == null) {
        return;
      }
      grams = value;
      final ratio = grams / 100;
      facts = NutritionFacts(
        calories: item.factsPer100g!.calories * ratio,
        protein: item.factsPer100g!.protein * ratio,
        fat: item.factsPer100g!.fat * ratio,
        carbs: item.factsPer100g!.carbs * ratio,
      );
    }

    setState(() => _isAdding = true);
    try {
      String advice;
      String name;
      if (facts != null) {
        name = item.name;
        try {
          advice = await NutritionService.instance.fetchDietAdvice(
            facts,
            _selectedGoal,
            productName: item.name,
          );
        } catch (_) {
          advice = 'Добавлено из поиска OFF.';
        }
      } else {
        analysis = await NutritionService.instance.analyzeWithAdvice(
          item.name,
          _selectedGoal,
        );
        facts = analysis.result.facts;
        name = analysis.result.name;
        advice = analysis.advice;
      }

      await DiaryService.instance.addEntry(
        name: name,
        brand: item.brand ?? analysis?.result.brand,
        calories: facts.calories,
        protein: facts.protein,
        fat: facts.fat,
        carbs: facts.carbs,
        goal: _selectedGoal.label,
        advice: advice,
        category: category,
        source: 'Search',
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

  Future<double?> _askPortion(String name) async {
    final controller = TextEditingController(text: '100');
    return showModalBottomSheet<double>(
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
                'Граммовка для "$name"',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'г',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final value =
                      double.tryParse(controller.text.replaceAll(',', '.'));
                  Navigator.of(context).pop(value);
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );
      },
    );
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
                        if (value != null) {
                          setModalState(() => selected = value);
                        }
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

  DiaryEntry? _findMatchingEntry(
      List<DiaryEntry> entries, SearchFoodItem item) {
    for (final entry in entries) {
      final sameName = entry.name.toLowerCase() == item.name.toLowerCase();
      final sourceLower = entry.source.toLowerCase();
      final sourceMatches =
          sourceLower.contains('search') || sourceLower.contains('поиск');
      final brandMatches = (item.brand == null || item.brand!.isEmpty)
          ? (entry.brand == null || entry.brand!.isEmpty)
          : (entry.brand?.toLowerCase() == item.brand!.toLowerCase());
      if (sameName && brandMatches && sourceMatches) {
        return entry;
      }
    }
    return null;
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
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
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
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Штрихкод (Open Food Facts)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _isBarcodeLoading ? null : _searchBarcode,
                icon: _isBarcodeLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_scanner),
                label: const Text('Найти по штрихкоду'),
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
                child: ValueListenableBuilder<List<DiaryEntry>>(
                  valueListenable: DiaryService.instance.listenable(),
                  builder: (context, entries, _) {
                    return ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final entry = _findMatchingEntry(entries, item);
                        final added = entry != null;
                        final theme = Theme.of(context);
                        final subtitleChildren = <Widget>[];
                        if (item.brand != null && item.brand!.isNotEmpty) {
                          subtitleChildren.add(Text(item.brand!));
                        }
                        if (added) {
                          subtitleChildren.add(
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Добавлено',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListTile(
                          leading: item.thumbnailUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(item.thumbnailUrl!))
                              : const CircleAvatar(
                                  child: Icon(Icons.restaurant_outlined)),
                          title: Text(item.name),
                          subtitle: subtitleChildren.isEmpty
                              ? null
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: subtitleChildren,
                                ),
                          trailing: FilledButton.tonalIcon(
                            onPressed: _isAdding
                                ? null
                                : () {
                                    if (added) {
                                      _removeEntry(entry);
                                    } else {
                                      _addFood(item);
                                    }
                                  },
                            icon:
                                Icon(added ? Icons.delete_outline : Icons.add),
                            label: Text(added ? 'Удалить' : 'Добавить'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeEntry(DiaryEntry entry) async {
    setState(() => _isAdding = true);
    try {
      await DiaryService.instance.deleteEntry(entry.id);
      if (!mounted) {
        return;
      }
      _showSnackBar('Удалено из дневника');
    } catch (error) {
      _showSnackBar('Не удалось удалить: $error');
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }
}
