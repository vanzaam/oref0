# 📋 ТОЧНАЯ КАРТА СООТВЕТСТВИЯ: JS WEBPACK МОДУЛИ → SWIFT ФАЙЛЫ

**Дата**: 2025-10-07 12:18  
**Статус**: ИСПРАВЛЕНО - правильные названия модулей

---

## ✅ ТОЧНОЕ СООТВЕТСТВИЕ 9 МОДУЛЕЙ

| # | Webpack Entry | JS Исходник | Swift Файл | Размер | Статус |
|---|---------------|-------------|------------|--------|--------|
| 1 | **iob.js** | lib/iob/index.js | ⚠️ SwiftOpenAPSAlgorithms.swift | 15KB | 🔴 НЕПРАВИЛЬНОЕ ИМЯ! |
| 2 | **meal.js** | lib/meal/index.js | ✅ SwiftMealAlgorithms.swift | 9KB | ✅ ПРАВИЛЬНО |
| 3 | **determineBasal.js** | lib/determine-basal/determine-basal.js | ✅ SwiftDetermineBasalAlgorithms.swift | 93KB | ✅ ГОТОВ |
| 4 | **glucoseGetLast.js** | lib/glucose-get-last.js | ❓ НЕ НАЙДЕН | - | 🔴 ОТСУТСТВУЕТ |
| 5 | **basalSetTemp.js** | lib/basal-set-temp.js | ⚠️ Внутри SwiftDetermineBasalAlgorithms.swift | - | 🟡 НЕ ОТДЕЛЬНЫЙ |
| 6 | **autosens.js** | lib/determine-basal/autosens.js | ✅ SwiftAutosensAlgorithms.swift | 15KB | ✅ ПРАВИЛЬНО |
| 7 | **profile.js** | lib/profile/index.js | ✅ SwiftProfileAlgorithms.swift | 15KB | ✅ ПРАВИЛЬНО |
| 8 | **autotunePrep.js** | lib/autotune-prep/index.js | ✅ SwiftAutotunePrepAlgorithms.swift | 29KB | ✅ ГОТОВ |
| 9 | **autotuneCore.js** | lib/autotune/index.js | ✅ SwiftAutotuneCoreAlgorithms.swift | 18KB | ✅ ГОТОВ |

---

## 🔴 ПРОБЛЕМЫ С ИМЕНОВАНИЕМ!

### 1. IOB МОДУЛЬ - НЕПРАВИЛЬНОЕ ИМЯ!

**Должно быть**: `SwiftIOBAlgorithms.swift` или `SwiftIOB.swift`  
**На самом деле**: `SwiftOpenAPSAlgorithms.swift` (смешано с другой логикой!)

**Проблема**: 
- lib/iob/index.js - это ОТДЕЛЬНЫЙ модуль для IOB расчетов
- В Swift он находится в SwiftOpenAPSAlgorithms.swift вместе с другими функциями
- Это НЕПРАВИЛЬНАЯ архитектура!

**Что нужно**:
```swift
// Должен быть отдельный файл:
SwiftIOBAlgorithms.swift
  - func calculateIOB(inputs: IOBInputs) -> IOBResult
  - func calculateBolusIOB(...)
  - func calculateBasalIOB(...)
  - func calculateBilinearIOB(...)
  - func calculateExponentialIOB(...)
```

---

### 2. basalSetTemp - НЕ ОТДЕЛЬНЫЙ МОДУЛЬ

**JS**: `lib/basal-set-temp.js` - отдельный модуль  
**Swift**: Функция `setTempBasal()` внутри SwiftDetermineBasalAlgorithms.swift

**Проблема**:
- В JS это отдельный webpack entry point
- В Swift это просто функция внутри determine-basal

**Решение**: Это ПРАВИЛЬНО! setTempBasal используется только в determine-basal, не нужен отдельный файл.

---

### 3. glucoseGetLast - ОТСУТСТВУЕТ

**JS**: `lib/glucose-get-last.js` - отдельный модуль  
**Swift**: ❌ НЕ НАЙДЕН!

**Что нужно**: Найти где в Swift происходит получение последней глюкозы

---

## 📊 ВСЕ SWIFT ФАЙЛЫ В ПРОЕКТЕ

