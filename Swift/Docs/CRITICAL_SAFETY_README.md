# 🚨 КРИТИЧЕСКАЯ БЕЗОПАСНОСТЬ: Портирование OpenAPS алгоритмов

## ⚠️ МЕДИЦИНСКОЕ ПРЕДУПРЕЖДЕНИЕ

**ВНИМАНИЕ: Этот код управляет дозированием инсулина для людей с диабетом!**

Любые изменения в алгоритмах должны быть **ТОЧНЫМИ КОПИЯМИ** исходного кода из oref0, чтобы сохранить медицинскую безопасность.

## 🔍 Исходные алгоритмы oref0

Исходный проект: https://github.com/openaps/oref0

### Критически важные файлы для портирования:

1. **lib/determine-basal/determine-basal.js** - основной алгоритм принятия решений
2. **lib/iob/calculate.js** - расчет активного инсулина  
3. **lib/profile/index.js** - создание профилей
4. **lib/meal/total.js** - расчет углеводов
5. **lib/autosens/index.js** - автоматическая чувствительность

## 🚨 КРИТИЧЕСКИЕ ПРОВЕРКИ БЕЗОПАСНОСТИ

### 1. Проверки данных CGM (из determine-basal.js):

```javascript
// Калибровка или проблемы сенсора
if (glucose <= 10 || glucose === 38 || noise >= 3) {
    return safety_result;
}

// Устаревшие данные
if (glucose_age > 12 || glucose_age < -5) {
    return safety_result;
}

// Застрявшие данные CGM
if (glucose > 60 && delta === 0 && 
    short_avgdelta > -1 && short_avgdelta < 1 &&
    long_avgdelta > -1 && long_avgdelta < 1) {
    return safety_result;
}
```

### 2. Проверки temp basal:

```javascript
// Несоответствие текущего temp с историей
if (currenttemp.rate !== lastTemp.rate && lastTempAge > 10) {
    return cancel_temp;
}

// Temp должен был закончиться
if (tempAge - tempDuration > 5 && lastTempAge > 10) {
    return cancel_temp;
}
```

### 3. Расчет IOB:

```javascript
// Точная математика кривых инсулина
function bilinear_curve(amount, minutes_ago, dia) {
    // ТОЧНЫЕ значения из оригинального кода
    var peak1 = 75;
    var peak2 = 180; 
    var tau = 3 / dia * minutes_ago;
    // ... остальная математика ТОЧНО как в оригинале
}
```

## ❌ ЗАПРЕЩЕНО

1. **НЕ упрощать алгоритмы** - даже если они кажутся сложными
2. **НЕ изменять математические константы** - они выверены годами использования  
3. **НЕ пропускать проверки безопасности** - каждая важна для жизни
4. **НЕ использовать приближения** - точность критична

## ✅ ОБЯЗАТЕЛЬНО

1. **Портировать ВСЮ логику** из исходного JavaScript
2. **Сохранять все проверки безопасности**
3. **Использовать точные математические формулы**
4. **Тестировать против исходного JavaScript кода**
5. **Документировать каждое отклонение от оригинала**

## 🧪 ТЕСТИРОВАНИЕ

Каждый портированный алгоритм ДОЛЖЕН:

1. **Давать идентичные результаты** с JavaScript версией
2. **Проходить все edge cases** как оригинал
3. **Обрабатывать ошибки** точно так же
4. **Иметь unit tests** для всех критических путей

## 📝 СТАТУС ПОРТИРОВАНИЯ

### ✅ Завершено с точным портированием:
- [x] IOB calculation - bilinear и exponential кривые
- [x] CGM safety checks - калибровка, устаревшие данные, застрявшие данные
- [x] Temp basal safety checks - несоответствия, истекшие temp basal

### ⚠️ Требует доработки до медицинского стандарта:
- [ ] Profile creation - полная логика конвертации единиц
- [ ] Meal/COB calculation - точная модель абсорбции углеводов  
- [ ] Autosens - полный алгоритм анализа отклонений
- [ ] Determine basal - все edge cases и микроболюсы

### 🔄 Следующие шаги:
1. Портировать ПОЛНЫЙ determine-basal алгоритм из либ/determine-basal/determine-basal.js
2. Добавить ВСЕ проверки безопасности из оригинала
3. Портировать точную математику IOB из lib/iob/calculate.js
4. Тестировать против референсных данных

## 🆘 В СЛУЧАЕ СОМНЕНИЙ

**ВСЕГДА обращайтесь к исходному коду oref0!**

Лучше потратить больше времени на точное портирование, чем рисковать безопасностью людей с диабетом.

## 📞 КОНТАКТЫ

- OpenAPS Community: https://openaps.org/
- oref0 GitHub: https://github.com/openaps/oref0
- Медицинская документация: https://openaps.readthedocs.io/

---

**Помните: Этот код спасает жизни. Каждая деталь важна.** 💙


# Findings

- **Каталог вывода**: `dist/` создаётся по настройке `output.path` в [webpack.config.js](oref0/webpack.config.js:0:0-0:0).
- **Минификация**: выполняется `TerserPlugin` (см. `optimization.minimizer`), поэтому файлы в `dist/` — минифицированные бандлы.

# Из каких исходников собраны файлы в `dist/`

См. `entry` в [webpack.config.js](oref0/webpack.config.js:0:0-0:0) ([oref0/webpack.config.js] (oref0/webpack.config.js:0:0-0:0)). Каждый ключ даёт один выходной файл `[name].js` в `dist/`, собранный из соответствующего входного файла и всех его зависимостей (`require`/`import`):

- **iob.js** ← из `lib/iob/index.js`
- **meal.js** ← из `lib/meal/index.js`
- **determineBasal.js** ← из `lib/determine-basal/determine-basal.js`
- **glucoseGetLast.js** ← из `lib/glucose-get-last.js`
- **basalSetTemp.js** ← из `lib/basal-set-temp.js`
- **autosens.js** ← из `lib/determine-basal/autosens.js`
- **profile.js** ← из `lib/profile/index.js`
- **autotunePrep.js** ← из `lib/autotune-prep/index.js`
- **autotuneCore.js** ← из `lib/autotune/index.js`

Например, открытый сейчас `dist/profile.js` построен из входной точки `lib/profile/index.js` плюс все его импортируемые модули.