import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/meal_category.dart';
import '../models/nutrition_models.dart';
import '../models/vision_prediction.dart';
import '../services/diary_service.dart';
import '../services/nutrition_service.dart';
import '../services/vision_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  final void Function(int index)? onNavigateToTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  NutritionResult? _latestResult;
  List<VisionPrediction>? _latestPredictions;
  String? _lastImagePath;
  bool _isLoading = false;
  String _pendingSource = 'Ручной ввод';
  bool _savingToDiary = false;
  String _lastAnalysisSource = 'Ручной ввод';
  final TextEditingController _gramsController =
      TextEditingController(text: '100');
  double _grams = 100;
  NutritionFacts? _baseFactsPer100g;

  @override
  void dispose() {
    _controller.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> startCameraScan() => _handlePhoto(ImageSource.camera);

  Future<void> startGalleryPick() => _handlePhoto(ImageSource.gallery);

  Future<void> _handlePhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) {
        return;
      }

      final file = File(picked.path);
      setState(() => _isLoading = true);
      _pendingSource = 'Фото';
      final predictions = await VisionService.instance.analyzeFood(file);
      if (!mounted) {
        return;
      }

      final choice = await _showPredictionSheet(predictions);
      if (choice == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _controller.text = choice;
        _latestPredictions = predictions;
        _lastImagePath = file.path;
      });

      await _calculate(queryOverride: choice);
    } on VisionException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Не удалось распознать блюдо: $e');
      await _offerManualFallback();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addAnalysisToDiary() async {
    final result = _latestResult;
    final baseFacts = _baseFactsPer100g;
    if (result == null || baseFacts == null || _savingToDiary) {
      return;
    }

    final grams = _grams;
    if (grams <= 0) {
      _showSnackBar('Укажите граммовку блюда.');
      return;
    }

    final category = await _pickCategory();
    if (category == null || !mounted) {
      return;
    }

    setState(() => _savingToDiary = true);
    try {
      await DiaryService.instance.addEntry(
        name: result.name,
        brand: result.brand,
        grams: grams,
        caloriesPer100g: baseFacts.calories,
        proteinPer100g: baseFacts.protein,
        fatPer100g: baseFacts.fat,
        carbsPer100g: baseFacts.carbs,
        goal: 'Home',
        advice: 'Добавлено из Home.',
        category: category,
        source: 'Home',
        imagePath: _lastImagePath,
        labels: _latestPredictions
            ?.map((prediction) =>
                '${prediction.label} (${prediction.confidencePercent()})')
            .toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Добавлено в дневник.')),
        );
    } catch (error) {
      _showSnackBar('Не удалось сохранить: $error');
    } finally {
      if (mounted) {
        setState(() => _savingToDiary = false);
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

  void _onGramsChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return;
    }
    setState(() => _grams = parsed);
  }

  Future<void> _offerManualFallback() async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Не удалось распознать блюдо. Попробуйте добавить его через поиск Open Food Facts.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTab?.call(1);
                },
                icon: const Icon(Icons.search_outlined),
                label: const Text('Перейти к поиску'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showPredictionSheet(
      List<VisionPrediction> predictions) async {
    if (predictions.isEmpty) {
      return null;
    }
    if (predictions.length == 1) {
      return predictions.first.label;
    }

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final prediction = predictions[index];
              return ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(
                  '${prediction.label} · ${prediction.confidencePercent()}',
                ),
                onTap: () => Navigator.of(context).pop(prediction.label),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: predictions.length,
          ),
        );
      },
    );
  }

  Future<void> _calculate({String? queryOverride, String? source}) async {
    final query = (queryOverride ?? _controller.text).trim();
    if (query.isEmpty) {
      _showSnackBar('Введите название блюда.');
      return;
    }

    setState(() {
      _isLoading = true;
      _latestResult = null;
      if (source != null && source == 'Ручной ввод') {
        _latestPredictions = null;
        _lastImagePath = null;
      }
    });

    if (source != null) {
      _pendingSource = source;
    }

    try {
      final result = await NutritionService.instance.fetchNutrition(query);
      if (!mounted) {
        return;
      }

      setState(() {
        _latestResult = result;
        _lastAnalysisSource = _pendingSource;
        _baseFactsPer100g = result.facts;
        _grams = 100;
        _gramsController.text = '100';
      });
      _pendingSource = 'Ручной ввод';
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Ошибка анализа: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,##0');
    final baseFacts = _baseFactsPer100g;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Что вы ели?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Например: 1 яблоко, 2 ломтика хлеба, 100 г куриной грудки',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : startCameraScan,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Сканировать еду'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : startGalleryPick,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Выбрать фото'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _isLoading ? null : () => _calculate(source: 'Ручной ввод'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Посчитать'),
            ),
            if (_latestResult != null && baseFacts != null) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Результат анализа',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                result: _latestResult!,
                imagePath: _lastImagePath,
                predictions: _latestPredictions,
                numberFormat: numberFormat,
                sourceLabel: _lastAnalysisSource,
                baseFacts: baseFacts,
                grams: _grams,
                gramsController: _gramsController,
                onGramsChanged: _onGramsChanged,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _savingToDiary ? null : _addAnalysisToDiary,
                icon: _savingToDiary
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.add_task),
                label:
                    Text(_savingToDiary ? 'Добавление…' : 'Добавить в дневник'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.result,
    required this.imagePath,
    required this.predictions,
    required this.numberFormat,
    required this.sourceLabel,
    required this.baseFacts,
    required this.grams,
    required this.gramsController,
    required this.onGramsChanged,
  });

  final NutritionResult result;
  final String? imagePath;
  final List<VisionPrediction>? predictions;
  final NumberFormat numberFormat;
  final String sourceLabel;
  final NutritionFacts baseFacts;
  final double grams;
  final TextEditingController gramsController;
  final ValueChanged<String> onGramsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macroFormat = NumberFormat('#,##0.0');

    String formatValue(double value) {
      return value % 1 == 0
          ? numberFormat.format(value)
          : macroFormat.format(value);
    }

    final scaledFacts = NutritionFacts(
      calories: baseFacts.calories * grams / 100,
      protein: baseFacts.protein * grams / 100,
      fat: baseFacts.fat * grams / 100,
      carbs: baseFacts.carbs * grams / 100,
    );
    final gramsText = formatValue(grams);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (result.brand != null && result.brand!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                result.brand!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Источник: $sourceLabel',
              style: theme.textTheme.bodySmall,
            ),
            if (imagePath != null && File(imagePath!).existsSync()) ...<Widget>[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(imagePath!),
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Пищевая ценность на 100 г',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _SummaryMetric(
                  title: 'Калории',
                  value: '${formatValue(baseFacts.calories)} ккал',
                ),
                _SummaryMetric(
                  title: 'Белки',
                  value: '${formatValue(baseFacts.protein)} г',
                ),
                _SummaryMetric(
                  title: 'Жиры',
                  value: '${formatValue(baseFacts.fat)} г',
                ),
                _SummaryMetric(
                  title: 'Углеводы',
                  value: '${formatValue(baseFacts.carbs)} г',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gramsController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Граммовка',
                suffixText: 'г',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: onGramsChanged,
            ),
            const SizedBox(height: 12),
            Text(
              'Итого для $gramsText г',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _SummaryMetric(
                  title: 'Калории',
                  value: '${formatValue(scaledFacts.calories)} ккал',
                ),
                _SummaryMetric(
                  title: 'Белки',
                  value: '${formatValue(scaledFacts.protein)} г',
                ),
                _SummaryMetric(
                  title: 'Жиры',
                  value: '${formatValue(scaledFacts.fat)} г',
                ),
                _SummaryMetric(
                  title: 'Углеводы',
                  value: '${formatValue(scaledFacts.carbs)} г',
                ),
              ],
            ),
            if (predictions != null && predictions!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: predictions!
                    .take(6)
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
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
