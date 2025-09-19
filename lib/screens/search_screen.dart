import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry_v2.dart';
import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../models/local_food_item.dart';
import '../services/diary_service_v2.dart';
import '../services/local_food_database_service.dart';

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
  List<LocalFoodItem> _results = const <LocalFoodItem>[];
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
        _results = const <LocalFoodItem>[];
        _syncControllers(const <LocalFoodItem>[]);
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final items = await LocalFoodDatabaseService.instance.searchFoods(query);
      if (!mounted) return;

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
          await LocalFoodDatabaseService.instance.getFoodByBarcode(barcode);
      if (!mounted) return;

      if (result == null) {
        _showSnackBar('Продукт не найден по штрихкоду.');
        return;
      }

      final grams = await _askPortion(result.name);
      if (grams == null) return;

      final category = await _pickCategory();
      if (category == null) return;

      setState(() => _isAdding = true);

      try {
        final entry = DiaryEntryV2(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.name,
          brand: result.brand,
          grams: grams,
          factsPer100g: result.factsPer100g,
          timestamp: DateTime.now(),
          category: category,
          source: 'OFF Barcode',
        );

        await DiaryServiceV2.instance.addEntry(entry);

        if (!mounted) return;
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

  Future<void> _addFood(LocalFoodItem item) async {
    final category = await _pickCategory();
    if (category == null) return;

    final grams = _gramsForItem(item);
    setState(() => _isAdding = true);

    try {
      final entry = DiaryEntryV2(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: item.name,
        brand: item.brand,
        grams: grams,
        factsPer100g: item.factsPer100g,
        timestamp: DateTime.now(),
        category: category,
        source: 'OFF Search',
      );

      await DiaryServiceV2.instance.addEntry(entry);

      if (!mounted) return;
      final key = _itemKey(item);
      _itemGrams[key] = grams;
      _gramControllers[key]?.text = _formatGrams(grams);
      _showSnackBar('Добавлено в дневник');
    } catch (error) {
      _showSnackBar('Не удалось добавить: $error');
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _removeFood(LocalFoodItem item) async {
    // Находим и удаляем соответствующую запись из дневника
    final entries = DiaryServiceV2.instance.getAllEntries();
    final matchingEntry = entries
        .where((entry) =>
            entry.name.toLowerCase() == item.name.toLowerCase() &&
            (entry.source == 'OFF Search' || entry.source == 'OFF Barcode') &&
            entry.brand == item.brand)
        .firstOrNull;

    if (matchingEntry != null) {
      try {
        await DiaryServiceV2.instance.removeEntry(matchingEntry.id);
        _showSnackBar('Удалено из дневника');
      } catch (error) {
        _showSnackBar('Не удалось удалить: $error');
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
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

  String _itemKey(LocalFoodItem item) =>
      '${item.name.toLowerCase()}|${item.brand?.toLowerCase() ?? ''}';

  double _gramsForItem(LocalFoodItem item) => _itemGrams[_itemKey(item)] ?? 100;

  TextEditingController _controllerForItem(LocalFoodItem item) {
    final key = _itemKey(item);
    return _gramControllers.putIfAbsent(
      key,
      () => TextEditingController(text: _formatGrams(_gramsForItem(item))),
    );
  }

  void _syncControllers(List<LocalFoodItem> items) {
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

  bool _isItemInDiary(LocalFoodItem item) {
    final entries = DiaryServiceV2.instance.getAllEntries();
    return entries.any((entry) =>
        entry.name.toLowerCase() == item.name.toLowerCase() &&
        (entry.source == 'OFF Search' || entry.source == 'OFF Barcode') &&
        entry.brand == item.brand);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
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
              'Поиск продуктов',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Поиск по базе Open Food Facts RU',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Например: куриная грудка',
                suffixIcon: IconButton(
                  onPressed: _isLoading ? null : _search,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: 'Штрихкод продукта',
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
                  child: Text('Начните ввод, чтобы найти нужный продукт.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    final isAdded = _isItemInDiary(item);
                    final theme = Theme.of(context);
                    final number = NumberFormat('#,##0');
                    final decimal = NumberFormat('#,##0.0');

                    String formatValue(double value) => value % 1 == 0
                        ? number.format(value)
                        : decimal.format(value);

                    final grams = _gramsForItem(item);
                    final gramsText = '${formatValue(grams)} г';
                    final scaledFacts = NutritionFacts(
                      calories: item.factsPer100g.calories * grams / 100,
                      protein: item.factsPer100g.protein * grams / 100,
                      fat: item.factsPer100g.fat * grams / 100,
                      carbs: item.factsPer100g.carbs * grams / 100,
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
                                item.photoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          item.photoUrl!,
                                          height: 60,
                                          width: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return CircleAvatar(
                                              radius: 30,
                                              backgroundColor: theme.colorScheme
                                                  .secondaryContainer,
                                              child: Icon(
                                                Icons.restaurant_outlined,
                                                color: theme.colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 30,
                                        backgroundColor: theme
                                            .colorScheme.secondaryContainer,
                                        child: Icon(
                                          Icons.restaurant_outlined,
                                          color: theme
                                              .colorScheme.onSecondaryContainer,
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
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'На 100 г · ${formatValue(item.factsPer100g.calories)} ккал · '
                                          'Б ${formatValue(item.factsPer100g.protein)} г · '
                                          'Ж ${formatValue(item.factsPer100g.fat)} г · '
                                          'У ${formatValue(item.factsPer100g.carbs)} г',
                                          style: theme.textTheme.bodySmall,
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
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
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
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                if (isAdded)
                                  Text(
                                    'Добавлено в дневник',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                FilledButton.tonalIcon(
                                  onPressed: _isAdding
                                      ? null
                                      : () {
                                          if (isAdded) {
                                            _removeFood(item);
                                          } else {
                                            _addFood(item);
                                          }
                                        },
                                  icon: Icon(isAdded
                                      ? Icons.delete_outline
                                      : Icons.add),
                                  label: Text(isAdded ? 'Удалить' : 'Добавить'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
