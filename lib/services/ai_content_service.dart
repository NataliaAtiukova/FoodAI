import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/diary_entry_v2.dart';

class AiContentException implements Exception {
  const AiContentException(this.message);
  final String message;

  @override
  String toString() => 'AiContentException: $message';
}

enum AiProvider { yandex, openAi }

typedef JsonMap = Map<String, dynamic>;

class AiContentService {
  AiContentService._({http.Client? client}) : _client = client ?? http.Client();

  static final AiContentService instance = AiContentService._();

  final http.Client _client;

  AiProvider? get _provider {
    if (AppConfig.hasYandexGptConfig) {
      return AiProvider.yandex;
    }
    if (AppConfig.hasOpenAiConfig) {
      return AiProvider.openAi;
    }
    return null;
  }

  bool get isConfigured => _provider != null;

  Future<String> generateAdvice({
    required List<DiaryEntryV2> diaryEntries,
    required JsonMap nutritionSummary,
    String? userGoal,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return _buildLocalAdvice(nutritionSummary, userGoal);
    }

    final summaryText = _formatSummary(nutritionSummary);
    final entriesText = _formatEntries(diaryEntries.take(10).toList());

    final prompt = StringBuffer()
      ..writeln(
          'Ты нутрициолог. Сформируй 3 лаконичных совета по питанию для пользователя.')
      ..writeln(
          'Ответ на русском языке, без приветствий, в формате нумерованного списка.')
      ..writeln('Учитывай цель пользователя: ${userGoal ?? 'не указана'}')
      ..writeln('Сводка по дневнику:')
      ..writeln(summaryText)
      ..writeln('Последние блюда:')
      ..writeln(entriesText);

    final result = await _complete(
      provider: provider,
      messages: <_AiMessage>[
        const _AiMessage(
          role: 'system',
          text:
              'Ты экспертом по питанию, давай практичные рекомендации, учитывай баланс КБЖУ и цели пользователя. Не добавляй вводных фраз.',
        ),
        _AiMessage(role: 'user', text: prompt.toString()),
      ],
      temperature: 0.45,
      maxTokens: 700,
    );

    return result.trim();
  }

