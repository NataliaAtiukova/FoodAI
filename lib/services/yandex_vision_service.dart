import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class YandexVisionException implements Exception {
  const YandexVisionException(this.message);
  final String message;

  @override
  String toString() => 'YandexVisionException: $message';
}

class YandexOcrResult {
  const YandexOcrResult({required this.fullText, required this.lines});

  final String fullText;
  final List<String> lines;

  bool get isEmpty => fullText.trim().isEmpty;
}

class YandexVisionService {
  YandexVisionService._({http.Client? client})
      : _client = client ?? http.Client();

  static final YandexVisionService instance = YandexVisionService._();

  final http.Client _client;

  static const String _endpoint =
      'https://vision.api.cloud.yandex.net/vision/v1/batchAnalyze';

  bool get isConfigured => AppConfig.hasYandexVisionConfig;

  Future<YandexOcrResult> recognizeText(File imageFile) async {
    if (!isConfigured) {
      throw const YandexVisionException(
        'Yandex Vision не настроен. Передайте токен или Api-Key и YANDEX_VISION_FOLDER_ID.',
      );
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final payload = <String, dynamic>{
        'folderId': AppConfig.yandexVisionFolderId,
        'analyze_specs': [
          {
            'content': base64Encode(bytes),
            'features': [
              {
                'type': 'TEXT_DETECTION',
                'text_detection_config': {
                  'language_codes': ['ru', 'en'],
                },
              },
            ],
          },
        ],
      };

      final headers = <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json',
      };

      if (AppConfig.yandexIamToken.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] =
            'Bearer ${AppConfig.yandexIamToken}';
      } else if (AppConfig.yandexVisionApiKey.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] =
            'Api-Key ${AppConfig.yandexVisionApiKey}';
      }

      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw YandexVisionException(
          'Ошибка OCR: ${response.statusCode} ${response.body}',
        );
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final specs = json['results'] as List<dynamic>?;
      if (specs == null || specs.isEmpty) {
        return const YandexOcrResult(fullText: '', lines: <String>[]);
      }

      final blocks = specs
          .expand((result) {
            if (result is! Map<String, dynamic>) return const <dynamic>[];
            final analysis = result['results'] as List<dynamic>?;
            if (analysis == null) return const <dynamic>[];
            return analysis;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final lines = <String>[];
      for (final block in blocks) {
        final textAnnotation = block['textDetection'] as Map<String, dynamic>?;
        final text = textAnnotation?['fullText'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          lines.addAll(
            text
                .split(RegExp(r'[\r\n]+'))
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty),
          );
        }
      }

      final fullText = lines.join('\n');
      return YandexOcrResult(fullText: fullText, lines: lines);
    } catch (error) {
      throw YandexVisionException('Не удалось распознать текст: $error');
    }
  }

  void dispose() {
    _client.close();
  }
}
