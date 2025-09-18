# FoodAI (NutriGo)

FoodAI — Flutter-приложение, которое распознаёт блюда по фото, рассчитывает КБЖУ через Nutritionix и даёт советы от YandexGPT. Приложение хранит историю рациона в дневнике и показывает прогресс на наглядных графиках.

## Возможности

- Ввод блюда вручную, сканирование камерой или выбор фото из галереи (Google Cloud Vision).
- Автоматический расчёт калорий, белков, жиров и углеводов (Nutritionix).
- Советы по питанию от YandexGPT с учётом цели: Похудение, Набор мышц, ЗОЖ или Спорт.
- Сохранение блюд в дневник с категориями (завтрак, обед, ужин, перекус), заметками и фото.
- Поиск по базе Nutritionix и моментальное добавление в дневник.
- Дневные итоги и прогресс: график калорий за неделю и распределение БЖУ за день.

## Быстрый старт

```bash
flutter pub get
flutter run
```

Перед запуском создайте `.env` в корне проекта и добавьте ключи сервисов:

```dotenv
NUTRITIONIX_APP_ID=YOUR_NUTRITIONIX_APP_ID
NUTRITIONIX_APP_KEY=YOUR_NUTRITIONIX_APP_KEY
YANDEX_API_KEY=YOUR_YANDEX_GPT_API_KEY
YANDEX_FOLDER_ID=YOUR_YANDEX_FOLDER_ID
GOOGLE_VISION_KEY_PATH=assets/keys/vision_key.json
```

Скопируйте JSON сервисного аккаунта Google Vision в `assets/keys/vision_key.json` (папка уже в `.gitignore`).

## Архитектура

- `lib/services/vision_service.dart` — классификация изображений через Google Cloud Vision.
- `lib/services/nutrition_service.dart` — Nutritionix + советы YandexGPT.
- `lib/services/diary_service.dart` — хранение в Hive, агрегаты по дням.
- UI разбит на вкладки (`Home`, `Diary`, `Progress`) и экран результатов `ResultsScreen`.

## Полезные команды

```bash
# Проверка стиля
flutter analyze

# Запуск тестов
flutter test
```

## Отладка интеграций

- **Google Vision** — убедитесь, что billing включён в проекте Google Cloud и ключ имеет доступ к Vision API.
- **Nutritionix** — используйте Application ID и Key из `.env` и следите за лимитами запросов.
- **YandexGPT** — проверьте, что сервис включён в каталоге `b1gggscveki4khab1snj` и ключ активен.
