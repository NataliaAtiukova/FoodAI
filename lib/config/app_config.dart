class AppConfig {
  const AppConfig._();

  static const String yandexIamToken =
      String.fromEnvironment('YANDEX_IAM_TOKEN');
  static const String yandexVisionFolderId = String.fromEnvironment(
    'YANDEX_VISION_FOLDER_ID',
    defaultValue: '',
  );
  static const String yandexVisionApiKey = String.fromEnvironment(
    'YANDEX_VISION_API_KEY',
    defaultValue: '',
  );
  static const String yandexGptApiKey = String.fromEnvironment(
    'YANDEX_GPT_API_KEY',
    defaultValue: '',
  );
  static const String yandexGptModel =
      String.fromEnvironment('YANDEX_GPT_MODEL');
  static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String openAiModel =
      String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini');

  static bool get hasYandexVisionConfig =>
      (yandexIamToken.isNotEmpty || yandexVisionApiKey.isNotEmpty) &&
      yandexVisionFolderId.isNotEmpty;

  static bool get hasYandexGptConfig =>
      (yandexIamToken.isNotEmpty || yandexGptApiKey.isNotEmpty) &&
      (yandexGptModel.isNotEmpty || yandexVisionFolderId.isNotEmpty);

  static bool get hasOpenAiConfig => openAiApiKey.isNotEmpty;

  static String effectiveYandexGptModel() {
    if (yandexGptModel.isNotEmpty) {
      return yandexGptModel;
    }
    if (yandexVisionFolderId.isEmpty) {
      return '';
    }
    return 'gpt://$yandexVisionFolderId/yandexgpt/latest';
  }
}
