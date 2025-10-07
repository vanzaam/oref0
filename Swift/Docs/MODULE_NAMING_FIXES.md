# 🔴 КРИТИЧНО: ИСПРАВЛЕНИЕ ИМЕНОВАНИЯ МОДУЛЕЙ

**Дата**: 2025-10-07 12:28  
**Статус**: 🔴 ТРЕБУЕТСЯ НЕМЕДЛЕННОЕ ИСПРАВЛЕНИЕ

---

## ❌ ПРОБЛЕМЫ С ИМЕНОВАНИЕМ

### 1. IOB модуль - НЕПРАВИЛЬНОЕ ИМЯ

**Сейчас**: `SwiftOpenAPSAlgorithms.swift` (содержит IOB логику)  
**Должно быть**: `SwiftIOBAlgorithms.swift`

**Причина**: lib/iob/index.js → должен соответствовать SwiftIOBAlgorithms.swift

---

### 2. glucoseGetLast - НЕТ ОТДЕЛЬНОГО ФАЙЛА!

**Сейчас**: функция `createGlucoseStatus()` в `SwiftOpenAPSCoordinator.swift`  
**Должно быть**: отдельный файл `SwiftGlucoseGetLast.swift`

**Причина**: lib/glucose-get-last.js → должен соответствовать SwiftGlucoseGetLast.swift

---

## ✅ ПРАВИЛЬНАЯ СТРУКТУРА МОДУЛЕЙ

### Должно быть:

```
Swift/
├── SwiftIOBAlgorithms.swift                    ← lib/iob/index.js
├── SwiftMealAlgorithms.swift                   ← lib/meal/index.js
├── SwiftDetermineBasalAlgorithms.swift         ← lib/determine-basal/determine-basal.js ✅
├── SwiftGlucoseGetLast.swift                   ← lib/glucose-get-last.js (СОЗДАТЬ!)
├── SwiftAutosensAlgorithms.swift               ← lib/determine-basal/autosens.js ✅
├── SwiftProfileAlgorithms.swift                ← lib/profile/index.js ✅
├── SwiftAutotunePrepAlgorithms.swift           ← lib/autotune-prep/index.js ✅
├── SwiftAutotuneCoreAlgorithms.swift           ← lib/autotune/index.js ✅
├── SwiftAutotuneShared.swift                   ← shared structures ✅
├── SwiftOpenAPS.swift                          ← API wrapper ✅
├── SwiftOpenAPSCoordinator.swift               ← orchestrator ✅
└── HybridOpenAPS.swift                         ← ???
```

**Примечание**: basalSetTemp.js → часть SwiftDetermineBasalAlgorithms.swift (правильно!)

---

## 🎯 ДЕЙСТВИЯ

### Критично:

1. **ПЕРЕИМЕНОВАТЬ**: `SwiftOpenAPSAlgorithms.swift` → `SwiftIOBAlgorithms.swift`
   - Или выделить IOB логику в новый SwiftIOBAlgorithms.swift
   - Перенести функцию `calculateIOB()` и все IOB-related функции

2. **СОЗДАТЬ**: `SwiftGlucoseGetLast.swift`
   - Перенести логику из `createGlucoseStatus()`
   - Добавить ВСЮ логику из lib/glucose-get-last.js:
     * Временные интервалы (2.5, 7.5, 17.5, 42.5 мин)
     * Усреднение близких точек
     * Нормализация delta к 5 минутам
     * Фильтрация по device
     * Calibration records
     * Округление результатов

---

## 📊 ТЕКУЩАЯ vs ПРАВИЛЬНАЯ СТРУКТУРА

### СЕЙЧАС (НЕПРАВИЛЬНО):

| JS Module | Swift Location | Правильно? |
|-----------|---------------|------------|
| lib/iob/ | SwiftOpenAPSAlgorithms.swift::calculateIOB() | ❌ Неправильное имя файла |
| lib/glucose-get-last.js | SwiftOpenAPSCoordinator.swift::createGlucoseStatus() | ❌ НЕТ отдельного файла |

### ДОЛЖНО БЫТЬ (ПРАВИЛЬНО):

