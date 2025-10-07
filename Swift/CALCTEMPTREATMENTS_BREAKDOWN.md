# 📋 calcTempTreatments() - ДЕТАЛЬНАЯ РАЗБИВКА

**Источник**: lib/iob/history.js lines 161-572 (411 строк!)  
**Оценка Swift**: ~250-300 строк

---

## СТРУКТУРА ФУНКЦИИ

### БЛОК 1: Initialization (lines 161-200, ~40 строк)
```javascript
// Variables init
var pumpHistory, tempHistory, tempBoluses
var pumpSuspends, pumpResumes
var suspendedPrior, currentlySuspended

// Concat history + history24
// Gather PumpSuspend and PumpResume
```
**Оценка Swift**: ~50 строк

### БЛОК 2: Suspend/Resume matching (lines 201-260, ~60 строк)
```javascript
// Sort suspends and resumes
// Match resumes with suspends
// Calculate durations
// Error checking for mismatches
```
**Оценка Swift**: ~70 строк

### БЛОК 3: Process temp basals (lines 260-400, ~140 строк)
**НЕ ПРОЧИТАНО ЕЩЕ!**
Нужно читать lines 260-400

### БЛОК 4: Process boluses (lines 400-500, ~100 строк)  
**НЕ ПРОЧИТАНО ЕЩЕ!**
Нужно читать lines 400-500

### БЛОК 5: Finalization (lines 500-572, ~72 строки)
**НЕ ПРОЧИТАНО ЕЩЕ!**
Нужно читать lines 500-572

---

## ПЛАН ПОРТАЦИИ

**ШАГ 1**: БЛОК 1+2 (~120 строк Swift) - СЕЙЧАС!
**ШАГ 2**: БЛОК 3 (~100 строк Swift)
**ШАГ 3**: БЛОК 4 (~80 строк Swift)
**ШАГ 4**: БЛОК 5 (~50 строк Swift)

**ИТОГО**: ~350 строк Swift
**ВРЕМЯ**: ~2 часа

---

## ДЕЙСТВИЕ СЕЙЧАС

Портирую БЛОКИ 1 и 2 (initialization + suspend matching)
~120 строк Swift
