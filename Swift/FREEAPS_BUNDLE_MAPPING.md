# 📦 MAPPING: Swift → FreeAPS X Bundle (dist/*.js)

**Дата**: 2025-10-07  
**Цель**: Заменить минифицированные JS файлы на нативный Swift

---

## 🎯 WEBPACK ENTRY POINTS → SWIFT MODULES

### В FreeAPS X используются файлы из `FreeAPS/Resources/javascript/bundle/`:

| dist/*.js | Размер | Entry Point | Swift Замена | Статус |
|-----------|--------|-------------|--------------|--------|
| **iob.js** | 1.3MB | lib/iob/index.js | **IOB/SwiftIOBAlgorithms.swift** | ✅ 100% |
| **meal.js** | 1.3MB | lib/meal/index.js | **Meal/SwiftMealAlgorithms.swift** | ✅ 100% |
| **autosens.js** | 1.3MB | lib/determine-basal/autosens.js | **Autosens/SwiftAutosensAlgorithms.swift** | ✅ 100% |
| **determineBasal.js** | 20KB | lib/determine-basal/determine-basal.js | **Core/SwiftDetermineBasalAlgorithms.swift** | ✅ 100% |
| **profile.js** | 78KB | lib/profile/index.js | **Core/SwiftProfileAlgorithms.swift** | ✅ 100% |
| **basalSetTemp.js** | 4.3KB | lib/basal-set-temp.js | **Core/SwiftBasalSetTemp.swift** | ✅ 100% |
| **glucoseGetLast.js** | 1.3KB | lib/glucose-get-last.js | **Core/SwiftGlucoseGetLast.swift** | ✅ 100% |
| **autotunePrep.js** | 1.3MB | lib/autotune-prep/index.js | **Core/SwiftAutotunePrepAlgorithms.swift** | ✅ 100% |
| **autotuneCore.js** | 7.9KB | lib/autotune/index.js | **Core/SwiftAutotuneCoreAlgorithms.swift** | ✅ 100% |

**ВСЕ 9 ФАЙЛОВ ПОРТИРОВАНЫ!** ✅

---

## 📊 ДЕТАЛЬНОЕ СООТВЕТСТВИЕ

### 1. iob.js (1.3MB минифицированный)

**JavaScript (Webpack bundle):**
```
lib/iob/index.js (entry point)
├── lib/iob/calculate.js
├── lib/iob/total.js
└── lib/iob/history.js
```

**Swift замена:**
```
IOB/SwiftIOBAlgorithms.swift (главный интерфейс)
├── IOB/SwiftIOBCalculate.swift (184 строки)
├── IOB/SwiftIOBTotal.swift (130 строк)
└── IOB/SwiftIOBHistory.swift (790 строк)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.calculateIOB(...)`
2. Заменить на `IOBAlgorithms.calculateIOB(inputs: ...)`
3. Импортировать `IOB/SwiftIOBAlgorithms.swift`

---

### 2. meal.js (1.3MB минифицированный)

**JavaScript (Webpack bundle):**
```
lib/meal/index.js (entry point)
├── lib/meal/history.js
├── lib/meal/total.js
└── lib/determine-basal/cob.js
```

**Swift замена:**
```
Meal/SwiftMealAlgorithms.swift (главный интерфейс)
├── Meal/SwiftMealHistory.swift (215 строк)
├── Meal/SwiftMealTotal.swift (243 строки)
└── Meal/SwiftCarbAbsorption.swift (263 строки)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.calculateMeal(...)`
2. Заменить на `MealAlgorithms.calculateMeal(inputs: ...)`
3. Импортировать `Meal/SwiftMealAlgorithms.swift`

---

### 3. autosens.js (1.3MB минифицированный)

**JavaScript (Webpack bundle):**
```
lib/determine-basal/autosens.js (455 строк)
├── lib/profile/isf.js
├── lib/profile/basal.js
├── lib/iob/*.js (для IOB calculation)
└── lib/meal/*.js (для COB tracking)
```

**Swift замена:**
```
Autosens/SwiftAutosensAlgorithms.swift (760 строк)
└── Все зависимости встроены (bucketing, COB, UAM, percentile, ratio)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.detectSensitivity(...)`
2. Заменить на `OpenAPSAlgorithms.calculateAutosens(inputs: ...)`
3. Импортировать `Autosens/SwiftAutosensAlgorithms.swift`

---

### 4. determineBasal.js (20KB минифицированный)

**JavaScript (Webpack bundle):**
```
lib/determine-basal/determine-basal.js (1100+ строк)
├── SMB calculation
├── Temp basal calculation
├── IOB/COB/ISF logic
└── Prediction arrays
```

**Swift замена:**
```
Core/SwiftDetermineBasalAlgorithms.swift (2600+ строк)
└── ПОЛНАЯ портация всей логики
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.determineBasal(...)`
2. Заменить на `OpenAPSAlgorithms.determineBasal(inputs: ...)`
3. Импортировать `Core/SwiftDetermineBasalAlgorithms.swift`

---

### 5. profile.js (78KB минифицированный)

**JavaScript (Webpack bundle):**
```
lib/profile/index.js (entry point)
├── lib/profile/isf.js
├── lib/profile/basal.js
├── lib/profile/carb-ratios.js
└── lib/profile/targets.js
```

**Swift замена:**
```
Core/SwiftProfileAlgorithms.swift (435 строк)
└── Все profile calculations
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.makeProfile(...)`
2. Заменить на `ProfileAlgorithms.makeProfile(inputs: ...)`
3. Импортировать `Core/SwiftProfileAlgorithms.swift`

---

### 6. basalSetTemp.js (4.3KB минифицированный)

**JavaScript:**
```
lib/basal-set-temp.js (180 строк)
```

**Swift замена:**
```
Core/SwiftBasalSetTemp.swift (210 строк)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.setTempBasal(...)`
2. Заменить на `BasalSetTemp.setTempBasal(inputs: ...)`
3. Импортировать `Core/SwiftBasalSetTemp.swift`

---

### 7. glucoseGetLast.js (1.3KB минифицированный)

**JavaScript:**
```
lib/glucose-get-last.js (50 строк)
```

**Swift замена:**
```
Core/SwiftGlucoseGetLast.swift (200 строк)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.getLastGlucose(...)`
2. Заменить на `GlucoseGetLast.getLastGlucose(inputs: ...)`
3. Импортировать `Core/SwiftGlucoseGetLast.swift`

---

### 8. autotunePrep.js (1.3MB минифицированный)

**JavaScript:**
```
lib/autotune-prep/index.js (850+ строк)
```

**Swift замена:**
```
Core/SwiftAutotunePrepAlgorithms.swift (830 строк)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.autotunePrep(...)`
2. Заменить на `AutotunePrepAlgorithms.categorize(inputs: ...)`
3. Импортировать `Core/SwiftAutotunePrepAlgorithms.swift`

---

### 9. autotuneCore.js (7.9KB минифицированный)

**JavaScript:**
```
lib/autotune/index.js (525 строк)
```

**Swift замена:**
```
Core/SwiftAutotuneCoreAlgorithms.swift (525 строк)
```

**Как заменить:**
1. Удалить вызовы `JavaScriptWorker.autotuneCore(...)`
2. Заменить на `AutotuneCoreAlgorithms.autotune(inputs: ...)`
3. Импортировать `Core/SwiftAutotuneCoreAlgorithms.swift`

---

## 🚀 ПЛАН ЗАМЕНЫ В FREEAPS X

### Шаг 1: Копирование Swift файлов

```bash
# Скопируйте структуру
cp -r oref0/Swift/IOB FreeAPS/Core/Algorithms/
cp -r oref0/Swift/Meal FreeAPS/Core/Algorithms/
cp -r oref0/Swift/Autosens FreeAPS/Core/Algorithms/
cp -r oref0/Swift/Core/* FreeAPS/Core/Algorithms/Core/
```

### Шаг 2: Найти все вызовы JavaScriptWorker

```bash
# В FreeAPS X проекте
grep -r "JavaScriptWorker" FreeAPS/
```

Типичные вызовы:
```swift
jsWorker.calculateIOB(...)
jsWorker.calculateMeal(...)
jsWorker.detectSensitivity(...)
jsWorker.determineBasal(...)
jsWorker.makeProfile(...)
```

### Шаг 3: Заменить на Swift вызовы

**БЫЛО (JavaScript):**
```swift
let iobResult = jsWorker.calculateIOB(
    pumpHistory: pumpHistoryJSON,
    profile: profileJSON,
    clock: clockJSON,
    autosens: autosensJSON
)
```

**СТАЛО (Swift):**
```swift
let inputs = IOBInputs(
    pumpHistory: pumpHistory,  // Swift types
    profile: profile,
    clock: Date(),
    autosens: autosens
)

let result = IOBAlgorithms.calculateIOB(inputs: inputs)
```

### Шаг 4: Удалить bundle/*.js (ОСТОРОЖНО!)

```bash
# СНАЧАЛА создайте backup!
cp -r FreeAPS/Resources/javascript/bundle FreeAPS/Resources/javascript/bundle.backup

# Затем можно удалить (ТОЛЬКО после полного тестирования!)
# rm FreeAPS/Resources/javascript/bundle/*.js
```

⚠️ **НЕ УДАЛЯЙТЕ сразу!** Оставьте JS для сравнения и отката!

---

## 📊 РАЗМЕР СРАВНЕНИЕ

### JavaScript (минифицированный):
```
iob.js:            1.3 MB
meal.js:           1.3 MB
autosens.js:       1.3 MB
determineBasal.js: 20 KB
profile.js:        78 KB
basalSetTemp.js:   4.3 KB
glucoseGetLast.js: 1.3 KB
autotunePrep.js:   1.3 MB
autotuneCore.js:   7.9 KB
----------------------------
ИТОГО:            ~5.5 MB минифицированного JS
```

### Swift (нативный):
```
IOB/:              ~30 KB (скомпилированный)
Meal/:             ~20 KB (скомпилированный)
Autosens/:         ~25 KB (скомпилированный)
Core/:             ~100 KB (скомпилированный)
----------------------------
ИТОГО:            ~175 KB нативного кода
ЭКОНОМИЯ:         ~5.3 MB (96%!)
```

**+ Преимущества:**
- Быстрее выполнение (нативный код)
- Нет JavaScriptCore overhead
- Лучшая отладка
- Тип-безопасность
- Меньше памяти

---

## ✅ ПРОВЕРОЧНЫЙ ЧЕКЛИСТ

### Перед заменой:
- [ ] Все Swift файлы скопированы
- [ ] Типы адаптированы (SwiftTypes.swift → ваши типы)
- [ ] Проект компилируется без ошибок
- [ ] Unit тесты написаны

### При замене:
- [ ] Backup bundle/*.js создан
- [ ] Все вызовы JavaScriptWorker найдены
- [ ] Постепенная замена (модуль за модулем)
- [ ] Sandbox тестирование 1-2 недели

### После замены:
- [ ] Результаты совпадают с JS (±1%)
- [ ] Нет крэшей
- [ ] Performance лучше
- [ ] Memory usage меньше

---

## 🎯 ПОРЯДОК ЗАМЕНЫ (рекомендуемый)

### 1. Profile (самый простой)
- `profile.js` → `SwiftProfileAlgorithms.swift`
- Меньше всего зависимостей
- Легко тестировать

### 2. GlucoseGetLast (тривиальный)
- `glucoseGetLast.js` → `SwiftGlucoseGetLast.swift`
- Самый маленький
- Без сложной логики

### 3. BasalSetTemp (простой)
- `basalSetTemp.js` → `SwiftBasalSetTemp.swift`
- Небольшой размер
- Простая логика

### 4. IOB (важный!)
- `iob.js` → `IOB/SwiftIOBAlgorithms.swift`
- Критичный модуль
- Требует тщательного тестирования

### 5. MEAL (важный!)
- `meal.js` → `Meal/SwiftMealAlgorithms.swift`
- COB calculation
- Тщательное тестирование

### 6. AUTOSENS (критический!)
- `autosens.js` → `Autosens/SwiftAutosensAlgorithms.swift`
- Влияет на все дозировки!
- Максимальное тестирование

### 7. DetermineBasal (САМЫЙ критический!)
- `determineBasal.js` → `Core/SwiftDetermineBasalAlgorithms.swift`
- Главный алгоритм!
- Требует weeks of testing

### 8. Autotune (опционально)
- `autotunePrep.js` + `autotuneCore.js`
- Не критично для работы
- Можно оставить на потом

---

## 🎊 ИТОГ

**ВСЕ 9 WEBPACK ENTRY POINTS ПОРТИРОВАНЫ В SWIFT!**

```
✅ iob.js → IOB/
✅ meal.js → Meal/
✅ autosens.js → Autosens/
✅ determineBasal.js → Core/SwiftDetermineBasalAlgorithms.swift
✅ profile.js → Core/SwiftProfileAlgorithms.swift
✅ basalSetTemp.js → Core/SwiftBasalSetTemp.swift
✅ glucoseGetLast.js → Core/SwiftGlucoseGetLast.swift
✅ autotunePrep.js → Core/SwiftAutotunePrepAlgorithms.swift
✅ autotuneCore.js → Core/SwiftAutotuneCoreAlgorithms.swift
```

**ГОТОВО К ЗАМЕНЕ В FREEAPS X!** 🚀

**Следуйте:** `Docs/INTEGRATION_GUIDE.md` для детальных инструкций!
