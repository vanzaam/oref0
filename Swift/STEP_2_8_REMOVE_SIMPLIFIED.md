# ✅ ШАГ 2.8: Удалены "Simplified" - найдены критические недоделки!

**Дата**: 2025-10-07 10:22  
**Статус**: ⚠️ ЧАСТИЧНО - найдены упрощения, добавлен TODO

---

## 🔴 КРИТИЧЕСКИЕ НАХОДКИ!

### ❌ Что было найдено:

**1. "Simplified" комментарии в коде**:
```swift
tick: "+0", // Simplified
```

**2. "Simple decision logic (will be expanded later)"**:
```swift
// Simple decision logic (will be expanded later)
if eventualBG >= 100, eventualBG <= 180 {
    reason += "in range: setting current basal"
    // ...
}
```

**3. Функция `createResultWithPredictions` - ЗАГЛУШКА!**
Вся логика там упрощена, не используются параметры!

**4. Функция `makeBasalDecisionWithPredictions` - почти ПУСТАЯ!**
Все параметры помечены `_` (игнорируются)!

---

## 🔴 ЧТО ДОЛЖНО БЫТЬ (по JS:820-1193):

После формирования reason (строка 818) в JS идет **374 СТРОКИ КОДА**:

### 1. carbsReqBG calculation (строки 820-826)
```javascript
var carbsReqBG = naive_eventualBG;
if ( carbsReqBG < 40 ) {
    carbsReqBG = Math.min( minGuardBG, carbsReqBG );
}
var bgUndershoot = threshold - carbsReqBG;
```

### 2. minutesAboveMinBG и minutesAboveThreshold (строки 827-860)
```javascript
var minutesAboveMinBG = 240;
var minutesAboveThreshold = 240;
if (meal_data.mealCOB > 0 && ( ci > 0 || remainingCIpeak > 0 )) {
    for (i=0; i<COBpredBGs.length; i++) {
        if ( COBpredBGs[i] < min_bg ) {
            minutesAboveMinBG = 5*i;
            break;
        }
    }
    // ... и для threshold
} else {
    // ... то же для IOBpredBGs
}
```

### 3. carbsReq calculation (строки 882-903)
```javascript
var zeroTempDuration = minutesAboveThreshold;
var zeroTempEffect = profile.current_basal*sens*zeroTempDuration/60;
var COBforCarbsReq = Math.max(0, meal_data.mealCOB - 0.25*meal_data.carbs);
var carbsReq = (bgUndershoot - zeroTempEffect) / csf - COBforCarbsReq;
if ( carbsReq >= profile.carbsReqThreshold && minutesAboveThreshold <= 45 ) {
    rT.carbsReq = carbsReq;
    rT.reason += carbsReq + " add'l carbs req w/in " + minutesAboveThreshold + "m; ";
}
```

### 4. Low glucose suspend (строки 907-927)
```javascript
// don't low glucose suspend if IOB is already super negative
if (bg < threshold && iob_data.iob < -profile.current_basal*20/60 && minDelta > 0 && minDelta > expectedDelta) {
    rT.reason += "IOB "+iob_data.iob+" < " + round(-profile.current_basal*20/60,2);
    rT.reason += " and minDelta " + convert_bg(minDelta, profile) + " > " + "expectedDelta " + convert_bg(expectedDelta, profile) + "; ";
// predictive low glucose suspend mode
} else if ( bg < threshold || minGuardBG < threshold ) {
    rT.reason += "minGuardBG: " + convert_bg(minGuardBG, profile) + "<" + convert_bg(threshold, profile);
    bgUndershoot = target_bg - minGuardBG;
    var worstCaseInsulinReq = bgUndershoot / sens;
    var durationReq = round(60*worstCaseInsulinReq / profile.current_basal);
    durationReq = round(durationReq/30)*30;
    durationReq = Math.min(120,Math.max(30,durationReq));
    return tempBasalFunctions.setTempBasal(0, durationReq, profile, rT, currenttemp);
}
```