  Future<List<JsonMap>> generateRecipes({
    required List<String> selectedProducts,
    required JsonMap nutritionSummary,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return _buildLocalRecipes(selectedProducts);
    }

    final prompt = StringBuffer()
      ..writeln(
          'Предложи 3 простых рецепта (по 1 порции) с упором на выбранные продукты.')
      ..writeln('Формат ответа — JSON-массив, у каждого рецепта поля:')
      ..writeln(
          '{"title":string,"description":string,"ingredients":string,"macros":string}.')
      ..writeln('Используй продукты: ${selectedProducts.join(', ')}.')
      ..writeln('Учитывай сводку БЖУ: ${_formatSummary(nutritionSummary)}.')
      ..writeln('Не добавляй код-блоки и комментарии, только JSON.');

    final raw = await _complete(
      provider: provider,
      messages: const <_AiMessage>[
        _AiMessage(
          role: 'system',
          text:
              'Ты шеф-повар и нутрициолог. Предлагай сбалансированные рецепты. Строго отвечай в JSON.',
        ),
      ],
      temperature: 0.7,
      maxTokens: 900,
      userMessage: prompt.toString(),
    );

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<JsonMap>().toList();
    } catch (_) {
      // Возвращаем fallback в случае ошибки парсинга
      return _buildLocalRecipes(selectedProducts);
    }
  }

  Future<JsonMap> generateMealPlan({
    required String goal,
    required int caloriesTarget,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return _buildLocalMealPlan(goal, caloriesTarget);
    }

    final prompt = StringBuffer()
      ..writeln('Составь недельный план питания для цели "$goal".')
      ..writeln(
          'Целевая калорийность в день: ${caloriesTarget.clamp(1200, 3500)}.')
      ..writeln(
          'Формат — JSON с полями {"days": [{"day":string,"meals":[{"title":string,"calories":number,"description":string}]}]}')
      ..writeln('Без доп. текста, строго валидный JSON.');

    final raw = await _complete(
      provider: provider,
      messages: const <_AiMessage>[
        _AiMessage(
          role: 'system',
          text:
              'Ты профессиональный нутрициолог. Формируй структурированные планы питания. Отвечай строго JSON без комментариев.',
        ),
      ],
      temperature: 0.5,
      maxTokens: 1200,
      userMessage: prompt.toString(),
    );

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return _buildLocalMealPlan(goal, caloriesTarget);
    }
  }

  Future<String> _complete({
    required AiProvider provider,
    required List<_AiMessage> messages,
    required double temperature,
    required int maxTokens,
    String? userMessage,
  }) async {
    final effectiveMessages = <_AiMessage>[...messages];
    if (userMessage != null) {
      effectiveMessages.add(_AiMessage(role: 'user', text: userMessage));
    }

    switch (provider) {
      case AiProvider.yandex:
        return _completeWithYandex(effectiveMessages, temperature, maxTokens);
      case AiProvider.openAi:
        return _completeWithOpenAi(effectiveMessages, temperature, maxTokens);
    }
  }

  Future<String> _completeWithYandex(
    List<_AiMessage> messages,
    double temperature,
    int maxTokens,
  ) async {
    final modelUri = AppConfig.effectiveYandexGptModel();
    if (modelUri.isEmpty) {
      throw const AiContentException('Модель YandexGPT не настроена.');
    }

    final body = <String, dynamic>{
      'modelUri': modelUri,
      'completionOptions': {
        'stream': false,
        'temperature': temperature,
        'maxTokens': maxTokens,
      },
      'messages': messages.map((m) => m.toYandexJson()).toList(),
    };

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    if (AppConfig.yandexIamToken.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] =
          'Bearer ${AppConfig.yandexIamToken}';
    } else if (AppConfig.yandexGptApiKey.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] =
          'Api-Key ${AppConfig.yandexGptApiKey}';
    } else {
      throw const AiContentException(
        'YandexGPT не настроен: отсутствуют IAM-токен и API-ключ.',
      );
    }

    final response = await _client.post(
      Uri.parse(
          'https://llm.api.cloud.yandex.net/foundationModels/v1/completion'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw AiContentException(
        'YandexGPT вернул ошибку: ${response.statusCode} ${response.body}',
      );
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    final alternatives = parsed['result']?['alternatives'] as List<dynamic>?;
    if (alternatives == null || alternatives.isEmpty) {
      throw const AiContentException('Пустой ответ от YandexGPT.');
    }

    final message = alternatives.first as Map<String, dynamic>;
    final text = message['message']?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const AiContentException('Пустой ответ от YandexGPT.');
    }

    return text;
  }

  Future<String> _completeWithOpenAi(
    List<_AiMessage> messages,
    double temperature,
    int maxTokens,
  ) async {
    final body = <String, dynamic>{
      'model': AppConfig.openAiModel,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'messages': messages.map((m) => m.toOpenAiJson()).toList(),
    };

    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${AppConfig.openAiApiKey}',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw AiContentException(
        'OpenAI вернул ошибку: ${response.statusCode} ${response.body}',
      );
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = parsed['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const AiContentException('Пустой ответ от OpenAI.');
    }

    final message = choices.first as Map<String, dynamic>;
    final content = message['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const AiContentException('Пустой ответ от OpenAI.');
    }

    return content;
  }

  String _formatSummary(JsonMap summary) {
    final buffer = StringBuffer();
    final calories =
        (summary['calories'] as num?)?.toStringAsFixedIfPossible() ?? '—';
    final protein =
        (summary['protein'] as num?)?.toStringAsFixedIfPossible() ?? '—';
    final fat = (summary['fat'] as num?)?.toStringAsFixedIfPossible() ?? '—';
    final carbs =
        (summary['carbs'] as num?)?.toStringAsFixedIfPossible() ?? '—';
    buffer
      ..writeln('Калории: $calories')
      ..writeln('Белки: $protein')
      ..writeln('Жиры: $fat')
      ..writeln('Углеводы: $carbs')
      ..writeln('Всего блюд: ${summary['entryCount'] ?? 0}');
    return buffer.toString();
  }

  String _formatEntries(List<DiaryEntryV2> entries) {
    if (entries.isEmpty) return 'Нет записей';
    return entries
        .map((entry) =>
            '${entry.name} (${entry.grams.toStringAsFixedIfPossible()} г, ${entry.factsForCurrentServing.calories.toStringAsFixedIfPossible()} ккал)')
        .join('; ');
  }

  String _buildLocalAdvice(JsonMap summary, String? goal) {
    final buffer = StringBuffer();
    buffer.writeln(
        '1. Добавьте цельнозерновой перекус и овощи к одному из приёмов пищи.');
    buffer.writeln(
        '2. Следите за питьевым режимом: не менее 6-8 стаканов воды в день.');
    buffer.writeln(
        '3. Планируйте рацион на день вперёд, чтобы легче удерживать цель "$goal".');

    final calories = summary['calories'] as double?;
    if (calories != null) {
      if (calories < 1400) {
        buffer.write(
            '\nДополнительно: калорийность низкая, подумайте о более плотном завтраке.');
      } else if (calories > 2600) {
        buffer.write(
            '\nДополнительно: общий калораж высоковат — уравновесьте меню более лёгким ужином.');
      }
    }

    return buffer.toString();
  }

  List<JsonMap> _buildLocalRecipes(List<String> products) {
    final baseProduct = products.isNotEmpty ? products.first : 'овощи';
    return <JsonMap>[
      {
        'title': 'Простой салат с $baseProduct',
        'description': 'Лёгкий салат для быстрого приёма пищи.',
        'ingredients':
            '$baseProduct, листовой салат, оливковое масло, лимонный сок',
        'macros': '~250 ккал на порцию',
      },
      {
        'title': 'Боул с киноа и белком',
        'description': 'Сбалансированное блюдо с белками и клетчаткой.',
        'ingredients': 'киноа, $baseProduct, шпинат, нута, йогуртовая заправка',
        'macros': '~420 ккал на порцию',
      },
      {
        'title': 'Тёплый овощной суп',
        'description': 'Насыщенный суп для ужина или обеда.',
        'ingredients':
            '$baseProduct, овощной бульон, морковь, сельдерей, специи',
        'macros': '~180 ккал на порцию',
      },
    ];
  }

  JsonMap _buildLocalMealPlan(String goal, int caloriesTarget) {
    final days = <JsonMap>[];
    const weekdays = <String>[
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];

    for (final day in weekdays) {
      days.add({
        'day': day,
        'meals': <JsonMap>[
          {
            'title': 'Завтрак',
            'calories': (caloriesTarget * 0.3).round(),
            'description': 'Овсяная каша на воде/молоке + ягоды + орехи.',
          },
          {
            'title': 'Обед',
            'calories': (caloriesTarget * 0.4).round(),
            'description': 'Цельнозерновые + белковый продукт + овощной салат.',
          },
          {
            'title': 'Ужин',
            'calories': (caloriesTarget * 0.25).round(),
            'description': 'Лёгкий белковый ужин с овощами.',
          },
          {
            'title': 'Перекус',
            'calories': (caloriesTarget * 0.05).round(),
            'description': 'Йогурт/фрукты/орехи по выбору.',
          },
        ],
      });
    }

    return <String, dynamic>{
      'goal': goal,
      'caloriesTarget': caloriesTarget,
      'days': days,
    };
  }
}

class _AiMessage {
  const _AiMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, String> toYandexJson() => <String, String>{
        'role': role,
        'text': text,
      };

  Map<String, String> toOpenAiJson() => <String, String>{
        'role': role,
        'content': text,
      };
}

extension _NumFormatting on num {
  String toStringAsFixedIfPossible() {
    return this % 1 == 0 ? toStringAsFixed(0) : toStringAsFixed(1);
  }
}
