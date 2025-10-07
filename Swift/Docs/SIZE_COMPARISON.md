# 📊 СРАВНЕНИЕ РАЗМЕРОВ: JS vs SWIFT

## WEBPACK BUNDLING (JS)

### autotuneCore.js (dist/) - после webpack:
```
Включает ВСЕ зависимости в ОДИН файл:
- lib/autotune/index.js (552 строки)
- lib/percentile.js
- lib/iob/index.js (весь IOB модуль)
- lib/iob/history.js
- lib/profile/index.js
- lib/profile/basal.js
- lib/profile/isf.js
+ все их зависимости рекурсивно
= ~1MB минифицированного кода
```

### autotunePrep.js (dist/) - после webpack:
```
Включает:
- lib/autotune-prep/index.js (176 строк)
- lib/autotune-prep/categorize.js (456 строк)
- lib/autotune-prep/dosed.js
- lib/meal/history.js
- lib/iob/index.js (ОПЯТЬ!)
- lib/profile/ (ОПЯТЬ!)
+ все зависимости
= ~1MB минифицированного кода
```

**ИТОГО JS (после webpack)**: ~2MB
**Причина**: Дублирование зависимостей в каждом bundle!

---

## SWIFT МОДУЛЬНАЯ АРХИТЕКТУРА

### SwiftAutotuneCoreAlgorithms.swift:
```swift
// 478 строк - ТОЛЬКО логика autotune-core
// Использует СУЩЕСТВУЮЩИЕ функции:
import Foundation
extension SwiftOpenAPSAlgorithms {
    // вызывает calculateIOB() - уже есть!
    // вызывает percentile() - локально 6 строк
}
```

### SwiftAutotunePrepAlgorithms.swift:
```swift
// 722 строки - ТОЛЬКО логика autotune-prep
// Использует СУЩЕСТВУЮЩИЕ функции:
extension SwiftOpenAPSAlgorithms {
    // вызывает calculateIOB() - уже есть!
    // вызывает getCurrentSensitivity() - локально 21 строка
    // вызывает getCurrentBasalRate() - локально 20 строк
}
```

### SwiftAutotuneShared.swift:
```swift
// 169 строк - структуры данных
struct AutotuneInputs { ... }
struct AutotuneResult { ... }
```

**ИТОГО Swift**: 1369 строк = ~50KB
**Причина**: НЕТ дублирования! Зависимости в отдельных файлах!

---

## ✅ ВСЕ ФУНКЦИИ НА МЕСТЕ!

### JavaScript (webpack bundle):
```
autotuneCore.js содержит:
- tuneAllTheThings() ✅
- + calculateIOB() (из lib/iob)
- + basalLookup() (из lib/profile)
- + ISF lookup (из lib/profile)
- + percentile() (из lib/percentile)
- + ВСЕ их зависимости
```

### Swift (модули):
```
SwiftAutotuneCoreAlgorithms.swift:
- autotuneCore() ✅

SwiftIOBAlgorithms.swift (уже есть):
- calculateIOB() ✅

SwiftProfileAlgorithms.swift (уже есть):
- basalLookup() ✅
- ISF lookup ✅

SwiftAutotuneCoreAlgorithms.swift:
- percentile() ✅ (локально)
```

---

## 🎯 ВЫВОД

### JavaScript:
- ✅ Все функции в ОДНОМ файле
- ❌ Много дублирования
- ❌ Большой размер (~1-2MB на файл)
- ✅ Готов к standalone использованию

### Swift:
- ✅ Все функции есть, но распределены по модулям
- ✅ НЕТ дублирования
- ✅ Маленький размер (~50KB все файлы)
- ✅ Оптимальная архитектура

**НИ ОДНА ФУНКЦИЯ НЕ ПОТЕРЯНА!**
Просто Swift использует imports вместо bundling!
