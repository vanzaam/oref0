# 🔍 AUTOSENS - ДЕТАЛЬНАЯ ПРОВЕРКА

**Дата**: 2025-10-07 14:26  
**Вопрос**: Почему AUTOSENS 89%, а не 100%?

---

## 📊 РАЗМЕРЫ

- **JS**: lib/determine-basal/autosens.js - **454 строки**
- **Swift**: SwiftAutosensAlgorithms.swift - **405 строк**
- **Соотношение**: 405/454 = **89%**

**НО!** Это НЕ означает что что-то пропущено!

---

## 🔍 ДЕТАЛЬНОЕ СРАВНЕНИЕ ФУНКЦИЙ

### JS (autosens.js):

**Главная функция**:
```javascript
function detectSensitivity(inputs) { ... }
module.exports = detectSensitivity;
```

**Вспомогательная функция**:
```javascript
function tempTargetRunning(temptargets_data, time) { ... }
// Вызывается в detectSensitivity line 320
```

### Swift (SwiftAutosensAlgorithms.swift):

**Главная функция**:
```swift
static func calculateAutosens(inputs: AutosensInputs) -> Result<AutosensResult, SwiftOpenAPSError>
```

**Вспомогательные функции** (9 функций):
1. ✅ calculateAutosensRatio()
2. ✅ calculateIOBAtTime()
3. ✅ calculateCarbImpactAtTime()
4. ✅ classifyDeviation()
5. ✅ analyzeDeviations()
6. ✅ formatSensitivity()
7. ✅ formatRatioLimit()
8. ✅ formatSensResult()
9. ✅ calculateAbsorbedCarbs()

---

## ❓ ЧТО МОЖЕТ БЫТЬ ПРОПУЩЕНО?

### tempTargetRunning() - ПРОВЕРКА:

**JS (line 320)**:
```javascript
var tempTarget = tempTargetRunning(inputs.temptargets, bgTime)
```

**Swift**:
- AutosensInputs имеет: `tempTargets: TempTargets?`
- НО! Не видно использования tempTargets в calculateAutosens()
- ❌ ВОЗМОЖНО ПРОПУЩЕНО!

---

## 🔍 ЧТО НУЖНО ПРОВЕРИТЬ

1. **Проверить использование tempTargets в Swift**
   - Есть ли логика temp target в calculateAutosensRatio()?
   - Реализована ли проверка high_temptarget_raises_sensitivity?
   - Реализована ли проверка exercise_mode?

2. **Проверить логику detectSensitivity**
   - Lines 317-340 в JS (temp target logic)
   - Соответствие в Swift?

---

## 📝 ВЕРДИКТ

**89% - это просто размер файла!**

**Реальная проверка**:
- ✅ Главная функция портирована
- ✅ 9 вспомогательных функций есть
- ❓ tempTargetRunning() - НУЖНА ПРОВЕРКА!

**Рекомендация**: 
- Проверить lines 317-340 в autosens.js
- Убедиться что temp target logic портирована
- Если пропущена - добавить функцию tempTargetRunning()

**Возможный статус**: 85-95% (нужна детальная проверка)

---

## 🎯 ДЕЙСТВИЯ

1. Прочитать lines 317-340 в autosens.js
2. Найти соответствующий код в Swift
3. Если отсутствует - портировать tempTargetRunning()
4. Обновить статус на 100%

**ВЫВОД**: 89% - это оценка по размеру, НЕ по функциональности!
