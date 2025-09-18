import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_secrets.dart';

class DietAdviceException implements Exception {
  DietAdviceException(this.message);
  final String message;

  @override
  String toString() => 'DietAdviceException: $message';
}

const String _yandexCompletionEndpoint =
    'https://llm.api.cloud.yandex.net/foundationModels/v1/completion';
const String _yandexModelId = 'yandexgpt-lite';

String _buildModelUri(String folderId) =>
    'gpt://$folderId/$_yandexModelId/latest';

Map<String, String> _buildHeaders(String apiKey, String folderId) =>
    <String, String>{
      'Authorization': 'Api-Key $apiKey',
      'Content-Type': 'application/json',
      'x-folder-id': folderId,
    };

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

  final prompt = '''
Ты — нутрициолог. Пользователь съел блюдо:
Калории: ${calories.toStringAsFixed(2)}
Белки: ${protein.toStringAsFixed(2)} г
Жиры: ${fat.toStringAsFixed(2)} г
Углеводы: ${carbs.toStringAsFixed(2)} г
Цель: $goal
Дай короткий совет, подходит ли блюдо, и предложи альтернативу, если нужно.
''';

  final apiKey = envOrThrow('YANDEX_API_KEY');
  final folderId = envOrThrow('YANDEX_FOLDER_ID');
  final modelUri = _buildModelUri(folderId);

  final body = <String, dynamic>{
    'modelUri': modelUri,
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
  };

  final response = await http.post(
    Uri.parse(_yandexCompletionEndpoint),
    headers: _buildHeaders(apiKey, folderId),
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    throw DietAdviceException(
      'YandexGPT request failed (${response.statusCode}): ${response.body}',
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

  final first = alternatives.first;
  if (first is! Map<String, dynamic>) {
    throw DietAdviceException('Invalid alternative format.');
  }

  final message = first['message'];
  if (message is! Map<String, dynamic>) {
    throw DietAdviceException('Missing assistant message.');
  }

  final text = message['text'];
  if (text is! String || text.trim().isEmpty) {
    throw DietAdviceException('Empty assistant response.');
  }

  return text.trim();
}

Future<String> getYandexGPTResponse(String prompt) async {
  final uri = Uri.parse(_yandexCompletionEndpoint);
  final apiKey = envOrThrow('YANDEX_API_KEY');
  final folderId = envOrThrow('YANDEX_FOLDER_ID');
  final modelUri = _buildModelUri(folderId);

  final body = <String, dynamic>{
    'modelUri': modelUri,
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
  };

  final response = await http.post(
    uri,
    headers: _buildHeaders(apiKey, folderId),
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    debugPrint('YandexGPT error: ${response.statusCode} ${response.body}');
    throw Exception(
      'YandexGPT request failed with status ${response.statusCode}',
    );
  }

  final Map<String, dynamic> data = jsonDecode(response.body);
  final result = data['result'];
  if (result is! Map<String, dynamic>) {
    throw Exception('Unexpected response from YandexGPT');
  }

  final alternatives = result['alternatives'];
  if (alternatives is! List || alternatives.isEmpty) {
    throw Exception('No alternatives returned by YandexGPT');
  }

  final first = alternatives.first;
  if (first is! Map<String, dynamic>) {
    throw Exception('Invalid alternative format.');
  }

  final message = first['message'];
  if (message is! Map<String, dynamic>) {
    throw Exception('Missing assistant message.');
  }

  final text = message['text'];
  if (text is! String || text.trim().isEmpty) {
    throw Exception('Empty assistant response.');
  }

  return text.trim();
}
