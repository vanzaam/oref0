# 📋 СООТВЕТСТВИЕ WEBPACK МОДУЛЕЙ И SWIFT ФАЙЛОВ

## ✅ WEBPACK ENTRY POINTS vs SWIFT

| # | Webpack Entry | Исходник JS | Swift Файл | Размер Swift | Статус |
|---|---------------|-------------|------------|--------------|--------|
| 1 | **iob.js** | lib/iob/index.js | ❓ Нужно проверить | - | 🔴 ПРОВЕРИТЬ |
| 2 | **meal.js** | lib/meal/index.js | SwiftMealAlgorithms.swift | 8.9KB | ✅ ЕСТЬ |
| 3 | **determineBasal.js** | lib/determine-basal/determine-basal.js | SwiftDetermineBasalAlgorithms.swift | 91KB | ✅ 100% ГОТОВ |
| 4 | **glucoseGetLast.js** | lib/glucose-get-last.js | ❓ Нужно проверить | - | 🔴 ПРОВЕРИТЬ |
| 5 | **basalSetTemp.js** | lib/basal-set-temp.js | ❓ Нужно проверить | - | 🔴 ПРОВЕРИТЬ |
| 6 | **autosens.js** | lib/determine-basal/autosens.js | SwiftAutosensAlgorithms.swift | 15KB | ✅ ЕСТЬ |
| 7 | **profile.js** | lib/profile/index.js | SwiftProfileAlgorithms.swift | 15KB | ✅ ЕСТЬ |
| 8 | **autotunePrep.js** | lib/autotune-prep/index.js | SwiftAutotunePrepAlgorithms.swift | 29KB | ✅ 100% ГОТОВ |
| 9 | **autotuneCore.js** | lib/autotune/index.js | SwiftAutotuneCoreAlgorithms.swift | 18KB | ✅ 100% ГОТОВ |

---

## 📊 ДЕТАЛЬНЫЙ АНАЛИЗ

### ✅ 1. determineBasal.js → SwiftDetermineBasalAlgorithms.swift
**Статус**: ✅ **100% ГОТОВ И ВЕРИФИЦИРОВАН**

**JS**: lib/determine-basal/determine-basal.js  
**Swift**: SwiftDetermineBasalAlgorithms.swift (91KB)

**Проверено**:
- ✅ Все формулы идентичны
- ✅ Все условия идентичны
- ✅ SMB logic портирован
- ✅ Low glucose suspend работает
- ✅ Prediction arrays идентичны

**Нужна проверка**: ❌ НЕТ - уже проверено!

---

### ✅ 2. autotunePrep.js → SwiftAutotunePrepAlgorithms.swift
**Статус**: ✅ **100% ГОТОВ И ВЕРИФИЦИРОВАН**

**JS**: lib/autotune-prep/index.js + lib/autotune-prep/categorize.js  
**Swift**: SwiftAutotunePrepAlgorithms.swift (29KB)

**Проверено**:
- ✅ categorizeBGDatums() - 14 критических блоков идентичны
- ✅ analyzeDIADeviations() идентично
- ✅ analyzePeakTimeDeviations() идентично
- ✅ Все формулы проверены

**Нужна проверка**: ❌ НЕТ - уже проверено построчно!

---

### ✅ 3. autotuneCore.js → SwiftAutotuneCoreAlgorithms.swift
**Статус**: ✅ **100% ГОТОВ И ВЕРИФИЦИРОВАН**

**JS**: lib/autotune/index.js  
**Swift**: SwiftAutotuneCoreAlgorithms.swift (18KB)

**Проверено**:
- ✅ tuneAllTheThings() → autotuneCore()
- ✅ tuneCarbohydrateRatio() идентично
- ✅ tuneInsulinSensitivity() идентично
- ✅ tuneBasalProfile() идентично
- ✅ optimizeDIA() идентично
- ✅ optimizeInsulinPeakTime() идентично

**Нужна проверка**: ❌ НЕТ - уже проверено!

---

### ✅ 4. autosens.js → SwiftAutosensAlgorithms.swift
**Статус**: 🟡 **ЕСТЬ, НУЖНА ПРОВЕРКА**

**JS**: lib/determine-basal/autosens.js  
**Swift**: SwiftAutosensAlgorithms.swift (15KB)

**Что нужно проверить**:
- 🔴 Соответствие функции detectSensitivity()
- 🔴 Все формулы расчета autosens
- 🔴 Ratio calculations

**Нужна проверка**: ✅ ДА!

---

### ✅ 5. profile.js → SwiftProfileAlgorithms.swift
**Статус**: 🟡 **ЕСТЬ, НУЖНА ПРОВЕРКА**

