# Оставшиеся вызовы DetermineBasalResult для исправления

Нужно добавить `profile: profile` в конец каждого вызова `DetermineBasalResult(...)`.

## Найденные места (из grep_search):

1. ✅ Строка ~195 - Error: could not get current basal rate - ИСПРАВЛЕНО
2. ✅ Строка ~229 - Error: could not determine target_bg - ИСПРАВЛЕНО  
3. ✅ Строка ~382 - Replacing high temp basal - ИСПРАВЛЕНО
4. ✅ Строка ~400 - Shortening long zero temp - ИСПРАВЛЕНО
5. ⏳ Строка ~417 - Temp <= current basal; doing nothing - НУЖНО ИСПРАВИТЬ
6. ⏳ Строка ~435 - Нет текущего temp basal - НУЖНО ИСПРАВИТЬ
7. ⏳ Строка ~457 - Error: iob_data missing - НУЖНО ИСПРАВИТЬ
8. ⏳ Строка ~514 - Error: could not calculate eventualBG - НУЖНО ИСПРАВИТЬ
9. ⏳ Строка ~570 - Temp mismatch - НУЖНО ИСПРАВИТЬ
10. ⏳ Строка ~599 - Temp expired - НУЖНО ИСПРАВИТЬ
11. ⏳ Строка ~867 - Microbolusing - НУЖНО ИСПРАВИТЬ
12. ⏳ Строка ~1103 - in range: setting current basal - НУЖНО ИСПРАВИТЬ
13. ⏳ Строка ~1120 - else branch - НУЖНО ИСПРАВИТЬ

## Прогресс: 4 из 13 (31%)
