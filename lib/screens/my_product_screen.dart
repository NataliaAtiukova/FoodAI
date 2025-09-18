import 'package:flutter/material.dart';

import '../models/meal_category.dart';
import '../services/diary_service.dart';

class MyProductScreen extends StatefulWidget {
  const MyProductScreen({super.key});

  @override
  State<MyProductScreen> createState() => _MyProductScreenState();
}

class _MyProductScreenState extends State<MyProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  MealCategory _category = MealCategory.snack;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final double? calories = double.tryParse(_caloriesController.text.replaceAll(',', '.'));
    final double? protein = double.tryParse(_proteinController.text.replaceAll(',', '.'));
    final double? fat = double.tryParse(_fatController.text.replaceAll(',', '.'));
    final double? carbs = double.tryParse(_carbsController.text.replaceAll(',', '.'));

    if (calories == null || protein == null || fat == null || carbs == null) {
      _showSnackBar('Введите корректные значения БЖУ.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await DiaryService.instance.addEntry(
        name: name,
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: carbs,
        goal: 'ручной',
        advice: 'Пользовательский продукт.',
        category: _category,
        source: 'Ручной ввод',
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Продукт добавлен.');
      _formKey.currentState?.reset();
      _nameController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _fatController.clear();
      _carbsController.clear();
    } catch (error) {
      _showSnackBar('Не удалось сохранить: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Мой продукт',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Калории',
                  suffixText: 'ккал',
                  border: OutlineInputBorder(),
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Белки',
                        suffixText: 'г',
                        border: OutlineInputBorder(),
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Жиры',
                        suffixText: 'г',
                        border: OutlineInputBorder(),
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _carbsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Углеводы',
                  suffixText: 'г',
                  border: OutlineInputBorder(),
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MealCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                items: MealCategory.values
                    .map(
                      (category) => DropdownMenuItem<MealCategory>(
                        value: category,
                        child: Text(category.displayName),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Заполните поле';
    }
    if (double.tryParse(value.replaceAll(',', '.')) == null) {
      return 'Введите число';
    }
    return null;
  }
}
