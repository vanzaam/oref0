# 🎯 ПЛАН НОРМАЛЬНОЙ ПОРТАЦИИ OREF0 → SWIFT

**Дата**: 2025-10-07  
**Цель**: Создать **точную, работающую** Swift-портацию oref0 без потерь функциональности

---

## 📋 ЭТАП 1: ИСПРАВЛЕНИЕ КРИТИЧЕСКИХ ОШИБОК (Приоритет 1)

### ✅ Шаг 1.1: Добавить `outUnits` в ProfileResult
**Файл**: `Swift/SwiftProfileAlgorithms.swift`

```swift
struct ProfileResult {
    // ... существующие поля
    let outUnits: String  // "mg/dL" или "mmol/L"
}
```

**Время**: 15 минут  
**Тестирование**: Unit test для проверки установки значения

---

### ✅ Шаг 1.2: Реализовать функцию `convertBG`
**Файл**: `Swift/SwiftDetermineBasalAlgorithms.swift`

```swift
/// КРИТИЧЕСКАЯ функция из determine-basal.js:39-49
/// Конвертирует значения глюкозы между mg/dL и mmol/L
private static func convertBG(_ value: Double, profile: ProfileResult) -> Double {
    if profile.outUnits == "mmol/L" {
        return round(value / 18.0 * 10) / 10  // round to 1 decimal
    } else {
        return round(value)  // round to integer
    }
}
```

**Время**: 10 минут  
**Тестирование**: 
- `convertBG(120, mg/dL) == 120`
- `convertBG(120, mmol/L) == 6.7`

---

### ✅ Шаг 1.3: Добавить `profile` в DetermineBasalResult
**Проблема**: Для конвертации в `rawJSON` нужен доступ к `profile.outUnits`

```swift
struct DetermineBasalResult {
    // ... существующие поля
    let profile: ProfileResult  // Добавляем для доступа к outUnits
}
```

**Время**: 20 минут  
**Тестирование**: Проверить, что все вызовы обновлены

---

### ✅ Шаг 1.4: Конвертировать все BG-значения в результатах
**Файл**: `Swift/SwiftDetermineBasalAlgorithms.swift`

**Места для исправления**:
1. `DetermineBasalResult.rawJSON` - конвертировать `bg`, `eventualBG`
2. Все строки `reason` - конвертировать все BG-значения
3. `predBGs` массивы - конвертировать каждый элемент
4. Поля результата: `BGI`, `deviation`, `ISF`, `target_bg`

**Время**: 2 часа  
**Тестирование**: Сравнительный тест Swift vs JS для mmol/L

---

## 📋 ЭТАП 2: ПОЛНАЯ ПОРТАЦИЯ DETERMINE-BASAL (Приоритет 1)

### ✅ Шаг 2.1: Портировать все вспомогательные функции

**Из determine-basal.js нужно портировать**:

1. **`round(value, digits)`** (строка 21-26)
   ```swift
   private static func round(_ value: Double, digits: Int = 0) -> Double {
       let scale = pow(10.0, Double(digits))
       return Darwin.round(value * scale) / scale
   }
   ```

2. **`calculate_expected_delta(target_bg, eventual_bg, bgi)`** (строка 31-36)
   ```swift
   private static func calculateExpectedDelta(
       targetBG: Double, 
       eventualBG: Double, 
       bgi: Double
   ) -> Double {
       let fiveMinBlocks = (2.0 * 60.0) / 5.0  // 24 blocks in 2 hours
       let targetDelta = targetBG - eventualBG
       return round(bgi + (targetDelta / fiveMinBlocks), digits: 1)
   }
   ```

3. **`enable_smb(...)`** (строка 51-125) - ПОЛНАЯ логика включения SMB
4. **`setTempBasal(...)`** - логика установки temp basal
5. **Все проверки безопасности CGM** (строка 149-221)

