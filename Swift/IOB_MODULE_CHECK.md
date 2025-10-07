# 🔴 КРИТИЧЕСКАЯ ПРОВЕРКА: IOB МОДУЛЬ

## 📋 СРАВНЕНИЕ: lib/iob/ vs SwiftOpenAPSAlgorithms.swift

**Дата**: 2025-10-07  
**Приоритет**: 🔴 КРИТИЧНО  
**Статус**: ⚠️ ТРЕБУЕТ ВНИМАНИЯ

---

## 🔍 АРХИТЕКТУРА JS vs SWIFT

### JavaScript (lib/iob/):
```javascript
lib/iob/index.js        - главная функция generate()
lib/iob/total.js        - функция iobTotal() 
lib/iob/calculate.js    - расчет IOB для одного treatment
lib/iob/history.js      - подготовка treatments
```

### Swift:
```swift
SwiftOpenAPSAlgorithms.swift - функция calculateIOB()
  - calculateBolusIOB()
  - calculateBasalIOB()
  - calculateBilinearIOB()
  - calculateExponentialIOB()
```

---

## ⚠️ КРИТИЧЕСКИЕ РАЗЛИЧИЯ ОБНАРУЖЕНЫ!

### 1. Архитектура обработки

**JS (lib/iob/total.js lines 67-92)**:
```javascript
treatments.forEach(function(treatment) {
    if( treatment.date <= now ) {
        var dia_ago = now - dia*60*60*1000;
        if( treatment.date > dia_ago ) {
            // Вызов iobCalc для КАЖДОГО treatment
            var tIOB = iobCalc(treatment, time, curve, dia, peak, profile_data);
            if (tIOB && tIOB.iobContrib) { iob += tIOB.iobContrib; }
            if (tIOB && tIOB.activityContrib) { activity += tIOB.activityContrib; }
            
            // Разделение на basal и bolus
            if (treatment.insulin < 0.1) {
                basaliob += tIOB.iobContrib;
            } else {
                bolusiob += tIOB.iobContrib;
            }
        }
    }
});
```

**Swift (SwiftOpenAPSAlgorithms.swift lines 74-128)**:
```swift
for event in recentEvents {
    switch event.type {
    case .bolus:
        let iobContrib = calculateBolusIOB(...)
        bolusIOB += iobContrib.iob
        
    case .tempBasal:
        let basalContrib = calculateBasalIOB(...)
        basalIOB += basalContrib.iob
    }
}
```

**ПРОБЛЕМА**: ⚠️ JS обрабатывает ВСЕ treatments единообразно через iobCalc(), Swift разделяет логику!

---

### 2. Фильтрация по времени

**JS (lib/iob/total.js lines 69-70)**:
```javascript
var dia_ago = now - dia*60*60*1000;
if( treatment.date > dia_ago ) {
    // обработка
}
```

**Swift (SwiftOpenAPSAlgorithms.swift lines 67-71)**:
```swift
let sixHoursAgo = currentTime.addingTimeInterval(-6 * 3600)
let recentEvents = inputs.pumpHistory.filter { event in
    return eventDate >= sixHoursAgo && eventDate <= currentTime
}
```

**ПРОБЛЕМА**: ⚠️ JS использует DIA для фильтрации, Swift использует фиксированные 6 часов!

---

### 3. Минимальный DIA

**JS (lib/iob/total.js lines 23-27)**:
```javascript
// force minimum DIA of 3h
if (dia < 3) {
    dia = 3;
}
```

**Swift**: ❌ НЕ НАЙДЕНО!

**ПРОБЛЕМА**: 🔴 КРИТИЧНО! Swift НЕ проверяет минимальный DIA!

---

### 4. Curve defaults

**JS (lib/iob/total.js lines 29-64)**:
```javascript
var curveDefaults = {
    'bilinear': {
        requireLongDia: false,
        peak: 75
    },
    'rapid-acting': {
        requireLongDia: true,
        peak: 75,
        tdMin: 300
    },
    'ultra-rapid': {
        requireLongDia: true,
        peak: 55,
        tdMin: 300
    },
};

// Force minimum of 5 hour DIA when default requires a Long DIA.
if (defaults.requireLongDia && dia < 5) {
    dia = 5;
}
```

**Swift (SwiftOpenAPSAlgorithms.swift line 164)**:
```swift
let curve = profile.insulinActionCurve ?? "rapid-acting"
```

