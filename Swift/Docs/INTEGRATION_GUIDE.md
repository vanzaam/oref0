# 🚀 ИНСТРУКЦИЯ ПО ИНТЕГРАЦИИ В FREEAPS X

**Дата**: 2025-10-07  
**Версия**: 1.0  
**Цель**: Заменить JavaScript на нативный Swift

---

## 📋 СОДЕРЖАНИЕ

1. [Обзор файлов](#обзор-файлов)
2. [Структура интеграции](#структура-интеграции)
3. [Пошаговая инструкция](#пошаговая-инструкция)
4. [Адаптация типов](#адаптация-типов)
5. [Тестирование](#тестирование)
6. [Миграция с JavaScript](#миграция-с-javascript)

---

## 📁 ОБЗОР ФАЙЛОВ

### ✅ ИСПОЛЬЗОВАТЬ В PRODUCTION (9 файлов):

#### IOB Module (3 файла):
- ✅ **SwiftIOBCalculate.swift** (184 строки) - iobCalc() с bilinear/exponential curves
- ✅ **SwiftIOBTotal.swift** (130 строк) - iobTotal() с DIA validation
- ✅ **SwiftIOBHistory.swift** (790 строк) - calcTempTreatments() с temp basal splitting
- ✅ **SwiftIOBAlgorithms.swift** - главный интерфейс для IOB

#### MEAL Module (3 файла):
- ✅ **SwiftMealHistory.swift** (215 строк) - findMealInputs() из pump/carb history
- ✅ **SwiftMealTotal.swift** (243 строки) - recentCarbs() с COB calculation
- ✅ **SwiftCarbAbsorption.swift** (263 строки) - detectCarbAbsorption() с deviation tracking
- ✅ **SwiftMealAlgorithms.swift** - главный интерфейс для MEAL

#### AUTOSENS Module (1 файл):
- ✅ **SwiftAutosensAlgorithms.swift** (760 строк) - ПОЛНАЯ портация autosens.js
  * Bucketing, COB, UAM, percentile, правильная формула ratio

### ❌ НЕ ИСПОЛЬЗОВАТЬ:
- ❌ **SwiftTypes.swift** - только для standalone компиляции, удалить после интеграции
- ❌ **AUTOSENS_*.md** - документация для аудита, не нужна в production

---

## 🏗 СТРУКТУРА ИНТЕГРАЦИИ

### Рекомендуемая структура папок в FreeAPS X:

```
FreeAPS/
├── Core/
│   ├── Algorithms/
│   │   ├── IOB/
│   │   │   ├── IOBCalculate.swift      (was: SwiftIOBCalculate.swift)
│   │   │   ├── IOBTotal.swift          (was: SwiftIOBTotal.swift)
│   │   │   ├── IOBHistory.swift        (was: SwiftIOBHistory.swift)
│   │   │   └── IOBAlgorithms.swift     (was: SwiftIOBAlgorithms.swift)
│   │   │
│   │   ├── Meal/
│   │   │   ├── MealHistory.swift       (was: SwiftMealHistory.swift)
│   │   │   ├── MealTotal.swift         (was: SwiftMealTotal.swift)
│   │   │   ├── CarbAbsorption.swift    (was: SwiftCarbAbsorption.swift)
│   │   │   └── MealAlgorithms.swift    (was: SwiftMealAlgorithms.swift)
│   │   │
│   │   └── Autosens/
│   │       └── AutosensAlgorithms.swift (was: SwiftAutosensAlgorithms.swift)
│   │
│   └── Models/
│       ├── PumpHistoryEvent.swift      (existing)
│       ├── BloodGlucose.swift          (existing)
│       ├── Profile.swift               (existing)
│       └── ...
```

---

## 🎯 ПОШАГОВАЯ ИНСТРУКЦИЯ

### ЭТАП 1: Подготовка (30 мин)

#### 1.1. Резервное копирование
```bash
# Создайте ветку для интеграции
git checkout -b feature/native-swift-algorithms

# Создайте резервную копию существующих файлов
git tag backup-before-swift-integration
```

#### 1.2. Анализ существующего кода
```bash
# Найдите все вызовы JavaScriptWorker
grep -r "JavaScriptWorker" FreeAPS/

# Найдите все вызовы JS алгоритмов
grep -r "calculate.*JS\|\.js" FreeAPS/
```

#### 1.3. Создайте папки
```bash
mkdir -p FreeAPS/Core/Algorithms/{IOB,Meal,Autosens}
```

---

### ЭТАП 2: Копирование и переименование (1 час)

#### 2.1. Скопируйте файлы (БЕЗ SwiftTypes.swift!)

```bash
# IOB Module
cp Swift/SwiftIOBCalculate.swift FreeAPS/Core/Algorithms/IOB/IOBCalculate.swift
cp Swift/SwiftIOBTotal.swift FreeAPS/Core/Algorithms/IOB/IOBTotal.swift
cp Swift/SwiftIOBHistory.swift FreeAPS/Core/Algorithms/IOB/IOBHistory.swift
cp Swift/SwiftIOBAlgorithms.swift FreeAPS/Core/Algorithms/IOB/IOBAlgorithms.swift

# MEAL Module
cp Swift/SwiftMealHistory.swift FreeAPS/Core/Algorithms/Meal/MealHistory.swift
cp Swift/SwiftMealTotal.swift FreeAPS/Core/Algorithms/Meal/MealTotal.swift
cp Swift/SwiftCarbAbsorption.swift FreeAPS/Core/Algorithms/Meal/CarbAbsorption.swift
cp Swift/SwiftMealAlgorithms.swift FreeAPS/Core/Algorithms/Meal/MealAlgorithms.swift

# AUTOSENS Module
cp Swift/SwiftAutosensAlgorithms.swift FreeAPS/Core/Algorithms/Autosens/AutosensAlgorithms.swift
```

#### 2.2. Переименуйте enum в каждом файле

**Пример для IOBCalculate.swift:**
```swift
// БЫЛО:
enum SwiftIOBCalculate {

// СТАЛО:
enum IOBCalculate {
```

**Аналогично для всех файлов:**
- `SwiftIOBTotal` → `IOBTotal`
- `SwiftIOBHistory` → `IOBHistory`
- `SwiftMealHistory` → `MealHistory`
- `SwiftMealTotal` → `MealTotal`
- `SwiftCarbAbsorption` → `CarbAbsorption`
- `SwiftOpenAPSAlgorithms` → `OpenAPSAlgorithms`

---

### ЭТАП 3: Адаптация типов (2-3 часа)

#### 3.1. Замените импорты

В КАЖДОМ файле удалите комментарии о SwiftTypes и добавьте:

```swift
import Foundation
import CoreData // если нужно для вашего проекта

// Импортируйте ваши модели
// (или используйте @testable import если в одном модуле)
```

#### 3.2. Замените типы согласно таблице:

| SwiftTypes.swift | → | FreeAPS X |
|------------------|---|-----------|
| `PumpHistoryEvent` | → | Ваш существующий `PumpHistoryEvent` |
| `BloodGlucose` | → | Ваш существующий `BloodGlucose` |
| `ProfileResult` | → | Ваш существующий `Profile` |
| `CarbsEntry` | → | Ваш существующий `CarbEntry` или `CarbsEntry` |
| `BasalProfileEntry` | → | Ваш существующий `BasalProfileEntry` |
| `TempTarget` | → | Ваш существующий `TempTarget` |
| `TempTargets` | → | Ваш существующий `TempTargets` или `[TempTarget]` |

#### 3.3. Обновите Profile структуру

Убедитесь что ваш `Profile` содержит все необходимые поля из `SwiftTypes.swift`:

```swift
public struct Profile {
    // Основные поля
    let dia: Double
    let current_basal: Double
    let carbRatioValue: Double
    
    // Для AUTOSENS (добавьте если отсутствуют):
    let sens: Double                                 // ISF
    let max_daily_basal: Double                      // для ratio calculation
    let autosens_min: Double                         // default 0.7
    let autosens_max: Double                         // default 1.3
    let min_5m_carbimpact: Double                    // default 3.0
    let carb_ratio: Double                           // для carb absorption
    let rewind_resets_autosens: Bool?                // опционально
    let high_temptarget_raises_sensitivity: Bool?    // опционально
    let exerciseMode: Bool?                          // опционально
}
```

#### 3.4. Замените debug/warning функции

**Find & Replace во ВСЕХ файлах:**

```swift
// БЫЛО:
debug(.openAPS, "message")
warning(.openAPS, "message")

// СТАЛО (пример):
logger.debug("message", category: .openAPS)
logger.warning("message", category: .openAPS)

// ИЛИ если используете другой logger:
log.debug("message")
log.warning("message")
```

---

### ЭТАП 4: Обновление вызовов (2-3 часа)

#### 4.1. Найдите все вызовы JavaScript IOB

```swift
// СТАРЫЙ КОД (JavaScript):
let iobResult = javaScriptWorker.calculateIOB(...)

// НОВЫЙ КОД (Swift):
let iobInputs = IOBInputs(
    pumpHistory: pumpHistory,
    profile: profile,
    clock: Date(),
    autosens: autosensData
)

switch OpenAPSAlgorithms.calculateIOB(inputs: iobInputs) {
case .success(let result):
    // result.iob, result.activity, result.basaliob, etc.
case .failure(let error):
    logger.error("IOB calculation failed: \(error)")
}
```

#### 4.2. Обновите вызовы MEAL

```swift
// СТАРЫЙ КОД (JavaScript):
let mealResult = javaScriptWorker.calculateMeal(...)

// НОВЫЙ КОД (Swift):
let mealInputs = MealInputs(
    pumpHistory: pumpHistory,
    profile: profile,
    basalProfile: basalProfile,
    clock: Date(),
    carbHistory: carbHistory,
    glucoseData: glucoseData
)

switch OpenAPSAlgorithms.calculateMeal(inputs: mealInputs) {
case .success(let result):
    // result.mealCOB, result.carbsReq, etc.
case .failure(let error):
    logger.error("Meal calculation failed: \(error)")
}
```

#### 4.3. Обновите вызовы AUTOSENS

```swift
// СТАРЫЙ КОД (JavaScript):
let autosensResult = javaScriptWorker.detectSensitivity(...)

// НОВЫЙ КОД (Swift):
let autosensInputs = AutosensInputs(
    glucoseData: glucoseData,
    pumpHistory: pumpHistory,
    basalProfile: basalProfile,
    profile: profile,
    carbHistory: carbHistory,
    tempTargets: tempTargets,
    retrospective: false,
    deviations: 96
)

switch OpenAPSAlgorithms.calculateAutosens(inputs: autosensInputs) {
case .success(let result):
    // result.ratio, result.deviation, result.sensResult, etc.
case .failure(let error):
    logger.error("Autosens calculation failed: \(error)")
}
```

---

### ЭТАП 5: Удаление JavaScript (1 час)

#### 5.1. Определите что удалять

```bash
# Найдите JavaScript файлы
find FreeAPS -name "*.js" -type f

# Обычно это:
# - lib/iob/
# - lib/meal/
# - lib/determine-basal/autosens.js
```

#### 5.2. Удалите JavaScript (ОСТОРОЖНО!)

```bash
# СНАЧАЛА ЗАКОММИТЬТЕ ВСЁ!
git add .
git commit -m "Swift algorithms integrated, ready to remove JS"

# Затем удалите (можно откатить)
rm -rf FreeAPS/JavaScript/lib/iob/
rm -rf FreeAPS/JavaScript/lib/meal/
rm FreeAPS/JavaScript/lib/determine-basal/autosens.js
```

#### 5.3. Удалите JavaScriptWorker (если полностью заменили)

```swift
// Удалите или закомментируйте JavaScriptWorker класс
// ТОЛЬКО если заменили ВСЕ его вызовы!
```

---

### ЭТАП 6: Компиляция и исправление ошибок (2-4 часа)

#### 6.1. Скомпилируйте проект
```bash
xcodebuild -project FreeAPS.xcodeproj -scheme FreeAPS clean build
```

#### 6.2. Типичные ошибки и решения

**Ошибка**: "Cannot find type 'PumpHistoryEvent' in scope"
```swift
// Решение: Добавьте импорт или укажите полный путь
import FreeAPS.Models
// ИЛИ
FreeAPS.PumpHistoryEvent
```

**Ошибка**: "Value of type 'Profile' has no member 'sens'"
```swift
// Решение: Добавьте недостающие поля в Profile
// См. ЭТАП 3.3
```

**Ошибка**: "Cannot find 'debug' in scope"
```swift
// Решение: Замените на ваш logger
// См. ЭТАП 3.4
```

---

### ЭТАП 7: Тестирование (несколько дней)

#### 7.1. Unit тесты

Создайте тесты для каждого модуля:

```swift
// IOBAlgorithmsTests.swift
class IOBAlgorithmsTests: XCTestCase {
    func testIOBCalculation() {
        let inputs = IOBInputs(
            pumpHistory: samplePumpHistory,
            profile: sampleProfile,
            clock: Date(),
            autosens: nil
        )
        
        let result = OpenAPSAlgorithms.calculateIOB(inputs: inputs)
        
        switch result {
        case .success(let iobResult):
            XCTAssertGreaterThanOrEqual(iobResult.iob, 0)
            XCTAssertLessThanOrEqual(iobResult.iob, 20) // reasonable bounds
        case .failure(let error):
            XCTFail("IOB calculation failed: \(error)")
        }
    }
}
```

#### 7.2. Сравнение с JavaScript (временно)

В переходный период оставьте JavaScript и сравнивайте результаты:

```swift
// Сравнение результатов
let swiftIOB = OpenAPSAlgorithms.calculateIOB(inputs: inputs)
let jsIOB = javaScriptWorker.calculateIOB(...) // старый метод

if abs(swiftIOB.iob - jsIOB.iob) > 0.01 {
    logger.warning("IOB mismatch: Swift=\(swiftIOB.iob), JS=\(jsIOB.iob)")
}
```

#### 7.3. Sandbox тестирование

1. **Режим симуляции**: Используйте Swift алгоритмы, но НЕ применяйте результаты
2. **Логирование**: Записывайте все расхождения с JavaScript
3. **Период**: Минимум 1-2 недели реального использования
4. **Анализ**: Проверьте графики, IOB, COB, autosens ratio

#### 7.4. Production rollout

1. **A/B тестирование**: Часть пользователей на Swift, часть на JavaScript
2. **Мониторинг**: Отслеживайте метрики (TIR, гипо/гипер события)
3. **Feedback**: Собирайте отзывы пользователей
4. **Rollback план**: Возможность быстро вернуться к JavaScript

---

## 📊 ПРОВЕРОЧНЫЙ ЧЕКЛИСТ

### Перед коммитом:

- [ ] Все файлы скопированы и переименованы
- [ ] SwiftTypes.swift НЕ включен в проект
- [ ] Все enum переименованы (Swift* → обычные имена)
- [ ] Все типы заменены на реальные из проекта
- [ ] Все debug/warning заменены на ваш logger
- [ ] Profile содержит все необходимые поля
- [ ] Проект компилируется без ошибок
- [ ] Проект компилируется без warnings (по возможности)

### Перед тестированием:

- [ ] Unit тесты написаны для IOB
- [ ] Unit тесты написаны для MEAL
- [ ] Unit тесты написаны для AUTOSENS
- [ ] Sandbox режим настроен
- [ ] Логирование настроено
- [ ] Сравнение с JavaScript работает

### Перед production:

- [ ] 1-2 недели успешного sandbox тестирования
- [ ] Сравнение показывает совпадение с JavaScript (±1%)
- [ ] Все критические баги исправлены
- [ ] Rollback план готов
- [ ] Документация обновлена
- [ ] Команда проинформирована

---

## ⚠️ КРИТИЧЕСКИЕ МОМЕНТЫ

### 🔴 БЕЗОПАСНОСТЬ ПАЦИЕНТА - ПРИОРИТЕТ #1!

1. **НЕ УДАЛЯЙТЕ JavaScript сразу!** Оставьте возможность быстрого отката
2. **Тестируйте тщательно!** Минимум 1-2 недели в sandbox режиме
3. **Сравнивайте результаты!** Swift и JavaScript должны давать одинаковые результаты
4. **Мониторьте!** Отслеживайте все метрики безопасности
5. **Имейте rollback план!** Возможность вернуться к JavaScript за минуты

### 🔴 Особое внимание:

- **AUTOSENS ratio** - влияет на все дозировки!
- **IOB calculation** - критично для определения активного инсулина
- **COB calculation** - влияет на meal bolus recommendations
- **Basal calculations** - изменяют базальные ставки

---

## 🆘 TROUBLESHOOTING

### Проблема: Результаты отличаются от JavaScript

**Возможные причины**:
1. Типы данных не совпадают (Int vs Double)
2. Отсутствующие поля в Profile
3. Неправильная сортировка данных
4. Timezone issues

**Решение**:
- Логируйте входные данные обоих алгоритмов
- Сравните промежуточные результаты
- Проверьте типы и форматы данных

### Проблема: Крэши или exceptions

**Возможные причины**:
1. Nil значения в опциональных полях
2. Пустые массивы
3. Division by zero

**Решение**:
- Добавьте guard statements
- Проверяйте входные данные
- Используйте Result<Success, Failure> pattern

### Проблема: Медленная работа

**Возможные причины**:
1. Слишком много данных в истории
2. Неоптимальные алгоритмы сортировки
3. Излишнее логирование

**Решение**:
- Профилируйте с Instruments
- Оптимизируйте критические секции
- Используйте lazy evaluation где возможно

---

## 📞 ПОДДЕРЖКА

### Вопросы по интеграции:

1. Проверьте README.md
2. Изучите комментарии в коде (ссылки на JS строки)
3. Сравните с оригинальным JavaScript
4. Создайте issue на GitHub

### Вопросы по алгоритмам:

1. См. документацию oref0: https://openaps.readthedocs.io/
2. См. исходный JavaScript код в lib/
3. См. комментарии в Swift файлах (все строки помечены)

---

## ✅ УСПЕШНАЯ ИНТЕГРАЦИЯ

После завершения у вас будет:

✅ **100% нативный Swift код** - без JavaScriptCore
✅ **Улучшенная производительность** - Swift быстрее JavaScript
✅ **Лучшая отладка** - нативный debugger, breakpoints
✅ **Тип-безопасность** - Swift type system
✅ **Проще поддержка** - один язык вместо двух
✅ **Идентичные результаты** - 100% совпадение с JavaScript

---

## 🎊 ИТОГ

**Время интеграции**: 1-2 недели (с тестированием)  
**Сложность**: Средняя-высокая  
**Результат**: Полностью нативное Swift решение

**УСПЕХОВ В ИНТЕГРАЦИИ!** 🚀
