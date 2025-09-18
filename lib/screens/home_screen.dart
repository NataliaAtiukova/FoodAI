import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/nutrition_models.dart';
import '../models/vision_prediction.dart';
import '../services/nutrition_service.dart';
import '../services/vision_service.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  final void Function(int index)? onNavigateToTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  NutritionGoal _selectedGoal = NutritionGoal.healthyLifestyle;
  NutritionAnalysis? _latestAnalysis;
  List<VisionPrediction>? _latestPredictions;
  String? _lastImagePath;
  bool _isLoading = false;
  String _pendingSource = 'Ручной ввод';

  @override
  void dispose() {
    _controller.dispose();
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
                'Не удалось распознать блюдо. Выберите способ добавления:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTab?.call(2);
                },
                icon: const Icon(Icons.search_outlined),
                label: const Text('Поиск (Open Food Facts)'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTab?.call(3);
                },
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Список русских блюд'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTab?.call(4);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Добавить свой продукт'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showPredictionSheet(List<VisionPrediction> predictions) async {
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
      _latestAnalysis = null;
    });

    if (source != null) {
      _pendingSource = source;
    }

    try {
      final analysis = await NutritionService.instance.analyzeWithAdvice(
        query,
        _selectedGoal,
      );
      if (!mounted) {
        return;
      }

      setState(() => _latestAnalysis = analysis);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ResultsScreen(
            analysis: analysis,
            goal: _selectedGoal,
            predictions: _latestPredictions,
            imagePath: _lastImagePath,
            source: _pendingSource,
          ),
        ),
      );
      _pendingSource = 'Ручной ввод';
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } on DietAdviceException catch (e) {
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
            const SizedBox(height: 20),
            Text(
              'Ваша цель',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NutritionGoal>(
              value: _selectedGoal,
              items: NutritionGoal.values
                  .map(
                    (goal) => DropdownMenuItem<NutritionGoal>(
                      value: goal,
                      child: Text(goal.displayName),
                    ),
                  )
                  .toList(),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGoal = value);
                }
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : () => _calculate(source: 'Ручной ввод'),
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
            if (_latestAnalysis != null) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Сегодняшняя сводка',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                analysis: _latestAnalysis!,
                imagePath: _lastImagePath,
                predictions: _latestPredictions,
                numberFormat: numberFormat,
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
    required this.analysis,
    required this.imagePath,
    required this.predictions,
    required this.numberFormat,
  });

  final NutritionAnalysis analysis;
  final String? imagePath;
  final List<VisionPrediction>? predictions;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              analysis.result.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _SummaryMetric(title: 'Калории', value: '${numberFormat.format(analysis.result.facts.calories)} ккал'),
                _SummaryMetric(title: 'Белки', value: '${numberFormat.format(analysis.result.facts.protein)} г'),
                _SummaryMetric(title: 'Жиры', value: '${numberFormat.format(analysis.result.facts.fat)} г'),
                _SummaryMetric(title: 'Углеводы', value: '${numberFormat.format(analysis.result.facts.carbs)} г'),
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
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
