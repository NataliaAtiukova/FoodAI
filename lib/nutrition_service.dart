import 'dart:convert';
import 'package:http/http.dart' as http;

import 'app_secrets.dart';

class NutritionInfo {
  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) {
      final dynamic value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      throw NutritionException('Missing or invalid value for "$key"');
    }

    return NutritionInfo(
      calories: readDouble('nf_calories'),
      protein: readDouble('nf_protein'),
      fat: readDouble('nf_total_fat'),
      carbohydrates: readDouble('nf_total_carbohydrate'),
    );
  }
}

class NutritionException implements Exception {
  NutritionException(this.message);
  final String message;

  @override
  String toString() => 'NutritionException: $message';
}

Future<NutritionInfo> getNutrition(String query) async {
  if (query.trim().isEmpty) {
    throw NutritionException('Query must not be empty.');
  }

  final uri =
      Uri.parse('https://trackapi.nutritionix.com/v2/natural/nutrients');
  final appId = envOrThrow('NUTRITIONIX_APP_ID');
  final appKey = envOrThrow('NUTRITIONIX_APP_KEY');

  final response = await http.post(
    uri,
    headers: <String, String>{
      'x-app-id': appId,
      'x-app-key': appKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'query': query,
      'timezone': 'Europe/Moscow',
    }),
  );

  if (response.statusCode != 200) {
    throw NutritionException(
      'Nutritionix request failed (${response.statusCode}).',
    );
  }

  final Map<String, dynamic> payload = jsonDecode(response.body);
  final foods = payload['foods'];
  if (foods is! List || foods.isEmpty) {
    throw NutritionException('Dish "$query" not found.');
  }

  final firstFood = foods.first;
  if (firstFood is! Map<String, dynamic>) {
    throw NutritionException('Unexpected response format.');
  }

  return NutritionInfo.fromJson(firstFood);
}
