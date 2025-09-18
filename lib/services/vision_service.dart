import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';

import '../app_secrets.dart';
import '../models/vision_prediction.dart';

const List<String> _visionScopes = <String>[
  vision.VisionApi.cloudVisionScope,
];

class VisionException implements Exception {
  VisionException(this.message);
  final String message;

  @override
  String toString() => 'VisionException: $message';
}

class VisionService {
  VisionService._();

  static final VisionService instance = VisionService._();

  Future<List<VisionPrediction>> analyzeFood(File image) async {
    if (!await image.exists()) {
      throw VisionException('Файл изображения не найден.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw VisionException('Файл изображения пуст.');
    }

    return _recognizeLabels(bytes);
  }

  Future<List<VisionPrediction>> _recognizeLabels(Uint8List imageBytes) async {
    final credentials = await _loadCredentials();
    final client = await clientViaServiceAccount(credentials, _visionScopes);
    try {
      final api = vision.VisionApi(client);
      final request = vision.BatchAnnotateImagesRequest(
        requests: <vision.AnnotateImageRequest>[
          vision.AnnotateImageRequest(
            image: vision.Image(content: base64Encode(imageBytes)),
            features: <vision.Feature>[
              vision.Feature(type: 'LABEL_DETECTION', maxResults: 10),
            ],
          ),
        ],
      );

      final response = await api.images.annotate(request);
      final responses = response.responses;
      if (responses == null || responses.isEmpty) {
        throw VisionException('Vision API не вернул ответ.');
      }

      final labels = responses.first.labelAnnotations;
      if (labels == null || labels.isEmpty) {
        throw VisionException('Не удалось распознать еду.');
      }

      final predictions = labels
          .where((annotation) =>
              (annotation.description ?? '').trim().isNotEmpty &&
              (annotation.score ?? 0) > 0)
          .map(
            (annotation) => VisionPrediction(
              label: annotation.description!.trim(),
              confidence: (annotation.score ?? 0).clamp(0, 1),
            ),
          )
          .toList();

      if (predictions.isEmpty) {
        throw VisionException('Не удалось распознать еду.');
      }

      predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
      return predictions;
    } finally {
      client.close();
    }
  }

  Future<ServiceAccountCredentials> _loadCredentials() async {
    final path = envOrThrow('GOOGLE_VISION_KEY_PATH').trim();

    ServiceAccountCredentials parse(String data) {
      final Map<String, dynamic> map = jsonDecode(data);
      return ServiceAccountCredentials.fromJson(map);
    }

    try {
      final jsonString = await rootBundle.loadString(path);
      return parse(jsonString);
    } catch (_) {
      final file = File(path);
      if (!file.existsSync()) {
        throw VisionException('Файл ключа Vision не найден по пути "$path".');
      }
      try {
        return parse(await file.readAsString());
      } on FormatException catch (error) {
        throw VisionException('Некорректный JSON ключа Vision: $error');
      }
    }
  }
}
