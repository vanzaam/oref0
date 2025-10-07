# 🎯 AUTOSENS - ПЛАН ПОЛНОЙ ПОРТАЦИИ

**Дата**: 2025-10-07 14:32  
**Цель**: 100% точная портация autosens.js → Swift  
**Источник**: lib/determine-basal/autosens.js (455 строк)  
**Время**: 4-6 часов

---

## 📋 ПОШАГОВЫЙ ПЛАН

### ЭТАП 1: Подготовка структур (30 мин)
- [ ] Обновить AutosensInputs (добавить все поля)
- [ ] Добавить структуры для bucketing
- [ ] Добавить percentile функцию

**Строки JS**: 1-10, 14-23  
**Оценка**: ~50 строк Swift

---

### ЭТАП 2: Bucketing логика (45 мин)
- [ ] Портировать glucose bucketing (lines 72-119)
  * Reverse glucose_data
  * Group by 5-minute intervals
  * Average if < 2 minutes apart

**Строки JS**: 72-119  
**Оценка**: ~60 строк Swift

---

### ЭТАП 3: lastSiteChange + rewind (30 мин)
- [ ] 24h lookback (lines 24-30)
- [ ] rewind_resets_autosens (lines 31-46)
- [ ] Scan pump history for Rewind events

**Строки JS**: 24-46  
**Оценка**: ~40 строк Swift

---

### ЭТАП 4: Meals integration (45 мин)
- [ ] find_meals() call (lines 51-58)
- [ ] Sort meals by timestamp (lines 59-64)
- [ ] Remove old meals (lines 122-141)

**Строки JS**: 51-64, 122-141  
**Оценка**: ~50 строк Swift

---

### ЭТАП 5: Main loop - Part 1 (1 час)
- [ ] Loop через bucketed_data (line 150)
- [ ] isfLookup (line 153) - dynamic sens
- [ ] BG validation (lines 159-172)
- [ ] avgDelta calculation (line 167)
- [ ] delta calculation (line 168)
- [ ] basalLookup (line 176) - dynamic basal
- [ ] IOB calculation (line 181)
- [ ] BGI calculation (line 185)
- [ ] Deviation calculation (lines 188-199)

**Строки JS**: 150-199  
**Оценка**: ~70 строк Swift

---

### ЭТАП 6: COB tracking (45 мин)
- [ ] Process meals in loop (lines 207-222)
- [ ] mealCOB accumulation
- [ ] Carb absorption calculation (lines 224-234)
  * ci = max(deviation, min_5m_carbimpact)
  * absorbed = ci * carb_ratio / sens
  * mealCOB -= absorbed

**Строки JS**: 207-234  
**Оценка**: ~50 строк Swift

---

### ЭТАП 7: absorbing + UAM (1 час)
- [ ] absorbing tracking (lines 236-265)
  * mealStartCounter
  * type="csf" когда mealCOB > 0
- [ ] UAM detection (lines 274-297)
  * iob.iob > 2 * currentBasal
  * type="uam"
- [ ] Type classification (lines 300-317)
  * "non-meal" vs "csf" vs "uam"
  * Exclude meal deviations from autosens

**Строки JS**: 236-317  
**Оценка**: ~100 строк Swift

---

### ЭТАП 8: tempTarget + hour markers (30 мин)
- [ ] tempTargetRunning usage (lines 319-331)
  * Add extra negative deviation for high target
  * tempDeviation = -(tempTarget-100)/20
- [ ] Hour markers (lines 333-343)
  * Add 0 deviation every 2 hours
  * Process.stderr hour display

**Строки JS**: 319-343  
**Оценка**: ~40 строк Swift

---

### ЭТАП 9: Deviations padding (20 мин)
- [ ] Lookback limit (lines 344-349)
  * Keep last 96 deviations (8h)
- [ ] Padding zeros (lines 359-366)
  * If < 96, add zeros
  * Formula: (1 - length/96) * 18

**Строки JS**: 344-349, 359-366  
**Оценка**: ~30 строк Swift

---

### ЭТАП 10: Percentile analysis (30 мин)
- [ ] Implement percentile() function
- [ ] Sort deviations (line 369)
- [ ] Percentile loop (lines 370-382)
  * Find where 50% cross zero
  * pSensitive / pResistant
- [ ] RMS deviation (lines 389-391)

**Строки JS**: 367-391  
**Оценка**: ~50 строк Swift

---

### ЭТАП 11: ПРАВИЛЬНАЯ формула ratio (45 мин)
- [ ] basalOff calculation (lines 393-403)
  * basalOff = pSensitive * (60/5) / profile.sens
  * OR basalOff = pResistant * (60/5) / profile.sens
- [ ] ratio calculation (line 404)
  * ratio = 1 + (basalOff / profile.max_daily_basal)
- [ ] Ratio limits (lines 409-414)
  * min: autosens_min (default 0.7)
  * max: autosens_max (default 1.3)
- [ ] newISF calculation (line 417)
  * newisf = profile.sens / ratio

**Строки JS**: 393-420  
**Оценка**: ~50 строк Swift

---

### ЭТАП 12: Testing + cleanup (30 мин)
- [ ] Remove old simplified code
- [ ] Add comments
- [ ] Test compilation
- [ ] Create unit tests

**Оценка**: cleanup + testing

---

## 📊 ИТОГО

**Этапов**: 12  
**Оценка строк Swift**: ~590 строк (вместо текущих 440)  
**Время**: 6-7 часов  

**Сложность**: ВЫСОКАЯ

---

## 🎯 ПОРЯДОК РЕАЛИЗАЦИИ

### Сессия 1 (2 часа): Этапы 1-4
- Структуры + bucketing + lastSiteChange + meals

### Сессия 2 (2 часа): Этапы 5-7
- Main loop + COB + UAM

### Сессия 3 (2 часа): Этапы 8-12
- tempTarget + percentile + правильная формула + cleanup

---

## 🚀 НАЧИНАЕМ!

**Следующий шаг**: ЭТАП 1 - Подготовка структур
