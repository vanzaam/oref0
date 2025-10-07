# 🚀 QUICK START - Интеграция за 30 минут

**Для**: Опытных разработчиков FreeAPS X  
**Детали**: См. INTEGRATION_GUIDE.md

---

## ⚡ ЗА 30 МИНУТ

### 1. Копируйте 9 файлов (2 мин)

```bash
# IOB (4 файла)
cp Swift/Swift{IOBCalculate,IOBTotal,IOBHistory,IOBAlgorithms}.swift YourProject/Core/Algorithms/IOB/

# MEAL (4 файла)  
cp Swift/Swift{MealHistory,MealTotal,CarbAbsorption,MealAlgorithms}.swift YourProject/Core/Algorithms/Meal/

# AUTOSENS (1 файл)
cp Swift/SwiftAutosensAlgorithms.swift YourProject/Core/Algorithms/Autosens/
```

### 2. Переименуйте enum (5 мин)

В каждом файле замените:
- `SwiftIOBCalculate` → `IOBCalculate`
- `SwiftIOBTotal` → `IOBTotal`
- `SwiftIOBHistory` → `IOBHistory`
- `SwiftMealHistory` → `MealHistory`
- `SwiftMealTotal` → `MealTotal`
- `SwiftCarbAbsorption` → `CarbAbsorption`
- `SwiftOpenAPSAlgorithms` → `OpenAPSAlgorithms`

### 3. Замените типы (10 мин)

Find & Replace во ВСЕХ файлах:

```swift
// Типы из SwiftTypes.swift → Ваши типы
PumpHistoryEvent  → YourPumpHistoryEvent
BloodGlucose      → YourBloodGlucose
ProfileResult     → YourProfile
CarbsEntry        → YourCarbEntry
BasalProfileEntry → YourBasalProfileEntry
TempTarget        → YourTempTarget

// Debug функции
debug(.openAPS, "msg")   → logger.debug("msg")
warning(.openAPS, "msg") → logger.warning("msg")
```

### 4. Обновите Profile (5 мин)

Добавьте в ваш Profile если отсутствуют:

```swift
let sens: Double                    // ISF
let max_daily_basal: Double         
let autosens_min: Double = 0.7      
let autosens_max: Double = 1.3      
let min_5m_carbimpact: Double = 3.0 
let carb_ratio: Double              
```

### 5. Скомпилируйте (5 мин)

```bash
xcodebuild -scheme YourScheme clean build
```

Исправьте ошибки компиляции (обычно пропущенные поля или типы).

### 6. Первый вызов (3 мин)

```swift
// IOB
let result = OpenAPSAlgorithms.calculateIOB(inputs: iobInputs)

// MEAL
let result = OpenAPSAlgorithms.calculateMeal(inputs: mealInputs)

// AUTOSENS
let result = OpenAPSAlgorithms.calculateAutosens(inputs: autosensInputs)
```

---

## ⚠️ НЕ ЗАБУДЬТЕ!

1. ❌ **НЕ копируйте SwiftTypes.swift** - только для standalone!
2. ✅ **Оставьте JavaScript** - для сравнения и отката
3. ✅ **Тестируйте 1-2 недели** - перед удалением JS
4. ✅ **Сравнивайте результаты** - Swift vs JavaScript

---

## 📚 ДАЛЬШЕ

- Полная инструкция: **INTEGRATION_GUIDE.md**
- Описание файлов: **README.md**
- Детали алгоритмов: Комментарии в коде

**УСПЕХОВ!** 🎊
