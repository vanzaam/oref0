# 🔴 IOB MODULE REFACTORING - FULL PLAN

**Дата**: 2025-10-07 13:19  
**Приоритет**: 🔴 ВЫСОКИЙ  
**Масштаб**: ~1000 строк Swift кода

---

## 📋 ТЕКУЩАЯ ПРОБЛЕМА

SwiftIOBAlgorithms.swift (1 файл):
- ❌ Портирован с "минифицированного" JS
- ❌ Неправильная структура
- ✅ Работает (5 проблем исправлены)

---

## 🎯 ПЛАН РЕФАКТОРИНГА (4 ФАЙЛА)

### ФАЙЛ 1: SwiftIOBCalculate.swift
**Источник**: lib/iob/calculate.js (147 строк)

**Функции**:
```javascript
function iobCalc(treatment, time, curve, dia, peak, profile)
function iobCalcBilinear(treatment, minsAgo, dia)
function iobCalcExponential(treatment, minsAgo, dia, peak, profile)
```

**Детали**:
- Bilinear curve (lines 36-80)
  * activityPeak = 2 / (dia * 60)
  * slopeUp, slopeDown
  * IOB coefficients
  
- Exponential curve (lines 83-143)
  * Custom peak time validation
  * tau calculation
  * activityContrib formula (line 134)
  * iobContrib formula (line 135)

**Оценка**: ~200 строк Swift

---

### ФАЙЛ 2: SwiftIOBTotal.swift
**Источник**: lib/iob/total.js (106 строк)

**Функция**: iobTotal(opts, time)

**Логика** (ТОЧНО как в JS!):
- Line 23-27: force minimum DIA of 3h ✅ (уже есть в текущем)
- Line 60-63: force minimum 5h DIA for exponential ✅ (уже есть)
- Line 67-92: forEach treatments
  * Calculate IOB using iobCalc
  * Split basaliob vs bolusiob (insulin < 0.1)
  * Accumulate totals
- Line 94-102: Return rounded values ✅ (уже есть)

**Оценка**: ~150 строк Swift

---

### ФАЙЛ 3: SwiftIOBHistory.swift
**Источник**: lib/iob/history.js (~600 строк!)

**Функция**: find_insulin(inputs, zeroTempDuration)

**СЛОЖНАЯ ЛОГИКА**:
- Обработка pump history
- Фильтрация basal vs bolus
- Обработка temp basals
- Создание treatments array

**Оценка**: ~400 строк Swift

---

### ФАЙЛ 4: SwiftIOBAlgorithms.swift (ОБНОВИТЬ)
**Источник**: lib/iob/index.js (86 строк)

**Функция**: generate(inputs, currentIOBOnly, treatments)

**Логика**:
- find_insulin() → treatments
- find_insulin() → treatmentsWithZeroTemp
- Loop: predict IOB out to 4h (lines 68-78)
- Return iobArray

**Оценка**: ~150 строк Swift

---

## 📊 ИТОГО

| Файл | JS строк | Swift строк (оценка) |
|------|----------|---------------------|
| SwiftIOBCalculate.swift | 147 | ~200 |
| SwiftIOBTotal.swift | 106 | ~150 |
| SwiftIOBHistory.swift | ~600 | ~400 |
| SwiftIOBAlgorithms.swift | 86 | ~150 |
| **ИТОГО** | **~940** | **~900** |

---

## 🎯 СЛЕДУЮЩАЯ СЕССИЯ - ДЕЙСТВИЯ

### ЭТАП 1: SwiftIOBCalculate.swift
1. Портировать iobCalc()
2. Портировать iobCalcBilinear()
3. Портировать iobCalcExponential()

### ЭТАП 2: SwiftIOBTotal.swift
1. Портировать iobTotal()
2. Curve defaults
3. DIA validation
4. Treatments loop

### ЭТАП 3: SwiftIOBHistory.swift
1. Прочитать lib/iob/history.js полностью
2. Портировать find_insulin()
3. Обработка pump history

### ЭТАП 4: Обновить SwiftIOBAlgorithms.swift
1. Портировать generate()
2. Интеграция всех компонентов
3. Убрать "минифицированного"

---

## ⚠️ ВАЖНО

**СОХРАНИТЬ**:
- Все 5 исправлений что уже сделаны:
  * ✅ Минимальный DIA (3h)
  * ✅ DIA для exponential (5h)
  * ✅ Округление результатов
  * ✅ DIA-based фильтрация
  * ✅ Правильное имя файла

**УДАЛИТЬ**:
- ❌ Все упоминания "минифицированного"
- ❌ Упрощенный код

**ДОБАВИТЬ**:
- ✅ Полная логика из оригинальных JS файлов
- ✅ Правильная архитектура (4 файла)

---

## 📝 СТАТУС

**ТЕКУЩИЙ**: 1 файл Swift, работает но неправильная структура  
**ПОСЛЕ РЕФАКТОРИНГА**: 4 файла Swift, правильная архитектура

**IOB MODULE: ГОТОВ К ПОЛНОЙ ПЕРЕДЕЛКЕ!** 🚀
