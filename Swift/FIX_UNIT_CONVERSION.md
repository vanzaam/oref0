# ✅ ИСПРАВЛЕНИЕ: Конвертация единиц (mg/dL vs mmol/L)

**Дата**: 2025-10-07 09:36  
**Проблема**: Неправильная конвертация bg, eventualBG и predBGs массивов

---

## ❌ Что было неправильно

Я ошибочно конвертировал ВСЁ в mmol/L, включая:
- `bg` - конвертировал (НЕПРАВИЛЬНО!)
- `eventualBG` - конвертировал (НЕПРАВИЛЬНО!)
- `predBGs` массивы - конвертировал (НЕПРАВИЛЬНО!)

---

## ✅ Как должно быть (согласно оригиналу)

### Что НЕ конвертируется (всегда mg/dL):

1. **`bg`** - всегда в mg/dL
   ```javascript
   rT.bg = bg;  // NO convert_bg!
   ```

2. **`eventualBG`** - всегда в mg/dL
   ```javascript
   rT.eventualBG = eventualBG;  // for FreeAPS-X needs to be in mg/dL
   ```
   Комментарий из оригинала (строка 698) прямо говорит: **"needs to be in mg/dL"**!

3. **`predBGs` массивы** - всегда в mg/dL
   ```javascript
   rT.predBGs.IOB = IOBpredBGs;  // NO convert_bg!
   rT.predBGs.COB = COBpredBGs;  // NO convert_bg!
   rT.predBGs.UAM = UAMpredBGs;  // NO convert_bg!
   rT.predBGs.ZT = ZTpredBGs;    // NO convert_bg!
   ```

### Что КОНВЕРТИРУЕТСЯ (для отображения пользователю):

1. **`BGI`** - конвертируется
   ```javascript
   rT.BGI = convert_bg(bgi, profile);  // YES!
   ```

2. **`deviation`** - конвертируется
   ```javascript
   rT.deviation = convert_bg(deviation, profile);  // YES!
   ```

3. **`ISF`** - конвертируется
   ```javascript
   rT.ISF = convert_bg(sens, profile);  // YES!
   ```

4. **`target_bg`** - конвертируется
   ```javascript
   rT.target_bg = convert_bg(target_bg, profile);  // YES!
   ```

5. **Значения в строке `reason`** - конвертируются (для отображения)
   ```javascript
   "minPredBG: " + convert_bg(minPredBG, profile)  // YES!
   ```

---

## 🎯 Почему так?

### 1. Алгоритм работает в mg/dL

Все внутренние вычисления OpenAPS происходят в mg/dL. Это стандарт алгоритма.

### 2. Nightscout работает в mg/dL

Nightscout и другие системы мониторинга ожидают данные в mg/dL. 
`bg`, `eventualBG` и `predBGs` идут напрямую в Nightscout.

### 3. Конвертация только для UI

`convert_bg()` используется только для значений, которые **показываются пользователю**:
- BGI, deviation, ISF, target_bg - это показатели для пользователя
- Строка `reason` - текст для пользователя

### 4. predBGs для графиков

Массивы `predBGs` используются для построения графиков прогноза.
Графики строятся в mg/dL, затем **UI сам конвертирует** их при отображении если нужно.

---

## 🔧 Исправления в коде

### В `rawJSON`:

```swift
// БЫЛО (НЕПРАВИЛЬНО):
"bg": \(convertedBG),
"eventualBG": \(convertedEventualBG),
predBGs: конвертированные массивы

// СТАЛО (ПРАВИЛЬНО):
"bg": \(Int(bg.rounded())),           // ВСЕГДА mg/dL
"eventualBG": \(Int(eventualBG.rounded())),  // ВСЕГДА mg/dL
predBGs: массивы в mg/dL              // ВСЕГДА mg/dL
```

### Поля, которые ПРАВИЛЬНО конвертируются:

```swift
"BGI": \(BGIString),           // ✅ Конвертируется
"deviation": \(deviationString),  // ✅ Конвертируется
"ISF": \(ISFString),           // ✅ Конвертируется
"target_bg": \(targetBGString)    // ✅ Конвертируется
```

---

## 📊 Пример правильного JSON

### Для mg/dL пользователя:
```json
{
  "bg": 120,           // mg/dL
  "eventualBG": 100,   // mg/dL
  "BGI": -2,           // mg/dL (показывается пользователю)
  "deviation": 5,      // mg/dL (показывается пользователю)
  "ISF": 50,           // mg/dL (показывается пользователю)
  "target_bg": 100,    // mg/dL (показывается пользователю)
  "predBGs": {
    "IOB": [120, 115, 110, ...]  // mg/dL
  }
}
```

### Для mmol/L пользователя:
```json
{
  "bg": 120,           // mg/dL (НЕ конвертируется!)
  "eventualBG": 100,   // mg/dL (НЕ конвертируется!)
  "BGI": -0.1,         // mmol/L (конвертировано для пользователя)
  "deviation": 0.3,    // mmol/L (конвертировано для пользователя)
  "ISF": 2.8,          // mmol/L (конвертировано для пользователя)
  "target_bg": 5.6,    // mmol/L (конвертировано для пользователя)
  "predBGs": {
    "IOB": [120, 115, 110, ...]  // mg/dL (НЕ конвертируется!)
  }
}
```

---

## ✅ Что правильно теперь

1. ✅ `bg` всегда в mg/dL (как в оригинале)
2. ✅ `eventualBG` всегда в mg/dL (как в оригинале)
3. ✅ `predBGs` массивы всегда в mg/dL (как в оригинале)
4. ✅ `BGI`, `deviation`, `ISF`, `target_bg` конвертируются (как в оригинале)
5. ✅ Алгоритм работает точно как оригинальный JavaScript
6. ✅ Совместимость с Nightscout сохранена
7. ✅ UI может сам конвертировать данные при отображении

---

## 📝 Ссылки на оригинальный код

1. **bg не конвертируется**: determine-basal.js (нет convert_bg для rT.bg)
2. **eventualBG не конвертируется**: determine-basal.js:698
   ```javascript
   rT.eventualBG = eventualBG;  // for FreeAPS-X needs to be in mg/dL
   ```
3. **predBGs не конвертируются**: determine-basal.js:657,667,677,690
   ```javascript
   rT.predBGs.IOB = IOBpredBGs;  // без convert_bg
   ```
4. **BGI конвертируется**: determine-basal.js:806
   ```javascript
   rT.BGI = convert_bg(bgi, profile);
   ```

---

## 🎯 Вывод

**Оригинальный функционал полностью сохранен**.

Алгоритм работает в mg/dL (как и задумано).
Конвертация происходит только для значений, показываемых пользователю (BGI, deviation, ISF, target_bg).

---

**Автор**: AI Assistant (исправлено после замечания пользователя)  
**Дата**: 2025-10-07
