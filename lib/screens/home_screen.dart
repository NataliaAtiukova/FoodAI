import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry_v2.dart';
import '../models/local_food_item.dart';
import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../services/diary_service_v2.dart';
import '../services/local_food_database_service.dart';
import '../services/yandex_vision_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  HomeScreenState();

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _manualController = TextEditingController();
  final Map<String, TextEditingController> _gramControllers =
      <String, TextEditingController>{};
  final Map<String, double> _itemGrams = <String, double>{};

  List<String> _recognizedCandidates = <String>[];
  List<LocalFoodItem> _results = <LocalFoodItem>[];
  bool _isScanning = false;
  bool _isSearching = false;
  bool _isAdding = false;
  String? _activeQuery;
  String _activeSourceLabel = 'Manual Search';
  String? _lastImagePath;
  String? _scanError;

  static const String _ocrSourceLabel = 'Yandex OCR';
  static const String _manualSourceLabel = 'Manual Search';

  @override
  void dispose() {
    _manualController.dispose();
    for (final controller in _gramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _scanPackaging(ImageSource source) async {
    if (_isScanning) return;

    try {
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _isScanning = true;
        _scanError = null;
      });

      final file = File(picked.path);
      _lastImagePath = file.path;

      final ocrResult = await YandexVisionService.instance.recognizeText(file);
      if (!mounted) return;

      final candidates = _prepareCandidates(ocrResult.lines);
      setState(() {
        _recognizedCandidates = candidates;
        if (candidates.isNotEmpty) {
          _activeQuery = candidates.first;
        }
      });

      if (candidates.isEmpty) {
        _showSnackBar('Не удалось распознать продукт на фотографии.');
        return;
      }

      await _search(candidates.first, sourceLabel: _ocrSourceLabel);
    } on YandexVisionException catch (error) {
      setState(() => _scanError = error.message);
      _showSnackBar(error.message);
    } catch (error) {
      setState(() => _scanError = error.toString());
      _showSnackBar('Ошибка распознавания: $error');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  List<String> _prepareCandidates(List<String> lines) {
    final seen = <String>{};
    final candidates = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.length < 3) continue;
      if (RegExp(r'^[0-9\-]+$').hasMatch(line)) {
        continue; // игнорируем штрихкоды
      }
      final normalized = line.toLowerCase();
      if (seen.add(normalized)) {
        candidates.add(line);
      }
    }

    if (candidates.isEmpty) {
      return lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList(growable: false);
    }

    return candidates;
  }

  Future<void> _search(String query, {required String sourceLabel}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      _showSnackBar('Введите название продукта.');
      return;
    }

    setState(() {
      _isSearching = true;
      _activeQuery = cleanQuery;
      _activeSourceLabel = sourceLabel;
    });

    try {
      final items =
          await LocalFoodDatabaseService.instance.searchFoods(cleanQuery);

      if (!mounted) return;
      setState(() {
        _results = items;
        _syncControllers(items);
      });

      if (items.isEmpty) {
        _showSnackBar('Продукт "$cleanQuery" не найден в Open Food Facts.');
      }
    } catch (error) {
      _showSnackBar('Ошибка поиска: $error');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _syncControllers(List<LocalFoodItem> items) {
    final existingKeys = _gramControllers.keys.toSet();
    final keepKeys = items.map(_itemKey).toSet();

    for (final key in existingKeys.difference(keepKeys)) {
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

  Future<void> _addFood(LocalFoodItem item) async {
    if (_isAdding) return;

    final grams = _gramsForItem(item);
    final category = await _pickCategory();
    if (category == null) return;

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
        source: _activeSourceLabel,
        imagePath:
            _activeSourceLabel == _ocrSourceLabel ? _lastImagePath : null,
      );

      await DiaryServiceV2.instance.addEntry(entry);

      if (!mounted) return;
      _showSnackBar('"${item.name}" добавлен в дневник.');
    } catch (error) {
      _showSnackBar('Не удалось добавить продукт: $error');
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

  void _updateGrams(LocalFoodItem item, String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) {
      setState(() => _itemGrams[_itemKey(item)] = parsed);
    }
  }

  String _formatGrams(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yandexConfigured = YandexVisionService.instance.isConfigured;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Сканирование упаковки',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Используйте камеру, чтобы распознать текст на этикетке и найти продукт в Open Food Facts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (!yandexConfigured)
            const _InfoBanner(
              icon: Icons.cloud_off_outlined,
              message:
                  'Yandex Vision не настроен. Передайте YANDEX_IAM_TOKEN и YANDEX_VISION_FOLDER_ID через --dart-define, чтобы активировать OCR.',
            ),
          if (_scanError != null)
            _InfoBanner(
              icon: Icons.error_outline,
              message: _scanError!,
              tone: InfoTone.error,
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: yandexConfigured && !_isScanning
                      ? () => _scanPackaging(ImageSource.camera)
                      : null,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label:
                      Text(_isScanning ? 'Сканирование…' : 'Сфотографировать'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: yandexConfigured && !_isScanning
                      ? () => _scanPackaging(ImageSource.gallery)
                      : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Из галереи'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_recognizedCandidates.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Распознанный текст',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recognizedCandidates
                      .map(
                        (candidate) => ChoiceChip(
                          label: Text(candidate),
                          selected: _activeQuery == candidate,
                          onSelected: (selected) {
                            if (selected) {
                              _search(candidate, sourceLabel: _ocrSourceLabel);
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          Text(
            'Поиск вручную',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                _search(value, sourceLabel: _manualSourceLabel),
            decoration: InputDecoration(
              hintText: 'Введите название продукта и нажмите поиск',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: IconButton(
                onPressed: _isSearching
                    ? null
                    : () => _search(_manualController.text,
                        sourceLabel: _manualSourceLabel),
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.search_outlined),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_results.isEmpty && !_isSearching)
            const _InfoBanner(
              icon: Icons.info_outline,
              message:
                  'Отсканируйте упаковку или выполните поиск, чтобы найти продукт.',
              tone: InfoTone.muted,
            )
          else
            ..._results.map(_buildResultCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResultCard(LocalFoodItem item) {
    final theme = Theme.of(context);
    final number = NumberFormat('#,##0');
    final decimal = NumberFormat('#,##0.0');
    final grams = _gramsForItem(item);
    final scaledFacts = NutritionFacts(
      calories: item.factsPer100g.calories * grams / 100,
      protein: item.factsPer100g.protein * grams / 100,
      fat: item.factsPer100g.fat * grams / 100,
      carbs: item.factsPer100g.carbs * grams / 100,
    );
    final controller = _controllerForItem(item);

    String format(double value) =>
        value % 1 == 0 ? number.format(value) : decimal.format(value);

    final assistantNote = _buildAssistantNote(item, scaledFacts, grams);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                        item.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Calories',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${format(scaledFacts.calories)} ккал',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.brand != null && item.brand!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.brand!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topRight,
                        child: Chip(
                          avatar: const Icon(Icons.qr_code_scanner, size: 18),
                          label: Text(_activeSourceLabel),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        textAlign: TextAlign.end,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
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
                        onChanged: (value) => _updateGrams(item, value),
                        onEditingComplete: () {
                          _updateGrams(item, controller.text);
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                _MacroTile(
                  label: 'Protein',
                  value: '${format(scaledFacts.protein)} г',
                ),
                _MacroTile(
                  label: 'Fat',
                  value: '${format(scaledFacts.fat)} г',
                ),
                _MacroTile(
                  label: 'Carbs',
                  value: '${format(scaledFacts.carbs)} г',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    child: Icon(
                      Icons.psychology_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'FoodAI Assistant',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          assistantNote,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isAdding ? null : () => _addFood(item),
              child: Text(_isAdding ? 'Сохранение…' : 'Сохранить в дневник'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildAssistantNote(
    LocalFoodItem item,
    NutritionFacts facts,
    double grams,
  ) {
    final buffer = StringBuffer();
    final number = NumberFormat('#,##0.0');
    final caloriesText = facts.calories % 1 == 0
        ? facts.calories.toStringAsFixed(0)
        : number.format(facts.calories);

    buffer.write(
        'Порция ${item.name.toLowerCase()} на ${_formatGrams(grams)} г даёт $caloriesText ккал. ');

    if (facts.protein >= 25) {
      buffer.write('Отличный источник белка — поддержит восстановление и сытость. ');
    } else if (facts.protein <= 10) {
      buffer.write('Белка немного, добавьте яйцо, рыбу или творог для баланса. ');
    }

    if (facts.fat >= facts.carbs && facts.fat > 20) {
      buffer.write('Блюдо довольно жирное, постарайтесь сочетать его со свежими овощами. ');
    } else if (facts.carbs > facts.fat && facts.carbs > 40) {
      buffer.write('Углеводов много — подойдут цельнозерновые гарниры или салат для клетчатки. ');
    }

    buffer.write('Контролируйте размер порции и запланируйте оставшиеся приёмы пищи, чтобы уложиться в дневную норму калорий.');

    return buffer.toString();
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        background = colorScheme.secondaryContainer.withValues(alpha: 0.3);
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
