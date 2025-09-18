class NutritionFacts {
  const NutritionFacts({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbs;
}

class NutritionResult {
  const NutritionResult({
    required this.name,
    required this.facts,
    this.servingQuantity,
    this.servingUnit,
    this.photoUrl,
  });

  final String name;
  final NutritionFacts facts;
  final double? servingQuantity;
  final String? servingUnit;
  final String? photoUrl;
}

class NutritionAnalysis {
  const NutritionAnalysis({
    required this.result,
    required this.advice,
  });

  final NutritionResult result;
  final String advice;
}

enum NutritionGoal {
  weightLoss,
  muscleGain,
  healthyLifestyle,
  sport,
}

extension NutritionGoalExt on NutritionGoal {
  String get label {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 'похудение';
      case NutritionGoal.muscleGain:
        return 'набор массы';
      case NutritionGoal.healthyLifestyle:
        return 'правильное питание';
      case NutritionGoal.sport:
        return 'спорт';
    }
  }

  String get displayName {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 'Похудение';
      case NutritionGoal.muscleGain:
        return 'Набор мышц';
      case NutritionGoal.healthyLifestyle:
        return 'ЗОЖ';
      case NutritionGoal.sport:
        return 'Спорт';
    }
  }
}