```
1. HybridOpenAPS.swift (25KB)           - координатор/обертка
2. SwiftAutosensAlgorithms.swift (15KB)  - autosens ✅
3. SwiftAutotuneCoreAlgorithms.swift (18KB) - autotune-core ✅
4. SwiftAutotunePrepAlgorithms.swift (29KB) - autotune-prep ✅
5. SwiftAutotuneShared.swift (5KB)       - shared structures ✅
6. SwiftDetermineBasalAlgorithms.swift (93KB) - determine-basal ✅
7. SwiftMealAlgorithms.swift (9KB)       - meal ✅
8. SwiftOpenAPS.swift (12KB)             - ???
9. SwiftOpenAPSAlgorithms.swift (15KB)   - IOB + ??? ⚠️
10. SwiftOpenAPSCoordinator.swift (36KB) - координатор
11. SwiftProfileAlgorithms.swift (15KB)  - profile ✅
```

---

## �� КРИТИЧЕСКИЕ ВЫВОДЫ

### ❌ IOB модуль НЕПРАВИЛЬНО назван!

**Проблема**: 
- `SwiftOpenAPSAlgorithms.swift` содержит IOB логику
- Но это НЕ соответствует названию модуля `iob.js`!

**Должно быть**:
```
lib/iob/index.js → SwiftIOBAlgorithms.swift (отдельный файл!)
```

**Сейчас**:
```
lib/iob/index.js → SwiftOpenAPSAlgorithms.swift (смешан с другой логикой)
```

---

### ❓ SwiftOpenAPS.swift и SwiftOpenAPSCoordinator.swift - ЧТО ЭТО?

Эти файлы НЕ соответствуют webpack entry points!

**Возможно**: 
- SwiftOpenAPS.swift - обертка/API
- SwiftOpenAPSCoordinator.swift - координатор/orchestrator
- Они НЕ являются портациями JS модулей

**Нужно**: Проверить их содержимое

---

## 📋 ИСПРАВЛЕННАЯ ТАБЛИЦА СООТВЕТСТВИЯ

| JS Модуль | Правильное имя Swift | Текущее имя Swift | Соответствие |
|-----------|---------------------|-------------------|--------------|
| lib/iob/ | ✅ SwiftIOBAlgorithms.swift | ❌ SwiftOpenAPSAlgorithms.swift | 🔴 НЕПРАВИЛЬНО |
| lib/meal/ | ✅ SwiftMealAlgorithms.swift | ✅ SwiftMealAlgorithms.swift | ✅ ПРАВИЛЬНО |
| lib/determine-basal/ | ✅ SwiftDetermineBasalAlgorithms.swift | ✅ SwiftDetermineBasalAlgorithms.swift | ✅ ПРАВИЛЬНО |
| lib/glucose-get-last.js | ✅ Должен быть Swift файл | ❌ НЕ НАЙДЕН | 🔴 ОТСУТСТВУЕТ |
| lib/basal-set-temp.js | ✅ Часть determine-basal | ✅ Часть determine-basal | ✅ ПРАВИЛЬНО |
| lib/determine-basal/autosens.js | ✅ SwiftAutosensAlgorithms.swift | ✅ SwiftAutosensAlgorithms.swift | ✅ ПРАВИЛЬНО |
| lib/profile/ | ✅ SwiftProfileAlgorithms.swift | ✅ SwiftProfileAlgorithms.swift | ✅ ПРАВИЛЬНО |
| lib/autotune-prep/ | ✅ SwiftAutotunePrepAlgorithms.swift | ✅ SwiftAutotunePrepAlgorithms.swift | ✅ ПРАВИЛЬНО |
| lib/autotune/ | ✅ SwiftAutotuneCoreAlgorithms.swift | ✅ SwiftAutotuneCoreAlgorithms.swift | ✅ ПРАВИЛЬНО |

---

## 🎯 ДЕЙСТВИЯ

### Критично:
1. 🔴 **ПЕРЕИМЕНОВАТЬ**: SwiftOpenAPSAlgorithms.swift → SwiftIOBAlgorithms.swift
   - Или выделить IOB логику в отдельный файл

2. 🔴 **НАЙТИ**: Где находится glucoseGetLast функция?
   - Возможно в SwiftOpenAPS.swift?
   - Или в SwiftOpenAPSCoordinator.swift?

### Проверить:
3. ⚠️ Что содержит SwiftOpenAPS.swift?
4. ⚠️ Что содержит SwiftOpenAPSCoordinator.swift?

---

## ✅ ВЕРДИКТ

**Правильные имена модулей**: 6/9 (67%)  
**Неправильные имена**: 1/9 (IOB)  
**Отсутствуют**: 2/9 (glucoseGetLast, возможно еще что-то)

**ТРЕБУЕТСЯ ИСПРАВЛЕНИЕ ИМЕНОВАНИЯ!**
