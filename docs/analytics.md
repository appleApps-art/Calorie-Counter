# Аналітика Bity (Amplitude)

Усі події йдуть в Amplitude через `Analytics.tracker` (`Data/Services/Analytics`).
Перевірити локально: запустити DEBUG-збірку з аргументом `-logAnalytics`, кожна подія друкується в консоль як `[analytics] назва ключ=значення …`.

## Що додається до кожної події автоматично

| Властивість | Що означає |
|---|---|
| `screen` | екран, на якому сталася дія (для `screen_viewed` — екран, що відкрився) |
| `is_offline` | чи був телефон без інтернету в цей момент |

## Шлях користувача

| Подія | Коли | Властивості |
|---|---|---|
| `screen_viewed` | відкрився екран | `screen`, `previous_screen`, `seconds_on_previous_screen`, `screen_index` (номер кроку в сесії) |
| `tab_selected` | перемкнув вкладку | `tab` |
| `[Amplitude] Element Interacted` | будь-яке натискання (автоматично Amplitude) | підпис кнопки, клас екрана, шлях у дереві view. Текст, який вводить користувач, не записується |
| `[Amplitude] Rage Click`, `Dead Click` | часті натискання в одне місце / натискання без реакції | те саме |

Закриття шторки або повернення назад повертає «поточний екран» на той, що під ним, тож дії після цього прив'язані до правильного екрана.

## Запуски й сесії

| Подія | Коли | Властивості |
|---|---|---|
| `app_first_opened` | найперший запуск після встановлення (один раз) | `app_version` |
| `app_opened` | кожен запуск і кожне повернення з фону | `launch` (`cold`/`warm`), `open_count`, `days_since_first_open`, `hours_since_last_open` |
| `app_backgrounded` | користувач згорнув застосунок | `seconds_in_foreground`, `last_screen`, `seconds_on_last_screen` |
| `[Amplitude] Session Start/End`, `Application Installed/Updated` | автоматично Amplitude | — |

Користувачі, які пройшли онбординг ще до цієї версії, `app_first_opened` не отримують, щоб не рахувались як нові встановлення.

## Властивості користувача (оновлюються на кожному відкритті)

`first_open_date`, `first_app_version` (записуються один раз), `open_count`, `days_since_first_open`, `last_open_date`, `app_version`, `is_premium`, `onboarding_completed`, `goal`, `sex`, `activity_level`, `age_group`, `theme`, `units`, `language`, `health_sync_enabled`, `notifications_enabled`, `current_streak`, `longest_streak`, `level`, `xp`, `badges_unlocked`, `saved_recipes`, `locale`.

Зріст, вага й цільова вага не надсилаються: це медичні дані.

## Онбординг

| Подія | Властивості |
|---|---|
| `onboarding_started` | — |
| `onboarding_step_completed` | `step` (`goal`, `sex`, `age`, `body`, `health`, `activity`, `plan`), `value` (ціль, стать, група віку, `connect`/`later`, рівень активності) |
| `onboarding_step_back` | `step` |
| `onboarding_completed` | `goal` |
| `paywall_shown` / `paywall_closed` / `purchase_completed` / `purchase_failed` | `placement` |

## Щоденник і запис їжі

| Подія | Властивості |
|---|---|
| `quick_log_option_selected` | `option` (`scanFood`, `scanBarcode`, `search`, `voiceLog`) |
| `food_log_started` | `method`, `source`, `meal_type` |
| `food_item_opened` | `source` (`recent`, `search_results`, `catalog`, `ask_bity`), `food_type` |
| `food_recognition_finished` | `method` (`photo`, `fridge`, `voice`, `text`, `barcode`), `outcome` (`recognized`, `no_food`, `not_found`, `offline`, `failed`), `confidence` (0–100) |
| `food_logged` | `method`, `meal_type`, `calories` |
| `food_log_failed` | `method` |
| `food_search_performed` | `query_length`, `result_count` |
| `food_deleted`, `food_marked_eaten` (`eaten`), `all_food_marked_eaten` (`count`), `food_portion_changed` | `meal_type` |
| `diary_date_changed` | `days_from_today` |
| `water_logged` (`amount_ml`), `water_removed`, `glass_volume_saved` | — |
| `weight_logged`, `workout_logged`, `progress_photo_saved` | — |
| `meal_edit_opened`, `meal_ai_sent`, `meal_ai_completed` | `meal_type`, … |

