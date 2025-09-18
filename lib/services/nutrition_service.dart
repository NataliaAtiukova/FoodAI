import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_secrets.dart';
import '../models/nutrition_models.dart';
import '../models/search_food_item.dart';

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

class NutritionService {
  NutritionService._();

  static final NutritionService instance = NutritionService._();

  static final Uri _nutritionixUri =
      Uri.parse('https://trackapi.nutritionix.com/v2/natural/nutrients');
  static final Uri _nutritionixSearchUri =
      Uri.parse('https://trackapi.nutritionix.com/v2/search/instant');
  static final Uri _yandexUri = Uri.parse(
    'https://llm.api.cloud.yandex.net/foundationModels/v1/completion',
  );

  Future<NutritionResult> fetchNutrition(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw NutritionException('Введите название блюда для анализа.');
    }

    final appId = envOrThrow('NUTRITIONIX_APP_ID');
    final appKey = envOrThrow('NUTRITIONIX_APP_KEY');

    final response = await http.post(
      _nutritionixUri,
      headers: <String, String>{
        'x-app-id': appId,
        'x-app-key': appKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'query': trimmed,
      }),
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw NutritionException('Не удалось получить данные о блюде.');
      }
      throw NutritionException(
        'Nutritionix недоступен (${response.statusCode}). Попробуйте позже.',
      );
    }

    final Map<String, dynamic> payload = jsonDecode(response.body);
    final foods = payload['foods'];
    if (foods is! List || foods.isEmpty) {
      throw NutritionException('Не удалось получить данные о блюде.');
    }

    final first = foods.first;
    if (first is! Map<String, dynamic>) {
      throw NutritionException('Ответ Nutritionix имеет неверный формат.');
    }

    double readDouble(String key) {
      final value = first[key];
      if (value is num) {
        return value.toDouble();
      }
      throw NutritionException('Отсутствует значение "$key" в ответе.');
    }

    final facts = NutritionFacts(
      calories: readDouble('nf_calories'),
      protein: readDouble('nf_protein'),
      fat: readDouble('nf_total_fat'),
      carbs: readDouble('nf_total_carbohydrate'),
    );

    return NutritionResult(
      name: (first['food_name'] as String?)?.trim() ?? trimmed,
      facts: facts,
      servingQuantity: (first['serving_qty'] as num?)?.toDouble(),
      servingUnit: first['serving_unit'] as String?,
      photoUrl: (first['photo'] is Map<String, dynamic>)
          ? (first['photo']['thumb'] as String?)
          : null,
    );
  }

  Future<List<SearchFoodItem>> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <SearchFoodItem>[];
    }

    final appId = envOrThrow('NUTRITIONIX_APP_ID');
    final appKey = envOrThrow('NUTRITIONIX_APP_KEY');

    final response = await http.get(
      _nutritionixSearchUri.replace(queryParameters: <String, String>{
        'query': trimmed,
        'detailed': 'true',
      }),
      headers: <String, String>{
        'x-app-id': appId,
        'x-app-key': appKey,
      },
    );

    if (response.statusCode != 200) {
      return const <SearchFoodItem>[];
    }

    final Map<String, dynamic> payload = jsonDecode(response.body);
    final List<SearchFoodItem> results = <SearchFoodItem>[];

    void parseList(dynamic list) {
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final name = (item['food_name'] as String?)?.trim();
            if (name == null || name.isEmpty) {
              continue;
            }
            final brand = (item['brand_name'] as String?)?.trim();
            String? thumb;
            final photo = item['photo'];
            if (photo is Map<String, dynamic>) {
              thumb = (photo['thumb'] as String?)?.trim();
            }
            results.add(
              SearchFoodItem(name: name, brand: brand, thumbnailUrl: thumb),
            );
          }
        }
      }
    }

    parseList(payload['common']);
    parseList(payload['branded']);

    return results;
  }

  Future<String> fetchDietAdvice(
    NutritionFacts facts,
    NutritionGoal goal, {
    String? productName,
  }) async {
    final apiKey = envOrThrow('YANDEX_API_KEY');
    final folderId = envOrThrow('YANDEX_FOLDER_ID');

    final prompt = _buildPrompt(facts, goal, productName: productName);

    final response = await http.post(
      _yandexUri,
      headers: <String, String>{
        'Authorization': 'Api-Key $apiKey',
        'Content-Type': 'application/json',
        'x-folder-id': folderId,
      },
      body: jsonEncode(<String, dynamic>{
        'modelUri': 'gpt://$folderId/yandexgpt-lite/latest',
        'completionOptions': <String, dynamic>{
          'stream': false,
          'temperature': 0.3,
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
        'YandexGPT вернул ошибку (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> payload = jsonDecode(response.body);
    final result = payload['result'];
    if (result is! Map<String, dynamic>) {
      throw DietAdviceException('Неожиданный ответ от YandexGPT.');
    }

    final alternatives = result['alternatives'];
    if (alternatives is! List || alternatives.isEmpty) {
      throw DietAdviceException('YandexGPT не вернул совет.');
    }

    final firstAlternative = alternatives.first;
    if (firstAlternative is Map<String, dynamic>) {
      final message = firstAlternative['message'];
      if (message is Map<String, dynamic>) {
        final text = message['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }

    throw DietAdviceException('Не удалось извлечь текст совета.');
  }

  Future<NutritionAnalysis> analyzeWithAdvice(
    String query,
    NutritionGoal goal,
  ) async {
    final result = await fetchNutrition(query);
    final advice = await fetchDietAdvice(
      result.facts,
      goal,
      productName: result.name,
    );
    return NutritionAnalysis(result: result, advice: advice);
  }

  String _buildPrompt(
    NutritionFacts facts,
    NutritionGoal goal, {
    String? productName,
  }) {
    final goalText = goal.label;
    final nameText = productName == null || productName.isEmpty
        ? ''
        : 'Блюдо: $productName\n';

    return 'Ты — нутрициолог. Помоги пользователю достичь цели "$goalText".'
        '\n$nameText'
        'Калории: ${facts.calories.toStringAsFixed(1)}\n'
        'Белки: ${facts.protein.toStringAsFixed(1)} г\n'
        'Жиры: ${facts.fat.toStringAsFixed(1)} г\n'
        'Углеводы: ${facts.carbs.toStringAsFixed(1)} г\n'
        'Дай практичный совет по приёму пищи и возможную альтернативу.';
  }
}