**Время**: 4 часа  
**Тестирование**: Unit tests для каждой функции

---

### ✅ Шаг 2.2: Портировать основной алгоритм determine_basal

**Критические секции для портирования**:

1. **CGM Safety Checks** (строка 149-221)
   - Калибровка / ??? state: `glucose <= 10 || glucose === 38 || noise >= 3`
   - Устаревшие данные: `glucose_age > 12 || glucose_age < -5`
   - Застрявшие данные: `delta === 0 && short_avgdelta > -1 && short_avgdelta < 1`

2. **Temp Basal Safety** (строка 188-221)
   - Несоответствие temp: `currenttemp.rate !== lastTemp.rate && lastTempAge > 10`
   - Истекший temp: `tempAge - tempDuration > 5 && lastTempAge > 10`

3. **Target BG Calculation** (строка 223-247)
   - `target_bg = (profile.min_bg + profile.max_bg) / 2`

4. **Sensitivity Ratio** (строка 249-290)
   - Temp target adjustments
   - Autosens ratio
   - Basal adjustments

5. **Target BG Adjustments** (строка 292-326)
   - Autosens adjustments
   - Noisy CGM target multiplier

6. **ISF Adjustments** (строка 335-348)
   - `sens = profile.sens / sensitivityRatio`

7. **BGI & Deviation** (строка 399-417)
   - `bgi = round((-iob_data.activity * sens * 5), 2)`
   - `deviation = round((30 / 5) * (minDelta - bgi), 2)`

8. **Prediction Arrays** (строка 442-657)
   - IOBpredBGs, COBpredBGs, UAMpredBGs, ZTpredBGs

9. **Eventual BG** (строка 417)
   - `eventualBG = naive_eventualBG + deviation`

10. **SMB Logic** (строка 659-1170)
    - Enable/disable SMB
    - Calculate microbolus
    - Safety limits

11. **Carbs Required** (строка 882-905)
    - `carbsReq = (bgUndershoot - zeroTempEffect) / csf - COBforCarbsReq`

12. **Low Glucose Suspend** (строка 907-927)
    - `bg < threshold || minGuardBG < threshold`

13. **Temp Basal Recommendations** (строка 930-1170)
    - High/low temp logic
    - Rate calculations
    - Duration calculations

**Время**: 8 часов  
**Тестирование**: Интеграционные тесты с реальными данными

---

## 📋 ЭТАП 3: ПОРТАЦИЯ IOB CALCULATION (Приоритет 1)

### ✅ Шаг 3.1: Проверить bilinear curve

**Файл**: `Swift/SwiftOpenAPSAlgorithms.swift`

**Проверить соответствие с** `lib/iob/calculate.js:36-80`:
- `peak = 75` минут
- `end = 180` минут
- `activityPeak = 2 / (dia * 60)`
- Формулы для `activityContrib` и `iobContrib`

**Время**: 1 час  
**Тестирование**: Сравнить результаты с JS для тестовых болюсов

---

### ✅ Шаг 3.2: Проверить exponential curve

**Проверить соответствие с** `lib/iob/calculate.js:83-147`:
- Peak times: rapid-acting = 75, ultra-rapid = 55
- Формулы tau, a, S
- `activityContrib` и `iobContrib` формулы

**Время**: 1 час  
**Тестирование**: Сравнить с JS для разных типов инсулина

---

## 📋 ЭТАП 4: ПОРТАЦИЯ PROFILE (Приоритет 2)

### ✅ Шаг 4.1: Добавить все поля из profile/index.js

**Файл**: `Swift/SwiftProfileAlgorithms.swift`

