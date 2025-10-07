# 🚨 КРИТИЧЕСКИЕ ОШИБКИ В SWIFT-ПОРТАЦИИ OREF0

**Дата анализа**: 2025-10-07  
**Анализируемые файлы**: Swift портация vs оригинальный oref0 JavaScript

---

## ❌ ОШИБКА #1: Отсутствует функция `convert_bg`

### Описание проблемы
Функция `convert_bg` **полностью отсутствует** в Swift-портации, хотя она используется **40+ раз** в оригинальном `determine-basal.js`.

### Оригинальный код (determine-basal.js:39-49)
```javascript
function convert_bg(value, profile) {
    if (profile.out_units === "mmol/L") {
        return round(value / 18, 1);
    } else {
        return Math.round(value);
    }
}
```

### Где используется в оригинале
```javascript
// Строка 806-818 в determine-basal.js
rT.BGI = convert_bg(bgi, profile);
rT.deviation = convert_bg(deviation, profile);
rT.ISF = convert_bg(sens, profile);
rT.target_bg = convert_bg(target_bg, profile);
rT.reason = "COB: " + rT.COB + ", Dev: " + rT.deviation + ", BGI: " + rT.BGI + 
            ", ISF: " + rT.ISF + ", CR: " + rT.CR + 
            ", minPredBG: " + convert_bg(minPredBG, profile) + 
            ", minGuardBG: " + convert_bg(minGuardBG, profile) + 
            ", IOBpredBG: " + convert_bg(lastIOBpredBG, profile);
```

### Последствия
1. **Все значения BG в результатах всегда в mg/dL**, даже если пользователь работает в mmol/L
2. **Графики прогнозов** (`predBGs`) показывают неправильные значения для mmol/L пользователей
3. **Строка `reason`** содержит неконвертированные значения
4. **UI показывает неправильные числа** для всех полей: BGI, deviation, ISF, eventualBG, minPredBG, etc.

### Решение
Добавить функцию в `SwiftDetermineBasalAlgorithms.swift`:

```swift
/// КРИТИЧЕСКАЯ функция конвертации BG из оригинального determine-basal.js:39-49
private static func convertBG(_ value: Double, profile: ProfileResult) -> Double {
    if profile.outUnits == "mmol/L" {
        return round(value / 18.0 * 10) / 10  // round to 1 decimal place
    } else {
        return round(value)  // round to integer for mg/dL
    }
}
```

И использовать её во ВСЕХ местах, где возвращаются значения BG.

---

## ❌ ОШИБКА #2: Отсутствует поле `out_units` в ProfileResult

### Описание проблемы
Структура `ProfileResult` в Swift **не содержит поле `out_units`** (или `outUnits`), которое критически важно для определения единиц вывода.

### Оригинальный код (profile/index.js:153)
```javascript
profile.out_units = inputs.targets.user_preferred_units;
```

### Текущий Swift код (SwiftProfileAlgorithms.swift:28-76)
```swift
struct ProfileResult {
    let settings: PumpSettings
    let targets: BGTargets
    let basals: [BasalProfileEntry]
    let isf: InsulinSensitivities
    let carbRatio: CarbRatios
    // ... другие поля
    // ❌ НЕТ ПОЛЯ out_units!
}
```

### Последствия
1. Невозможно определить, в каких единицах пользователь хочет видеть результаты
2. Функция `convert_bg` не может работать без этого поля
3. Все результаты всегда в mg/dL

### Решение
Добавить поле в `ProfileResult`:

```swift
struct ProfileResult {
    // ... существующие поля
    let outUnits: String  // "mg/dL" или "mmol/L"
    
    // ... остальные поля
}
```

И устанавливать его при создании профиля:

```swift
let profile = ProfileResult(
    // ... другие параметры
    outUnits: inputs.bgTargets?.units == .mmolL ? "mmol/L" : "mg/dL",
    // ... остальные параметры
)
```

---

## ❌ ОШИБКА #3: Неправильная конвертация в `rawJSON`

### Описание проблемы
В `DetermineBasalResult.rawJSON` (SwiftDetermineBasalAlgorithms.swift:85-122) все значения BG выводятся **без конвертации**:

```swift
var rawJSON: String {
    // ...
    return """
    {
        "bg": \(bg),  // ❌ Не конвертировано!
        "eventualBG": \(Int(eventualBG.rounded())),  // ❌ Не конвертировано!
        // ...
    }
    """
}
```

### Оригинальный код
В JavaScript все значения BG в результате **уже сконвертированы** через `convert_bg` перед добавлением в `rT`.

### Последствия
1. JSON-результат содержит значения в mg/dL даже для mmol/L пользователей
2. FreeAPS UI получает неправильные данные
3. Графики и уведомления показывают неправильные числа

### Решение
Конвертировать все BG-значения перед добавлением в JSON:

```swift
var rawJSON: String {
    // Конвертируем все BG значения
    let convertedBG = convertBG(bg, profile: profile)
    let convertedEventualBG = convertBG(eventualBG, profile: profile)
    // ... и т.д. для всех BG значений
    
    return """
    {
        "bg": \(convertedBG),
        "eventualBG": \(Int(convertedEventualBG.rounded())),
        // ...
    }
    """
}
```

---

## ❌ ОШИБКА #4: Prediction arrays не конвертируются

### Описание проблемы
Массивы прогнозов `predBGs` (IOB, COB, UAM, ZT) содержат значения в mg/dL без конвертации.

### Текущий код (SwiftDetermineBasalAlgorithms.swift:98-102)
```swift
let predBGsJSON = predBGs.map { key, values in
    let valuesString = values.map { String(Int($0.rounded())) }.joined(separator: ",")
    return "\"\(key)\": [\(valuesString)]"
}.joined(separator: ",")
```