### 5. Skip neutral temps (строки 923-928)
```javascript
if ( profile.skip_neutral_temps && rT.deliverAt.getMinutes() >= 55 ) {
    rT.reason += "; Canceling temp at " + rT.deliverAt.getMinutes() + "m past the hour. ";
    return tempBasalFunctions.setTempBasal(0, 0, profile, rT, currenttemp);
}
```

### 6. Core dosing logic - ОГРОМНАЯ часть (строки 930-1187)
- eventualBG < min_bg: low temp logic
- eventualBG >= max_bg: high temp logic  
- In range logic
- Adjustment logic
- Rate calculations
- Duration calculations
- Safety checks

**ВСЁ ЭТО НЕ ПОРТИРОВАНО!**

---

## ✅ Что исправлено СЕЙЧАС:

### 1. Убрана функция `makeBasalDecisionWithPredictions`
Она была пустой заглушкой.

### 2. reason формируется в правильном месте
Точно после SMB logic, как в JS строка 804-818.

### 3. Добавлен TODO с ясным указанием
```swift
// TODO: Портировать логику строк 820-1193 из JS
```

### 4. Временный результат с правильным reason
Возвращается результат с:
- ✅ Правильный reason (COB, Dev, BGI, minPredBG, minGuardBG, etc.)
- ✅ Правильные BGI, deviation, ISF, targetBG
- ✅ Правильные predBGs
- ⚠️ "portation in progress" в reason (явно показывает что недоделано)

---

## 📊 Что НЕ работает без этой логики:

### ❌ carbsReq calculation
Пользователь не получает рекомендации по углеводам при гипо!

### ❌ Low glucose suspend
Алгоритм не останавливает инсулин при угрозе гипо!

### ❌ Skip neutral temps
Лишние beeping/vibration в конце часа!

### ❌ Core dosing logic
Неправильные temp basal решения!

**ЭТО КРИТИЧНО ДЛЯ БЕЗОПАСНОСТИ!**

---

## 🎯 Что нужно портировать (приоритет):

| Логика | JS строки | Важность | Оценка |
|--------|-----------|----------|--------|
| Low glucose suspend | 907-927 | 🔴 КРИТИЧНО | 30 мин |
| carbsReq calculation | 820-860, 882-903 | 🔴 КРИТИЧНО | 1 час |
| Core dosing logic | 930-1187 | 🔴 КРИТИЧНО | 3-4 часа |
| Skip neutral temps | 923-928 | 🟡 Средне | 10 мин |

**Общая оценка**: 5-6 часов до полной портации

---

## ✅ Оригинальный функционал - ЧТО УЖЕ РАБОТАЕТ:

- ✅ enableSMB logic
- ✅ SMB calculation
- ✅ Prediction arrays (IOB, COB, UAM, ZT)
- ✅ minGuardBG safety checks  
- ✅ expectedDelta
- ✅ reason formation (COB, Dev, BGI, minPredBG, minGuardBG)
- ✅ All min/max values

---

## ⚠️ ТЕКУЩИЙ СТАТУС

**Портация**: ~70% (было ~95% - переоценка!)

**Работает**:
- ✅ SMB logic полностью
- ✅ Prediction arrays полностью
- ✅ reason формируется правильно

**НЕ работает**:
- ❌ carbsReq
- ❌ Low glucose suspend
- ❌ Core dosing logic (temp basal decisions)

---

## 📝 СЛЕДУЮЩИЕ ШАГИ

### 1. Портировать Low glucose suspend (КРИТИЧНО!)
Строки 907-927 - 20 строк кода
**Время**: 30 минут

### 2. Портировать carbsReq
Строки 820-860, 882-903 - ~60 строк
**Время**: 1 час

### 3. Портировать Core dosing logic
Строки 930-1187 - ~250 строк
**Время**: 3-4 часа

---

**Автор**: AI Assistant  
**Дата**: 2025-10-07  
**Важность**: 🔴 КРИТИЧЕСКАЯ
