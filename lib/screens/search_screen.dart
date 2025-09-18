import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isLoading = false;
  bool _isBarcodeLoading = false;
  bool _isAdding = false;
  List<SearchFoodItem> _results = const <SearchFoodItem>[];
  final Map<String, double> _itemGrams = <String, double>{};
  final Map<String, TextEditingController> _gramControllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    _controller.dispose();
    _barcodeController.dispose();
    _focusNode.dispose();
    for (final controller in _gramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <SearchFoodItem>[];
        _syncControllers(const <SearchFoodItem>[]);
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final items = await NutritionService.instance.searchFoods(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = items;
        _syncControllers(items);
      });
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
        await DiaryService.instance.addEntry(
          name: result.name,
          brand: result.brand,
          grams: grams,
          caloriesPer100g: result.facts.calories,
          proteinPer100g: result.facts.protein,
          fatPer100g: result.facts.fat,
          carbsPer100g: result.facts.carbs,
          goal: 'Каталог',
          advice: 'Добавлено по штрихкоду.',
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

    final grams = _gramsForItem(item);
    setState(() => _isAdding = true);
    try {
      NutritionFacts per100Facts;
      const advice = 'Добавлено из поиска.';
      String name = item.name;
      String? brand = item.brand;

      if (item.factsPer100g != null) {
        per100Facts = item.factsPer100g!;
      } else {
        final result =
            await NutritionService.instance.fetchNutrition(item.name);
        per100Facts = result.facts;
        name = result.name;
        brand = result.brand ?? brand;
      }

      await DiaryService.instance.addEntry(
        name: name,
        brand: brand,
        grams: grams,
        caloriesPer100g: per100Facts.calories,
        proteinPer100g: per100Facts.protein,
        fatPer100g: per100Facts.fat,
        carbsPer100g: per100Facts.carbs,
        goal: 'Каталог',
        advice: advice,
        category: category,
        source: 'Search',
      );
      if (!mounted) {
        return;
      }
      final key = _itemKey(item);
      _itemGrams[key] = grams;
      _gramControllers[key]?.text = _formatGrams(grams);
      _showSnackBar('Добавлено в дневник');
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } catch (error) {
      _showSnackBar('Не удалось добавить: $error');
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<double?> _askPortion(String name, {double initial = 100}) async {
    final initialText = initial % 1 == 0
        ? initial.toStringAsFixed(0)
        : initial.toStringAsFixed(1);
    final controller = TextEditingController(text: initialText);
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

  String _itemKey(SearchFoodItem item) =>
      '${item.name.toLowerCase()}|${item.brand?.toLowerCase() ?? ''}';

  double _gramsForItem(SearchFoodItem item) =>
      _itemGrams[_itemKey(item)] ?? 100;

  TextEditingController _controllerForItem(SearchFoodItem item) {
    final key = _itemKey(item);
    return _gramControllers.putIfAbsent(
      key,
      () => TextEditingController(text: _formatGrams(_gramsForItem(item))),
    );
  }

  void _syncControllers(List<SearchFoodItem> items) {
    final keepKeys = items.map(_itemKey).toSet();
    final keysToRemove = _gramControllers.keys
        .where((key) => !keepKeys.contains(key))
        .toList(growable: false);
    for (final key in keysToRemove) {
      _gramControllers.remove(key)?.dispose();
      _itemGrams.remove(key);
    }
    for (final item in items) {
      final key = _itemKey(item);
      _gramControllers.putIfAbsent(
        key,
        () => TextEditingController(text: _formatGrams(_gramsForItem(item))),
      );
    }
  }

  void _updateGramsFromInput(String key, String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) {
      setState(() => _itemGrams[key] = parsed);
    }
  }

  String _formatGrams(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

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
                        final isAdded = entry != null;
                        final theme = Theme.of(context);
                        final number = NumberFormat('#,##0');
                        final decimal = NumberFormat('#,##0.0');

                        String formatValue(double value) => value % 1 == 0
                            ? number.format(value)
                            : decimal.format(value);

                        final grams = _gramsForItem(item);
                        final gramsText = '${formatValue(grams)} г';
                        final NutritionFacts? scaledFacts = item.factsPer100g ==
                                null
                            ? null
                            : NutritionFacts(
                                calories:
                                    item.factsPer100g!.calories * grams / 100,
                                protein:
                                    item.factsPer100g!.protein * grams / 100,
                                fat: item.factsPer100g!.fat * grams / 100,
                                carbs: item.factsPer100g!.carbs * grams / 100,
                              );

                        final controller = _controllerForItem(item);
                        final key = _itemKey(item);

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    item.thumbnailUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Image.network(
                                              item.thumbnailUrl!,
                                              height: 60,
                                              width: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: 30,
                                            backgroundColor: theme
                                                .colorScheme.secondaryContainer,
                                            child: Icon(
                                              Icons.restaurant_outlined,
                                              color: theme.colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (item.brand != null &&
                                              item.brand!.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                item.brand!,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                          if (item.factsPer100g != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: Text(
                                                'На 100 г · ${formatValue(item.factsPer100g!.calories)} ккал · '
                                                'Б ${formatValue(item.factsPer100g!.protein)} г · '
                                                'Ж ${formatValue(item.factsPer100g!.fat)} г · '
                                                'У ${formatValue(item.factsPer100g!.carbs)} г',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: controller,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Граммовка',
                                    suffixText: 'г',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      _updateGramsFromInput(key, value),
                                  onEditingComplete: () {
                                    _updateGramsFromInput(
                                        key, controller.text.trim());
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                                if (scaledFacts != null) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Для $gramsText · ${formatValue(scaledFacts.calories)} ккал',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Б ${formatValue(scaledFacts.protein)} г · '
                                    'Ж ${formatValue(scaledFacts.fat)} г · '
                                    'У ${formatValue(scaledFacts.carbs)} г',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    if (isAdded)
                                      Text(
                                        'Добавлено в дневник',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    FilledButton.tonalIcon(
                                      onPressed: _isAdding
                                          ? null
                                          : () {
                                              if (entry != null) {
                                                _removeEntry(entry);
                                              } else {
                                                _addFood(item);
                                              }
                                            },
                                      icon: Icon(isAdded
                                          ? Icons.delete_outline
                                          : Icons.add),
                                      label: Text(
                                        isAdded ? 'Удалить' : 'Добавить',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
