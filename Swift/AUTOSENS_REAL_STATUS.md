# 🚨 AUTOSENS - РЕАЛЬНЫЙ СТАТУС ПОСЛЕ ПОСТРОЧНОЙ ПРОВЕРКИ

**Дата**: 2025-10-07 14:30  
**Проверка**: Построчное сравнение autosens.js vs SwiftAutosensAlgorithms.swift

---

## 📊 ЧТО ПРОПУЩЕНО В SWIFT

### ❌ КРИТИЧЕСКИЕ КОМПОНЕНТЫ (ОТСУТСТВУЮТ):

1. **Bucketing** (lines 72-119)
   - Группировка BG по 5-минутным интервалам
   - В Swift: просто фильтр по времени

2. **lastSiteChange + rewind_resets_autosens** (lines 24-46)
   - 24h lookback или с последнего rewind
   - В Swift: отсутствует полностью

3. **Meals tracking** (lines 122-141, 207-222)
   - find_meals() вызов
   - Удаление старых meals
   - mealCOB tracking
   - В Swift: отсутствует

4. **Carb absorption calculation** (lines 224-234)
   - ci = max(deviation, min_5m_carbimpact)
   - absorbed = ci * carb_ratio / sens
   - mealCOB -= absorbed
   - В Swift: отсутствует

5. **absorbing tracking** (lines 236-265)
   - Track если meal absorbing
   - mealStartCounter
   - type="csf"
   - В Swift: отсутствует

6. **UAM (Unannounced Meal) detection** (lines 274-297)
   - iob.iob > 2 * currentBasal
   - type="uam"
   - В Swift: отсутствует

7. **Type classification** (lines 300-317)
   - "non-meal", "csf", "uam"
   - Exclude meal deviations
   - В Swift: упрощенная classifyDeviation()

8. **tempTargetRunning usage** (lines 319-331)
   - ✅ Функция ДОБАВЛЕНА
   - ❌ НЕ ИСПОЛЬЗУЕТСЯ в calculateAutosensRatio!
   - Должна добавлять extra deviation для высокого target

9. **Hour marker + neutral deviations** (lines 333-343)
   - Add 0 deviation каждые 2 часа
   - В Swift: отсутствует

10. **Deviations padding** (lines 359-366)
    - Если deviations < 96, pad zeros
    - В Swift: отсутствует

11. **Percentile analysis** (lines 367-382)
    - percentile(deviations, 0.50)
    - Анализ % negative/positive
    - В Swift: отсутствует

12. **RMS deviation** (lines 389-391)
    - Root mean square calculation
    - В Swift: отсутствует

13. **basalOff calculation** (lines 393-404)
    ```javascript
    basalOff = pSensitive * (60/5) / profile.sens;
    ratio = 1 + (basalOff / profile.max_daily_basal);
    ```
    - В Swift: совершенно другая формула!

14. **isfLookup** (line 153)
    - Different sens for different times
    - В Swift: fixed profile.sens

15. **basalLookup** (line 176)
    - current_basal по времени
    - В Swift: fixed profile.current_basal

---

## ⚠️ КРИТИЧЕСКИ НЕПРАВИЛЬНАЯ ФОРМУЛА RATIO

### JS (ОРИГИНАЛ):
```javascript
// Line 396 или 399
basalOff = pSensitive * (60/5) / profile.sens;
// Line 404
ratio = 1 + (basalOff / profile.max_daily_basal);
// Lines 409-410
ratio = Math.max(ratio, profile.autosens_min);
ratio = Math.min(ratio, profile.autosens_max);
```

### Swift (УПРОЩЕНИЕ):
```swift
// Lines 313-314
let ratioChange = avgDeviation / 100.0
ratio = 1.0 - ratioChange * 0.2
// Line 317
ratio = max(0.7, min(1.3, ratio))
```

**ЭТО СОВЕРШЕННО РАЗНЫЕ АЛГОРИТМЫ!**

---

## 📊 РЕАЛЬНЫЙ ПРОЦЕНТ ПОРТАЦИИ

### По функциональности:

**Портировано**:
- ✅ Базовая структура loop через glucose
- ✅ Delta calculation (упрощенно)
- ✅ IOB calculation (через calculateIOBAtTime)
- ✅ BGI calculation (упрощенно)
- ✅ Carb impact (упрощенно)
- ✅ Deviation calculation (базовый)
- ✅ tempTargetRunning() функция (НО НЕ ИСПОЛЬЗУЕТСЯ!)

**ОТСУТСТВУЕТ**:
- ❌ Bucketing (критично!)
- ❌ Meals tracking (критично!)
- ❌ COB calculation (критично!)
- ❌ UAM detection (критично!)
- ❌ Type classification (важно!)
- ❌ Percentile analysis (критично!)
- ❌ Правильная формула ratio (КРИТИЧНО!)
- ❌ tempTarget usage (критично!)
- ❌ Hour markers (важно!)
- ❌ Padding zeros (важно!)
- ❌ isfLookup (важно!)
- ❌ basalLookup (важно!)
- ❌ RMS deviation (менее важно)
- ❌ lastSiteChange (менее важно)

**РЕАЛЬНЫЙ ПРОЦЕНТ**: ~30-40% функциональности!

---

## 🎯 ВЕРДИКТ

**SwiftAutosensAlgorithms.swift - это НЕ полная портация!**

Это **УПРОЩЕННАЯ ВЕРСИЯ** с:
- Базовым loop через glucose
- Упрощенным IOB/BGI calculation
- **НЕПРАВИЛЬНОЙ формулой ratio**
- Отсутствием критичных компонентов

**Реальный статус**: **30-40%**, не 89% и не 97%!

---

## 📋 ЧТО НУЖНО ДЛЯ 100%

1. Портировать bucketing логику
2. Портировать meals tracking + COB
3. Портировать UAM detection
4. Портировать type classification (csf/uam/non-meal)
5. Портировать percentile analysis
6. **ИСПРАВИТЬ формулу ratio на правильную из JS!**
7. ИСПОЛЬЗОВАТЬ tempTargetRunning() в loop
8. Добавить hour markers + neutral deviations
9. Добавить padding zeros
10. Добавить isfLookup
11. Добавить basalLookup

**Объем работы**: ~400 строк Swift кода

**Время**: 4-6 часов

---

## 🚨 КРИТИЧЕСКИЙ ВЫВОД

**AUTOSENS В SWIFT - ЭТО УПРОЩЕННАЯ ИМПЛЕМЕНТАЦИЯ, НЕ ТОЧНАЯ ПОРТАЦИЯ!**

Использует другую логику и формулы. Может давать РАЗНЫЕ результаты от оригинального JS кода!

**Для production использования требуется ПОЛНАЯ ПОРТАЦИЯ!**