## Рецепти, плани, комора

| Подія | Властивості |
|---|---|
| `recipe_hub_tab_selected` | `tab` |
| `recipe_opened` | `source` (`browse`, `search`, `saved`, `section`, `create`, `meal_plan`, `pantry`, `photo`/`voice`/… з запису їжі), `origin` (`catalog`/`ai`) |
| `recipe_section_opened` | `section` |
| `recipe_filters_applied` | `filter_count` |
| `recipe_saved` | `saved` |
| `recipe_add_tapped` | `meal_type` (сам запис рахується в `food_logged`) |
| `recipe_shared` | — |
| `recipe_create_started` | `kind` (`recipe`/`meal_plan`), `source` (`pantry`/`custom`), `ingredient_count` |
| `recipe_create_finished` | `kind`, `success`, `origin`, `seconds` |
| `meal_plan_opened` | — |
| `pantry_items_added` | `count`, `method` (`fridge_scan`, джерело продукту) |
| `pantry_items_deleted` | `count` |

## Bity AI

`ai_message_sent`, `ai_message_completed` (`success`, `action_count`, `source`), `ai_action_applied` (`kind`: `log_food`, `swap_food`, `meal_suggestion`, `log_water`, `save_recipe`, …, `success`), `ai_intro_completed`.

## Нагороди

`badge_unlocked` (`badge`, у момент отримання), `badge_celebration_shown`, `badge_opened` (`badge`, `earned`), `badge_shared`, `level_reached` (`level`).

## Налаштування й сповіщення

`setting_changed` (`setting`: `theme`, `units`, `nutrition_goal`, `weight_goal`, `daily_goals`, `avatar`, `health`, `restore_purchases`, `preference_added`, `preference_removed`, `reminder_<тип>`; `value`), `health_sync_toggled`, `notification_permission_answered` (`granted`), `notification_opened` (`kind` нагадування), `app_rating_shown`, `app_rating_tapped`.

## Тертя: де користувач не отримав те, що хотів

| Подія | Властивості |
|---|---|
| `error_shown` | `context` (`recipe_details`, `create_recipe`, `ai_chat`, `paywall_*`, `photo_camera`, `food_classification`), `reason` (`offline`, `failed`, `unavailable`, `capture_failed`, `no_ingredients`) |
| `offline_state_shown` | `context` (`recipes_browse`, `recipes_search`, `recipe_section`, `food_search`) |
| `retry_tapped` | `context` |

## Готові питання для аналізу

- **Де застрягають:** розподіл `app_backgrounded.last_screen` для сесій без `food_logged`; `screen_viewed` з великим `seconds_on_previous_screen`; `Rage Click` / `Dead Click` за екраном.
- **Воронка онбордингу:** `app_first_opened` → `onboarding_started` → `onboarding_step_completed` по кожному `step` → `onboarding_completed` → `paywall_shown` → `purchase_completed`.
- **Перша цінність:** час від `app_first_opened` до першого `food_logged`.
- **Утримання:** `app_opened` за `days_since_first_open`; когорти за `first_open_date`.
- **Чим користуються:** `food_log_started.method`, `food_recognition_finished.outcome` за `method`, `recipe_opened.source`, `ai_action_applied.kind`.
- **Надійність:** `food_recognition_finished` з `outcome` = `failed`/`offline`, `error_shown`, `offline_state_shown`, частка `is_offline=true`.
