# Bity — темна тема, 10 вересня 2026

## Статус після виправлень

Підтверджені розбіжності F1–F6 виправлено в клієнті. Деталі рецепта перевірено окремо: [рендери й результати](../../qa/recipe-detail-dark-palette/README.md). Решту палітри — план, комору, створення рецепта, фільтри, налаштування та їхні вікна — перевірено в наступному проході: [зміни, рендери й межі перевірки](../../qa/remaining-dark-palette/README.md).

- F1: картки деталей рецепта, плану та комори використовують backgroundsPrimaryElevated через cardFillColor; колір не скидається під час layout.
- F2: чорний фон налаштувань, сірі секції та сірі іконки в dark.
- F3: чорні написи й хрестики на вибраних бірюзових/червоних chips у dark.
- F4: чорні галочки комори; старе зображення олівця очищається при переході в режим вибору.
- F5: адаптивні розділювачі сповіщень, білі кола й сірі системні іконки в dark.
- F6: чорні списки в сірих вікнах налаштувань; декоративний dark-фон взято безпосередньо з Figma.

Додатково виправлено скидання кольорів карток CreateRecipeForm, теги інгредієнтів і вибраний день плану. Для Search Results у фільтрах повторна звірка конкретного шару 262:27034 підтвердила backgroundsPrimary, а не backgroundsPrimaryElevated: початкове припущення попереднього аудиту уточнено.

Це закриває перелік підтверджених помилок палітри. Повний інтерактивний прохід усіх 59 станів, включно з мережею, клавіатурою, VoiceOver і Dynamic Type, не виконано. Нижче збережено історичні знахідки й перелік переглянутих макетів; вони не означають, що кожен стан реалізації перевірений.

## Початковий аудит — історичні знахідки

Переглянуто 59 темних макетів Figma та код. Світла група 262:24622 тоді повернула лише контейнер без дочірніх шарів, експорти завершилися Transport closed. Зображення в каталозі images — макети Figma. Знімки реалізації з наступних перевірок розміщено за QA-посиланнями вище.

## Розбіжності

### F1. Картки деталей рецепта, плану та комори

У Figma картки темно-сірі. Код використовує AppColor.card, що в dark повертає чорний. Втрачається відділення карток від фону.

Код: RecipeDetailViewController.swift:194–196,551; MealPlanPreviewViewController.swift:157; MealPlanMealRowView.swift:82; MyPantryViewController.swift:397.

Застосувати backgroundsPrimaryElevated до карток саме цих екранів; зберегти світлий колір. Не міняти AppColor.card глобально: чорні вкладені поля в sheets відповідають макету.

### F2. Головний екран налаштувань

Темний макет має чорний фон і темно-сірі секції. Код задає gray6 для фону і card для секцій — протилежне співвідношення.

Код: SettingsViewController.swift:32,189.

Ввести окремі кольори фону сторінки і секції: dark black / gray6, не змінюючи light.

### F3. Вибрані фільтри та виключені інгредієнти

У темному макеті чорний текст на бірюзових і червоних chips; код жорстко задає білий.

Код: RecipeFiltersViewController.swift:545–551.

Застосувати AppColor.onAccent для підпису та іконки, зберігши білий у light.

### F4. Вибрані продукти комори

Темний макет містить чорну галочку на бірюзовому колі. Код задає білу іконку з alwaysOriginal.

Код: PantryItemRowView.swift:75–90.

Використати динамічний onAccent для foreground, tint і зображення; наявний trait callback має перемальовувати іконку.

### F5. Сповіщення

Розділювач завжди чорний із прозорістю 12%; на темній картці майже не відділяє повідомлення.

Код: NotificationRowView.swift:66.

Застосувати AppColor.hairline з темним варіантом. Окремо звірити колір круглих іконок: у dark-макеті вони світлі.

### F6. Списки у sheets налаштувань

Макети цілей, теми й Apple Health показують чорні вкладені списки на сірому sheet. Спільний applyListCard задає напівпрозорий fillQuaternary.

Код: SettingsSheetDecorationsView.swift:90–99.

Для цих вкладених списків окремий dynamic колір із чорним dark; перевірити світлі відповідники після отримання доступу.

## Перелік 59 макетів

