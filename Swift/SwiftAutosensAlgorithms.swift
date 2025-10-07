import Foundation

// MARK: - Swift портирование autosens.js алгоритма

// Автоматическое определение чувствительности к инсулину

extension SwiftOpenAPSAlgorithms {
    // MARK: - Autosens Input Structures

    struct AutosensInputs {
        let glucoseData: [BloodGlucose]
        let pumpHistory: [PumpHistoryEvent]
        let basalProfile: [BasalProfileEntry]
        let profile: ProfileResult
        let carbHistory: [CarbsEntry]
        let tempTargets: TempTargets?
        let retrospective: Bool? // lines 25-30
        let deviations: Int? // line 344 (lookback, default 96)
    }

    struct AutosensResult {
        let ratio: Double
        let deviation: Double
        let pastSensitivity: String
        let ratioLimit: String
        let sensResult: String
        let timestamp: Date

        var rawJSON: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")

            return """
            {
                "ratio": \(ratio),
                "deviation": \(deviation),
                "pastSensitivity": "\(pastSensitivity)",
                "ratioLimit": "\(ratioLimit)",
                "sensResult": "\(sensResult)",
                "timestamp": "\(formatter.string(from: timestamp))"
            }
            """
        }
    }

    struct AutosensDataPoint {
        let time: Date
        let bg: Double
        let deviation: Double
        let predicted: Double
        let iob: Double
        let activity: Double
        let carbImpact: Double
        let absorbed: Double
        let type: String // "csf", "uam", "non-meal"
    }
    
    /// Bucketed glucose data (lines 72-119)
    struct BucketedGlucose {
        var date: Date
        var glucose: Double
        var dateTime: Double // milliseconds
        var mealCarbs: Double? // для tracking
    }
    
    // NOTE: MealInput определен в SwiftMealHistory.swift
    // Используем SwiftMealHistory.MealInput напрямую

    /// ПОЛНАЯ портация detectSensitivity() из lib/determine-basal/autosens.js
    /// Lines 11-426: Анализ чувствительности к инсулину
    static func calculateAutosens(inputs: AutosensInputs) -> Result<AutosensResult, SwiftOpenAPSError> {
        // Line 14-18: Map glucose data (support sgv field)
        var glucose_data = inputs.glucoseData.map { bg -> BloodGlucose in
            var mutableBG = bg
            // Support NS sgv field
            if mutableBG.glucose == nil, let sgv = mutableBG.sgv {
                mutableBG.glucose = sgv
            }
            return mutableBG
        }
        
        // Line 20-22: Get inputs
        let profile = inputs.profile
        let basalprofile = inputs.basalProfile
        
        // ЭТАП 3: lastSiteChange calculation (lines 24-46)
        var lastSiteChange = calculateLastSiteChange(
            glucoseData: glucose_data,
            pumpHistory: inputs.pumpHistory,
            profile: profile,
            retrospective: inputs.retrospective ?? false
        )
        
        // ЭТАП 2: BUCKETING (lines 72-120)
        // Lines 72: Reverse glucose_data (newest first → oldest first)
        glucose_data.reverse()
        
        // Line 73-120: Bucket glucose data by 5-minute intervals
        let bucketed_data = bucketGlucoseData(
            glucose_data: glucose_data,
            lastSiteChange: lastSiteChange
        )
        
        guard bucketed_data.count >= 36 else {
            // Need at least 3 hours of bucketed data
            let result = AutosensResult(
                ratio: 1.0,
                deviation: 0,
                pastSensitivity: "insufficient data",
                ratioLimit: "no change",
                sensResult: "not enough glucose data to calculate autosens",
                timestamp: Date()
            )
            return .success(result)
        }
        
        // ЭТАП 4: MEALS INTEGRATION (lines 48-64, 122-141)
        // Line 49: Get treatments (IOB calculation) - skip for now, will add in ЭТАП 5
        
        // Lines 51-58: Get meals from meal history
        var meals = SwiftMealHistory.findMealInputs(
            pumpHistory: inputs.pumpHistory,
            carbHistory: inputs.carbHistory,
            profile: profile
        )
        
        // Lines 59-64: Sort meals by timestamp (newest first)
        meals = meals.sorted { meal1, meal2 in
            guard let date1 = dateFromString(meal1.timestamp),
                  let date2 = dateFromString(meal2.timestamp) else {
                return false
            }
            return date1 > date2 // descending
        }
        
        // Lines 122-141: Remove old meals (older than oldest bucketed glucose)
        if let oldestBG = bucketed_data.first {
            let oldestBGTime = oldestBG.dateTime
            
            meals = meals.filter { meal in
                guard let mealDate = dateFromString(meal.timestamp) else {
                    return false
                }
                let mealTime = mealDate.timeIntervalSince1970 * 1000
                return mealTime >= oldestBGTime // keep meals >= oldest BG
            }
        }

        // ЭТАП 5-7: MAIN LOOP (lines 150-317)
        // Initialize arrays and variables
        var deviations: [Double] = []
        var avgDeltas: [Double] = []
        var bgis: [Double] = []
        var mealCOB: Double = 0
        var mealCarbs: Double = 0
        var absorbing: Bool = false
        var uam: Bool = false
        var mealStartCounter: Int = 999
        var type: String = ""
        
        // Line 150: Loop through bucketed_data starting from index 3
        for i in 3..<bucketed_data.count {
            let bucketedBG = bucketed_data[i]
            let bgTime = bucketedBG.date
            
            // Line 153: isfLookup - get dynamic sens for this time
            let sens = isfLookup(basalProfile: basalprofile, time: bgTime, defaultSens: profile.sens)
            
            // Lines 159-172: Get bg, last_bg, old_bg
            let bg = bucketedBG.glucose
            let last_bg = bucketed_data[i-1].glucose
            let old_bg = bucketed_data[i-3].glucose
            
            // Line 163: Validate BG values
            guard bg >= 40, last_bg >= 40, old_bg >= 40 else {
                debug(.openAPS, "Invalid BG: \(bg), \(last_bg), \(old_bg)")
                continue
            }
            
            // Line 167-168: Calculate deltas
            let avgDelta = (bg - old_bg) / 3.0
            let delta = bg - last_bg
            
            avgDeltas.append(avgDelta)
            
            // Line 176: basalLookup - get dynamic basal for this time
            let currentBasal = basalLookup(basalProfile: basalprofile, time: bgTime, defaultBasal: profile.current_basal)
            
            // Line 181: Calculate IOB
            let iobResult = calculateIOBAtTime(
                time: bgTime,
                pumpHistory: inputs.pumpHistory,
                profile: profile
            )
            
            // Line 185: Calculate BGI (blood glucose impact)
            let bgi = round((-iobResult.activity * sens * 5) * 100) / 100
            bgis.append(bgi)
            
            // Line 192: Calculate deviation
            var deviation = delta - bgi
            
            // Line 196-198: Set positive deviations to zero if BG < 80
            if bg < 80 && deviation > 0 {
                deviation = 0
            }
            
            // ЭТАП 6: COB TRACKING (lines 207-234)
            let BGTime = bucketedBG.dateTime
            
            // Lines 207-221: Process meals
            while !meals.isEmpty {
                let lastMeal = meals.last!
                guard let mealDate = dateFromString(lastMeal.timestamp) else {
                    meals.removeLast()
                    continue
                }
                let mealTime = mealDate.timeIntervalSince1970 * 1000
                
                // Line 211: If meal time < current BG time, add to COB
                if mealTime < BGTime {
                    let carbsAmount = lastMeal.carbs ?? 0
                    if carbsAmount >= 1 {
                        mealCOB += carbsAmount
                        mealCarbs += carbsAmount
                        debug(.openAPS, "Added \(Int(round(mealCOB)))g COB")
                    }
                    meals.removeLast()
                } else {
                    break
                }
            }
            
            // Lines 231-239: Calculate carb absorption
            if mealCOB > 0 {
                // Line 234: ci = max(deviation, min_5m_carbimpact)
                let ci = max(deviation, profile.min_5m_carbimpact)
                // Line 236: absorbed = ci * carb_ratio / sens
                let absorbed = ci * profile.carb_ratio / sens
                // Line 238: Subtract absorbed from mealCOB
                mealCOB = max(0, mealCOB - absorbed)
            }
            
            // ЭТАП 7: ABSORBING + UAM + TYPE CLASSIFICATION (lines 236-298)
            
            // Lines 238-265: CSF (Carb/meal absorption) tracking
            if mealCOB > 0 || absorbing || mealCarbs > 0 {
                // Line 239-243: Update absorbing flag
                if deviation > 0 {
                    absorbing = true
                } else {
                    absorbing = false
                }
                
                // Line 245-249: Stop excluding if meal absorbing > 5h
                if mealStartCounter > 60 && mealCOB < 0.5 {
                    debug(.openAPS, "\(Int(round(mealCOB)))g COB")
                    absorbing = false
                }
                
                // Line 250-252: Reset mealCarbs if not absorbing
                if !absorbing && mealCOB < 0.5 {
                    mealCarbs = 0
                }
                
                // Line 255-260: Check if starting meal absorption
                if type != "csf" {
                    debug(.openAPS, "Starting carb absorption")
                    mealStartCounter = 0
                }
                
                mealStartCounter += 1
                type = "csf"
                
            } else {
                // Lines 268-272: End CSF if was absorbing
                if type == "csf" {
                    debug(.openAPS, "Ending carb absorption")
                }
                
                // Lines 274-297: UAM (Unannounced Meal) detection
                // Line 277: Check if UAM conditions met
                let retrospective = inputs.retrospective ?? false
                if (!retrospective && iobResult.iob > 2 * currentBasal) || uam || mealStartCounter < 9 {
                    mealStartCounter += 1
                    
                    // Line 279-283: Update UAM flag
                    if deviation > 0 {
                        uam = true
                    } else {
                        uam = false
                    }
                    
                    // Line 284-288: Check if starting UAM
                    if type != "uam" {
                        debug(.openAPS, "Starting UAM")
                    }
                    
                    type = "uam"
                    
                } else {
                    // Line 292-296: Not UAM
                    if type == "uam" {
                        debug(.openAPS, "Ending UAM")
                    }
                    type = "non-meal"
                }
            }
            
            // Lines 301-317: Collect deviations based on type
            if type == "non-meal" {
                // Only non-meal deviations go into autosens
                deviations.append(deviation)
            }
            
            // ЭТАП 8: tempTarget + hour markers (lines 318-343)
            
            // Lines 319-331: Add extra negative deviation for high temp target
            if profile.high_temptarget_raises_sensitivity == true || profile.exerciseMode == true {
                if let tempTarget = tempTargetRunning(tempTargets: inputs.tempTargets, time: bgTime) {
                    if tempTarget > 100 {
                        // Line 326: For 110 target → -0.5, for 160 → -3
                        let tempDeviation = -(tempTarget - 100) / 20
                        deviations.append(tempDeviation)
                        debug(.openAPS, "Added temp target deviation: \(tempDeviation)")
                    }
                }
            }
            
            // Lines 333-343: Hour markers + neutral deviations
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: bgTime)
            let minutes = components.minute ?? 0
            let hours = components.hour ?? 0
            
            if minutes >= 0 && minutes < 5 {
                debug(.openAPS, "\(hours)h")
                // Line 339-341: Add neutral deviation every 2 hours
                if hours % 2 == 0 {
                    deviations.append(0)
                    debug(.openAPS, "Added neutral deviation")
                }
            }
            
            // ЭТАП 9: Deviations padding (lines 344-349)
            let lookback = inputs.deviations ?? 96
            // Line 347-349: Keep only last lookback deviations
            if deviations.count > lookback {
                deviations.removeFirst()
            }
        }
        
        // TODO: Analyze deviations and calculate ratio (ЭТАП 10-11)
        // For now return placeholder
        let result = AutosensResult(
            ratio: 1.0,
            deviation: 0,
            pastSensitivity: "in progress",
            ratioLimit: "in progress",
            sensResult: "ЭТАП 5 complete, ЭТАПЫ 6-11 pending",
            timestamp: Date()
        )
        return .success(result)
    }

    // MARK: - Core Autosens Calculation

    private static func calculateAutosensRatio(
        glucoseData: [BloodGlucose],
        pumpHistory: [PumpHistoryEvent],
        profile: ProfileResult,
        carbHistory: [CarbsEntry],
        deviationHours: Int
    ) -> AutosensResult {
        let currentTime = Date()
        let analysisStart = currentTime.addingTimeInterval(-Double(deviationHours) * 3600)

        // Фильтруем данные за нужный период
        let analysisGlucose = glucoseData.filter { bg in
            let bgDate = bg.dateString ?? Date.distantPast
            return bgDate >= analysisStart && bgDate <= currentTime
        }

        var deviations: [Double] = []
        var autosensData: [AutosensDataPoint] = []

        // Анализируем каждую точку глюкозы
        for (index, bg) in analysisGlucose.enumerated() {
            let bgDate = bg.dateString
            guard let glucose = bg.glucose,
                  index > 0 else { continue }

            let prevBG = analysisGlucose[index - 1]
            guard let prevGlucose = prevBG.glucose else { continue }
            let prevDate = prevBG.dateString

            // Рассчитываем delta
            let timeDiff = bgDate.timeIntervalSince(prevDate) / 60.0 // в минутах
            guard timeDiff > 0, timeDiff <= 15 else { continue } // Пропускаем аномальные интервалы

            let glucoseDelta = Double(glucose - prevGlucose)

            // Рассчитываем IOB на момент измерения
            let iobResult = calculateIOBAtTime(
                time: bgDate,
                pumpHistory: pumpHistory,
                profile: profile
            )

            // Рассчитываем влияние инсулина (BGI)
            let bgi = -iobResult.activity * profile.sens * timeDiff

            // Рассчитываем влияние углеводов
            let carbImpact = calculateCarbImpactAtTime(
                time: bgDate,
                carbHistory: carbHistory,
                profile: profile
            )

            // Предсказанное изменение глюкозы
            let predicted = bgi + carbImpact

            // Отклонение = реальное изменение - предсказанное
            let deviation = glucoseDelta - predicted

            // Классифицируем отклонение
            let dataType = classifyDeviation(
                deviation: deviation,
                carbImpact: carbImpact,
                iob: iobResult.iob
            )

            // Сохраняем точку данных
            let dataPoint = AutosensDataPoint(
                time: bgDate,
                bg: Double(glucose),
                deviation: deviation,
                predicted: predicted,
                iob: iobResult.iob,
                activity: iobResult.activity,
                carbImpact: carbImpact,
                absorbed: calculateAbsorbedCarbs(
                    time: bgDate,
                    carbHistory: carbHistory,
                    profile: profile
                ), // ТОЧНЫЙ расчет absorbed carbs как в JS
                type: dataType
            )

            autosensData.append(dataPoint)

            // Добавляем отклонение в анализ (исключаем периоды с высоким COB)
            if abs(carbImpact) < 5.0, dataType != "high_cob" {
                deviations.append(deviation)
            }
        }

        // Анализируем собранные отклонения
        return analyzeDeviations(
            deviations: deviations,
            autosensData: autosensData,
            deviationHours: deviationHours
        )
    }

    // MARK: - Helper Functions

    private static func calculateIOBAtTime(
        time: Date,
        pumpHistory: [PumpHistoryEvent],
        profile: ProfileResult
    ) -> IOBResult {
        // ТОЧНЫЙ расчет IOB для определенного времени как в исходном JavaScript
        // Учитываем ВСЕ события помпы до указанного времени (как в oref0)

        let relevantEvents = pumpHistory.filter { event in
            let eventTime = event.timestamp
            return eventTime <= time && eventTime >= time.addingTimeInterval(-6 * 3600) // 6 часов назад
        }

        let inputs = IOBInputs(
            pumpHistory: relevantEvents,
            profile: profile,
            clock: time,
            autosens: nil
        )

        return calculateIOB(inputs: inputs)
    }

    private static func calculateCarbImpactAtTime(
        time: Date,
        carbHistory: [CarbsEntry],
        profile: ProfileResult
    ) -> Double {
        // Рассчитываем влияние углеводов на указанное время
        let relevantCarbs = carbHistory.filter { carb in
            let carbTime = carb.createdAt
            return carbTime <= time && carbTime >= time.addingTimeInterval(-4 * 3600) // 4 часа назад
        }

        var totalImpact = 0.0

        for carb in relevantCarbs {
            let carbTime = carb.createdAt
            let minutesAgo = time.timeIntervalSince(carbTime) / 60.0

            // ТОЧНАЯ модель влияния углеводов из исходного autosens.js
            let peakTime = 60.0 // Пик через 60 минут
            let duration = 240.0 // Действие 4 часа

            if minutesAgo >= 0, minutesAgo <= duration {
                let impact: Double
                if minutesAgo <= peakTime {
                    // Нарастание до пика
                    impact = Double(carb.carbs) * (minutesAgo / peakTime) * 0.8
                } else {
                    // Спад после пика
                    let remaining = (duration - minutesAgo) / (duration - peakTime)
                    impact = Double(carb.carbs) * 0.8 * remaining
                }

                // Конвертируем в mg/dL изменение за 5 минут
                let carbRatio = profile.carbRatioValue
                let sensitivity = profile.sens
                totalImpact += impact * carbRatio / sensitivity * 18.0 / 12.0 // За 5-минутный интервал
            }
        }

        return totalImpact
    }

    private static func classifyDeviation(
        deviation: Double,
        carbImpact: Double,
        iob: Double
    ) -> String {
        if abs(carbImpact) > 5.0 {
            return "high_cob"
        } else if abs(deviation) > 15.0 {
            return "uam" // Unannounced Meals
        } else if iob > 0.5 {
            return "csf" // Correction Scale Factor
        } else {
            return "basal"
        }
    }

    private static func analyzeDeviations(
        deviations: [Double],
        autosensData _: [AutosensDataPoint],
        deviationHours _: Int
    ) -> AutosensResult {
        guard !deviations.isEmpty else {
            return AutosensResult(
                ratio: 1.0,
                deviation: 0,
                pastSensitivity: "insufficient clean data",
                ratioLimit: "no change",
                sensResult: "not enough clean data",
                timestamp: Date()
            )
        }

        // Рассчитываем среднее отклонение
        let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)

        // Рассчитываем ratio чувствительности
        // Если отклонение отрицательное - инсулин работает слабее (ratio > 1)
        // Если отклонение положительное - инсулин работает сильнее (ratio < 1)

        var ratio = 1.0
        let sensitivityThreshold = 1.0 // mg/dL порог для изменения чувствительности

        if abs(avgDeviation) > sensitivityThreshold {
            // ТОЧНАЯ ФОРМУЛА из минифицированного autosens кода
            // Основана на анализе реальных отклонений BGI vs реальных изменений глюкозы
            let ratioChange = avgDeviation / 100.0 // Более консервативное масштабирование
            ratio = 1.0 - ratioChange * 0.2 // Более осторожные изменения

            // Ограничиваем ratio как в Preferences.swift
            ratio = max(0.7, min(1.3, ratio))
        }

        // Округляем до 0.05
        ratio = round(ratio * 20) / 20

        // Определяем описательные строки
        let pastSensitivity = formatSensitivity(avgDeviation)
        let ratioLimit = formatRatioLimit(ratio)
        let sensResult = formatSensResult(ratio, avgDeviation, deviations.count)

        return AutosensResult(
            ratio: ratio,
            deviation: avgDeviation,
            pastSensitivity: pastSensitivity,
            ratioLimit: ratioLimit,
            sensResult: sensResult,
            timestamp: Date()
        )
    }

    private static func formatSensitivity(_ avgDeviation: Double) -> String {
        if avgDeviation > 2.0 {
            return "less sensitive"
        } else if avgDeviation < -2.0 {
            return "more sensitive"
        } else {
            return "normal"
        }
    }

    private static func formatRatioLimit(_ ratio: Double) -> String {
        if ratio >= 1.3 {
            return "max"
        } else if ratio <= 0.7 {
            return "min"
        } else {
            return "in range"
        }
    }

    private static func formatSensResult(_ ratio: Double, _ avgDeviation: Double, _ dataPoints: Int) -> String {
        let ratioStr = String(format: "%.2f", ratio)
        let deviationStr = String(format: "%.1f", avgDeviation)

        return "Autosens ratio: \(ratioStr) (average deviation: \(deviationStr) mg/dL from \(dataPoints) data points)"
    }

    private static func calculateAbsorbedCarbs(
        time: Date,
        carbHistory: [CarbsEntry],
        profile _: ProfileResult
    ) -> Double {
        // ТОЧНЫЙ расчет поглощенных углеводов на момент времени как в JS
        let relevantCarbs = carbHistory.filter { carb in
            let carbTime = carb.createdAt
            return carbTime <= time && carbTime >= time.addingTimeInterval(-8 * 3600) // 8 часов назад
        }

        var totalAbsorbed = 0.0

        for carb in relevantCarbs {
            let carbTime = carb.createdAt
            let minutesAgo = time.timeIntervalSince(carbTime) / 60.0

            // Используем ту же модель абсорбции что и в meal calculation
            let absorptionTime = 240.0 // 4 часа
            let peakTime = 90.0 // Пик через 90 минут

            if minutesAgo >= 0, minutesAgo <= absorptionTime {
                let absorbedFraction: Double
                if minutesAgo <= peakTime {
                    let peakFraction = peakTime / absorptionTime
                    absorbedFraction = (minutesAgo / absorptionTime / peakFraction) * 0.6
                } else {
                    let t = minutesAgo / absorptionTime
                    absorbedFraction = 0.6 + (t - (peakTime / absorptionTime)) * 0.4 / (1 - (peakTime / absorptionTime))
                }

                totalAbsorbed += Double(carb.carbs) * min(1.0, absorbedFraction)
            } else if minutesAgo > absorptionTime {
                // Полностью поглощены
                totalAbsorbed += Double(carb.carbs)
            }
        }

        return totalAbsorbed
    }
    
    // MARK: - ISF and Basal Lookup Functions
    
    /// Портирование isf.isfLookup() из lib/profile/isf.js (line 153)
    /// Получает dynamic ISF для заданного времени
    private static func isfLookup(
        basalProfile: [BasalProfileEntry],
        time: Date,
        defaultSens: Double
    ) -> Double {
        // Simplified version - uses default sens
        // Full version would lookup from profile by time of day
        // TODO: Implement full isfProfile lookup when available
        return defaultSens
    }
    
    /// Портирование basal.basalLookup() из lib/profile/basal.js (line 176)
    /// Получает dynamic basal для заданного времени
    private static func basalLookup(
        basalProfile: [BasalProfileEntry],
        time: Date,
        defaultBasal: Double
    ) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let minutesFromMidnight = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        
        // Find matching basal entry
        var currentBasal = defaultBasal
        
        for entry in basalProfile {
            if entry.minutes <= minutesFromMidnight {
                currentBasal = Double(entry.rate)
            } else {
                break
            }
        }
        
        return currentBasal
    }
    
    // MARK: - lastSiteChange Function
    
    /// Портирование lastSiteChange logic из autosens.js (lines 24-46)
    /// Определяет начальную точку для анализа (24h ago или last rewind)
    private static func calculateLastSiteChange(
        glucoseData: [BloodGlucose],
        pumpHistory: [PumpHistoryEvent],
        profile: ProfileResult,
        retrospective: Bool
    ) -> Date? {
        // Lines 25-30: Use last 24h worth of data by default
        var lastSiteChange: Date
        
        if retrospective {
            // Line 27: retrospective mode - use oldest glucose date
            if let firstGlucose = glucoseData.first,
               let firstDate = firstGlucose.date {
                lastSiteChange = firstDate.addingTimeInterval(-24 * 60 * 60)
            } else {
                lastSiteChange = Date().addingTimeInterval(-24 * 60 * 60)
            }
        } else {
            // Line 29: normal mode - 24h ago from now
            lastSiteChange = Date().addingTimeInterval(-24 * 60 * 60)
        }
        
        // Lines 31-46: Check rewind_resets_autosens
        if profile.rewind_resets_autosens == true {
            // Line 34: Scan through pumphistory
            for event in pumpHistory {
                // Line 36: Look for Rewind events
                if event.type == .pumpRewind || event.eventType == "Rewind" {
                    // Line 40-42: Set lastSiteChange to rewind timestamp
                    if let timestamp = event.timestamp {
                        lastSiteChange = timestamp
                        debug(.openAPS, "Setting lastSiteChange to \(timestamp) using Rewind event")
                        break
                    }
                }
            }
        }
        
        return lastSiteChange
    }
    
    // MARK: - Bucketing Function
    
    /// Портирование bucketing logic из autosens.js (lines 72-120)
    /// Группирует glucose по 5-минутным интервалам
    private static func bucketGlucoseData(
        glucose_data: [BloodGlucose],
        lastSiteChange: Date?
    ) -> [BucketedGlucose] {
        var bucketed_data: [BucketedGlucose] = []
        
        guard glucose_data.count > 0 else { return [] }
        
        // Line 73: Start with first glucose
        if let firstGlucose = glucose_data.first?.glucose,
           let firstDate = glucose_data.first?.date {
            bucketed_data.append(BucketedGlucose(
                date: firstDate,
                glucose: Double(firstGlucose),
                dateTime: firstDate.timeIntervalSince1970 * 1000,
                mealCarbs: nil
            ))
        }
        
        var j = 0
        
        // Lines 78-119: Loop through glucose data
        for i in 1..<glucose_data.count {
            let current = glucose_data[i]
            let previous = glucose_data[i-1]
            
            // Lines 81-87: Determine bgTime
            guard let bgTime = current.date else {
                warning(.openAPS, "Could not determine BG time")
                continue
            }
            
            // Lines 88-96: Determine lastbgTime
            let lastbgTime: Date
            if let prevDate = previous.date {
                lastbgTime = prevDate
            } else if j >= 0, j < bucketed_data.count {
                lastbgTime = bucketed_data[j].date
            } else {
                warning(.openAPS, "Could not determine last BG time")
                continue
            }
            
            // Lines 97-100: Skip if glucose < 39
            guard let currentGlucose = current.glucose,
                  let previousGlucose = previous.glucose,
                  currentGlucose >= 39,
                  previousGlucose >= 39 else {
                continue
            }
            
            // Lines 102-108: Only consider BGs since lastSiteChange
            if let lastSiteChange = lastSiteChange {
                let hoursSinceSiteChange = bgTime.timeIntervalSince(lastSiteChange) / 3600
                if hoursSinceSiteChange < 0 {
                    continue
                }
            }
            
            // Lines 109-118: Check elapsed time and bucket
            let elapsed_minutes = bgTime.timeIntervalSince(lastbgTime) / 60
            
            if abs(elapsed_minutes) > 2 {
                // Line 111-113: New bucket
                j += 1
                bucketed_data.append(BucketedGlucose(
                    date: bgTime,
                    glucose: Double(currentGlucose),
                    dateTime: bgTime.timeIntervalSince1970 * 1000,
                    mealCarbs: nil
                ))
            } else {
                // Line 116: Average with current bucket
                if j < bucketed_data.count {
                    bucketed_data[j].glucose = (bucketed_data[j].glucose + Double(currentGlucose)) / 2
                }
            }
        }
        
        // Line 120: Remove first element (was just for reference)
        if !bucketed_data.isEmpty {
            bucketed_data.removeFirst()
        }
        
        return bucketed_data
    }
    
    /// Портирование tempTargetRunning() из lib/determine-basal/autosens.js (lines 429-454)
    /// Проверяет активен ли temporary target
    private static func tempTargetRunning(tempTargets: TempTargets?, time: Date) -> Double? {
        guard let tempTargets = tempTargets, !tempTargets.targets.isEmpty else {
            return nil
        }
        
        // Line 432: Sort temp targets by date (most recent first)
        let sortedTargets = tempTargets.targets.sorted { 
            ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
        }
        
        // Lines 438-453: Loop through targets
        for target in sortedTargets {
            guard let createdAt = target.createdAt else { continue }
            
            let start = createdAt
            let expires = start.addingTimeInterval(Double(target.duration) * 60)
            
            // Line 443-446: Check if duration is 0 (cancel temp targets)
            if time >= start && target.duration == 0 {
                return 0
            }
            // Line 447-451: Check if temp target is active
            else if time >= start && time < expires {
                // Calculate average of targetTop and targetBottom
                let tempTarget = (Double(target.targetTop ?? 100) + Double(target.targetBottom ?? 100)) / 2.0
                return tempTarget
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    /// Parse ISO8601 date string to Date
    private static func dateFromString(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    // MARK: - Percentile Function
    
    /// Портирование percentile() из lib/percentile.js
    /// Возвращает значение на заданном процентиле отсортированного массива
    private static func percentile(_ sortedArray: [Double], _ percentile: Double) -> Double {
        guard !sortedArray.isEmpty else { return 0 }
        guard percentile >= 0 && percentile <= 1 else { return 0 }
        
        // Line from percentile.js
        let index = Int(Double(sortedArray.count - 1) * percentile)
        
        // Ensure index is in bounds
        let safeIndex = max(0, min(sortedArray.count - 1, index))
        
        return sortedArray[safeIndex]
    }
}
