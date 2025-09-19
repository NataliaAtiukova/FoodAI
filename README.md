# FoodAI

FoodAI — Flutter-приложение, которое сканирует упаковки с помощью Yandex Vision OCR, ищет продукты в Open Food Facts RU и ведёт дневник питания с AI-подсказками.

## Возможности

- Сканирование текста на этикетке (камера/галерея) и быстрый поиск продукта в Open Food Facts.
- Поиск по названию или штрихкоду без сторонних Nutritionix/Google Vision сервисов.
- Мгновенное добавление продукта в дневник с возможностью редактировать граммовку и пересчёт КБЖУ.
- Вкладка «AI Советы» с персональными рекомендациями по дневнику (YandexGPT или ChatGPT).
- Вкладка «Рецепты» — подбор идей на основе выбранных продуктов из дневника.
- Вкладка «План питания» — недельное меню под цель: похудение, набор массы или ЗОЖ.
- Локальное хранение дневника и избранных продуктов, кеширование найденных позиций OFF.

## Быстрый старт

```bash
flutter pub get
flutter run \
  --dart-define=YANDEX_IAM_TOKEN=... \
  --dart-define=YANDEX_VISION_FOLDER_ID=...
```

Дополнительные переменные (необязательно):

- `YANDEX_GPT_MODEL` — кастомная модель YandexGPT (`gpt://<folder-id>/yandexgpt/latest` по умолчанию).
- `OPENAI_API_KEY` и `OPENAI_MODEL` — для использования ChatGPT вместо YandexGPT.

Если ключи не заданы, приложение использует локальные заглушки для советов/рецептов/плана питания.

## Архитектура

- `lib/services/yandex_vision_service.dart` — OCR через Yandex Vision.
- `lib/services/local_food_database_service.dart` — поиск и кеширование результатов Open Food Facts.
- `lib/services/ai_content_service.dart` — генерация советов, рецептов и планов питания (YandexGPT/OpenAI + fallback).
- `lib/services/diary_service_v2.dart` — хранение дневника в `SharedPreferences`, пересчёт КБЖУ.
- UI разбит на вкладки нижней навигации: `Home` (сканер + поиск), `Search`, `Diary`, `Advice` (TabBar: AI Советы/Рецепты/План питания).

## Полезные команды

```bash
flutter analyze
flutter test
```

## Настройка интеграций

- **Yandex Vision OCR** — получите IAM-токен и `folderId`, передайте через `--dart-define`.
- **YandexGPT / ChatGPT** — для лучшего качества советов и планов добавьте соответствующие ключи.
- **Open Food Facts** — используется публичный RU API, данные кешируются в локальной SQLite базе.

Теперь проект полностью избавлен от Google Vision и Nutritionix.
