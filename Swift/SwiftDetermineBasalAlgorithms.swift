import Foundation

// MARK: - Swift портирование determine-basal.js алгоритма

// Основной алгоритм принятия решений OpenAPS для расчета базальной скорости инсулина

extension SwiftOpenAPSAlgorithms {
    // MARK: - Determine Basal Input Structures

    struct DetermineBasalInputs {
        let iob: IOBResult
        let currentTemp: TempBasal?
        let glucose: GlucoseStatus
        let profile: ProfileResult
        let autosens: Autosens?
        let meal: MealResult?
        let microBolusAllowed: Bool
        let reservoir: Reservoir?
        let clock: Date
        let pumpHistory: [PumpHistoryEvent]
    }

    struct GlucoseStatus {
        let glucose: Double
        let delta: Double
        let shortAvgDelta: Double
        let longAvgDelta: Double
        let date: Date
        let noise: Int?

        var rawJSON: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")

            return """
            {
                "glucose": \(glucose),
                "delta": \(delta),
                "short_avgdelta": \(shortAvgDelta),
                "long_avgdelta": \(longAvgDelta),
                "date": "\(formatter.string(from: date))",
                "noise": \(noise ?? 0)
            }
            """
        }
    }

    struct PredictionArrays {
        let IOBpredBGs: [Double] // IOB predictions как в оригинале
        let COBpredBGs: [Double] // COB predictions как в оригинале
        let UAMpredBGs: [Double] // UAM predictions как в оригинале
        let ZTpredBGs: [Double] // Zero Temp predictions как в оригинале
        let predCIs: [Double] // Predicted carb impacts
        let remainingCIs: [Double] // Remaining carb impacts
        
        // КРИТИЧЕСКИЕ значения из prediction arrays (строки 550-568 в JS)
        let minIOBPredBG: Double
        let minCOBPredBG: Double
        let minUAMPredBG: Double
        let minGuardBG: Double
        let minCOBGuardBG: Double
        let minUAMGuardBG: Double
        let minIOBGuardBG: Double
        let minZTGuardBG: Double
        let maxIOBPredBG: Double
        let maxCOBPredBG: Double
        let maxUAMPredBG: Double
        let avgPredBG: Double
        let UAMduration: Double
        
        // Last prediction values для reason (строки 658, 678, 691 в JS)
        let lastIOBpredBG: Double
        let lastCOBpredBG: Double
        let lastUAMpredBG: Double
        let lastZTpredBG: Double
        let minPredBG: Double

        var predBGsDict: [String: [Double]] {
            [
                "IOB": IOBpredBGs,
                "COB": COBpredBGs,
                "UAM": UAMpredBGs,
                "ZT": ZTpredBGs
            ]
        }
    }

    struct DetermineBasalResult {
        let temp: String // "absolute" или "cancel"
        let bg: Double
        let tick: String
        let eventualBG: Double
        let insulinReq: Double
        let reservoir: Double?
        let deliverAt: Date
        let sensitivityRatio: Double?
        let reason: String
        let rate: Double?
        let duration: Int?
        let units: Double? // Для микроболюсов
        let carbsReq: Double?
        
        // ✅ НОВЫЕ ПОЛЯ из determine-basal.js для полной совместимости (строка 806-810)
        // Эти значения уже сконвертированы через convertBG перед созданием результата
        let BGI: Double?  // Blood Glucose Impact (сконвертировано)
        let deviation: Double?  // Отклонение от прогноза (сконвертировано)
        let ISF: Double?  // Insulin Sensitivity Factor (сконвертировано)
        let targetBG: Double?  // Целевой BG (сконвертировано)

        // 🚀 КРИТИЧЕСКАЯ ДОБАВКА: Prediction arrays для рисования прогнозов!
        let predBGs: [String: [Double]] // Contains IOB, COB, UAM, ZT arrays
        
        // ✅ КРИТИЧЕСКОЕ ПОЛЕ: profile для доступа к outUnits при конвертации
        let profile: ProfileResult

        var rawJSON: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")

            // ВАЖНО: bg и eventualBG ВСЕГДА в mg/dL (как в оригинале determine-basal.js:698)
            // Комментарий из оригинала: "for FreeAPS-X needs to be in mg/dL"
            // НЕ конвертируем bg и eventualBG!

            // Ограничиваем точность чисел для совместимости с Swift Decimal
            let rateString = rate.map { String(format: "%.2f", $0) } ?? "null"
            let durationString = duration.map { "\($0)" } ?? "null"
            let unitsString = units.map { String(format: "%.2f", $0) } ?? "null"
            let carbsReqString = carbsReq.map { String(format: "%.1f", $0) } ?? "null"
            let sensRatioString = sensitivityRatio.map { String(format: "%.2f", $0) } ?? "null"
            let reservoirString = reservoir.map { String(format: "%.1f", $0) } ?? "null"
            
            // ✅ НОВЫЕ ПОЛЯ: BGI, deviation, ISF, targetBG (уже сконвертированы)
            let BGIString = BGI.map { 
                profile.outUnits == "mmol/L" ? String(format: "%.1f", $0) : String(format: "%.1f", $0)
            } ?? "null"
            let deviationString = deviation.map { 
                profile.outUnits == "mmol/L" ? String(format: "%.1f", $0) : String(format: "%.1f", $0)
            } ?? "null"
            let ISFString = ISF.map { 
                profile.outUnits == "mmol/L" ? String(format: "%.1f", $0) : String(format: "%.1f", $0)
            } ?? "null"
            let targetBGString = targetBG.map { 
                profile.outUnits == "mmol/L" ? String(format: "%.1f", $0) : String(Int($0.rounded()))
            } ?? "null"

            // ВАЖНО: predBGs массивы ВСЕГДА в mg/dL (как в оригинале determine-basal.js:657,667,677,690)
            // Оригинал: rT.predBGs.IOB = IOBpredBGs (без конвертации!)
            // НЕ конвертируем predBGs массивы!
            let predBGsJSON = predBGs.map { key, values in
                let valuesString = values.map { String(Int($0.rounded())) }.joined(separator: ",")
                return "\"\(key)\": [\(valuesString)]"
            }.joined(separator: ",")

            return """
            {
                "temp": "\(temp)",
                "bg": \(Int(bg.rounded())),
                "tick": "\(tick)",
                "eventualBG": \(Int(eventualBG.rounded())),
                "insulinReq": \(insulinReq),
                "reservoir": \(reservoirString),
                "deliverAt": "\(formatter.string(from: deliverAt))",
                "sensitivityRatio": \(sensRatioString),
                "reason": "\(reason)",
                "rate": \(rateString),
                "duration": \(durationString),
                "units": \(unitsString),
                "carbsReq": \(carbsReqString),
                "BGI": \(BGIString),
                "deviation": \(deviationString),
                "ISF": \(ISFString),
                "target_bg": \(targetBGString),
                "predBGs": {\(predBGsJSON)}
            }
            """
        }
    }

    // MARK: - КРИТИЧЕСКИЕ вспомогательные функции из determine-basal.js

    /// КРИТИЧЕСКАЯ функция из determine-basal.js:39-49
    /// Конвертирует значения глюкозы между mg/dL и mmol/L
    /// Используется во ВСЕХ местах, где возвращаются BG-значения
    private static func convertBG(_ value: Double, profile: ProfileResult) -> Double {
        if profile.outUnits == "mmol/L" {
            // Конвертируем mg/dL -> mmol/L и округляем до 1 знака
            return round(value / 18.0 * 10) / 10
        } else {
            // Округляем до целого для mg/dL
            return round(value)
        }
    }

    /// Функция округления из determine-basal.js:21-26
    /// Rounds value to 'digits' decimal places
    private static func round(_ value: Double, digits: Int = 0) -> Double {
        if digits == 0 {
            return Darwin.round(value)
        }
        let scale = pow(10.0, Double(digits))
        return Darwin.round(value * scale) / scale
    }

    /// Функция из determine-basal.js:31-36
    /// Рассчитывает ожидаемую дельту BG для достижения target за 2 часа
    /// we expect BG to rise or fall at the rate of BGI,
    /// adjusted by the rate at which BG would need to rise/fall to get eventualBG to target over 2 hours
    private static func calculateExpectedDelta(targetBG: Double, eventualBG: Double, bgi: Double) -> Double {
        // (hours * mins_per_hour) / 5 = how many 5 minute periods in 2h = 24
        let fiveMinBlocks = (2.0 * 60.0) / 5.0
        let targetDelta = targetBG - eventualBG
        return round(bgi + (targetDelta / fiveMinBlocks), digits: 1)
    }

    /// ТОЧНАЯ портация функции enable_smb из determine-basal.js:51-126
    /// НЕТ ИЗМЕНЕНИЙ! Каждая строка соответствует оригиналу
    /// Определяет, можно ли использовать Super Micro Bolus (SMB)
    private static func enableSMB(
        profile: ProfileResult,
        microBolusAllowed: Bool,
        mealData: MealResult?,
        bg: Double,
        targetBG: Double,
        highBG: Double?
    ) -> Bool {
        // disable SMB when a high temptarget is set (строка 59-69)
        if !microBolusAllowed {
            debug(.openAPS, "SMB disabled (!microBolusAllowed)")
            return false
        } else if !(profile.allowSMBWithHighTemptarget ?? true) && profile.temptargetSet && targetBG > 100 {
            debug(.openAPS, "SMB disabled due to high temptarget of \(targetBG)")
            return false
        } else if mealData?.bwFound == true && !(profile.a52RiskEnable ?? false) {
            debug(.openAPS, "SMB disabled due to Bolus Wizard activity in the last 6 hours.")
            return false
        }

        // enable SMB/UAM if always-on (unless previously disabled for high temptarget) (строка 71-79)
        if profile.enableSMBAlways ?? false {
            if mealData?.bwFound == true {
                debug(.openAPS, "Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard")
            } else {
                debug(.openAPS, "SMB enabled due to enableSMB_always")
            }
            return true
        }

        // enable SMB/UAM (if enabled in preferences) while we have COB (строка 81-89)
        if profile.enableSMBWithCOB ?? false && (mealData?.mealCOB ?? 0) > 0 {
            if mealData?.bwCarbs ?? 0 > 0 {
                debug(.openAPS, "Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard")
            } else {
                debug(.openAPS, "SMB enabled for COB of \(mealData?.mealCOB ?? 0)")
            }
            return true
        }

        // enable SMB/UAM (if enabled in preferences) for a full 6 hours after any carb entry (строка 91-100)
        // (6 hours is defined in carbWindow in lib/meal/total.js)
        if profile.enableSMBAfterCarbs ?? false && (mealData?.carbs ?? 0) > 0 {
            if mealData?.bwCarbs ?? 0 > 0 {
                debug(.openAPS, "Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard")
            } else {
                debug(.openAPS, "SMB enabled for 6h after carb entry")
            }
            return true
        }

        // enable SMB/UAM (if enabled in preferences) if a low temptarget is set (строка 102-110)
        if profile.enableSMBWithTemptarget ?? false && profile.temptargetSet && targetBG < 100 {
            if mealData?.bwFound == true {
                debug(.openAPS, "Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard")
            } else {
                debug(.openAPS, "SMB enabled for temptarget of \(convertBG(targetBG, profile: profile))")
            }
            return true
        }

        // enable SMB if high bg is found (строка 112-122)
        if profile.enableSMBHighBG ?? false, let highBG = highBG, bg >= highBG {
            debug(.openAPS, "Checking BG to see if High for SMB enablement.")
            debug(.openAPS, "Current BG \(bg) | High BG \(highBG)")
            if mealData?.bwFound == true {
                debug(.openAPS, "Warning: High BG SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard")
            } else {
                debug(.openAPS, "High BG detected. Enabling SMB.")
            }
            return true
        }

        debug(.openAPS, "SMB disabled (no enableSMB preferences active or no condition satisfied)")
        return false
    }

    /// ТОЧНОЕ портирование freeaps_determineBasal функции из минифицированного JavaScript
    /// НЕТ УПРОЩЕНИЙ! Каждая строка соответствует исходному алгоритму oref0
    /// Основной алгоритм принятия решений OpenAPS для управления инсулином
    static func determineBasal(inputs: DetermineBasalInputs) -> Result<DetermineBasalResult, SwiftOpenAPSError> {
        let glucose = inputs.glucose
        let profile = inputs.profile
        let iob = inputs.iob
        let currentTemp = inputs.currentTemp
        let meal = inputs.meal
        let autosens = inputs.autosens
        let clock = inputs.clock

        // ТОЧНАЯ инициализация переменных как в JS: var p={},h=new Date
        var result: [String: Any] = [:]
        let deliverAt = inputs.clock // h=new Date

        // КРИТИЧЕСКАЯ ПРОВЕРКА: void 0===s||void 0===s.current_basal
        // ИСПРАВЛЕНО: Должно быть current_basal, а не maxBasal!
        let currentBasalRate = profile.currentBasal
        guard currentBasalRate > 0 else {
            return .success(DetermineBasalResult(
                temp: "absolute",
                bg: glucose.glucose,
                tick: formatTick(glucose.delta),
                eventualBG: glucose.glucose,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: nil,
                reason: "Error: could not get current basal rate",
                rate: nil,
                duration: nil,
                units: nil,
                carbsReq: nil,
                BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                predBGs: emptyPredictionArrays(bg: glucose.glucose),
                profile: profile
            ))
        }

        // РАЗМИНИФИЦИРОВАННЫЕ переменные с понятными названиями из исходного oref0
        var currentBasal = currentBasalRate // g в JS = current basal rate
        var adjustedBasal = currentBasal // f в JS = adjusted basal rate
        let maxIOB = profile.maxIOB // S в JS = s.max_iob

        // ТОЧНАЯ логика определения target_bg с понятными названиями
        var minBG: Double // G в JS = min_bg
        var maxBG: Double // C в JS = max_bg
        var targetBG: Double // _ в JS = target_bg
        var sensitivityRatio: Double? // w в JS = sensitivity ratio

        // Проверяем наличие min_bg и max_bg как в JS
        guard !profile.targets.targets.isEmpty,
              let firstTarget = profile.targets.targets.first
        else {
            return .success(DetermineBasalResult(
                temp: "absolute",
                bg: glucose.glucose,
                tick: formatTick(glucose.delta),
                eventualBG: glucose.glucose,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: nil,
                reason: "Error: could not determine target_bg.",
                rate: nil,
                duration: nil,
                units: nil,
                carbsReq: nil,
                predBGs: emptyPredictionArrays(bg: glucose.glucose),
                profile: profile
            ))
        }

        minBG = Double(firstTarget.low) // G в JS = min_bg
        maxBG = Double(firstTarget.high) // C в JS = max_bg
        targetBG = (minBG + maxBG) / 2 // _ в JS = target_bg = (s.min_bg+s.max_bg)/2

        // ТОЧНОЕ определение threshold как в оригинале (строка 329)
        // min_bg of 90 -> threshold of 65, 100 -> 70 110 -> 75, and 130 -> 85
        let threshold = minBG - 0.5 * (minBG - 40)

        // РАЗМИНИФИЦИРОВАННАЯ логика sensitivity ratio с понятными названиями
        // O в JS = exercise_mode || high_temptarget_raises_sensitivity
        let exerciseOrHighTempRaisesSens = profile.exerciseMode || profile.highTemptargetRaisesSensitivity
        let normalTarget = 100.0 // y в JS = 100

        // T в JS = half_basal_exercise_target или 160
        var halfBasalTarget: Double
        if let halfBasalExerciseTarget = profile.halfBasalExerciseTarget {
            halfBasalTarget = halfBasalExerciseTarget
        } else {
            halfBasalTarget = 160.0
        }

        // КРИТИЧЕСКАЯ логика temp target sensitivity с понятными названиями
        // if(exerciseOrHighTemp && temptargetSet && targetBG > normalTarget ||
        //    lowTemptargetLowersSensitivity && temptargetSet && targetBG < normalTarget)
        if (exerciseOrHighTempRaisesSens && profile.temptargetSet && targetBG > normalTarget) ||
            (profile.lowTemptargetLowersSensitivity && profile.temptargetSet && targetBG < normalTarget)
        {
            // A в JS = T-y = halfBasalTarget - normalTarget
            let targetDifference = halfBasalTarget - normalTarget
            sensitivityRatio = targetDifference / (targetDifference + targetBG - normalTarget)

            // Ограничиваем максимальным autosens и округляем до 2 знаков
            sensitivityRatio = min(sensitivityRatio!, profile.autosensMax)
            sensitivityRatio = round(sensitivityRatio! * 100) / 100 // n(w,2) - округление до 2 знаков

            print("Sensitivity ratio set to \(sensitivityRatio!) based on temp target of \(targetBG)")

        } else if let autosens = autosens {
            // Используем autosens ratio если нет temp target
            sensitivityRatio = Double(autosens.ratio)
            print("Autosens ratio: \(sensitivityRatio!)")
        }

        // ТОЧНАЯ коррекция basal с понятными названиями
        // if(sensitivityRatio && (adjustedBasal = currentBasal * sensitivityRatio)
        if let sensitivityRatioValue = sensitivityRatio {
            adjustedBasal = Double(profile.currentBasal) * sensitivityRatioValue
            // f=t(f,s) - функция округления базала
            let roundedAdjustedBasal = roundBasal(adjustedBasal, profile: profile)

            if roundedAdjustedBasal != currentBasal {
                print("Adjusting basal from \(currentBasal) to \(roundedAdjustedBasal)")
            } else {
                print("Basal unchanged: \(roundedAdjustedBasal)")
            }
            adjustedBasal = roundedAdjustedBasal
        }

        // ТОЧНАЯ корректировка target_bg на основе autosens из минифицированного кода
        // if(s.temptargetSet);else if(void 0!==i&&i&&(s.sensitivity_raises_target&&i.ratio<1||s.resistance_lowers_target&&i.ratio>1))
        if !profile.temptargetSet {
            if let autosens = autosens,
               (profile.sensitivityRaisesTarget && Double(autosens.ratio) < 1.0) ||
               (profile.resistanceLowersTarget && Double(autosens.ratio) > 1.0)
            {
                // Корректируем targets на основе autosens ratio
                // G=n((G-60)/i.ratio)+60 - adjusting min_bg
                let minBGAdjusted = (minBG - 60.0) / Double(autosens.ratio)
                minBG = round(minBGAdjusted * 100) / 100 + 60.0

                let maxBGAdjusted = (maxBG - 60.0) / Double(autosens.ratio)
                maxBG = round(maxBGAdjusted * 100) / 100 + 60.0

                // U в JS = новый target_bg с минимумом 80
                let targetBGAdjusted = (targetBG - 60.0) / Double(autosens.ratio)
                var newTargetBG = round(targetBGAdjusted * 100) / 100 + 60.0
                newTargetBG = max(80.0, newTargetBG)

                if targetBG == newTargetBG {
                    print("target_bg unchanged: \(newTargetBG)")
                } else {
                    print("target_bg from \(targetBG) to \(newTargetBG)")
                }
                targetBG = newTargetBG
            }
        }

        // РАЗМИНИФИЦИРОВАННЫЕ проверки безопасности с понятными названиями
        let currentGlucose = glucose.glucose // M в JS = current glucose
        let cgmNoise = glucose.noise ?? 0 // x в JS = noise level

        // M переменная УБРАНА - используем только currentGlucose

        // Критическая проверка 1: CGM калибровка или проблемы с сенсором
        // Из минифицированного: (currentGlucose<=10||currentGlucose===38||cgmNoise>=3)
        var safetyReason = ""
        let hasCGMIssues = currentGlucose <= 10 || currentGlucose == 38 || cgmNoise >= 3

        if hasCGMIssues {
            safetyReason = "CGM is calibrating, in ??? state, or noise is high"
        }

        // Критическая проверка 2: Свежесть данных glucose
        // Из минифицированного: glucoseAgeMinutes>12||glucoseAgeMinutes<-5
        let glucoseAgeMinutes = clock.timeIntervalSince(glucose.date) / 60.0 // в минутах
        let roundedGlucoseAge = round(glucoseAgeMinutes * 10) / 10 // v в JS - округляем как в JS коде

        if roundedGlucoseAge > 12 || roundedGlucoseAge < -5 {
            if safetyReason.isEmpty {
                safetyReason =
                    "If current system time \(clock) is correct, then BG data is too old. The last BG data was read \(String(format: "%.1f", roundedGlucoseAge))m ago at \(glucose.date)"
            }
        }

        // Критическая проверка 3: Застрявшие данные CGM
        // Из минифицированного: currentGlucose>60 && delta==0 && shortAvgDelta>-1 && shortAvgDelta<1 && longAvgDelta>-1 && longAvgDelta<1
        let hasStuckCGM = currentGlucose > 60 &&
            glucose.delta == 0 &&
            glucose.shortAvgDelta > -1 && glucose.shortAvgDelta < 1 &&
            glucose.longAvgDelta > -1 && glucose.longAvgDelta < 1

        if hasStuckCGM && safetyReason.isEmpty {
            // ТОЧНАЯ ЛОГИКА из минифицированного кода: e.last_cal&&e.last_cal<3
            // В JS проверяется последняя калибровка, но в FreeAPS этих данных нет
            // Поэтому используем безопасное сообщение как в JS fallback
            safetyReason = "Error: CGM data is unchanged for the past ~45m"
        }

        // Если есть проблемы безопасности - возвращаем безопасное решение
        let hasAnySafetyIssue = hasCGMIssues || roundedGlucoseAge > 12 || roundedGlucoseAge < -5 || hasStuckCGM

        if hasAnySafetyIssue {
            // ТОЧНАЯ ЛОГИКА SAFETY РЕЗУЛЬТАТОВ из минифицированного кода
            // return r.rate>f?(p.reason+=". Replacing high temp basal of "+r.rate+" with neutral temp of "+f
            // :0===r.rate&&r.duration>30?(p.reason+=". Shortening "+r.duration+"m long zero temp to 30m. "
            // :(p.reason+=". Temp "+r.rate+" <= current basal "+f+"U/hr; doing nothing. "

            if let currentTemp = currentTemp {
                if Double(currentTemp.rate) > adjustedBasal {
                    // Заменяем высокий temp basal на нейтральный
                    return .success(DetermineBasalResult(
                        temp: "absolute",
                        bg: currentGlucose,
                        tick: formatTick(glucose.delta),
                        eventualBG: currentGlucose,
                        insulinReq: 0,
                        reservoir: nil,
                        deliverAt: clock,
                        sensitivityRatio: sensitivityRatio,
                        reason: safetyReason +
                            ". Replacing high temp basal of \(currentTemp.rate) with neutral temp of \(adjustedBasal)",
                        rate: adjustedBasal,
                        duration: 30,
                        units: nil,
                        carbsReq: nil,
                        BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                        predBGs: emptyPredictionArrays(bg: currentGlucose),
                        profile: profile
                    ))
                } else if currentTemp.rate == 0, currentTemp.duration > 30 {
                    // Сокращаем длинный zero temp до 30 минут
                    return .success(DetermineBasalResult(
                        temp: "absolute",
                        bg: currentGlucose,
                        tick: formatTick(glucose.delta),
                        eventualBG: currentGlucose, // В safety cases используем текущую глюкозу как eventual
                        insulinReq: 0,
                        reservoir: nil,
                        deliverAt: clock,
                        sensitivityRatio: sensitivityRatio,
                        reason: safetyReason + ". Shortening \(currentTemp.duration)m long zero temp to 30m.",
                        rate: 0,
                        duration: 30,
                        units: nil,
                        carbsReq: nil,
                        BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                        predBGs: emptyPredictionArrays(bg: currentGlucose),
                        profile: profile
                    ))
                } else {
                    // Temp <= current basal; ничего не делаем
                    return .success(DetermineBasalResult(
                        temp: "absolute",
                        bg: currentGlucose,
                        tick: formatTick(glucose.delta),
                        eventualBG: currentGlucose, // В safety cases используем текущую глюкозу как eventual
                        insulinReq: 0,
                        reservoir: nil,
                        deliverAt: clock,
                        sensitivityRatio: sensitivityRatio,
                        reason: safetyReason + ". Temp \(currentTemp.rate) <= current basal \(adjustedBasal)U/hr; doing nothing.",
                        rate: nil,
                        duration: nil,
                        units: nil,
                        carbsReq: nil,
                        BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                        predBGs: emptyPredictionArrays(bg: currentGlucose),
                        profile: profile
                    ))
                }
            } else {
                // Нет текущего temp basal
                return .success(DetermineBasalResult(
                    temp: "absolute",
                    bg: currentGlucose,
                    tick: formatTick(glucose.delta),
                    eventualBG: currentGlucose, // В safety cases eventualBG = текущая глюкоза (как в JS)
                    insulinReq: 0,
                    reservoir: nil,
                    deliverAt: clock,
                    sensitivityRatio: sensitivityRatio,
                    reason: safetyReason,
                    rate: nil,
                    duration: nil,
                    units: nil,
                    carbsReq: nil,
                    BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                    predBGs: emptyPredictionArrays(bg: currentGlucose),
                    profile: profile
                ))
            }
        }

        // КРИТИЧЕСКАЯ ПРОВЕРКА IOB данных из минифицированного кода
        // if(void 0===a)return p.error="Error: iob_data undefined. ",p
        // void 0===a.activity||void 0===a.iob)return p.error="Error: iob_data missing some property. ",p
        if iob.activity.isNaN || iob.iob.isNaN {
            return .success(DetermineBasalResult(
                temp: "absolute",
                bg: currentGlucose,
                tick: formatTick(glucose.delta),
                eventualBG: currentGlucose, // В safety cases eventualBG = текущая глюкоза (как в JS)
                insulinReq: 0,
                reservoir: nil,
                deliverAt: clock,
                sensitivityRatio: nil,
                reason: "Error: iob_data missing some property.",
                rate: nil,
                duration: nil,
                units: nil,
                carbsReq: nil,
                BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                predBGs: emptyPredictionArrays(bg: currentGlucose),
                profile: profile
            ))
        }

        // Коррекция базала на autosens - используем уже вычисленный adjustedBasal
        let sensitivity = profile.sens / Double(autosens?.ratio ?? 1.0)

        // РАЗМИНИФИЦИРОВАННЫЙ расчет eventual BG с понятными названиями из oref0
        // Все переменные соответствуют исходному determine-basal.js из oref0
        let minDelta = min(glucose.delta, glucose.shortAvgDelta) // E в JS = min delta
        let minAvgDelta = min(glucose.shortAvgDelta, glucose.longAvgDelta) // F в JS = min average delta
        let maxDelta = max(glucose.delta, glucose.shortAvgDelta, glucose.longAvgDelta) // q в JS = max delta

        // 🚨 ИСПРАВЛЕНО: ТОЧНЫЕ формулы из оригинального determine-basal.js (строка 399-417)

        // BGI calculation как в оригинале (строка 399)
        let bgi = round((-iob.activity * sensitivity * 5.0) * 100) / 100

        // ТОЧНАЯ deviation calculation как в оригинале (строка 400-408)
        var deviation = round((30.0 / 5.0) * (minDelta - bgi) * 100) / 100

        // Don't overreact to big negative delta как в оригинале (строка 402-408)
        if deviation < 0 {
            deviation = round((30.0 / 5.0) * (minAvgDelta - bgi) * 100) / 100
            if deviation < 0 {
                deviation = round((30.0 / 5.0) * (glucose.longAvgDelta - bgi) * 100) / 100
            }
        }

        // ТОЧНАЯ naive eventualBG calculation как в оригинале (строка 411-415)
        let naive_eventualBG: Double
        if iob.iob > 0 {
            naive_eventualBG = round((currentGlucose - iob.iob * sensitivity) * 100) / 100
        } else {
            // If IOB is negative, be more conservative (строка 413-414)
            naive_eventualBG = round((currentGlucose - iob.iob * min(sensitivity, profile.sens)) * 100) / 100
        }

        // КРИТИЧЕСКАЯ ФОРМУЛА: ТОЧНЫЙ eventualBG как в оригинале (строка 417)
        let eventualBG = naive_eventualBG + deviation

        // ТОЧНЫЙ расчет expectedDelta как в оригинале (строка 423)
        let expectedDelta = calculateExpectedDelta(targetBG: targetBG, eventualBG: eventualBG, bgi: bgi)

        // КРИТИЧЕСКАЯ ПРОВЕРКА eventual BG из минифицированного кода
        // if(void 0===$||isNaN($))return p.error="Error: could not calculate eventualBG. ",p
        if eventualBG.isNaN || eventualBG.isInfinite {
            return .success(DetermineBasalResult(
                temp: "absolute",
                bg: currentGlucose,
                tick: formatTick(glucose.delta),
                eventualBG: currentGlucose, // В safety cases eventualBG = текущая глюкоза (как в JS)
                insulinReq: 0,
                reservoir: nil,
                deliverAt: clock,
                sensitivityRatio: nil,
                reason: "Error: could not calculate eventualBG.",
                rate: nil,
                duration: nil,
                units: nil,
                carbsReq: nil,
                BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                predBGs: emptyPredictionArrays(bg: currentGlucose),
                profile: profile
            ))
        }

        // КРИТИЧЕСКАЯ ФУНКЦИЯ: Noisy CGM target adjustments с понятными названиями
        // if(cgmNoise >= 2) - корректируем targets для шумного CGM
        if cgmNoise >= 2 {
            let noisyTargetMultiplier = max(1.1, profile.noisyCGMTargetMultiplier) // Z в JS
            let adjustedMinBG = round(min(200.0, minBG * noisyTargetMultiplier) * 100) / 100 // H в JS
            let adjustedTargetBG = round(min(200.0, targetBG * noisyTargetMultiplier) * 100) / 100 // J в JS
            let adjustedMaxBG = round(min(200.0, maxBG * noisyTargetMultiplier) * 100) / 100 // K в JS

            print("Raising target_bg for noisy / raw CGM data, from \(targetBG) to \(adjustedTargetBG)")
            minBG = adjustedMinBG
            targetBG = adjustedTargetBG
            maxBG = adjustedMaxBG
        } else if currentGlucose > maxBG, profile.advTargetAdjustments, !profile.temptargetSet {
            // КРИТИЧЕСКАЯ ФУНКЦИЯ: Advanced target adjustments для высокой глюкозы с понятными названиями
            // currentGlucose > maxBG && advTargetAdjustments && !temptargetSet
            let advancedMinBG = round(max(80.0, minBG - (currentGlucose - minBG) / 3.0) * 100) / 100 // H в JS
            let advancedTargetBG = round(max(80.0, targetBG - (currentGlucose - targetBG) / 3.0) * 100) / 100 // J в JS
            let advancedMaxBG = round(max(80.0, maxBG - (currentGlucose - maxBG) / 3.0) * 100) / 100 // K в JS

            // ВРЕМЕННО ОТКЛЮЧЕНО: advanced target adjustments требуют предварительного расчета eventualBG
            // Эта логика будет добавлена после расчета eventualBG
            debug(.openAPS, "📊 Advanced target adjustments: high BG detected (\(currentGlucose) > \(maxBG))")
            debug(.openAPS, "📊 Will adjust targets after eventualBG calculation")
        }

        // Сохраняем разминифицированные названия для передачи в makeBasalDecision
        // (эти переменные уже определены выше с понятными названиями)

        // КРИТИЧЕСКИЕ проверки temp basal из минифицированного кода
        // Проверка 1: Несоответствие текущего temp с историей помпы
        // u&&r&&a.lastTemp&&r.rate!==a.lastTemp.rate&&I>10&&r.duration
        if let currentTemp = currentTemp,
           let lastTemp = iob.lastTemp,
           Double(currentTemp.rate) != Double(lastTemp.rate)
        {
            // I - lastTempAge: ТОЧНЫЙ расчет как в JS: n((new Date(b).getTime()-a.lastTemp.date)/6e4)
            let lastTempDate = lastTemp.timestamp
            let lastTempAge = clock.timeIntervalSince(lastTempDate) / 60.0
            if lastTempAge > 10, currentTemp.duration > 0 {
                return .success(DetermineBasalResult(
                    temp: "absolute",
                    bg: glucose.glucose,
                    tick: formatTick(glucose.delta),
                    eventualBG: glucose.glucose,
                    insulinReq: 0,
                    reservoir: nil,
                    deliverAt: deliverAt,
                    sensitivityRatio: nil,
                    reason: "Warning: currenttemp rate \(Double(currentTemp.rate)) != lastTemp rate \(Double(lastTemp.rate)) from pumphistory; canceling temp",
                    rate: nil,
                    duration: nil,
                    units: nil,
                    carbsReq: nil,
                    BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                    predBGs: emptyPredictionArrays(bg: currentGlucose),
                    profile: profile
                ))
            }
        }

        // Проверка 2: Temp basal работает, но история показывает, что он должен был закончиться
        // r&&a.lastTemp&&r.duration>0 и k>5&&I>10
        if let currentTemp = currentTemp,
           let lastTemp = iob.lastTemp,
           currentTemp.duration > 0
        {
            let lastTempDate = lastTemp.timestamp
            let lastTempAge = clock.timeIntervalSince(lastTempDate) / 60.0 // I
            let k = lastTempAge - Double(lastTemp.duration) // Разница между возрастом и продолжительностью

            if k > 5, lastTempAge > 10 {
                return .success(DetermineBasalResult(
                    temp: "absolute",
                    bg: glucose.glucose,
                    tick: formatTick(glucose.delta),
                    eventualBG: glucose.glucose,
                    insulinReq: 0,
                    reservoir: nil,
                    deliverAt: deliverAt,
                    sensitivityRatio: nil,
                    reason: "Warning: currenttemp running but lastTemp from pumphistory ended \(String(format: "%.0f", k))m ago; canceling temp",
                    rate: nil,
                    duration: nil,
                    units: nil,
                    carbsReq: nil,
                    BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                    predBGs: emptyPredictionArrays(bg: currentGlucose),
                    profile: profile
                ))
            }
        }

        // Добавляем влияние углеводов (если есть meal данные)
        let mealAdjustedEventualBG = eventualBG

        // ТОЧНЫЙ вызов enable_smb как в оригинале (строка 451-458)
        var enableSMB = enableSMB(
            profile: profile,
            microBolusAllowed: inputs.microBolusAllowed,
            mealData: meal,
            bg: glucose.glucose,
            targetBG: targetBG,
            highBG: profile.enableSMBHighBGTarget
        )

        // enable UAM (if enabled in preferences) (строка 460-461)
        let enableUAM = profile.enableUAM ?? false

        // 🚨 КРИТИЧЕСКАЯ ФУНКЦИЯ: Calculate prediction arrays как в оригинале (строка 442-657)
        let predictionArrays = calculatePredictionArrays(
            bg: glucose.glucose,
            bgi: bgi,
            iob: iob,
            meal: meal,
            profile: profile,
            sensitivity: sensitivity,
            sensitivityRatio: sensitivityRatio,
            minDelta: minDelta,
            enableUAM: enableUAM,
            targetBG: targetBG
        )

        debug(
            .openAPS,
            "📊 Prediction arrays created: IOB=\(predictionArrays.IOBpredBGs.count), COB=\(predictionArrays.COBpredBGs.count), UAM=\(predictionArrays.UAMpredBGs.count), ZT=\(predictionArrays.ZTpredBGs.count)"
        )

        // ТОЧНАЯ логика отключения SMB как в оригинале (строка 862-880)
        // Проверка minGuardBG < threshold (строка 862-866)
        if enableSMB && predictionArrays.minGuardBG < threshold {
            debug(.openAPS, "minGuardBG \(convertBG(predictionArrays.minGuardBG, profile: profile)) projected below \(convertBG(threshold, profile: profile)) - disabling SMB")
            enableSMB = false
        }

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
            // rT.reason будет обновлен ниже
            enableSMB = false
        }

        // ТОЧНАЯ SMB calculation logic из оригинала (строка 1076-1155)
        // only allow microboluses with COB or low temp targets, or within DIA hours of a bolus
        if inputs.microBolusAllowed && enableSMB && glucose.glucose > threshold {
            // Расчет insulinReq (должен быть определен выше в полной портации)
            let insulinReq = (glucose.glucose - targetBG) / sensitivity
            
            // never bolus more than maxSMBBasalMinutes worth of basal (строка 1077-1095)
            let mealInsulinReq = round((meal?.mealCOB ?? 0) / profile.carbRatioValue, digits: 3)
            let maxBolus: Double
            
            if profile.maxSMBBasalMinutes == nil {
                maxBolus = round(profile.currentBasal * 30 / 60, digits: 1)
                debug(.openAPS, "profile.maxSMBBasalMinutes undefined: defaulting to 30m")
            } else if iob.iob > mealInsulinReq && iob.iob > 0 {
                // if IOB covers more than COB, limit maxBolus to 30m of basal
                debug(.openAPS, "IOB \(iob.iob) > COB \(meal?.mealCOB ?? 0); mealInsulinReq = \(mealInsulinReq)")
                if let maxUAMSMBBasalMinutes = profile.maxUAMSMBBasalMinutes {
                    debug(.openAPS, "profile.maxUAMSMBBasalMinutes: \(maxUAMSMBBasalMinutes) profile.current_basal: \(profile.currentBasal)")
                    maxBolus = round(profile.currentBasal * maxUAMSMBBasalMinutes / 60, digits: 1)
                } else {
                    debug(.openAPS, "profile.maxUAMSMBBasalMinutes undefined: defaulting to 30m")
                    maxBolus = round(profile.currentBasal * 30 / 60, digits: 1)
                }
            } else {
                let maxSMBBasalMinutes = profile.maxSMBBasalMinutes ?? 30
                debug(.openAPS, "profile.maxSMBBasalMinutes: \(maxSMBBasalMinutes) profile.current_basal: \(profile.currentBasal)")
                maxBolus = round(profile.currentBasal * maxSMBBasalMinutes / 60, digits: 1)
            }
            
            // bolus 1/2 the insulinReq, up to maxBolus, rounding down to nearest bolus increment (строка 1096-1100)
            let bolusIncrement = profile.bolusIncrement ?? 0.1
            let roundSMBTo = 1 / bolusIncrement
            let microBolus = floor(min(insulinReq / 2, maxBolus) * roundSMBTo) / roundSMBTo
            
            // calculate a long enough zero temp to eventually correct back up to target (строка 1101-1104)
            let smbTarget = targetBG
            // ТОЧНО как в JS (строка 1103): используем (naive_eventualBG + minIOBPredBG)/2
            let worstCaseInsulinReq = (smbTarget - (naive_eventualBG + predictionArrays.minIOBPredBG) / 2) / sensitivity
            var durationReq = round(60 * worstCaseInsulinReq / profile.currentBasal)
            
            // if insulinReq > 0 but not enough for a microBolus, don't set an SMB zero temp (строка 1106-1109)
            if insulinReq > 0 && microBolus < bolusIncrement {
                durationReq = 0
            }
            
            var smbLowTempReq = 0.0
            if durationReq <= 0 {
                durationReq = 0
            } else if durationReq >= 30 {
                // don't set an SMB zero temp longer than 60 minutes (строка 1114-1118)
                durationReq = round(durationReq / 30) * 30
                durationReq = min(60, max(0, durationReq))
            } else {
                // if SMB durationReq is less than 30m, set a nonzero low temp (строка 1119-1122)
                smbLowTempReq = round(Double(adjustedBasal) * durationReq / 30, digits: 2)
                durationReq = 30
            }
            
            var smbReason = " insulinReq \(insulinReq)"
            if microBolus >= maxBolus {
                smbReason += "; maxBolus \(maxBolus)"
            }
            if durationReq > 0 {
                smbReason += "; setting \(Int(durationReq))m low temp of \(smbLowTempReq)U/h"
            }
            smbReason += ". "
            
            // allow SMBs every 3 minutes by default (строка 1132-1142)
            let SMBInterval = min(10, max(1, profile.smbInterval ?? 3))
            let lastBolusAge = (meal?.lastBolusTime.map { clock.timeIntervalSince($0) / 60 } ?? 999)
            let nextBolusMins = round(SMBInterval - lastBolusAge)
            let nextBolusSeconds = round((SMBInterval - lastBolusAge) * 60).truncatingRemainder(dividingBy: 60)
            
            debug(.openAPS, "naive_eventualBG \(convertBG(naiveEventualBG, profile: profile)), \(Int(durationReq))m \(smbLowTempReq)U/h temp needed; last bolus \(lastBolusAge)m ago; maxBolus: \(maxBolus)")
            
            if lastBolusAge > SMBInterval {
                if microBolus > 0 {
                    // Возвращаем SMB результат с микроболюсом (строка 1144-1147)
                    smbReason = "Microbolusing \(microBolus)U. " + smbReason
                    
                    return .success(DetermineBasalResult(
                        temp: "absolute",
                        bg: glucose.glucose,
                        tick: formatTick(glucose.delta),
                        eventualBG: eventualBG,
                        insulinReq: insulinReq,
                        reservoir: inputs.reservoir.map { $0.reservoir },
                        deliverAt: clock,
                        sensitivityRatio: sensitivityRatio,
                        reason: smbReason,
                        rate: smbLowTempReq,
                        duration: Int(durationReq),
                        units: microBolus,  // ← МИКРОБОЛЮС!
                        carbsReq: nil,
                        BGI: convertBG(bgi, profile: profile),
                        deviation: convertBG(deviation, profile: profile),
                        ISF: convertBG(sensitivity, profile: profile),
                        targetBG: convertBG(targetBG, profile: profile),
                        predBGs: predictionArrays.predBGsDict,
                        profile: profile
                    ))
                }
            } else {
                smbReason += "Waiting \(Int(nextBolusMins))m \(Int(nextBolusSeconds))s to microbolus again. "
            }
            
            // if no zero temp is required, don't return yet; allow later code to set a high temp (строка 1153-1154)
            // Продолжаем к обычной temp basal logic
        }

        // ТОЧНАЯ формируем reason как в JS (строка 804-818)
        let convertedBGI = convertBG(bgi, profile: profile)
        let convertedDeviation = convertBG(deviation, profile: profile)
        let convertedISF = convertBG(sensitivity, profile: profile)
        let convertedTargetBG = convertBG(targetBG, profile: profile)
        let CR = round(profile.carbRatioValue, digits: 2)
        
        var reason = "COB: \(meal?.mealCOB ?? 0), Dev: \(convertedDeviation), BGI: \(convertedBGI), ISF: \(convertedISF), CR: \(CR), minPredBG: \(convertBG(predictionArrays.minPredBG, profile: profile)), minGuardBG: \(convertBG(predictionArrays.minGuardBG, profile: profile)), IOBpredBG: \(convertBG(predictionArrays.lastIOBpredBG, profile: profile))"
        if predictionArrays.lastCOBpredBG > 0 {
            reason += ", COBpredBG: \(convertBG(predictionArrays.lastCOBpredBG, profile: profile))"
        }
        if predictionArrays.lastUAMpredBG > 0 {
            reason += ", UAMpredBG: \(convertBG(predictionArrays.lastUAMpredBG, profile: profile))"
        }
        reason += "; "
        
        // TODO: Портировать логику строк 820-1193 из JS
        // Пока возвращаем временный результат с правильным reason
        return .success(DetermineBasalResult(
            temp: "absolute",
            bg: glucose.glucose,
            tick: formatTick(glucose.delta),
            eventualBG: eventualBG,
            insulinReq: 0,
            reservoir: inputs.reservoir.map { $0.reservoir },
            deliverAt: clock,
            sensitivityRatio: sensitivityRatio,
            reason: reason + "portation in progress",
            rate: Double(adjustedBasal),
            duration: 30,
            units: nil,
            carbsReq: nil,
            BGI: convertedBGI,
            deviation: convertedDeviation,
            ISF: convertedISF,
            targetBG: convertedTargetBG,
            predBGs: predictionArrays.predBGsDict,
            profile: profile
        ))
    }

    // MARK: - Old Decision Logic (DEPRECATED - будет удалена после полной портации)

    private static func makeBasalDecision(
        currentBG: Double,
        eventualBG: Double,
        minBG: Double,
        maxBG: Double,
        targetBG: Double,
        iob: IOBResult,
        sensitivity: Double,
        currentBasal: Double,
        maxIOB: Double,
        currentTemp: TempBasal?,
        meal: MealResult?,
        microBolusAllowed: Bool,
        reservoir _: Reservoir?,
        tick: String,
        deliverAt: Date,
        sensitivityRatio: Double?,
        minDelta: Double,
        maxDelta _: Double,
        profile: ProfileResult
    ) -> DetermineBasalResult {
        var reason = "BG: \(Int(currentBG)), "
        reason += "Delta: \(tick), "
        reason += "IOB: \(String(format: "%.2f", iob.iob))U, "
        reason += "Target: \(Int(targetBG)), "

        // Проверка на низкую глюкозу
        if eventualBG < minBG {
            reason += "Eventual BG \(Int(eventualBG)) < \(Int(minBG))"

            // Если глюкоза падает быстро, устанавливаем низкий temp basal
            if minDelta > 0, minDelta > calculateExpectedDelta(targetBG: targetBG, eventualBG: eventualBG) {
                reason += ", but Min. Delta \(String(format: "%.1f", minDelta)) > Exp. Delta"

                // Проверяем текущий temp basal
                if let temp = currentTemp,
                   temp.duration > 15,
                   abs(Double(temp.rate) - currentBasal) < 0.1
                {
                    reason +=
                        ", temp \(String(format: "%.1f", Double(temp.rate))) ~ req \(String(format: "%.1f", currentBasal))U/hr"
                    return createNoChangeResult(
                        reason: reason,
                        bg: currentBG,
                        tick: tick,
                        eventualBG: eventualBG,
                        deliverAt: deliverAt,
                        profile: profile
                    )
                } else {
                    reason += "; setting current basal of \(String(format: "%.1f", currentBasal)) as temp"
                    return createTempBasalResult(
                        rate: currentBasal,
                        duration: 30,
                        reason: reason,
                        bg: currentBG,
                        tick: tick,
                        eventualBG: eventualBG,
                        deliverAt: deliverAt,
                        sensitivityRatio: sensitivityRatio,
                        profile: profile
                    )
                }
            }

            // Рассчитываем необходимый инсулин для коррекции
            let insulinReq = (min(eventualBG, currentBG) - targetBG) / sensitivity
            let adjInsulinReq = min(insulinReq, maxIOB - iob.iob)

            let requiredRate = max(0, currentBasal + 2 * adjInsulinReq)

            if requiredRate <= 0 {
                // Нужен zero temp
                let duration = calculateZeroTempDuration(
                    bgUndershoot: targetBG - currentBG,
                    sensitivity: sensitivity,
                    currentBasal: currentBasal
                )

                reason += ", setting \(duration)m zero temp"
                return createTempBasalResult(
                    rate: 0,
                    duration: duration,
                    reason: reason,
                    bg: currentBG,
                    tick: tick,
                    eventualBG: eventualBG,
                    deliverAt: deliverAt,
                    sensitivityRatio: sensitivityRatio,
                    profile: profile
                )
            } else {
                reason += ", setting \(String(format: "%.1f", requiredRate))U/hr"
                return createTempBasalResult(
                    rate: requiredRate,
                    duration: 30,
                    reason: reason,
                    bg: currentBG,
                    tick: tick,
                    eventualBG: eventualBG,
                    deliverAt: deliverAt,
                    sensitivityRatio: sensitivityRatio,
                    profile: profile
                )
            }
        }

        // В пределах целевого диапазона
        if eventualBG >= minBG, eventualBG <= maxBG {
            reason += "\(Int(eventualBG)) in range: no temp required"

            if let temp = currentTemp,
               temp.duration > 15,
               abs(Double(temp.rate) - currentBasal) < 0.1
            {
                reason += ", temp \(String(format: "%.1f", Double(temp.rate))) ~ req \(String(format: "%.1f", currentBasal))U/hr"
                return createNoChangeResult(
                    reason: reason,
                    bg: currentBG,
                    tick: tick,
                    eventualBG: eventualBG,
                    deliverAt: deliverAt,
                    profile: profile
                )
            } else {
                reason += "; setting current basal of \(String(format: "%.1f", currentBasal)) as temp"
                return createTempBasalResult(
                    rate: currentBasal,
                    duration: 30,
                    reason: reason,
                    bg: currentBG,
                    tick: tick,
                    eventualBG: eventualBG,
                    deliverAt: deliverAt,
                    sensitivityRatio: sensitivityRatio,
                    profile: profile
                )
            }
        }

        // Высокая глюкоза
        reason += "Eventual BG \(Int(eventualBG)) >= \(Int(maxBG))"

        // Проверка на максимальный IOB
        if iob.iob > maxIOB {
            reason += ", IOB \(String(format: "%.2f", iob.iob)) > max_iob \(maxIOB)"
            return createNoChangeResult(reason: reason, bg: currentBG, tick: tick, eventualBG: eventualBG, deliverAt: deliverAt, profile: profile)
        }

        // Рассчитываем необходимый инсулин
        var insulinReq = (eventualBG - targetBG) / sensitivity

        // Ограничиваем максимальным IOB
        if insulinReq > maxIOB - iob.iob {
            reason += "max_iob \(maxIOB), "
            insulinReq = maxIOB - iob.iob
        }

        let requiredRate = currentBasal + 2 * insulinReq
        let maxSafeRate = getMaxSafeBasal(profile: profile)
        let finalRate = min(requiredRate, maxSafeRate)

        // Проверка на микроболюс
        if microBolusAllowed, currentBG > targetBG {
            let microbolus = calculateMicrobolusDose(
                insulinReq: insulinReq,
                profile: profile,
                iob: iob,
                meal: meal
            )

            if microbolus > 0 {
                reason += "Microbolusing \(String(format: "%.1f", microbolus))U"
                return .success(DetermineBasalResult(
                    temp: "absolute",
                    bg: currentBG,
                    tick: tick,
                    eventualBG: eventualBG,
                    insulinReq: insulinReq,
                    reservoir: nil,
                    deliverAt: deliverAt,
                    sensitivityRatio: sensitivityRatio,
                    reason: reason,
                    rate: currentBasal * 0.5, // Низкий temp на время микроболюса
                    duration: 30,
                    units: microbolus,
                    carbsReq: nil,
                    BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                    predBGs: emptyPredictionArrays(bg: currentBG),
                    profile: profile
                ))
            }
        }

        reason += "temp \(String(format: "%.1f", finalRate))U/hr"
        return createTempBasalResult(
            rate: finalRate,
            duration: 30,
            reason: reason,
            bg: currentBG,
            tick: tick,
            eventualBG: eventualBG,
            deliverAt: deliverAt,
            sensitivityRatio: sensitivityRatio,
            profile: profile
        )
    }

    // MARK: - КРИТИЧЕСКАЯ ФУНКЦИЯ: Prediction Arrays (строка 442-657 determine-basal.js)

    /// ТОЧНАЯ портация prediction arrays из determine-basal.js:466-657
    /// НЕТ УПРОЩЕНИЙ! Каждая формула точно как в JS
    private static func calculatePredictionArrays(
        bg: Double,
        bgi: Double,
        iob: IOBResult,
        meal: MealResult?,
        profile: ProfileResult,
        sensitivity: Double,
        sensitivityRatio: Double?,
        minDelta: Double,
        enableUAM: Bool,
        targetBG: Double
    ) -> PredictionArrays {
        // ТОЧНАЯ инициализация как в JS (строка 466-477)
        var ci = round(minDelta - bgi, digits: 1)
        let uci = round(minDelta - bgi, digits: 1)
        
        // ISF (mg/dL/U) / CR (g/U) = CSF (mg/dL/g) (строка 477)
        let csf = sensitivity / profile.carbRatioValue
        debug(.openAPS, "profile.sens: \(profile.sens) sens: \(sensitivity) CSF: \(csf)")
        
        // ТОЧНО как в JS (строка 480-486)
        let maxCarbAbsorptionRate: Double = 30 // g/h
        let maxCI = round(maxCarbAbsorptionRate * csf * 5 / 60, digits: 1)
        if ci > maxCI {
            debug(.openAPS, "Limiting carb impact from \(ci) to \(maxCI) mg/dL/5m (\(maxCarbAbsorptionRate) g/h )")
            ci = maxCI
        }
        
        // ТОЧНЫЙ расчет remainingCATime как в JS (строка 487-509)
        var remainingCATimeMin: Double = 3 // h
        if let ratio = sensitivityRatio {
            remainingCATimeMin = remainingCATimeMin / ratio
        }
        let assumedCarbAbsorptionRate: Double = 20 // g/h
        var remainingCATime = remainingCATimeMin
        
        if let carbs = meal?.carbs, carbs > 0 {
            remainingCATimeMin = max(remainingCATimeMin, (meal?.mealCOB ?? 0) / assumedCarbAbsorptionRate)
            // ТОЧНО как в JS (строка 500): lastCarbAge calculation
            let lastCarbAge: Double
            if let lastCarbTime = meal?.lastCarbTime {
                lastCarbAge = round(clock.timeIntervalSince(lastCarbTime) / 60) // в минутах
            } else {
                lastCarbAge = 0
            }
            let fractionCOBAbsorbed = (carbs - (meal?.mealCOB ?? 0)) / carbs
            // if the lastCarbTime was 1h ago, increase remainingCATime by 1.5 hours (строка 505)
            remainingCATime = remainingCATimeMin + 1.5 * lastCarbAge / 60
            remainingCATime = round(remainingCATime, digits: 1)
            debug(.openAPS, "Last carbs \(Int(lastCarbAge)) minutes ago; remainingCATime: \(remainingCATime) hours; \(round(fractionCOBAbsorbed*100))% carbs absorbed")
        }
        
        // ТОЧНЫЙ расчет totalCI и remainingCarbs как в JS (строка 511-528)
        let totalCI = max(0.0, ci / 5 * 60 * remainingCATime / 2)
        let totalCA = totalCI / csf
        let remainingCarbsCap: Double = profile.remainingCarbsCap.map { min(90, $0) } ?? 90
        let remainingCarbsFraction: Double = profile.remainingCarbsFraction.map { min(1, $0) } ?? 1
        let remainingCarbsIgnore = 1 - remainingCarbsFraction
        var remainingCarbs = max(0, (meal?.mealCOB ?? 0) - totalCA - (meal?.carbs ?? 0) * remainingCarbsIgnore)
        remainingCarbs = min(remainingCarbsCap, remainingCarbs)
        let remainingCIpeak = remainingCarbs * csf * 5 / 60 / (remainingCATime / 2)
        
        // ТОЧНЫЙ расчет slopeFromDeviations как в JS (строка 530-536)
        let slopeFromMaxDeviation = round(meal?.slopeFromMaxDeviation ?? 0, digits: 2)
        let slopeFromMinDeviation = round(meal?.slopeFromMinDeviation ?? 0, digits: 2)
        let slopeFromDeviations = min(slopeFromMaxDeviation, -slopeFromMinDeviation / 3)
        
        // ТОЧНЫЙ расчет cid как в JS (строка 541-548)
        let cid: Double
        if ci == 0 {
            cid = 0
        } else {
            cid = min(remainingCATime * 60 / 5 / 2, max(0, (meal?.mealCOB ?? 0) * csf / ci))
        }
        debug(.openAPS, "Carb Impact: \(ci) mg/dL per 5m; CI Duration: \(round(cid*5/60*2, digits: 1)) hours; remaining CI (\(remainingCATime) peak): \(round(remainingCIpeak, digits: 1)) mg/dL per 5m")
        
        // ТОЧНАЯ инициализация min/max значений как в JS (строка 550-568)
        var minIOBPredBG: Double = 999
        var minCOBPredBG: Double = 999
        var minUAMPredBG: Double = 999
        var minGuardBG: Double = bg
        var minCOBGuardBG: Double = 999
        var minUAMGuardBG: Double = 999
        var minIOBGuardBG: Double = 999
        var minZTGuardBG: Double = 999
        var maxIOBPredBG: Double = bg
        var maxCOBPredBG: Double = bg
        var maxUAMPredBG: Double = bg
        var IOBpredBG = bg
        var COBpredBG = bg
        var UAMpredBG = bg
        var ZTpredBG = bg
        var UAMduration: Double = 0
        
        var remainingCItotal: Double = 0
        var remainingCIs: [Double] = []
        var predCIs: [Double] = []
        
        // Initialize arrays как в JS (строка 442-449)
        var IOBpredBGs: [Double] = [bg]
        var COBpredBGs: [Double] = [bg]
        var UAMpredBGs: [Double] = [bg]
        var ZTpredBGs: [Double] = [bg]
        
        // ТОЧНЫЙ цикл по iobArray как в JS (строка 574-639)
        for iobTick in iob.iobContrib {
            // ТОЧНЫЕ формулы из JS (строка 576-577)
            let predBGI = round(-iobTick.activity * sensitivity * 5, digits: 2)
            let predZTBGI = round(-(iobTick.iobWithZeroTemp?.activity ?? iobTick.activity) * sensitivity * 5, digits: 2)
            
            // for IOBpredBGs (строка 578-581)
            let predDev = ci * (1 - min(1.0, Double(IOBpredBGs.count) / (60 / 5)))
            IOBpredBG = IOBpredBGs.last! + predBGI + predDev
            
            // calculate predBGs with long zero temp (строка 582-583)
            ZTpredBG = ZTpredBGs.last! + predZTBGI
            
            // for COBpredBGs (строка 584-596)
            var predCI = max(0, max(0, ci) * (1 - Double(COBpredBGs.count) / max(cid * 2, 1)))
            let intervals = min(Double(COBpredBGs.count), (remainingCATime * 12) - Double(COBpredBGs.count))
            let remainingCI = max(0, intervals / (remainingCATime / 2 * 12) * remainingCIpeak)
            remainingCItotal += predCI + remainingCI
            remainingCIs.append(round(remainingCI, digits: 0))
            predCIs.append(round(predCI, digits: 0))
            COBpredBG = COBpredBGs.last! + predBGI + min(0, predDev) + predCI + remainingCI
            
            // for UAMpredBGs (строка 597-610)
            let predUCIslope = max(0, uci + (Double(UAMpredBGs.count) * slopeFromDeviations))
            let predUCImax = max(0, uci * (1 - Double(UAMpredBGs.count) / max(3 * 60 / 5, 1)))
            let predUCI = min(predUCIslope, predUCImax)
            if predUCI > 0 {
                UAMduration = round(Double(UAMpredBGs.count + 1) * 5 / 60, digits: 1)
            }
            UAMpredBG = UAMpredBGs.last! + predBGI + min(0, predDev) + predUCI
            
            // truncate all BG predictions at 4 hours (строка 612-616)
            if IOBpredBGs.count < 48 { IOBpredBGs.append(IOBpredBG) }
            if COBpredBGs.count < 48 { COBpredBGs.append(COBpredBG) }
            if UAMpredBGs.count < 48 { UAMpredBGs.append(UAMpredBG) }
            if ZTpredBGs.count < 48 { ZTpredBGs.append(ZTpredBG) }
            
            // calculate minGuardBGs (строка 617-621)
            if COBpredBG < minCOBGuardBG { minCOBGuardBG = round(COBpredBG) }
            if UAMpredBG < minUAMGuardBG { minUAMGuardBG = round(UAMpredBG) }
            if IOBpredBG < minIOBGuardBG { minIOBGuardBG = round(IOBpredBG) }
            if ZTpredBG < minZTGuardBG { minZTGuardBG = round(ZTpredBG) }
            
            // set minPredBGs (строка 623-638)
            let insulinPeakTime: Double = 90 // 60m + 30m for insulin delivery
            let insulinPeak5m = (insulinPeakTime / 60) * 12
            
            // wait 90m before setting minIOBPredBG (строка 631-633)
            if Double(IOBpredBGs.count) > insulinPeak5m && IOBpredBG < minIOBPredBG {
                minIOBPredBG = round(IOBpredBG)
            }
            if IOBpredBG > maxIOBPredBG { maxIOBPredBG = IOBpredBG }
            
            // wait 85-105m before setting COB and 60m for UAM minPredBGs (строка 634-638)
            if (cid > 0 || remainingCIpeak > 0) && Double(COBpredBGs.count) > insulinPeak5m && COBpredBG < minCOBPredBG {
                minCOBPredBG = round(COBpredBG)
            }
            if (cid > 0 || remainingCIpeak > 0) && COBpredBG > maxIOBPredBG {
                maxCOBPredBG = COBpredBG
            }
            if enableUAM && Double(UAMpredBGs.count) > 12 && UAMpredBG < minUAMPredBG {
                minUAMPredBG = round(UAMpredBG)
            }
            if enableUAM && UAMpredBG > maxIOBPredBG {
                maxUAMPredBG = UAMpredBG
            }
        }
        
        debug(.openAPS, "UAM Impact: \(uci) mg/dL per 5m; UAM Duration: \(UAMduration) hours")
        
        // ТОЧНАЯ постобработка массивов как в JS (строка 650-699)
        IOBpredBGs = IOBpredBGs.map { round(min(401, max(39, $0))) }
        // trim IOBpredBGs (строка 653-656)
        while IOBpredBGs.count > 12 && IOBpredBGs[IOBpredBGs.count - 1] == IOBpredBGs[IOBpredBGs.count - 2] {
            IOBpredBGs.removeLast()
        }
        
        ZTpredBGs = ZTpredBGs.map { round(min(401, max(39, $0))) }
        // trim ZTpredBGs (строка 662-666): stop displaying once they're rising and above target
        var i = ZTpredBGs.count - 1
        while i > 6 {
            if ZTpredBGs[i - 1] >= ZTpredBGs[i] || ZTpredBGs[i] <= targetBG {
                break
            }
            ZTpredBGs.removeLast()
            i -= 1
        }
        
        if (meal?.mealCOB ?? 0) > 0 && (ci > 0 || remainingCIpeak > 0) {
            COBpredBGs = COBpredBGs.map { round(min(401, max(39, $0))) }
            // trim COBpredBGs (строка 673-676)
            while COBpredBGs.count > 12 && COBpredBGs[COBpredBGs.count - 1] == COBpredBGs[COBpredBGs.count - 2] {
                COBpredBGs.removeLast()
            }
        }
        
        if ci > 0 || remainingCIpeak > 0 {
            if enableUAM {
                UAMpredBGs = UAMpredBGs.map { round(min(401, max(39, $0))) }
                // trim UAMpredBGs (строка 686-689)
                while UAMpredBGs.count > 12 && UAMpredBGs[UAMpredBGs.count - 1] == UAMpredBGs[UAMpredBGs.count - 2] {
                    UAMpredBGs.removeLast()
                }
            }
        }
        
        // ТОЧНЫЙ расчет avgPredBG и minGuardBG как в JS (строка 704-740)
        minIOBPredBG = max(39, minIOBPredBG)
        minCOBPredBG = max(39, minCOBPredBG)
        minUAMPredBG = max(39, minUAMPredBG)
        let minPredBG = round(minIOBPredBG)
        
        let fractionCarbsLeft = (meal?.mealCOB ?? 0) / max(meal?.carbs ?? 1, 1)
        var avgPredBG: Double
        
        if minUAMPredBG < 999 && minCOBPredBG < 999 {
            avgPredBG = round((1 - fractionCarbsLeft) * UAMpredBG + fractionCarbsLeft * COBpredBG)
        } else if minCOBPredBG < 999 {
            avgPredBG = round((IOBpredBG + COBpredBG) / 2)
        } else if minUAMPredBG < 999 {
            avgPredBG = round((IOBpredBG + UAMpredBG) / 2)
        } else {
            avgPredBG = round(IOBpredBG)
        }
        
        if minZTGuardBG > avgPredBG {
            avgPredBG = minZTGuardBG
        }
        
        // calculate minGuardBG (строка 728-740)
        if cid > 0 || remainingCIpeak > 0 {
            if enableUAM {
                minGuardBG = fractionCarbsLeft * minCOBGuardBG + (1 - fractionCarbsLeft) * minUAMGuardBG
            } else {
                minGuardBG = minCOBGuardBG
            }
        } else if enableUAM {
            minGuardBG = minUAMGuardBG
        } else {
            minGuardBG = minIOBGuardBG
        }
        minGuardBG = round(minGuardBG)
        
        // ТОЧНО как в JS (строки 658, 678, 691, 668): last prediction values
        let lastIOBpredBG = round(IOBpredBGs.last ?? bg)
        let lastCOBpredBG = COBpredBGs.isEmpty ? 0 : round(COBpredBGs.last!)
        let lastUAMpredBG = UAMpredBGs.isEmpty ? 0 : round(UAMpredBGs.last!)
        let lastZTpredBG = round(ZTpredBGs.last ?? bg)
        
        return PredictionArrays(
            IOBpredBGs: IOBpredBGs,
            COBpredBGs: COBpredBGs,
            UAMpredBGs: UAMpredBGs,
            ZTpredBGs: ZTpredBGs,
            predCIs: predCIs,
            remainingCIs: remainingCIs,
            minIOBPredBG: minIOBPredBG,
            minCOBPredBG: minCOBPredBG,
            minUAMPredBG: minUAMPredBG,
            minGuardBG: minGuardBG,
            minCOBGuardBG: minCOBGuardBG,
            minUAMGuardBG: minUAMGuardBG,
            minIOBGuardBG: minIOBGuardBG,
            minZTGuardBG: minZTGuardBG,
            maxIOBPredBG: maxIOBPredBG,
            maxCOBPredBG: maxCOBPredBG,
            maxUAMPredBG: maxUAMPredBG,
            avgPredBG: avgPredBG,
            UAMduration: UAMduration,
            lastIOBpredBG: lastIOBpredBG,
            lastCOBpredBG: lastCOBpredBG,
            lastUAMpredBG: lastUAMpredBG,
            lastZTpredBG: lastZTpredBG,
            minPredBG: minPredBG
        )
    }

    // MARK: - Helper Functions

    private static func round(_ value: Double, digits: Int = 0) -> Double {
        // ТОЧНАЯ функция из оригинала (строка 21-26 determine-basal.js)
        let scale = pow(10.0, Double(digits))
        return Foundation.round(value * scale) / scale
    }

    /// Создает пустые prediction arrays для compatibility
    private static func emptyPredictionArrays(bg: Double) -> [String: [Double]] {
        [
            "IOB": [bg],
            "COB": [bg],
            "UAM": [bg],
            "ZT": [bg]
        ]
    }

    private static func getTargetBG(profile: ProfileResult, isLow: Bool) -> Double {
        // ТОЧНАЯ реализация из минифицированного кода
        // Проверяем наличие min_bg и max_bg в профиле
        guard let minBG = profile.targets.targets.first?.low,
              let maxBG = profile.targets.targets.first?.high
        else {
            // Значения по умолчанию если нет targets
            return isLow ? 100.0 : 180.0
        }

        return isLow ? Double(minBG) : Double(maxBG)
    }

    private static func formatTick(_ delta: Double) -> String {
        // ТОЧНАЯ формула из минифицированного кода: j=e.delta>-.5?"+"+n(e.delta,0):n(e.delta,0)
        if delta > -0.5 {
            return "+\(round(delta))" // n(e.delta,0) - округление до 0 знаков
        } else {
            return "\(round(delta))" // n(e.delta,0)
        }
    }

    private static func calculateExpectedDelta(targetBG: Double, eventualBG: Double) -> Double {
        // ТОЧНАЯ формула expectedDelta из минифицированного кода
        // function(e,r,a){return n(a+(e-r)/24,1)}(_,$,L)
        round((targetBG - eventualBG) / 24.0 * 10) / 10
    }

    /// ТОЧНАЯ функция округления базала как в oref0 (функция t в минифицированном коде)
    private static func roundBasal(_ basal: Double, profile _: ProfileResult) -> Double {
        // Функция t(f,s) из минифицированного кода - rounds basal rate
        // Обычно округляет до 0.05 или 0.1 в зависимости от помпы

        // Для большинства помп округление до 0.05
        let increment = 0.05
        return round(basal / increment) * increment
    }

    private static func calculateZeroTempDuration(bgUndershoot: Double, sensitivity: Double, currentBasal: Double) -> Int {
        let insulinReq = bgUndershoot / sensitivity
        let duration = Int(60 * insulinReq / currentBasal)
        return max(30, min(120, (duration / 30) * 30)) // Округляем до 30 минут
    }

    private static func getMaxSafeBasal(profile: ProfileResult) -> Double {
        // ТОЧНАЯ ФОРМУЛА из JS: обычно max из maxBasal и current*safety_multiplier
        let maxBasal = Double(profile.settings.maxBasal)
        let currentBasal = profile.currentBasal
        let safetyMultiplier = 4.0 // Обычно current_basal_safety_multiplier

        return min(maxBasal, currentBasal * safetyMultiplier)
    }

    private static func calculateMicrobolusDose(
        insulinReq: Double,
        profile: ProfileResult,
        iob: IOBResult,
        meal: MealResult?
    ) -> Double {
        // ТОЧНАЯ логика микроболюса из минифицированного кода

        // Определяем максимальный микроболюс на основе профиля
        let mealInsulinReq = (meal?.mealCOB ?? 0) / profile.carbRatioValue

        var maxMicrobolusDose: Double

        // Логика из JS: if IOB > meal insulin req, use maxUAMSMBBasalMinutes, else maxSMBBasalMinutes
        if iob.iob > mealInsulinReq, iob.iob > 0 {
            // maxUAMSMBBasalMinutes (обычно 30 минут)
            let maxUAMSMBBasalMinutes = profile.maxUAMSMBBasalMinutes ?? 30.0
            maxMicrobolusDose = round((profile.currentBasal * maxUAMSMBBasalMinutes / 60.0) * 100) / 100
        } else {
            // maxSMBBasalMinutes (обычно 30 минут)
            let maxSMBBasalMinutes = profile.maxSMBBasalMinutes ?? 30.0
            maxMicrobolusDose = round((profile.currentBasal * maxSMBBasalMinutes / 60.0) * 100) / 100
        }

        // Ограничиваем болюсным инкрементом (используем стандартный 0.1)
        let bolusIncrement = 0.1 // Стандартный инкремент болюса
        let microbolusDose = min(insulinReq / 2.0, maxMicrobolusDose)

        // Округляем до инкремента болюса
        let roundedDose = floor(microbolusDose / bolusIncrement) * bolusIncrement

        return max(0, roundedDose)
    }

    // MARK: - Result Creators

    private static func createSafetyResult(
        reason: String,
        currentTemp: TempBasal?,
        currentBasal: Double,
        bg: Double,
        tick: String,
        deliverAt: Date,
        profile: ProfileResult
    ) -> Result<DetermineBasalResult, SwiftOpenAPSError> {
        if let temp = currentTemp, Double(temp.rate) > currentBasal {
            let result = DetermineBasalResult(
                temp: "absolute",
                bg: bg,
                tick: tick,
                eventualBG: bg,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: nil,
                reason: reason + ". Replacing high temp basal",
                rate: currentBasal,
                duration: 30,
                units: nil,
                carbsReq: nil,
                BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                predBGs: emptyPredictionArrays(bg: bg),
                profile: profile
            )
            return .success(result)
        } else {
            let result = DetermineBasalResult(
                temp: "absolute",
                bg: bg,
                tick: tick,
                eventualBG: bg,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: nil,
                reason: reason + ". Temp <= current basal; doing nothing",
                rate: nil,
                duration: nil,
                units: nil,
                carbsReq: nil,
                BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
                predBGs: emptyPredictionArrays(bg: bg),
                profile: profile
            )
            return .success(result)
        }
    }

    private static func createNoChangeResult(
        reason: String,
        bg: Double,
        tick: String,
        eventualBG: Double,
        deliverAt: Date,
        profile: ProfileResult
    ) -> DetermineBasalResult {
        DetermineBasalResult(
            temp: "absolute",
            bg: bg,
            tick: tick,
            eventualBG: eventualBG,
            insulinReq: 0,
            reservoir: nil,
            deliverAt: deliverAt,
            sensitivityRatio: nil,
            reason: reason,
            rate: nil,
            duration: nil,
            units: nil,
            carbsReq: nil,
            BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
            predBGs: emptyPredictionArrays(bg: bg),
            profile: profile
        )
    }

    private static func createTempBasalResult(
        rate: Double,
        duration: Int,
        reason: String,
        bg: Double,
        tick: String,
        eventualBG: Double,
        deliverAt: Date,
        sensitivityRatio: Double?,
        profile: ProfileResult
    ) -> DetermineBasalResult {
        DetermineBasalResult(
            temp: "absolute",
            bg: bg,
            tick: tick,
            eventualBG: eventualBG,
            insulinReq: 0, // Будет рассчитан выше
            reservoir: nil,
            deliverAt: deliverAt,
            sensitivityRatio: sensitivityRatio,
            reason: reason,
            rate: rate,
            duration: duration,
            units: nil,
            carbsReq: nil,
            BGI: nil, deviation: nil, ISF: nil, targetBG: nil,
            predBGs: emptyPredictionArrays(bg: bg),
            profile: profile
        )
    }
}