**Недостающие поля**:
```swift
struct ProfileResult {
    // ... существующие
    
    // Из profile/index.js:153-189
    let outUnits: String
    let minBG: Double
    let maxBG: Double
    let bgTargets: BGTargets
    let temptargetSet: Bool
    let isfProfile: InsulinSensitivities
    
    // SMB параметры (строка 60-100 в profile/index.js)
    let enableSMBAlways: Bool
    let enableSMBWithCOB: Bool
    let enableSMBWithTemptarget: Bool
    let enableSMBAfterCarbs: Bool
    let allowSMBWithHighTemptarget: Bool
    let maxSMBBasalMinutes: Double
    let maxUAMSMBBasalMinutes: Double
    let SMBInterval: Double
    
    // Safety параметры
    let carbsReqThreshold: Double
    let noisyCGMTargetMultiplier: Double
    let maxRaw: Double
    let a52RiskEnable: Bool
    
    // Autosens параметры
    let autosensMax: Double
    let autosensMin: Double
    let sensitivityRaisesTarget: Bool
    let resistanceLowersTarget: Bool
}
```

**Время**: 2 часа  
**Тестирование**: Проверить создание профиля с всеми полями

---

## 📋 ЭТАП 5: ПОРТАЦИЯ MEAL/COB (Приоритет 2)

### ✅ Шаг 5.1: Портировать meal/total.js

**Критические функции**:
1. **Carb absorption model** (строка 30-150)
   - `carbWindow = 6` часов
   - Модель абсорбции углеводов
   - COB calculation

2. **Carb impact** (строка 150-200)
   - `ci = (minDelta - bgi) / sens * 5`
   - Carb sensitivity factor

**Время**: 3 часа  
**Тестирование**: Сравнить COB с JS для тестовых приемов пищи

---

## 📋 ЭТАП 6: ПОРТАЦИЯ AUTOSENS (Приоритет 2)

### ✅ Шаг 6.1: Портировать autosens/index.js

**Критические части**:
1. **Deviation analysis** (строка 50-200)
   - Анализ отклонений BGI vs реальных изменений
   - Классификация периодов (CSF, UAM, high_cob)

2. **Ratio calculation** (строка 200-300)
   - `ratio = 1.0 + (avgDeviation / sensitivityThreshold)`
   - Ограничения autosens_min/max

**Время**: 4 часа  
**Тестирование**: Сравнить ratio с JS для тестовых данных

---

## 📋 ЭТАП 7: ТЕСТИРОВАНИЕ (Приоритет 1)

### ✅ Шаг 7.1: Unit Tests

**Создать тесты для**:
1. `convertBG` - mg/dL ↔ mmol/L
2. `round` - округление с разными digits
3. `calculateExpectedDelta`
4. `enable_smb` - все условия
5. IOB calculation - bilinear и exponential
6. Profile creation - все поля
7. Meal/COB calculation
8. Autosens calculation

**Время**: 4 часа

---

### ✅ Шаг 7.2: Integration Tests

**Тест-кейсы**:
1. **Нормальный случай**: BG = 120, COB = 30, IOB = 2
2. **Низкий BG**: BG = 70, suspend insulin
3. **Высокий BG**: BG = 200, high temp + SMB
4. **mmol/L пользователь**: все значения конвертированы
5. **Noisy CGM**: target adjustments
6. **Temp target**: sensitivity adjustments
7. **Autosens**: ratio применен к basal и ISF

**Время**: 6 часов

---

### ✅ Шаг 7.3: Сравнительное тестирование Swift vs JS

**Метод**:
1. Запустить оба алгоритма с одинаковыми входными данными
2. Сравнить все поля результата
3. Допустимая погрешность: 0.01 для всех значений

**Тест-данные**:
- 100 реальных сценариев из production
- Покрытие всех edge cases
- mg/dL и mmol/L пользователи

**Время**: 8 часов

---

## 📋 ЭТАП 8: ДОКУМЕНТАЦИЯ (Приоритет 3)

### ✅ Шаг 8.1: Обновить CRITICAL_SAFETY_README.md

**Добавить**:
- ✅ Статус портирования каждой функции
- ✅ Результаты тестирования
- ✅ Известные отличия от JS (если есть)

