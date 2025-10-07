# ✅ ШАГ 2.2: Использование enableSMB в алгоритме

**Дата**: 2025-10-07 09:48  
**Статус**: ✅ Завершено

---

## 🎯 Что сделано

### 1. ✅ Добавлен вызов enableSMB() (строка 451-458 из оригинала)

**Файл**: `Swift/SwiftDetermineBasalAlgorithms.swift:747-755`

**Оригинал**: `lib/determine-basal/determine-basal.js:451-458`

```swift
// ТОЧНЫЙ вызов enable_smb как в оригинале (строка 451-458)
var enableSMB = enableSMB(
    profile: profile,
    microBolusAllowed: inputs.microBolusAllowed,
    mealData: meal,
    bg: glucose.glucose,
    targetBG: targetBG,
    highBG: profile.enableSMBHighBGTarget
)
```

### 2. ✅ Добавлен enableUAM (строка 460-461 из оригинала)

```swift
// enable UAM (if enabled in preferences) (строка 460-461)
let enableUAM = profile.enableUAM ?? false
```

### 3. ✅ Добавлен threshold (строка 329 из оригинала)

**Файл**: `Swift/SwiftDetermineBasalAlgorithms.swift:353-355`

**Оригинал**: `lib/determine-basal/determine-basal.js:329`

```swift
// ТОЧНОЕ определение threshold как в оригинале (строка 329)
// min_bg of 90 -> threshold of 65, 100 -> 70 110 -> 75, and 130 -> 85
let threshold = minBG - 0.5 * (minBG - 40)
```

### 4. ✅ Добавлена логика отключения SMB для sudden rises (строка 867-880)

**Файл**: `Swift/SwiftDetermineBasalAlgorithms.swift:784-797`

**Оригинал**: `lib/determine-basal/determine-basal.js:867-880`

```swift
// Disable SMB for sudden rises (строка 867-880)
// Added maxDelta_bg_threshold as a hidden preference and included a cap at 0.3 as a safety limit
let maxDeltaBGThreshold: Double
if let profileMaxDelta = profile.maxDeltaBGThreshold {
    maxDeltaBGThreshold = min(profileMaxDelta, 0.3)
} else {
    maxDeltaBGThreshold = 0.2
}

if maxDelta > maxDeltaBGThreshold * glucose.glucose {
    debug(.openAPS, "maxDelta \(convertBG(maxDelta, profile: profile)) > \(100 * maxDeltaBGThreshold)% of BG \(convertBG(glucose.glucose, profile: profile)) - disabling SMB")
    enableSMB = false
}
```

### 5. ✅ Добавлены недостающие поля в ProfileResult

**Файл**: `Swift/SwiftProfileAlgorithms.swift`

**Новые поля**:
```swift
let enableSMBHighBGTarget: Double?     // enableSMB_high_bg_target (строка 240)
let enableUAM: Bool?                   // enableUAM (строка 461)
let maxDeltaBGThreshold: Double?       // maxDelta_bg_threshold (строка 870-875)
```

---

## 📊 Соответствие оригиналу

| Строка JS | Строка Swift | Описание | Статус |
|-----------|-------------|----------|--------|
| 329 | 353-355 | threshold calculation | ✅ |
| 451-458 | 747-755 | enableSMB call | ✅ |
| 460-461 | 757-758 | enableUAM | ✅ |
| 870-875 | 786-791 | maxDelta_bg_threshold logic | ✅ |
| 876-880 | 793-797 | maxDelta check | ✅ |

---

## ✅ Оригинальный функционал сохранен

- ✅ threshold вычисляется точно по формуле из JS
- ✅ enableSMB вызывается с теми же параметрами
- ✅ enableUAM берется из preferences (как в JS)
- ✅ maxDeltaBGThreshold имеет default 0.2 и cap 0.3 (точно как в JS)
- ✅ Проверка maxDelta идентична оригиналу
- ✅ Сообщения debug идентичны оригиналу
- ✅ НЕТ изменений или "улучшений"

---

## ⏳ TODO (для будущей портации)

### Проверка minGuardBG < threshold (строка 862-866)

**Не реализовано**, потому что требует полной портации prediction arrays:

```javascript
// JS (строка 862-866):
if (enableSMB && minGuardBG < threshold) {
    console.error("minGuardBG",convert_bg(minGuardBG, profile),"projected below", convert_bg(threshold, profile) ,"- disabling SMB");
    enableSMB = false;
}
```

**Причина**: `minGuardBG` вычисляется внутри prediction arrays (строка 617-621).

**Когда добавить**: При полной портации prediction arrays (Этап 2.2 продолжение).

---

## 🎯 Результат

**enableSMB теперь используется в алгоритме!**

- ✅ Вызывается в нужном месте (после deviation, перед prediction arrays)
- ✅ Отключается при sudden rises (maxDelta check)
- ✅ Готово для использования в SMB calculation logic

---

## 📝 Следующие шаги

### Этап 2.3: SMB Calculation Logic

Теперь нужно использовать `enableSMB` для расчета микроболюса.

**Где в оригинале**: `determine-basal.js:659-860` (SMB calculation)

**Что нужно**:
1. Проверить `if (enableSMB)` и рассчитать microbolus
2. Добавить все safety checks для SMB
3. Ограничить SMB по maxSMBBasalMinutes и maxUAMSMBBasalMinutes

**Время**: 2-3 часа

---

**Автор**: AI Assistant  
**Дата**: 2025-10-07  
**Время**: ~20 минут
