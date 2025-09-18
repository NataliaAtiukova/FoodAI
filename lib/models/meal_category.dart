enum MealCategory {
  breakfast,
  lunch,
  dinner,
  snack,
}

extension MealCategoryExt on MealCategory {
  String get displayName {
    switch (this) {
      case MealCategory.breakfast:
        return 'Завтрак';
      case MealCategory.lunch:
        return 'Обед';
      case MealCategory.dinner:
        return 'Ужин';
      case MealCategory.snack:
        return 'Перекус';
    }
  }

  String get storageValue => name;

  static MealCategory fromStorage(String? value) {
    if (value == null) {
      return MealCategory.snack;
    }
    return MealCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => MealCategory.snack,
    );
  }
}
