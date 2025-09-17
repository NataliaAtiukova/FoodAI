import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle, ServicesBinding;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

const String googleVisionKeyAsset =
    'assets/keys/zinc-night-453821-n5-f79b987f7522.json';

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
    double _readDouble(String key) {
      final dynamic value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      throw NutritionException('Missing or invalid value for "$key"');
    }

    return NutritionInfo(
      calories: _readDouble('nf_calories'),
      protein: _readDouble('nf_protein'),
      fat: _readDouble('nf_total_fat'),
      carbohydrates: _readDouble('nf_total_carbohydrate'),
    );
  }

  @override
  String toString() =>
      'Calories: ${calories.toStringAsFixed(2)} kcal, Protein: '
      '${protein.toStringAsFixed(2)} g, Fat: ${fat.toStringAsFixed(2)} g, '
      'Carbohydrates: ${carbohydrates.toStringAsFixed(2)} g';
}

class NutritionException implements Exception {
  NutritionException(this.message);
  final String message;

  @override
  String toString() => 'NutritionException: $message';
}

class DietAdviceException implements Exception {
  DietAdviceException(this.message);
  final String message;

  @override
  String toString() => 'DietAdviceException: $message';
}

Future<void> initializeSecrets() async {
  if (!dotenv.isInitialized) {
    await dotenv.load(fileName: '.env');
  }
  ServicesBinding.ensureInitialized();
}

String _envOrThrow(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError('Environment variable "$key" is not set.');
  }
  return value;
}

Future<String> loadGoogleVisionServiceAccount() async {
  ServicesBinding.ensureInitialized();
  return rootBundle.loadString(googleVisionKeyAsset);
}

Future<NutritionInfo> getNutrition(String query) async {
  if (query.trim().isEmpty) {
    throw NutritionException('Query must not be empty.');
  }

  final uri = Uri.parse('https://trackapi.nutritionix.com/v2/natural/nutrients');
  final appId = _envOrThrow('NUTRITIONIX_APP_ID');
  final appKey = _envOrThrow('NUTRITIONIX_APP_KEY');

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

Future<String> getDietAdvice(
  Map<String, dynamic> nutrition,
  String goal,
) async {
  const allowedGoals = <String>{
    'похудение',
    'набор массы',
    'правильное питание',
    'спорт',
  };
  if (!allowedGoals.contains(goal)) {
    throw DietAdviceException('Unsupported goal "$goal".');
  }

  double readMetric(String key) {
    final value = nutrition[key];
    if (value is num) {
      return value.toDouble();
    }
    throw DietAdviceException('Nutrition map is missing "$key".');
  }

  final calories = readMetric('calories');
  final protein = readMetric('protein');
  final fat = readMetric('fat');
  final carbs = readMetric('carbs');

  final Uri uri = Uri.parse(
    'https://llm.api.cloud.yandex.net/foundationModels/v1/completion',
  );
  final apiKey = _envOrThrow('YANDEX_API_KEY');
  final folderId = _envOrThrow('YANDEX_FOLDER_ID');

  final prompt = '''
Ты — нутрициолог. Пользователь съел блюдо:
Калории: ${calories.toStringAsFixed(2)}
Белки: ${protein.toStringAsFixed(2)} г
Жиры: ${fat.toStringAsFixed(2)} г
Углеводы: ${carbs.toStringAsFixed(2)} г
Цель: $goal
Дай короткий совет, подходит ли блюдо, и предложи альтернативу, если нужно.
''';

  final response = await http.post(
    uri,
    headers: <String, String>{
      'Authorization': 'Api-Key $apiKey',
      'Content-Type': 'application/json',
      'x-folder-id': folderId,
    },
    body: jsonEncode(<String, dynamic>{
      'modelUri': 'gpt://$folderId/yandexgpt-lite',
      'completionOptions': <String, dynamic>{
        'stream': false,
        'temperature': 0.4,
        'maxTokens': 200,
      },
      'messages': <Map<String, String>>[
        <String, String>{
          'role': 'user',
          'text': prompt,
        },
      ],
    }),
  );

  if (response.statusCode != 200) {
    throw DietAdviceException(
      'YandexGPT request failed (${response.statusCode}).',
    );
  }

  final Map<String, dynamic> payload = jsonDecode(response.body);
  final result = payload['result'];
  if (result is! Map<String, dynamic>) {
    throw DietAdviceException('Unexpected response from YandexGPT.');
  }

  final alternatives = result['alternatives'];
  if (alternatives is! List || alternatives.isEmpty) {
    throw DietAdviceException('YandexGPT returned no advice.');
  }

  final firstAlternative = alternatives.first;
  if (firstAlternative is Map<String, dynamic>) {
    final altText = firstAlternative['text'];
    if (altText is String && altText.trim().isNotEmpty) {
      return altText.trim();
    }

    final message = firstAlternative['message'];
    if (message is Map<String, dynamic>) {
      final text = message['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }

      final content = message['content'];
      if (content is List && content.isNotEmpty) {
        final firstContent = content.first;
        if (firstContent is Map<String, dynamic>) {
          final innerText = firstContent['text'];
          if (innerText is String && innerText.trim().isNotEmpty) {
            return innerText.trim();
          }
        }
      }
    }
  }

  throw DietAdviceException('Unable to extract assistant response.');
}

Future<void> main() async {
  try {
    await initializeSecrets();

    final googleVisionKey = await loadGoogleVisionServiceAccount();
    print('Google Vision key length: ${googleVisionKey.length} characters');

    final info = await getNutrition('борщ');
    print('Nutrition info for борщ:');
    print(info);

    final advice = await getDietAdvice(
      <String, dynamic>{
        'calories': info.calories,
        'protein': info.protein,
        'fat': info.fat,
        'carbs': info.carbohydrates,
      },
      'похудение',
    );

    print('\nDiet advice:');
    print(advice);
  } on NutritionException catch (e) {
    print(e);
  } on DietAdviceException catch (e) {
    print(e);
  } catch (e) {
    print('Unexpected error: $e');
  }
}
