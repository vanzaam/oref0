# 🔴 MEAL MODULE - ПЛАН ПОЛНОЙ ПЕРЕДЕЛКИ

**Дата**: 2025-10-07 12:52  
**Приоритет**: 🔴 КРИТИЧНО  
**Статус**: В РАБОТЕ

---

## 📋 ПЛАН ПЕРЕДЕЛКИ

### ЭТАП 1: Портировать lib/meal/history.js (142 строки)
**Файл**: SwiftMealHistory.swift

**Функции**:
1. ✅ `arrayHasElementWithSameTimestampAndProperty()` (lines 3-17)
2. ✅ `findMealInputs()` (lines 19-139)
   - Обработка carbHistory (lines 27-40)
   - Обработка pumpHistory:
     * Bolus (lines 44-54)
     * BolusWizard delay processing (lines 55-58)
     * Nightscout Care Portal (lines 60-73)
     * xdrip entries (lines 74-84)
     * General carbs (lines 85-95)
     * JournalEntryMealMarker (lines 96-106)
   - Delayed BolusWizard processing (lines 109-135)

**Структуры данных**:
```swift
struct MealInput {
    var timestamp: Date
    var carbs: Double?
    var nsCarbs: Double?
    var bwCarbs: Double?
    var journalCarbs: Double?
    var bolus: Double?
}
```

---

### ЭТАП 2: Портировать lib/meal/total.js (145 строк)
**Файл**: SwiftMealTotal.swift

**Функции**:
1. ✅ `recentCarbs()` (lines 6-141)
   - Сортировка treatments (lines 35-40)
   - 6-hour carb window (lines 49)
   - carbsToRemove логика (lines 75-98)
   - zombie-carb safety (lines 114-124)
   - Правильные возвращаемые поля (lines 126-140)

**Возвращаемые поля** (ТОЧНО как в JS!):
```swift
struct RecentCarbsResult {
    let carbs: Double
    let nsCarbs: Double
    let bwCarbs: Double
    let journalCarbs: Double
    let mealCOB: Double
    let currentDeviation: Double
    let maxDeviation: Double
    let minDeviation: Double
    let slopeFromMaxDeviation: Double
    let slopeFromMinDeviation: Double
    let allDeviations: [Double]
    let lastCarbTime: Double
    let bwFound: Bool
}
```

---

### ЭТАП 3: Портировать detectCarbAbsorption из cob.js
**Файл**: SwiftCarbAbsorption.swift

**Требуется**:
- Найти lib/determine-basal/cob.js
- Портировать detectCarbAbsorption()
- Интегрировать с meal/total.js

---

### ЭТАП 4: Обновить SwiftMealAlgorithms.swift
**Действия**:
1. Использовать findMealInputs() из SwiftMealHistory
2. Использовать recentCarbs() из SwiftMealTotal
3. Использовать detectCarbAbsorption() из SwiftCarbAbsorption
4. Исправить структуру MealResult

---

## 📊 ПРОГРЕСС

- [ ] ЭТАП 1: SwiftMealHistory.swift (142 строки)
- [ ] ЭТАП 2: SwiftMealTotal.swift (145 строк)
- [ ] ЭТАП 3: SwiftCarbAbsorption.swift
- [ ] ЭТАП 4: Обновить SwiftMealAlgorithms.swift

---

## 🎯 РЕЗУЛЬТАТ

После завершения:
- ✅ 100% соответствие lib/meal/
- ✅ Все типы treatments обработаны
- ✅ zombie-carb safety реализована
- ✅ Правильная структура данных
- ✅ Интеграция с cob.js

**Meal модуль будет ГОТОВ к production!** 🚀
