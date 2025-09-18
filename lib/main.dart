import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ai_service.dart';
import 'app_secrets.dart';
import 'nutrition_service.dart';
import 'vision_service.dart';

Future<void> main() async {
  await ensureEnvLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodAI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
          primary: Colors.green,
          secondary: Colors.greenAccent,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const Map<String, String> _goalOptions = <String, String>{
    'Похудение': 'похудение',
    'Набор массы': 'набор массы',
    'ПП': 'правильное питание',
    'Спорт': 'спорт',
  };

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedGoal = _goalOptions.values.first;
  NutritionInfo? _nutritionInfo;
  String? _advice;
  File? _selectedImage;
  String? _recognizedDish;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _showSnackBar('Введите название блюда.');
      return;
    }
    await _processQuery(query);
  }

  Future<void> _processQuery(String query) async {
    setState(() {
      _isLoading = true;
      _nutritionInfo = null;
      _advice = null;
    });

    try {
      final info = await getNutrition(query);
      final advice = await getDietAdvice(
        <String, dynamic>{
          'calories': info.calories,
          'protein': info.protein,
          'fat': info.fat,
          'carbs': info.carbohydrates,
        },
        _selectedGoal,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nutritionInfo = info;
        _advice = advice;
      });
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } on DietAdviceException catch (e) {
      _showSnackBar(e.message);
    } on StateError catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Что-то пошло не так: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanPhoto() async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return;
      }

      final file = File(pickedFile.path);

      setState(() {
        _isLoading = true;
        _selectedImage = file;
        _recognizedDish = null;
        _nutritionInfo = null;
        _advice = null;
      });

      final dishName = await analyzeImage(file);

      if (!mounted) {
        return;
      }

      setState(() {
        _recognizedDish = dishName;
        _controller.text = dishName;
      });

      await _processQuery(dishName);
    } on VisionException catch (e) {
      _showSnackBar(e.message);
    } on NutritionException catch (e) {
      _showSnackBar(e.message);
    } on DietAdviceException catch (e) {
      _showSnackBar(e.message);
    } on StateError catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Не удалось обработать фото: $e');
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodAI Нутриценты'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Введите блюдо',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _calculate(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGoal,
                decoration: const InputDecoration(
                  labelText: 'Цель',
                  border: OutlineInputBorder(),
                ),
                items: _goalOptions.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.value,
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedGoal = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _calculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Посчитать'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _scanPhoto,
                  child: const Text('📸 Сканировать фото'),
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedImage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_recognizedDish != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Распознано: $_recognizedDish',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              if (_nutritionInfo != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Пищевая ценность',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NutritionRow(
                          label: 'Калории',
                          value:
                              '${_nutritionInfo!.calories.toStringAsFixed(1)} ккал',
                        ),
                        _NutritionRow(
                          label: 'Белки',
                          value:
                              '${_nutritionInfo!.protein.toStringAsFixed(1)} г',
                        ),
                        _NutritionRow(
                          label: 'Жиры',
                          value: '${_nutritionInfo!.fat.toStringAsFixed(1)} г',
                        ),
                        _NutritionRow(
                          label: 'Углеводы',
                          value:
                              '${_nutritionInfo!.carbohydrates.toStringAsFixed(1)} г',
                        ),
                      ],
                    ),
                  ),
                ),
              if (_advice != null)
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(top: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Совет нутрициолога',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _advice!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