**Время**: 2 часа

---

### ✅ Шаг 8.2: Создать Migration Guide

**Для разработчиков**:
- Как переключиться с JS на Swift
- Как тестировать изменения
- Как откатиться при проблемах

**Время**: 2 часа

---

## 📊 ОБЩАЯ ОЦЕНКА ВРЕМЕНИ

| Этап | Время | Приоритет |
|------|-------|-----------|
| 1. Исправление критических ошибок | 3 часа | 🔴 Критический |
| 2. Полная портация determine-basal | 12 часов | 🔴 Критический |
| 3. Портация IOB | 2 часа | 🔴 Критический |
| 4. Портация Profile | 2 часа | 🟡 Высокий |
| 5. Портация Meal/COB | 3 часа | 🟡 Высокий |
| 6. Портация Autosens | 4 часа | 🟡 Высокий |
| 7. Тестирование | 18 часов | 🔴 Критический |
| 8. Документация | 4 часа | 🟢 Средний |
| **ИТОГО** | **48 часов** | |

---

## 🎯 КРИТЕРИИ УСПЕХА

### ✅ Минимальные требования (MVP)
1. ✅ Функция `convertBG` работает для mg/dL и mmol/L
2. ✅ Все BG-значения в результатах конвертированы
3. ✅ CGM safety checks работают точно как в JS
4. ✅ Temp basal recommendations совпадают с JS (±0.01)
5. ✅ IOB calculation совпадает с JS (±0.001)

### ✅ Полная портация
6. ✅ SMB logic работает точно как в JS
7. ✅ Prediction arrays совпадают с JS
8. ✅ Autosens ratio совпадает с JS (±0.01)
9. ✅ COB calculation совпадает с JS (±0.1g)
10. ✅ Все edge cases обработаны

### ✅ Production Ready
11. ✅ 100% покрытие unit tests
12. ✅ 100 integration tests passed
13. ✅ Сравнительное тестирование: 99%+ совпадение с JS
14. ✅ Документация обновлена
15. ✅ Code review пройден

---

## 🚀 ПОРЯДОК ВЫПОЛНЕНИЯ

### Неделя 1: Критические исправления
- День 1-2: Этап 1 (критические ошибки)
- День 3-5: Этап 2 (determine-basal, часть 1)

### Неделя 2: Основной алгоритм
- День 1-3: Этап 2 (determine-basal, часть 2)
- День 4-5: Этап 3 (IOB)

### Неделя 3: Дополнительные алгоритмы
- День 1-2: Этап 4 (Profile)
- День 3: Этап 5 (Meal/COB)
- День 4-5: Этап 6 (Autosens)

### Неделя 4: Тестирование и документация
- День 1-2: Этап 7.1 (Unit tests)
- День 3-4: Этап 7.2-7.3 (Integration + сравнительное)
- День 5: Этап 8 (Документация)

---

## 📝 ЧЕКЛИСТ ПЕРЕД КОММИТОМ

- [ ] Все unit tests проходят
- [ ] Сравнительное тестирование: >95% совпадение
- [ ] SwiftLint warnings исправлены
- [ ] Документация обновлена
- [ ] CRITICAL_SAFETY_README.md обновлен
- [ ] Code review пройден
- [ ] Тестирование на реальных данных

---

## 🆘 РИСКИ И МИТИГАЦИЯ

### Риск 1: Неточная портация математики
**Митигация**: Сравнительное тестирование каждой функции с JS

### Риск 2: Пропущенные edge cases
**Митигация**: Анализ всех условий в JS коде, 100% покрытие тестами

### Риск 3: Проблемы с производительностью
**Митигация**: Профилирование, оптимизация только после корректности

### Риск 4: Регрессии в production
**Митигация**: Постепенный rollout, feature flag для переключения JS↔Swift

---

**Начинаем с Этапа 1: Исправление критических ошибок** 🚀