| JS Module | Swift File | Статус |
|-----------|-----------|--------|
| lib/iob/index.js | SwiftIOBAlgorithms.swift | 🔴 ПЕРЕИМЕНОВАТЬ |
| lib/glucose-get-last.js | SwiftGlucoseGetLast.swift | 🔴 СОЗДАТЬ |

---

## 🔴 PLAN OF ACTION

### Step 1: Создать SwiftGlucoseGetLast.swift

```swift
import Foundation

extension SwiftOpenAPSAlgorithms {
    
    /// Портирование lib/glucose-get-last.js
    /// ТОЧНАЯ копия логики getLastGlucose()
    static func getLastGlucose(data: [BloodGlucose]) -> GlucoseStatus {
        // TODO: Портировать ВСЮ логику из JS:
        // 1. Фильтрация (glucose || sgv)
        // 2. Temporal intervals (2.5, 7.5, 17.5, 42.5)
        // 3. Averaging within 2.5 minutes
        // 4. Device filtering
        // 5. Calibration records
        // 6. Normalization to 5-min intervals: avgdelta = change/minutesago * 5
        // 7. Rounding results
        
        // КРИТИЧНО: НЕ использовать упрощенную логику!
        // Должно быть ТОЧНО как в lib/glucose-get-last.js
    }
}
```

---

### Step 2: Переименовать или выделить IOB модуль

**Вариант A - Переименовать файл**:
```bash
mv SwiftOpenAPSAlgorithms.swift SwiftIOBAlgorithms.swift
```

**Вариант B - Создать новый файл** (если SwiftOpenAPSAlgorithms содержит еще что-то):
```swift
// SwiftIOBAlgorithms.swift
import Foundation

extension SwiftOpenAPSAlgorithms {
    
    /// Портирование lib/iob/index.js
    static func calculateIOB(inputs: IOBInputs) -> IOBResult {
        // Перенести логику + ИСПРАВИТЬ 5 проблем:
        // 1. Добавить: if (dia < 3) { dia = 3 }
        // 2. Добавить: if (requireLongDia && dia < 5) { dia = 5 }
        // 3. Добавить округление: Math.round(iob * 1000) / 1000
        // 4. Изменить фильтрацию на DIA-based
        // 5. Исправить архитектуру
    }
}
```

---

## ✅ ПОСЛЕ ИСПРАВЛЕНИЯ

### Правильная карта соответствия:

| # | JS Module | Swift File | Match |
|---|-----------|-----------|-------|
| 1 | iob.js | SwiftIOBAlgorithms.swift | ✅ |
| 2 | meal.js | SwiftMealAlgorithms.swift | ✅ |
| 3 | determineBasal.js | SwiftDetermineBasalAlgorithms.swift | ✅ |
| 4 | glucoseGetLast.js | SwiftGlucoseGetLast.swift | ✅ |
| 5 | basalSetTemp.js | Part of SwiftDetermineBasalAlgorithms.swift | ✅ |
| 6 | autosens.js | SwiftAutosensAlgorithms.swift | ✅ |
| 7 | profile.js | SwiftProfileAlgorithms.swift | ✅ |
| 8 | autotunePrep.js | SwiftAutotunePrepAlgorithms.swift | ✅ |
| 9 | autotuneCore.js | SwiftAutotuneCoreAlgorithms.swift | ✅ |

**100% правильное соответствие имен!** 🎉

---

## 🚨 КРИТИЧНОСТЬ

**Без правильного именования**:
- ❌ Сложно найти соответствующий модуль
- ❌ Сложно поддерживать код
- ❌ Сложно сравнивать с оригиналом
- ❌ Нарушается архитектура проекта

**С правильным именованием**:
- ✅ Понятно какой JS соответствует какому Swift
- ✅ Легко найти и исправить проблемы
- ✅ Правильная архитектура
- ✅ Соответствие оригиналу

---

## 📝 ВЫВОД

**ТРЕБУЕТСЯ**:
1. 🔴 Переименовать SwiftOpenAPSAlgorithms.swift → SwiftIOBAlgorithms.swift
2. 🔴 Создать SwiftGlucoseGetLast.swift с ПОЛНОЙ логикой из JS

**ПОСЛЕ ЭТОГО**:
- Все 9 модулей будут иметь правильные имена
- Будет легко исправлять обнаруженные проблемы
- Архитектура будет соответствовать оригиналу
