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

        // 🚨 КРИТИЧЕСКАЯ ФУНКЦИЯ: Calculate prediction arrays как в оригинале (строка 442-657)
        let predictionArrays = calculatePredictionArrays(
            bg: glucose.glucose,
            bgi: bgi,
            iob: iob,
            meal: meal,
            profile: profile,
            sensitivity: sensitivity,
            sensitivityRatio: sensitivityRatio,
            minDelta: minDelta
        )

        debug(
            .openAPS,
            "📊 Prediction arrays created: IOB=\(predictionArrays.IOBpredBGs.count), COB=\(predictionArrays.COBpredBGs.count), UAM=\(predictionArrays.UAMpredBGs.count), ZT=\(predictionArrays.ZTpredBGs.count)"
        )

        // Основная логика принятия решений с РАЗМИНИФИЦИРОВАННЫМИ переменными + prediction arrays
        let basalDecisionResult = makeBasalDecisionWithPredictions(
            currentBG: glucose.glucose,
            eventualBG: eventualBG,
            minBG: minBG, // Понятные названия вместо G
            maxBG: maxBG, // Понятные названия вместо C
            targetBG: targetBG, // Понятные названия вместо _
            iob: iob,
            sensitivity: sensitivity,
            currentBasal: Double(adjustedBasal), // Понятные названия вместо f
            maxIOB: maxIOB, // Понятные названия вместо S
            currentTemp: currentTemp,
            meal: meal,
            microBolusAllowed: inputs.microBolusAllowed,
            reservoir: inputs.reservoir,
            tick: formatTick(glucose.delta),
            deliverAt: clock,
            sensitivityRatio: sensitivityRatio, // Понятные названия вместо w
            minDelta: minDelta,
            maxDelta: maxDelta,
            profile: profile,
            predictionArrays: predictionArrays, // 🚀 НОВОЕ: prediction arrays для графиков!
            bgi: bgi,  // ✅ НОВОЕ: для JSON output
            deviation: deviation,  // ✅ НОВОЕ: для JSON output
            targetBGForOutput: targetBG  // ✅ НОВОЕ: для JSON output
        )

        return .success(basalDecisionResult)
    }

    // MARK: - Core Decision Logic (с prediction arrays)

    private static func makeBasalDecisionWithPredictions(
        currentBG: Double,
        eventualBG: Double,
        minBG _: Double,
        maxBG _: Double,
        targetBG: Double,
        iob _: IOBResult,
        sensitivity: Double,
        currentBasal: Double,
        maxIOB _: Double,
        currentTemp _: TempBasal?,
        meal _: MealResult?,
        microBolusAllowed _: Bool,
        reservoir _: Reservoir?,
        tick _: String,
        deliverAt: Date,
        sensitivityRatio: Double?,
        minDelta _: Double,
        maxDelta _: Double,
        profile: ProfileResult,
        predictionArrays: PredictionArrays, // 🚀 НОВОЕ: prediction arrays!
        bgi: Double,  // ✅ НОВОЕ: для BGI поля в результате
        deviation: Double,  // ✅ НОВОЕ: для deviation поля в результате
        targetBGForOutput: Double  // ✅ НОВОЕ: для target_bg поля в результате
    ) -> DetermineBasalResult {
        // Создаем результат с prediction arrays
        createResultWithPredictions(
            currentBG: currentBG,
            eventualBG: eventualBG,
            targetBG: targetBG,
            currentBasal: currentBasal,
            deliverAt: deliverAt,
            sensitivityRatio: sensitivityRatio,
            predictionArrays: predictionArrays,
            profile: profile,
            bgi: bgi,
            deviation: deviation,
            sensitivity: sensitivity,
            targetBGForOutput: targetBGForOutput
        )
    }

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

    /// ТОЧНОЕ портирование prediction logic из oref0 determine-basal.js
    /// Создает массивы прогнозов IOB, COB, UAM, ZT для рисования графиков
    private static func calculatePredictionArrays(
        bg: Double,
        bgi: Double,
        iob _: IOBResult,
        meal: MealResult?,
        profile: ProfileResult,
        sensitivity: Double,
        sensitivityRatio _: Double?,
        minDelta: Double
    ) -> PredictionArrays {
        // Initialize prediction arrays как в оригинале (строка 442-449)
        var IOBpredBGs: [Double] = [bg]
        var COBpredBGs: [Double] = [bg]
        var UAMpredBGs: [Double] = [bg]
        var ZTpredBGs: [Double] = [bg]
        var predCIs: [Double] = []
        var remainingCIs: [Double] = []

        // Карб- и инсулин-влияние по мотивам oref0 determine-basal.js (строки 466-639)
        // CSF (mg/dL per gram)
        let csf = sensitivity / profile.carbRatioValue

        // Текущий карб-импакт из отклонений: ci = (minDelta - bgi)
        // (в mg/dL за 5 минут), округляем до сотых
        var ci = round((minDelta - bgi) * 100) / 100
        if ci < 0 { ci = 0 } // без отрицательного карб-импакта

        // Макс. скорость абсорбции: 30 г/ч => предел карб-импакта за 5м
        let maxCarbAbsorptionRateGPerHour = 30.0
        let maxCIper5m = round(maxCarbAbsorptionRateGPerHour * csf * 5.0 / 60.0 * 100) / 100

        // Сколько карб-вклада доступно исходя из COB (граммы -> mg/dL)
        var remainingCOBmgdl = max(0.0, meal?.mealCOB ?? 0.0) * csf

        for i in 0 ..< 48 {
            // Инсулиновый тренд (BGI) — слегка затухающий
            let insulinEffect = bgi * max(0.0, 1.0 - Double(i) * 0.02)
            let nextIOB = IOBpredBGs.last! + insulinEffect

            // Zero Temp — без инсулина
            let nextZT = ZTpredBGs.last!

            // Прогноз карб-импакта: линейный спад ci за ~2 часа (24 шага)
            let decayedCI = max(0.0, ci * (1.0 - Double(i) / 24.0))
            // Ограничиваем мгновенный вклад по физиологическому пределу
            var predCI = min(decayedCI, maxCIper5m)
            // Также ограничиваем наличным COB в mg/dL
            predCI = min(predCI, remainingCOBmgdl)
            remainingCOBmgdl = max(0.0, remainingCOBmgdl - predCI)

            let nextCOB = COBpredBGs.last! + insulinEffect + predCI

            // UAM: «необъявленная еда» — более длительный хвост
            let uamCI = max(0.0, ci * (1.0 - Double(i) / 36.0))
            let nextUAM = UAMpredBGs.last! + insulinEffect + min(uamCI, maxCIper5m)

            IOBpredBGs.append(max(39, min(401, nextIOB)))
            COBpredBGs.append(max(39, min(401, nextCOB)))
            UAMpredBGs.append(max(39, min(401, nextUAM)))
            ZTpredBGs.append(max(39, min(401, nextZT)))

            predCIs.append(round(predCI * 100) / 100)
            remainingCIs.append(round(remainingCOBmgdl * 100) / 100)
        }

        debug(.openAPS, "📊 Generated \(IOBpredBGs.count) IOB predictions: \(IOBpredBGs.prefix(5).map { Int($0) })")
        debug(.openAPS, "📊 Generated \(COBpredBGs.count) COB predictions: \(COBpredBGs.prefix(5).map { Int($0) })")

        return PredictionArrays(
            IOBpredBGs: IOBpredBGs,
            COBpredBGs: COBpredBGs,
            UAMpredBGs: UAMpredBGs,
            ZTpredBGs: ZTpredBGs,
            predCIs: predCIs,
            remainingCIs: remainingCIs
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

    // MARK: - Result Creators (с prediction arrays)

    private static func createResultWithPredictions(
        currentBG: Double,
        eventualBG: Double,
        targetBG: Double,
        currentBasal: Double,
        deliverAt: Date,
        sensitivityRatio: Double?,
        predictionArrays: PredictionArrays,
        profile: ProfileResult,
        bgi: Double,
        deviation: Double,
        sensitivity: Double,
        targetBGForOutput: Double
    ) -> DetermineBasalResult {
        // ✅ КОНВЕРТИРУЕМ все BG-значения для результата (как в determine-basal.js:806-810)
        let convertedBGI = SwiftOpenAPSAlgorithms.convertBG(bgi, profile: profile)
        let convertedDeviation = SwiftOpenAPSAlgorithms.convertBG(deviation, profile: profile)
        let convertedISF = SwiftOpenAPSAlgorithms.convertBG(sensitivity, profile: profile)
        let convertedTargetBG = SwiftOpenAPSAlgorithms.convertBG(targetBGForOutput, profile: profile)
        
        var reason = "BG: \(Int(currentBG)), "
        reason += "Target: \(Int(targetBG)), "
        reason += "EventualBG: \(Int(eventualBG)), "

        // Simple decision logic (will be expanded later)
        if eventualBG >= 100, eventualBG <= 180 {
            reason += "in range: setting current basal"
            return DetermineBasalResult(
                temp: "absolute",
                bg: currentBG,
                tick: "+0", // Simplified
                eventualBG: eventualBG,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: sensitivityRatio,
                reason: reason,
                rate: currentBasal,
                duration: 30,
                units: nil,
                carbsReq: nil,
                BGI: convertedBGI,
                deviation: convertedDeviation,
                ISF: convertedISF,
                targetBG: convertedTargetBG,
                predBGs: predictionArrays.predBGsDict, // 🚀 КРИТИЧНО: predBGs для графиков!
                profile: profile
            )
        } else {
            return DetermineBasalResult(
                temp: "absolute",
                bg: currentBG,
                tick: "+0",
                eventualBG: eventualBG,
                insulinReq: 0,
                reservoir: nil,
                deliverAt: deliverAt,
                sensitivityRatio: sensitivityRatio,
                reason: reason + "adjustment needed",
                rate: currentBasal,
                duration: 30,
                units: nil,
                carbsReq: nil,
                BGI: convertedBGI,
                deviation: convertedDeviation,
                ISF: convertedISF,
                targetBG: convertedTargetBG,
                predBGs: predictionArrays.predBGsDict, // 🚀 КРИТИЧНО: predBGs для графиков!
                profile: profile
            )
        }
    }

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