**ПРОБЛЕМА**: ⚠️ Swift НЕ проверяет requireLongDia и минимум 5 часов для exponential curves!

---

### 5. Возвращаемые значения

**JS (lib/iob/total.js lines 94-102)**:
```javascript
return {
    iob: Math.round(iob * 1000) / 1000,
    activity: Math.round(activity * 10000) / 10000,
    basaliob: Math.round(basaliob * 1000) / 1000,
    bolusiob: Math.round(bolusiob * 1000) / 1000,
    netbasalinsulin: Math.round(netbasalinsulin * 1000) / 1000,
    bolusinsulin: Math.round(bolusinsulin * 1000) / 1000,
    time: time
};
```

**Swift (SwiftOpenAPSAlgorithms.swift lines 132-142)**:
```swift
return IOBResult(
    iob: totalIOB,
    activity: totalActivity,
    basaliob: basalIOB,
    netBasalInsulin: netBasalInsulin,
    bolusiob: bolusIOB,
    hightempInsulin: hightempInsulin,  // ← ДОПОЛНИТЕЛЬНОЕ поле!
    lastBolusTime: lastBolusTime,
    lastTemp: lastTemp,
    time: currentTime
)
```

**ПРОБЛЕМА**: ⚠️ Swift НЕ округляет значения! JS: `Math.round(iob * 1000) / 1000`

---

## 🚨 КРИТИЧЕСКИЕ ПРОБЛЕМЫ

### 1. 🔴 Нет проверки минимального DIA (3 часа)
**JS**: `if (dia < 3) { dia = 3; }`  
**Swift**: ❌ ОТСУТСТВУЕТ

### 2. 🔴 Нет проверки минимального DIA для exponential curves (5 часов)
**JS**: `if (defaults.requireLongDia && dia < 5) { dia = 5; }`  
**Swift**: ❌ ОТСУТСТВУЕТ

### 3. ⚠️ Фильтрация по фиксированным 6 часам вместо DIA
**JS**: фильтрует по `dia * 60 * 60 * 1000`  
**Swift**: фильтрует по фиксированным 6 часам

### 4. ⚠️ Нет округления результатов
**JS**: округляет все значения  
**Swift**: возвращает без округления

### 5. ⚠️ Разная архитектура обработки treatments
**JS**: единообразная обработка через iobCalc()  
**Swift**: разделение на bolus и basal логику

---

## 📊 ОЦЕНКА СООТВЕТСТВИЯ

| Критерий | JS | Swift | Соответствие |
|----------|-----|-------|--------------|
| Минимальный DIA 3h | ✅ Есть | ❌ Нет | 🔴 НЕТ |
| Минимальный DIA 5h для exponential | ✅ Есть | ❌ Нет | 🔴 НЕТ |
| Фильтрация по DIA | ✅ Есть | ⚠️ По 6h | 🟡 ЧАСТИЧНО |
| Округление результатов | ✅ Есть | ❌ Нет | 🔴 НЕТ |
| Curve defaults | ✅ Есть | ⚠️ Частично | 🟡 ЧАСТИЧНО |
| IOB calculation | ✅ Есть | ✅ Есть | ✅ ДА |
| lastBolusTime | ✅ Есть | ✅ Есть | ✅ ДА |
| lastTemp | ✅ Есть | ✅ Есть | ✅ ДА |

**ИТОГО**: 3/8 (37.5%) - НЕДОСТАТОЧНО!

---

## 🎯 РЕКОМЕНДАЦИИ

### Критично исправить:
1. 🔴 Добавить проверку минимального DIA (3 часа)
2. 🔴 Добавить проверку минимального DIA для exponential curves (5 часов)
3. 🔴 Добавить округление результатов

### Важно проверить:
4. ⚠️ Изменить фильтрацию с фиксированных 6 часов на DIA-based
5. ⚠️ Проверить соответствие iobCalc() логики

---

## 📝 ВЕРДИКТ

**Статус**: 🔴 **ТРЕБУЕТ ИСПРАВЛЕНИЙ**

**Swift реализация IOB**:
- ✅ Основная логика есть
- ❌ Отсутствуют критические проверки DIA
- ❌ Нет округления результатов
- ⚠️ Архитектура отличается от оригинала

**НЕ ГОТОВО для production!** Требуются исправления!