1. [Recipes/ All](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26763) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
2. [Recipes/ Create](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26819) — У самому dark-макеті кнопки варіантів БІЛІ. Не замінювати їх на чорні автоматично.
3. [Recipes/ Search](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26849) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
4. [Recipes/ Filters Results](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26879) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
5. [Recipes/ Filters Results](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26900) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
6. [Recipes/ Search/ Filters](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26915) — F3: у коді білий текст вибраних chips, у dark-макеті чорний.
7. [Recipes/ Filters/ Add Excluded ingredients/ Full Scroll](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-26979) — F3: у коді білий текст вибраних chips, у dark-макеті чорний.
8. [Recipes/ Healthy Breakfast Section](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27050) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
9. [Recipes/ Create/New Recipe/ My Pantry Ingredients](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27066) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
10. [Recipes/ Create Meal Plan](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27127) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
11. [Recipes/ Create/New Recipe/ My Pantry Ingredients Empty](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27177) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
12. [Recipes/ Create/New Recipe/Custom Ingredients Empty/Search Typing](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27230) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
13. [Recipes/ Create/New Recipe/Custom Ingredients](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27290) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
14. [Recipes/ Create/New Recipe/Custom Ingredients Empty Default](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27359) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
15. [My Products/ List](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27419) — F1/F4: перевірити сірі картки комори; вибрані галочки мають бути чорними.
16. [My Products/ Fridge Photo Result](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27461) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
17. [My Products/ Item Edit Sheet](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27502) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
18. [My Products/ Add Sheet](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27515) — У самому dark-макеті кнопки варіантів БІЛІ. Не замінювати їх на чорні автоматично.
19. [My Pantry/ List/Select](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27564) — F1/F4: перевірити сірі картки комори; вибрані галочки мають бути чорними.
20. [My Pantry/ List/Selected](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27607) — F1/F4: перевірити сірі картки комори; вибрані галочки мають бути чорними.
21. [My Pantry/ List/Delete Alert](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27650) — F1/F4: перевірити сірі картки комори; вибрані галочки мають бути чорними.
22. [My Pantry/ List](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27696) — F1/F4: перевірити сірі картки комори; вибрані галочки мають бути чорними.
23. [Recipes/ Saved/ Empty](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27704) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
24. [Recipes/ Meal Plans/ Empty](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27714) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
25. [Recipes/ Meal Plans](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27724) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
26. [Recipes/ Saved](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27740) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
27. [AI Photo - Camera ·Identifying/ Fridge photo](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27756) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
28. [Recipe/ Details/Nutrition](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27773) — F1: основні картки в коді чорні замість темно-сірих із макета.
29. [Created Recipe/ Details/Nutrition](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27832) — F1: основні картки в коді чорні замість темно-сірих із макета.
30. [Meal Plan/ Preview](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27891) — F1: основні картки в коді чорні замість темно-сірих із макета.
31. [Meal Plan/ Preview](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-27956) — F1: основні картки в коді чорні замість темно-сірих із макета.
32. [Meal Plan/ Preview/Alert Swapped](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28033) — F1: основні картки в коді чорні замість темно-сірих із макета.
33. [Recipe/ Meal Plan/ Add To Diary Sheet/ Added Alert](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28100) — F1: основні картки в коді чорні замість темно-сірих із макета.
34. [Recipe/ Details/Ingredients](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28167) — F1: основні картки в коді чорні замість темно-сірих із макета.
35. [Recipe/ Details/Instructions](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28226) — F1: основні картки в коді чорні замість темно-сірих із макета.
36. [Recipe/ Details/Saved Alert](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28285) — F1: основні картки в коді чорні замість темно-сірих із макета.
37. [Recipe/ Details/ Add To Diary Sheet](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28346) — У dark-макеті є світлий нижній відблиск. Потрібна звірка компонента, перш ніж вважати його дефектом додатка.
38. [Recipe/ Details/ Add To Diary Sheet/Added Alert](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28378) — У dark-макеті є світлий нижній відблиск. Потрібна звірка компонента, перш ніж вважати його дефектом додатка.
39. [Account Settings/ Free trial](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28412) — F2: у коді перевернуте співвідношення фону та кольору секцій. Макет показує значення Light при темному оформленні — не копіювати цей демонстраційний стан буквально.
40. [Account Settings/ With subscription](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28444) — F2: у коді перевернуте співвідношення фону та кольору секцій. Макет показує значення Light при темному оформленні — не копіювати цей демонстраційний стан буквально.
41. [Account Settings/ Nutrition Goals](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28475) — F6: вкладені списки мають бути чорними на сірому sheet.
42. [Account Settings/ Weight Goal](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28489) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
43. [Account Settings/ Theme](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28499) — F6: вкладені списки мають бути чорними на сірому sheet. Макет показує значення Light при темному оформленні — не копіювати цей демонстраційний стан буквально.
44. [Account Settings/ Notifications](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28513) — F5: чорний статичний розділювач; окремо перевірити іконки повідомлень.
45. [Account Settings/ Apple Health/Conected](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28542) — F6: вкладені списки мають бути чорними на сірому sheet.
46. [Account Settings/ Apple Health/disconected](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28560) — F6: вкладені списки мають бути чорними на сірому sheet.
47. [Account Settings/ Share App](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28578) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
48. [Account Settings/ Help & Support](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28582) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
49. [Recipe/ Meal Plan/ Add To Diary Sheet](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28600) — У dark-макеті є світлий нижній відблиск. Потрібна звірка компонента, перш ніж вважати його дефектом додатка.
50. [Loading](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28623) — Бірюзовий екран, білий трек і чорний прогрес відповідають dark-макету; це не підстава затемнювати весь екран.
51. [Loading](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28630) — Бірюзовий екран, білий трек і чорний прогрес відповідають dark-макету; це не підстава затемнювати весь екран.
52. [Meal Plan/ Edit with Bity](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28637) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
53. [Progress](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28663) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
54. [Progress Full scroll](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28698) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
55. [Progress/Selected Chart/Full scroll](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28735) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
56. [Progress Full scroll/ Freemium user](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28772) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
57. [Progress Full scroll/Empty Data](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28809) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
58. [Progress/Add (Log)](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28846) — У самому dark-макеті кнопки варіантів БІЛІ. Не замінювати їх на чорні автоматично.
59. [Progress/Progress Photos](https://www.figma.com/design/M37Q2Q2mOe0UwzTWeA2Ofl/Untitled?node-id=262-28887) — Макет переглянуто. Відповідний стан у додатку не пройдено; відповідність не підтверджена.
