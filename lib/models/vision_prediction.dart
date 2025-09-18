class VisionPrediction {
  const VisionPrediction({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;

  String confidencePercent({int fractionDigits = 0}) =>
      '${(confidence * 100).toStringAsFixed(fractionDigits)}%';
}
