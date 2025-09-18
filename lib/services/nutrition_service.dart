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
  static const String _openFoodFactsEndpoint =
      'https://world.openfoodfacts.org/api/v0/product/';
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

    final uri = Uri.parse(
      'https://ru.openfoodfacts.org/cgi/search.pl',
    ).replace(queryParameters: <String, String>{
      'search_terms': trimmed,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return const <SearchFoodItem>[];
    }

    final Map<String, dynamic> payload = jsonDecode(response.body);
    final products = payload['products'];
    if (products is! List) {
      return const <SearchFoodItem>[];
    }

    final List<SearchFoodItem> items = <SearchFoodItem>[];
    for (final product in products) {
      if (product is! Map<String, dynamic>) {
        continue;
      }
      final name = (product['product_name_ru'] as String?)?.trim() ??
          (product['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      final String? brand = (product['brands'] as String?)?.split(',').first.trim();
      final nutriments = product['nutriments'];
      NutritionFacts? facts;
      if (nutriments is Map<String, dynamic>) {
        double? read(String key) {
          final value = nutriments[key];
          if (value is num) {
            return value.toDouble();
          }
          if (value is String) {
            return double.tryParse(value);
          }
          return null;
        }

        final calories = read('energy-kcal_100g');
        final protein = read('proteins_100g');
        final fat = read('fat_100g');
        final carbs = read('carbohydrates_100g');

        if (calories != null && protein != null && fat != null && carbs != null) {
          facts = NutritionFacts(
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
          );
        }
      }

      items.add(
        SearchFoodItem(
          name: name,
          brand: brand,
          thumbnailUrl: (product['image_thumb_url'] as String?)?.trim(),
          factsPer100g: facts,
        ),
      );
    }

    return items;
  }

  Future<NutritionResult?> fetchFoodByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final response = await http.get(Uri.parse('$_openFoodFactsEndpoint$trimmed.json'));
    if (response.statusCode != 200) {
      return null;
    }

    final Map<String, dynamic> payload = jsonDecode(response.body);
    final product = payload['product'];
    if (product is! Map<String, dynamic>) {
      return null;
    }

    final nutriments = product['nutriments'];
    if (nutriments is! Map<String, dynamic>) {
      return null;
    }

    double? readNutriment(String key) {
      final value = nutriments[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    final calories = readNutriment('energy-kcal_100g');
    final protein = readNutriment('proteins_100g');
    final fat = readNutriment('fat_100g');
    final carbs = readNutriment('carbohydrates_100g');

    if (calories == null || protein == null || fat == null || carbs == null) {
      return null;
    }

    final facts = NutritionFacts(
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
    );

    final name = (product['product_name'] as String?)?.trim();
    return NutritionResult(
      name: name == null || name.isEmpty ? 'Продукт по штрихкоду $trimmed' : name,
      facts: facts,
      servingQuantity: 100,
      servingUnit: 'г',
      photoUrl: (product['image_thumb_url'] as String?)?.trim(),
    );
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