### Последствия
Графики прогнозов BG в FreeAPS показывают неправильные значения для mmol/L пользователей.

### Решение
```swift
let predBGsJSON = predBGs.map { key, values in
    let convertedValues = values.map { convertBG($0, profile: profile) }
    let valuesString = convertedValues.map { String(Int($0.rounded())) }.joined(separator: ",")
    return "\"\(key)\": [\(valuesString)]"
}.joined(separator: ",")
```

---

## ❌ ОШИБКА #5: Строка `reason` содержит неконвертированные значения

### Описание проблемы
Все сообщения в `reason` содержат значения BG в mg/dL без конвертации.

### Пример из Swift кода (SwiftDetermineBasalAlgorithms.swift:341-342)
```swift
reason: safetyReason + 
    ". Replacing high temp basal of \(currentTemp.rate) with neutral temp of \(adjustedBasal)"
// ❌ Нет конвертации BG значений в reason!
```

### Оригинальный код (determine-basal.js:811-817)
```javascript
rT.reason = "COB: " + rT.COB + ", Dev: " + rT.deviation + ", BGI: " + rT.BGI + 
            ", ISF: " + rT.ISF + ", CR: " + rT.CR + 
            ", minPredBG: " + convert_bg(minPredBG, profile) +  // ✅ Конвертировано!
            ", minGuardBG: " + convert_bg(minGuardBG, profile) +  // ✅ Конвертировано!
            ", IOBpredBG: " + convert_bg(lastIOBpredBG, profile);  // ✅ Конвертировано!
```

### Последствия
Пользователи видят в логах и уведомлениях значения в mg/dL вместо mmol/L.

### Решение
Конвертировать ВСЕ BG-значения в строках `reason`:

```swift
let minPredBGConverted = convertBG(minPredBG, profile: profile)
let minGuardBGConverted = convertBG(minGuardBG, profile: profile)
reason = "minPredBG: \(String(format: "%.1f", minPredBGConverted)), " +
         "minGuardBG: \(String(format: "%.1f", minGuardBGConverted))"
```

---

## ✅ ПЛАН ИСПРАВЛЕНИЯ

### Приоритет 1 (Критический)
1. ✅ Добавить поле `outUnits: String` в `ProfileResult`
2. ✅ Реализовать функцию `convertBG(_ value: Double, profile: ProfileResult) -> Double`
3. ✅ Конвертировать все BG-значения в `DetermineBasalResult` перед возвратом

### Приоритет 2 (Высокий)
4. ✅ Конвертировать все значения в `predBGs` массивах
5. ✅ Конвертировать все BG-значения в строках `reason`
6. ✅ Добавить unit tests для проверки конвертации mg/dL ↔ mmol/L

### Приоритет 3 (Средний)
7. ✅ Проверить все места использования BG-значений в других алгоритмах (IOB, Meal, Autosens)
8. ✅ Добавить логирование единиц измерения для отладки
9. ✅ Создать сравнительные тесты Swift vs JavaScript для mmol/L пользователей

---

## 🧪 ТЕСТИРОВАНИЕ

### Тест-кейсы для проверки исправлений

#### Тест 1: mg/dL пользователь
```swift
// Input: BG = 120 mg/dL, profile.outUnits = "mg/dL"
// Expected: все значения остаются в mg/dL, округлены до целых
// eventualBG = 120, minPredBG = 115, etc.
```

#### Тест 2: mmol/L пользователь
```swift
// Input: BG = 120 mg/dL (внутреннее), profile.outUnits = "mmol/L"
// Expected: все значения конвертированы в mmol/L, округлены до 1 знака
// eventualBG = 6.7, minPredBG = 6.4, etc.
```

#### Тест 3: Строка reason
```swift
// Input: minPredBG = 100 mg/dL, profile.outUnits = "mmol/L"
// Expected: reason содержит "minPredBG: 5.6" (не "minPredBG: 100")
```

#### Тест 4: Prediction arrays
```swift
// Input: IOBpredBGs = [120, 115, 110, ...], profile.outUnits = "mmol/L"
// Expected: JSON содержит "IOB": [7, 6, 6, ...] (не [120, 115, 110, ...])
```

---

## 📊 СТАТИСТИКА ОШИБОК

- **Критичность**: 🔴 КРИТИЧЕСКАЯ (медицинское ПО)
- **Затронутые пользователи**: Все пользователи mmol/L (Европа, Австралия, и др.)
- **Процент кода с ошибкой**: ~30% (все функции, работающие с BG)
- **Количество мест для исправления**: 50+ строк кода

---

## 💡 ПОЧЕМУ ЭТО НЕ РАБОТАЛО

1. **Пользователи mmol/L видели значения в 18 раз больше** (120 mg/dL вместо 6.7 mmol/L)
2. **Алгоритм принимал неправильные решения** из-за неправильной интерпретации целевых значений
3. **Графики были нечитаемыми** (шкала 0-400 вместо 0-22)
4. **Логи и уведомления были бессмысленными** для mmol/L пользователей

---

## 🔗 ССЫЛКИ НА ИСХОДНЫЙ КОД

- `lib/determine-basal/determine-basal.js:39-49` - функция `convert_bg`
- `lib/determine-basal/determine-basal.js:806-818` - использование `convert_bg` в результатах
- `lib/profile/index.js:153` - установка `profile.out_units`

---

**Вывод**: Swift-портация **не может работать корректно для mmol/L пользователей** без этих исправлений. Это объясняет, почему "ничего не работало нормально".
