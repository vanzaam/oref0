# 🔍 ДЕТАЛЬНЫЙ ПЛАН ПРОВЕРКИ СООТВЕТСТВИЯ (ПО 300 СТРОК)

**Дата**: 2025-10-07 11:59  
**Критичность**: 🔴 МАКСИМАЛЬНАЯ - НЕ ПОТЕРЯТЬ НИ ОДНОЙ ФУНКЦИИ!

---

## 📋 ПЛАН ПРОВЕРКИ

### ЭТАП 1: AUTOTUNE-PREP
**Файл JS**: lib/autotune-prep/index.js (176 строк)  
**Файл Swift**: SwiftAutotunePrepAlgorithms.swift (688 строк)

**Проверка по блокам**:
- ✅ Блок 1: Строки 1-50 (JS) vs строки 1-150 (Swift)
- ✅ Блок 2: Строки 51-100 (JS) vs строки 151-300 (Swift)
- ✅ Блок 3: Строки 101-176 (JS) vs строки 301-450 (Swift)
- ✅ Блок 4: Проверка helper functions (строки 451-688 Swift)

### ЭТАП 2: AUTOTUNE-PREP/CATEGORIZE
**Файл JS**: lib/autotune-prep/categorize.js  
**Функция в Swift**: categorizeBGDatums() (строки 131-448)

**Проверка по блокам**:
- ✅ Блок 1: Строки 1-100 (categorize.js)
- ✅ Блок 2: Строки 101-200 (categorize.js)
- ✅ Блок 3: Строки 201-300 (categorize.js)
- ✅ Блок 4: Строки 301-конец (categorize.js)

### ЭТАП 3: AUTOTUNE-CORE
**Файл JS**: lib/autotune/index.js (552 строки)  
**Файл Swift**: SwiftAutotuneCoreAlgorithms.swift (478 строк)

**Проверка по блокам**:
- ✅ Блок 1: Строки 1-150 (JS) vs строки 1-150 (Swift)
- ✅ Блок 2: Строки 151-300 (JS) vs строки 151-300 (Swift)
- ✅ Блок 3: Строки 301-450 (JS) vs строки 301-450 (Swift)
- ✅ Блок 4: Строки 451-552 (JS) vs строки 451-478 (Swift)

---

## 🎯 КРИТЕРИИ ПРОВЕРКИ

### Для каждого блока проверить:

1. **Математические формулы**: ВСЕ должны быть идентичны
2. **Условия (if/else)**: Порядок и логика идентичны
3. **Циклы (for/while)**: Границы и шаги идентичны
4. **Константы**: Все значения идентичны
5. **Вызовы функций**: Параметры идентичны
6. **Возвращаемые значения**: Структуры идентичны

### 🔴 КРИТИЧЕСКИЕ ПРОВЕРКИ:

- ❌ **НЕТ пропущенных функций**
- ❌ **НЕТ упрощений логики**
- ❌ **НЕТ изменённых констант**
- ❌ **НЕТ пропущенных условий**
- ❌ **НЕТ изменённых формул**

---

## 📊 ЧЕКЛИСТ ФУНКЦИЙ

### AUTOTUNE-PREP (index.js):
- [ ] generate() - главная функция
- [ ] find_meals() вызов - проверить
- [ ] DIA analysis loop (lines 41-92) - детально
- [ ] Peak analysis loop (lines 111-162) - детально
- [ ] categorize() вызов - проверить параметры

### AUTOTUNE-PREP (categorize.js):
- [ ] Main categorization loop - критично!
- [ ] IOB calculation logic
- [ ] BGI calculation
- [ ] Deviation calculation
- [ ] Carb absorption logic
- [ ] CR calculation logic
- [ ] CSF/ISF/Basal/UAM categorization
- [ ] UAM re-categorization logic

### AUTOTUNE-CORE (index.js):
- [ ] tuneAllTheThings() - главная функция
- [ ] DIA optimization (lines 59-99)
- [ ] Peak optimization (lines 102-139)
- [ ] CR calculation (lines 149-168)
- [ ] Basal tuning (lines 211-339)
- [ ] ISF tuning (lines 446-552)
- [ ] Safety limits
- [ ] Return structure

---

## 🚨 НАЧИНАЕМ ПРОВЕРКУ!

Буду проверять каждый блок по 300 строк и отмечать результаты...