**JS**: lib/profile/index.js (+ basal.js, isf.js, carbs.js)  
**Swift**: SwiftProfileAlgorithms.swift (15KB)

**Что нужно проверить**:
- 🔴 basalLookup()
- 🔴 isfLookup()
- 🔴 carbsLookup()
- 🔴 Target calculations

**Нужна проверка**: ✅ ДА!

---

### ✅ 6. meal.js → SwiftMealAlgorithms.swift
**Статус**: 🟡 **ЕСТЬ, НУЖНА ПРОВЕРКА**

**JS**: lib/meal/index.js  
**Swift**: SwiftMealAlgorithms.swift (8.9KB)

**Что нужно проверить**:
- 🔴 find_meals() функция
- 🔴 COB calculation
- 🔴 Meal detection logic

**Нужна проверка**: ✅ ДА!

---

### 🔴 7. iob.js → ???
**Статус**: 🔴 **НУЖНО НАЙТИ**

**JS**: lib/iob/index.js  
**Swift**: ❓ Возможно в SwiftOpenAPSAlgorithms.swift?

**Нужно**:
- 🔴 Найти где находится calculateIOB()
- 🔴 Проверить соответствие

**Нужна проверка**: ✅ ДА!

---

### 🔴 8. glucoseGetLast.js → ???
**Статус**: 🔴 **НУЖНО НАЙТИ**

**JS**: lib/glucose-get-last.js  
**Swift**: ❓ Возможно в SwiftOpenAPSAlgorithms.swift?

**Нужно**:
- 🔴 Найти функцию получения последней глюкозы
- 🔴 Проверить соответствие

**Нужна проверка**: ✅ ДА!

---

### 🔴 9. basalSetTemp.js → ???
**Статус**: 🔴 **НУЖНО НАЙТИ**

**JS**: lib/basal-set-temp.js  
**Swift**: ❓ Возможно в SwiftOpenAPSAlgorithms.swift?

**Нужно**:
- 🔴 Найти функцию setTempBasal()
- 🔴 Проверить соответствие

**Нужна проверка**: ✅ ДА!

---

## 📋 ИТОГОВАЯ ТАБЛИЦА ПРОВЕРКИ

| Модуль | Статус | Приоритет проверки |
|--------|--------|-------------------|
| determineBasal.js | ✅ 100% готов | ✅ Не нужна |
| autotunePrep.js | ✅ 100% готов | ✅ Не нужна |
| autotuneCore.js | ✅ 100% готов | ✅ Не нужна |
| autosens.js | 🟡 Есть файл | 🟡 Средний |
| profile.js | �� Есть файл | 🟡 Средний |
| meal.js | 🟡 Есть файл | 🟡 Средний |
| iob.js | 🔴 Найти | 🔴 Высокий |
| glucoseGetLast.js | 🔴 Найти | 🟢 Низкий |
| basalSetTemp.js | 🔴 Найти | 🟢 Низкий |

---

## �� ПЛАН ДАЛЬНЕЙШЕЙ ПРОВЕРКИ

### Приоритет 1 (КРИТИЧНО):
1. 🔴 **Найти и проверить IOB модуль** (calculateIOB)
   - Это КРИТИЧНО для всех алгоритмов!

### Приоритет 2 (ВАЖНО):
2. 🟡 **Проверить autosens.js** → SwiftAutosensAlgorithms.swift
3. 🟡 **Проверить profile.js** → SwiftProfileAlgorithms.swift
4. 🟡 **Проверить meal.js** → SwiftMealAlgorithms.swift

### Приоритет 3 (ПОЛЕЗНО):
5. 🔴 **Найти glucoseGetLast.js**
6. 🔴 **Найти basalSetTemp.js**

---

## ✅ УЖЕ ГОТОВО (100%)

1. ✅ **determineBasal.js** (91KB Swift) - ПОЛНОСТЬЮ ПРОВЕРЕН!
2. ✅ **autotunePrep.js** (29KB Swift) - ПОЛНОСТЬЮ ПРОВЕРЕН!
3. ✅ **autotuneCore.js** (18KB Swift) - ПОЛНОСТЬЮ ПРОВЕРЕН!

**3 из 9 модулей (33%) - ГОТОВЫ И ВЕРИФИЦИРОВАНЫ!**

---

## 🚀 СЛЕДУЮЩИЙ ШАГ

**Рекомендую начать с IOB модуля** - это основа для всех остальных!

Найти `calculateIOB()` функцию в Swift файлах и проверить соответствие lib/iob/index.js
