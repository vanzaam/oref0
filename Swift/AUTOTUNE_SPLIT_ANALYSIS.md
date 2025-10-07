# 📋 АНАЛИЗ РАЗДЕЛЕНИЯ SwiftAutotuneAlgorithms.swift

**Дата**: 2025-10-07 11:28  
**Размер файла**: 1335 строк

---

## 📊 СТРУКТУРА ФАЙЛА

### 1. Shared Structures (строки 8-155) → SwiftAutotuneShared.swift ✅

**УЖЕ СОЗДАНО!**
- `AutotuneInputs`
- `AutotunePreppedData`
- `AutotuneGlucoseEntry`
- `AutotuneCREntry`
- `DiaDeviation`
- `PeakDeviation`
- `AutotuneResult`

---

### 2. AUTOTUNE PREP Functions (строки 157-1059) → SwiftAutotunePrepAlgorithms.swift

#### 2.1 Main Prep Function (строки 157-275)
```swift
static func autotunePrep(inputs: AutotuneInputs) -> Result<AutotunePreppedData, SwiftOpenAPSError>
```
**Из**: `lib/autotune-prep/index.js`

#### 2.2 Categorization (строки 739-1058)
```swift
private static func categorizeBGDatums(
    bucketedData: [AutotuneGlucoseEntry],
    treatments: [CarbsEntry],
    profile: ProfileResult,
    ...
)
```
**Из**: `lib/autotune-prep/categorize.js`

#### 2.3 Helper Functions (строки 1060-1165)
- `calculateIOBAtTime()` - строки 1062-1088
- `getCurrentSensitivity()` - строки 1090-1110
- `getCurrentBasalRate()` - строки 1112-1131
- `calculateInsulinDosed()` - строки 1133-1164

**Из**: `lib/autotune-prep/dosed.js` и helpers

#### 2.4 DIA/Peak Analysis (строки 1166-1313)
- `analyzeDIADeviations()` - строки 1168-1240
- `analyzePeakTimeDeviations()` - строки 1242-1313

**Из**: `lib/autotune-prep/categorize.js`

**ИТОГО**: ~900 строк

---

### 3. AUTOTUNE CORE Functions (строки 277-737) → SwiftAutotuneCoreAlgorithms.swift

#### 3.1 Main Autotune Function (строки 277-416)
```swift
static func autotuneCore(
    preppedData: AutotunePreppedData,
    previousAutotune: AutotuneResult,
    pumpProfile: ProfileResult,
    ...
) -> Result<AutotuneResult, SwiftOpenAPSError>
```
**Из**: `lib/autotune/index.js` - `tuneAllTheThings()`

#### 3.2 Tuning Functions (строки 418-601)
- `tuneCarbohydrateRatio()` - строки 420-450
- `tuneInsulinSensitivity()` - строки 452-502
- `tuneBasalProfile()` - строки 504-601

**Из**: `lib/autotune/index.js`

#### 3.3 Optimization Functions (строки 603-732)
- `percentile()` - строки 605-610
- `optimizeDIA()` - строки 612-674
- `optimizeInsulinPeakTime()` - строки 676-732

**Из**: `lib/autotune/index.js`

#### 3.4 Helper (строки 734-737)
- `round()` - строки 734-737

**ИТОГО**: ~460 строк

---

### 4. Extensions (строки 1327-1335) → Оставить в SwiftAutotuneShared.swift

```swift
extension SwiftOpenAPSAlgorithms.ProfileResult {
    var min5mCarbimpact_autotune: Double
}
```

**ИТОГО**: ~8 строк

---

## 📋 ПЛАН РАЗДЕЛЕНИЯ (ПО ШАГАМ)

### Шаг 1: Создать SwiftAutotunePrepAlgorithms.swift ✅

**Содержимое**:
1. Import Foundation
2. Extension SwiftOpenAPSAlgorithms
3. Main function: `autotunePrep()` (строки 157-275)
4. Categorization: `categorizeBGDatums()` (строки 739-1058)
5. Helper functions (строки 1060-1165)
6. DIA/Peak analysis (строки 1166-1313)
7. Helper: `getMinutesFromStart()` (строки 1315-1324)

**Размер**: ~900 строк

---

### Шаг 2: Создать SwiftAutotuneCoreAlgorithms.swift ✅

**Содержимое**:
1. Import Foundation
2. Extension SwiftOpenAPSAlgorithms
3. Main function: `autotuneCore()` (строки 277-416)
4. Tuning functions (строки 418-601)
5. Optimization functions (строки 603-732)
6. Helper: `round()` (строки 734-737)

**Размер**: ~460 строк

---

### Шаг 3: Обновить SwiftAutotuneShared.swift ✅

**Добавить**:
- Extensions (строки 1327-1335)

**Размер**: ~170 строк

---

### Шаг 4: Удалить SwiftAutotuneAlgorithms.swift ✅

После проверки что все работает.

---

## 🎯 ПОРЯДОК ВЫПОЛНЕНИЯ

1. ✅ Создать SwiftAutotunePrepAlgorithms.swift
2. ✅ Создать SwiftAutotuneCoreAlgorithms.swift
3. ✅ Обновить SwiftAutotuneShared.swift (добавить extensions)
4. ✅ Проверить что нет конфликтов
5. ✅ Удалить SwiftAutotuneAlgorithms.swift
6. ✅ Проверить компиляцию

---

## 📊 ИТОГОВАЯ СТРУКТУРА

```
Swift/
├── SwiftAutotuneShared.swift          (~170 строк)
│   ├── Structures
│   └── Extensions
│
├── SwiftAutotunePrepAlgorithms.swift  (~900 строк)
│   ├── autotunePrep()
│   ├── categorizeBGDatums()
│   ├── Helper functions
│   └── DIA/Peak analysis
│
└── SwiftAutotuneCoreAlgorithms.swift  (~460 строк)
    ├── autotuneCore()
    ├── Tuning functions
    └── Optimization functions
```

**ИТОГО**: 3 файла, ~1530 строк (вместо 1 файла 1335 строк)

---

**Автор**: AI Assistant  
**Дата**: 2025-10-07  
**Статус**: Готов к выполнению
