import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Ensures the `.env` file is loaded before accessing secrets.
Future<void> ensureEnvLoaded() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!dotenv.isInitialized) {
    await dotenv.load(fileName: '.env');
  }
}

/// Reads an environment value or throws if it is missing.
String envOrThrow(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError('Environment variable "$key" is not set.');
  }
  return value;
}
