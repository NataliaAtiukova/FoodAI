# FoodAI (NutriGo)

FoodAI — Flutter-приложение, которое рассчитывает КБЖУ блюда через Nutritionix и подбирает рекомендацию по питанию от YandexGPT. Дополнительно можно распознать блюдо по фото с помощью Google Vision.

## Быстрый старт

```bash
flutter pub get
flutter run
```

Перед запуском создайте `.env` (см. пример ниже) и положите ключ Google Vision по пути `assets/keys/zinc-night-453821-n5-f79b987f7522.json`.

### Конфигурация `.env`

```dotenv
YANDEX_API_KEY=YOUR_YANDEX_API_KEY
YANDEX_FOLDER_ID=YOUR_YANDEX_FOLDER_ID
NUTRITIONIX_APP_ID=YOUR_NUTRITIONIX_APP_ID
NUTRITIONIX_APP_KEY=YOUR_NUTRITIONIX_APP_KEY
```

## Пример запроса к YandexGPT

```http
POST https://llm.api.cloud.yandex.net/foundationModels/v1/completion
Authorization: Api-Key YOUR_YANDEX_API_KEY
x-folder-id: YOUR_YANDEX_FOLDER_ID
Content-Type: application/json

{
  "modelUri": "gpt://YOUR_YANDEX_FOLDER_ID/yandexgpt/latest",
  "completionOptions": {
    "stream": false,
    "temperature": 0.4,
    "maxTokens": 200
  },
  "messages": [
    {
      "role": "user",
      "text": "Ты — нутрициолог. Пользователь съел блюдо: Калории: 350 Белки: 25 г Жиры: 10 г Углеводы: 40 г Цель: похудение Дай короткий совет, подходит ли блюдо, и предложи альтернативу, если нужно."
    }
  ]
}
```

### Пример успешного ответа

```json
{
  "result": {
    "alternatives": [
      {
        "message": {
          "role": "assistant",
          "text": "Блюдо подходит для похудения: умеренная калорийность и хороший баланс белков. Если хочешь облегчить его, замени часть углеводов на свежие овощи или салат."
        },
        "status": "ALTERNATIVE_STATUS_FINAL"
      }
    ],
    "usage": {
      "inputTextTokensCount": 74,
      "outputTextTokensCount": 42
    }
  }
}
```

## Вызов `getDietAdvice` в коде

Во время расчёта приложение передаёт данные о блюде и цель "Похудение" (строка `"похудение"` в API):

```dart
final advice = await getDietAdvice(
  {
    'calories': info.calories,
    'protein': info.protein,
    'fat': info.fat,
    'carbs': info.carbohydrates,
  },
  'похудение',
);
```

Тот же вызов используется в `lib/main.dart`, когда пользователь выбирает цель.
