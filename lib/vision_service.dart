import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';

const String _googleVisionKeyAsset =
    'assets/keys/zinc-night-453821-n5-f79b987f7522.json';
const List<String> _visionScopes = <String>[
  vision.VisionApi.cloudVisionScope,
];

class VisionException implements Exception {
  VisionException(this.message);
  final String message;

  @override
  String toString() => 'VisionException: $message';
}

Future<String> analyzeImage(File image) async {
  if (!await image.exists()) {
    throw VisionException('Image file not found: ${image.path}');
  }

  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) {
    throw VisionException('Image data is empty.');
  }

  return _recognizeFoodFromImage(bytes);
}

Future<String> _recognizeFoodFromImage(Uint8List imageBytes) async {
  final credentials = await _loadServiceAccount();
  final authClient = await clientViaServiceAccount(credentials, _visionScopes);
  try {
    final api = vision.VisionApi(authClient);
    final request = vision.BatchAnnotateImagesRequest(
      requests: <vision.AnnotateImageRequest>[
        vision.AnnotateImageRequest(
          image: vision.Image(content: base64Encode(imageBytes)),
          features: <vision.Feature>[
            vision.Feature(type: 'LABEL_DETECTION', maxResults: 5),
          ],
        ),
      ],
    );

    final response = await api.images.annotate(request);
    final responses = response.responses;
    if (responses == null || responses.isEmpty) {
      throw VisionException('Vision API returned no response.');
    }

    final labelAnnotations = responses.first.labelAnnotations;
    if (labelAnnotations == null || labelAnnotations.isEmpty) {
      throw VisionException('Unable to recognize the dish.');
    }

    labelAnnotations.sort(
      (a, b) => (b.score ?? 0).compareTo(a.score ?? 0),
    );

    final candidate = labelAnnotations.firstWhere(
      (annotation) {
        final description = annotation.description?.toLowerCase() ?? '';
        return description.contains('food') || description.contains('dish');
      },
      orElse: () => labelAnnotations.first,
    );

    final description = candidate.description?.trim();
    if (description == null || description.isEmpty) {
      throw VisionException('Vision API returned empty description.');
    }

    return description;
  } on Exception catch (error) {
    throw VisionException('Failed to recognize image: $error');
  } finally {
    authClient.close();
  }
}

Future<ServiceAccountCredentials> _loadServiceAccount() async {
  try {
    final jsonString = await rootBundle.loadString(_googleVisionKeyAsset);
    final Map<String, dynamic> map = jsonDecode(jsonString);
    return ServiceAccountCredentials.fromJson(map);
  } on FlutterError {
    throw VisionException(
      'Google Vision key not found at "$_googleVisionKeyAsset".',
    );
  } on FormatException catch (error) {
    throw VisionException('Invalid Vision service account JSON: $error');
  }
}
