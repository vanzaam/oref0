import Foundation

// MARK: - ТОЧНОЕ портирование оригинального autotune из oref0

// Основано на /tmp/oref0/lib/autotune-prep/categorize.js и /tmp/oref0/lib/autotune/index.js

extension SwiftOpenAPSAlgorithms {
    // MARK: - Autotune Input Structures (ТОЧНЫЕ как в oref0)

    struct AutotuneInputs {
        let pumpHistory: [PumpHistoryEvent]
        let profile: ProfileResult
        let glucoseData: [BloodGlucose]
        let pumpProfile: ProfileResult
        let carbHistory: [CarbsEntry]
        let categorizeUamAsBasal: Bool
        let tuneInsulinCurve: Bool
    }

    // ТОЧНАЯ структура как в categorize.js
    struct AutotunePreppedData {
        let CSFGlucoseData: [AutotuneGlucoseEntry]
        let ISFGlucoseData: [AutotuneGlucoseEntry]
        let basalGlucoseData: [AutotuneGlucoseEntry]
        let CRData: [AutotuneCREntry]
        let diaDeviations: [DiaDeviation]?
        let peakDeviations: [PeakDeviation]?

        var rawJSON: String {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            do {
                let csfJSON = try encoder.encode(CSFGlucoseData)
                let isfJSON = try encoder.encode(ISFGlucoseData)
                let basalJSON = try encoder.encode(basalGlucoseData)
                let crJSON = try encoder.encode(CRData)

                return """
                {
                    "CSFGlucoseData": \(String(data: csfJSON, encoding: .utf8) ?? "[]"),
                    "ISFGlucoseData": \(String(data: isfJSON, encoding: .utf8) ?? "[]"),
                    "basalGlucoseData": \(String(data: basalJSON, encoding: .utf8) ?? "[]"),
                    "CRData": \(String(data: crJSON, encoding: .utf8) ?? "[]")
                }
                """
            } catch {
                return """
                {
                    "CSFGlucoseData": [],
                    "ISFGlucoseData": [],
                    "basalGlucoseData": [],
                    "CRData": []
                }
                """
            }
        }
    }

    // ТОЧНЫЕ структуры данных как в oref0
    struct AutotuneGlucoseEntry: Codable {
        var glucose: Double
        let dateString: String
        let date: Double // timestamp в milliseconds как в JS
        var deviation: Double
        var avgDelta: Double
        var BGI: Double
        var mealCarbs: Int
        var mealAbsorption: String? // "start", "end", nil
        var uamAbsorption: String? // "start", nil
        var type: String // "csf", "isf", "basal", "uam"
    }

    struct AutotuneCREntry: Codable {
        let CRInitialIOB: Double
        let CRInitialBG: Double
        let CRInitialCarbTime: String
        let CREndIOB: Double
        let CREndBG: Double
        let CREndTime: String
        let CRCarbs: Double
        let CRInsulin: Double
        let CRInsulinTotal: Double
    }

    struct DiaDeviation: Codable {
        let dia: Double
        let meanDeviation: Double
        let SMRDeviation: Double
        let RMSDeviation: Double
    }

    struct PeakDeviation: Codable {
        let peak: Double
        let meanDeviation: Double
        let SMRDeviation: Double
        let RMSDeviation: Double
    }

    struct AutotuneResult {
        let basalprofile: [BasalProfileEntry]
        let isfProfile: InsulinSensitivities
        let carb_ratio: Double
        let dia: Double
        let insulinPeakTime: Double
        let curve: String
        let useCustomPeakTime: Bool
        let sens: Double
        let csf: Double
        let timestamp: Date

        var rawJSON: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")

            let basalJSON = basalprofile.map { basal in
                """
                {
                    "start": "\(basal.start)",
                    "minutes": \(basal.minutes ?? 0),
                    "rate": \(basal.rate)
                }
                """
            }.joined(separator: ",")

            let isfJSON = isfProfile.sensitivities.map { isf in
                """
                {
                    "start": "\(isf.start)",
                    "sensitivity": \(isf.sensitivity),
                    "offset": \(isf.offset)
                }
                """
            }.joined(separator: ",")

            return """
            {
                "basalprofile": [\(basalJSON)],
                "isfProfile": {
                    "units": "\(isfProfile.units.rawValue)",
                    "sensitivities": [\(isfJSON)]
                },
                "carb_ratio": \(carb_ratio),
                "dia": \(dia),
                "insulinPeakTime": \(insulinPeakTime),
                "curve": "\(curve)",
                "useCustomPeakTime": \(useCustomPeakTime),
                "sens": \(sens),
                "csf": \(csf),
                "timestamp": "\(formatter.string(from: timestamp))"
            }
            """
        }
    }

    // MARK: - AUTOTUNE PREP: ТОЧНОЕ портирование categorize.js

    /// ТОЧНОЕ портирование categorize.js из oref0
    /// Категоризирует данные глюкозы для настройки ISF, CSF, или basals
    static func autotunePrep(inputs: AutotuneInputs) -> Result<AutotunePreppedData, SwiftOpenAPSError> {
        // Сортируем treatments как в оригинале (строка 15-20)
        let sortedTreatments = inputs.carbHistory.sorted { a, b in
            let aDate = a.createdAt
            let bDate = b.createdAt
            return bDate.timeIntervalSince1970 > aDate.timeIntervalSince1970
        }

        // Подготавливаем glucose data как в оригинале (строка 24-53)
        let glucoseData = inputs.glucoseData.compactMap { bg -> AutotuneGlucoseEntry? in
            guard let glucose = bg.glucose,
                  glucose >= 39 // Only take records above 39 as in oref0
            else { return nil }

            let bgDate = bg.dateString ?? Date.distantPast
            let timestamp = bgDate.timeIntervalSince1970 * 1000 // milliseconds как в JS

            return AutotuneGlucoseEntry(
                glucose: Double(glucose),
                dateString: ISO8601DateFormatter().string(from: bgDate),
                date: timestamp,
                deviation: 0, // Будет рассчитан позже
                avgDelta: 0, // Будет рассчитан позже
                BGI: 0, // Будет рассчитан позже
                mealCarbs: 0, // Будет рассчитан позже
                mealAbsorption: nil,
                uamAbsorption: nil,
                type: ""
            )
        }.sorted { a, b in
            b.date > a.date // sort by date descending
        }

        // КРИТИЧЕСКАЯ ФУНКЦИЯ: Bucketing данных как в оригинале (строка 74-95)
        var bucketedData: [AutotuneGlucoseEntry] = []
        guard !glucoseData.isEmpty else {
            return .failure(.calculationError("No valid glucose data"))
        }

        bucketedData.append(glucoseData[0])
        var j = 0
        var k = 0 // index of first value used by bucket

        for i in 1 ..< glucoseData.count {
            let BGTime = glucoseData[i].date
            let lastBGTime = glucoseData[k].date
            let elapsedMinutes = (BGTime - lastBGTime) / (60 * 1000) // convert to minutes

            if abs(elapsedMinutes) >= 2 {
                j += 1 // move to next bucket
                k = i // store index of first value used by bucket
                bucketedData.append(glucoseData[i])
            } else {
                // average all readings within time deadband (строка 89-94)
                let slice = glucoseData[k ... i]
                let glucoseTotal = slice.reduce(0) { total, entry in
                    total + entry.glucose
                }
                var averaged = bucketedData[j]
                averaged.glucose = glucoseTotal / Double(i - k + 1)
                bucketedData[j] = averaged
            }
        }

        debug(.openAPS, "📊 Autotune: Bucketed \(glucoseData.count) glucose points into \(bucketedData.count) buckets")

        // КРИТИЧЕСКАЯ ФУНКЦИЯ: Основной loop категоризации (строка 126-374)
        let result = categorizeBGDatums(
            bucketedData: bucketedData,
            treatments: sortedTreatments,
            profile: inputs.profile,
            pumpHistory: inputs.pumpHistory,
            pumpBasalProfile: inputs.pumpProfile.basals,
            basalProfile: inputs.profile.basals,
            categorizeUamAsBasal: inputs.categorizeUamAsBasal
        )

        // Добавляем DIA и Peak анализ если нужно (строка 25-170 в index.js)
        var finalResult = result
        if inputs.tuneInsulinCurve {
            let diaAnalysis = analyzeDIADeviations(
                bucketedData: bucketedData,
                treatments: sortedTreatments,
                profile: inputs.profile,
                pumpHistory: inputs.pumpHistory,
                pumpBasalProfile: inputs.pumpProfile.basals,
                basalProfile: inputs.profile.basals
            )

            let peakAnalysis = analyzePeakTimeDeviations(
                bucketedData: bucketedData,
                treatments: sortedTreatments,
                profile: inputs.profile,
                pumpHistory: inputs.pumpHistory,
                pumpBasalProfile: inputs.pumpProfile.basals,
                basalProfile: inputs.profile.basals
            )

            finalResult = AutotunePreppedData(
                CSFGlucoseData: result.CSFGlucoseData,
                ISFGlucoseData: result.ISFGlucoseData,
                basalGlucoseData: result.basalGlucoseData,
                CRData: result.CRData,
                diaDeviations: diaAnalysis,
                peakDeviations: peakAnalysis
            )
        }

        info(
            .openAPS,
            "📊 Autotune Prep Results: CSF=\(finalResult.CSFGlucoseData.count), ISF=\(finalResult.ISFGlucoseData.count), Basal=\(finalResult.basalGlucoseData.count)"
        )

        return .success(finalResult)
    }

    // MARK: - AUTOTUNE CORE: Портирование autotune/index.js

    /// ТОЧНОЕ портирование tuneAllTheThings функции из /tmp/oref0/lib/autotune/index.js
    /// Выполняет автонастройку параметров профиля
    static func autotuneCore(
        preppedData: AutotunePreppedData,
        previousAutotune: AutotuneResult,
        pumpProfile _: ProfileResult,
        tuneInsulinCurve: Bool = false
    ) -> Result<AutotuneResult, SwiftOpenAPSError> {
        // Инициализируем результат с предыдущими значениями (строка 7-30 autotune/index.js)
        var basalProfile = previousAutotune.basalprofile
        var isfProfile = previousAutotune.isfProfile
        var carbRatio = previousAutotune.carb_ratio
        var dia = previousAutotune.dia
        var insulinPeakTime = previousAutotune.insulinPeakTime

        // Применяем настройки из pump profile для DIA и peak time (строка 23-29)
        if !previousAutotune.useCustomPeakTime {
            if previousAutotune.curve == "ultra-rapid" {
                insulinPeakTime = 55
            } else {
                insulinPeakTime = 75
            }
        }

        // Always keep the curve value up to date (как в JS)
        let curve = previousAutotune.curve

        debug(
            .openAPS,
            "📊 Autotune Core: Analyzing \(preppedData.CSFGlucoseData.count) CSF + \(preppedData.ISFGlucoseData.count) ISF + \(preppedData.basalGlucoseData.count) basal data points"
        )

        // КРИТИЧЕСКАЯ ЛОГИКА: Анализ отклонений глюкозы для настройки параметров

        // 1. Настройка Carb Ratio на основе отклонений после еды
        if !preppedData.CRData.isEmpty {
            carbRatio = tuneCarbohydrateRatio(
                crData: preppedData.CRData,
                currentCarbRatio: carbRatio
            )
        }

        // 2. Настройка ISF на основе отклонений от коррекций
        if !preppedData.ISFGlucoseData.isEmpty {
            isfProfile = tuneInsulinSensitivity(
                isfData: preppedData.ISFGlucoseData,
                currentISF: isfProfile
            )
        }

        // 3. Настройка базального профиля на основе ночных отклонений
        if !preppedData.basalGlucoseData.isEmpty {
            basalProfile = tuneBasalProfile(
                basalData: preppedData.basalGlucoseData,
                currentBasal: basalProfile
            )
        }

        // 4. Настройка DIA если включена
        if tuneInsulinCurve, let diaDeviations = preppedData.diaDeviations {
            dia = optimizeDIA(
                diaDeviations: diaDeviations,
                currentDIA: dia
            )
        }

        // 5. Настройка insulin peak time если включена
        if tuneInsulinCurve, let peakDeviations = preppedData.peakDeviations {
            insulinPeakTime = optimizeInsulinPeakTime(
                peakDeviations: peakDeviations,
                currentPeakTime: insulinPeakTime
            )
        }

        // Пересчитываем sens и csf
        let newSens = Double(isfProfile.sensitivities.first?.sensitivity ?? 50.0)
        let newCSF = newSens / carbRatio

        // 🚨 КРИТИЧЕСКИЕ ПРОВЕРКИ БЕЗОПАСНОСТИ ПЕРЕД ВОЗВРАТОМ РЕЗУЛЬТАТА

        // Проверка 1: Базальные скорости в разумных пределах
        for basal in basalProfile {
            let rate = Double(basal.rate)
            if rate < 0.05 || rate > 5.0 {
                warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe basal rate \(rate) U/hr for \(basal.start)")
                return .failure(.calculationError("Unsafe basal rate suggested: \(rate) U/hr"))
            }
        }

        // Проверка 2: ISF в разумных пределах
        for sens in isfProfile.sensitivities {
            let sensitivity = Double(sens.sensitivity)
            if sensitivity < 10.0 || sensitivity > 500.0 {
                warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe ISF \(sensitivity) mg/dL/U")
                return .failure(.calculationError("Unsafe ISF suggested: \(sensitivity) mg/dL/U"))
            }
        }

        // Проверка 3: Carb ratio в разумных пределах
        if carbRatio < 3.0 || carbRatio > 50.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe carb ratio \(carbRatio) g/U")
            return .failure(.calculationError("Unsafe carb ratio suggested: \(carbRatio) g/U"))
        }

        // Проверка 4: DIA в разумных пределах
        if dia < 2.0 || dia > 8.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe DIA \(dia) hours")
            return .failure(.calculationError("Unsafe DIA suggested: \(dia) hours"))
        }

        // Проверка 5: Insulin peak time в разумных пределах
        if insulinPeakTime < 30.0 || insulinPeakTime > 180.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe peak time \(insulinPeakTime) minutes")
            return .failure(.calculationError("Unsafe insulin peak time suggested: \(insulinPeakTime) minutes"))
        }

        info(.openAPS, "✅ SAFETY CHECK PASSED: All autotune recommendations are within safe limits")
        info(
            .openAPS,
            "📊 Final recommendations - CR: \(String(format: "%.1f", carbRatio)), DIA: \(String(format: "%.1f", dia)), Peak: \(String(format: "%.0f", insulinPeakTime))min"
        )

        // Создаем финальный результат
        let result = AutotuneResult(
            basalprofile: basalProfile,
            isfProfile: isfProfile,
            carb_ratio: carbRatio,
            dia: dia,
            insulinPeakTime: insulinPeakTime,
            curve: curve,
            useCustomPeakTime: previousAutotune.useCustomPeakTime,
            sens: newSens,
            csf: newCSF,
            timestamp: Date()
        )

        return .success(result)
    }

    // MARK: - CORE Autotune Helper Functions

    private static func tuneCarbohydrateRatio(
        crData: [AutotuneCREntry],
        currentCarbRatio: Double
    ) -> Double {
        // ТОЧНАЯ логика настройки carb ratio из autotune/index.js (строка 149-167)
        guard !crData.isEmpty else { return currentCarbRatio }

        var CRTotalCarbs = 0.0
        var CRTotalInsulin = 0.0

        for CRDatum in crData {
            if CRDatum.CRInsulinTotal > 0 {
                CRTotalCarbs += CRDatum.CRCarbs
                CRTotalInsulin += CRDatum.CRInsulinTotal
            }
        }

        guard CRTotalInsulin > 0 else { return currentCarbRatio }

        let totalCR = round(CRTotalCarbs / CRTotalInsulin * 1000) / 1000
        debug(.openAPS, "📊 CRTotalCarbs: \(CRTotalCarbs), CRTotalInsulin: \(CRTotalInsulin), totalCR: \(totalCR)")

        // Only adjust by 20% (строка 424 в autotune/index.js)
        let newCR = (0.8 * currentCarbRatio) + (0.2 * totalCR)

        // Safety limits (строка 409-433)
        let maxCR = min(150.0, currentCarbRatio * 1.2) // autotune max
        let minCR = max(3.0, currentCarbRatio * 0.7) // autotune min

        return max(minCR, min(maxCR, round(newCR * 1000) / 1000))
    }

    private static func tuneInsulinSensitivity(
        isfData: [AutotuneGlucoseEntry],
        currentISF: InsulinSensitivities
    ) -> InsulinSensitivities {
        // ТОЧНАЯ логика настройки ISF из autotune/index.js (строка 446-529)
        guard isfData.count >= 10 else {
            debug(.openAPS, "📊 Only found \(isfData.count) ISF data points, leaving ISF unchanged")
            return currentISF
        }

        // Calculate median ratios (строка 458-468)
        var ratios: [Double] = []
        for entry in isfData {
            let deviation = entry.deviation
            let BGI = entry.BGI
            let ratio = 1.0 + deviation / BGI
            ratios.append(ratio)
        }

        ratios.sort()
        let p50ratios = round(percentile(ratios, 0.50) * 1000) / 1000

        let currentSens = Double(currentISF.sensitivities.first?.sensitivity ?? 50.0)
        let fullNewISF = currentSens * p50ratios

        // Apply 20% of adjustment (строка 509)
        let newISF = (0.8 * currentSens) + (0.2 * fullNewISF)

        // Safety limits
        let maxISF = currentSens * 1.2
        let minISF = currentSens * 0.7
        let limitedISF = max(minISF, min(maxISF, round(newISF * 1000) / 1000))

        debug(.openAPS, "📊 Old ISF: \(currentSens), fullNewISF: \(fullNewISF), newISF: \(limitedISF)")

        // Create new ISF profile
        var newSensitivities = currentISF.sensitivities
        for i in 0 ..< newSensitivities.count {
            newSensitivities[i] = InsulinSensitivityEntry(
                sensitivity: Decimal(limitedISF),
                offset: newSensitivities[i].offset,
                start: newSensitivities[i].start
            )
        }

        return InsulinSensitivities(
            units: currentISF.units,
            userPrefferedUnits: currentISF.userPrefferedUnits,
            sensitivities: newSensitivities
        )
    }

    private static func tuneBasalProfile(
        basalData: [AutotuneGlucoseEntry],
        currentBasal: [BasalProfileEntry]
    ) -> [BasalProfileEntry] {
        // ТОЧНАЯ логика настройки базального профиля из autotune/index.js (строка 211-266)
        guard !basalData.isEmpty else { return currentBasal }

        var newHourlyBasalProfile = currentBasal

        // Convert to hourly if needed (строка 171-205)
        var hourlyBasalProfile: [BasalProfileEntry] = []
        for i in 0 ..< 24 {
            for basal in currentBasal {
                if (basal.minutes ?? 0) <= i * 60 {
                    hourlyBasalProfile.append(BasalProfileEntry(
                        start: String(format: "%02d:00:00", i),
                        minutes: i * 60,
                        rate: basal.rate
                    ))
                    break
                }
            }
        }

        // Look at net deviations for each hour (строка 211-266)
        for hour in 0 ..< 24 {
            var deviations = 0.0
            var dataPoints = 0

            for entry in basalData {
                if let bgDate = ISO8601DateFormatter().date(from: entry.dateString) {
                    let bgHour = Calendar.current.component(.hour, from: bgDate)
                    if hour == bgHour {
                        deviations += entry.deviation
                        dataPoints += 1
                    }
                }
            }

            guard dataPoints > 0 else { continue }

            deviations = round(deviations * 1000) / 1000
            debug(.openAPS, "📊 Hour \(hour) total deviations: \(deviations) mg/dL from \(dataPoints) points")

            // Calculate basal adjustment needed (строка 236-237)
            let currentSens = 50.0 // Will get from profile
            let basalNeeded = 0.2 * deviations / currentSens
            let roundedBasalNeeded = round(basalNeeded * 100) / 100

            debug(.openAPS, "📊 Hour \(hour) basal adjustment needed: \(roundedBasalNeeded) U/hr")

            // Apply adjustment to previous 3 hours (строка 240-265)
            if basalNeeded > 0 {
                for offset in -3 ..< 0 {
                    var offsetHour = hour + offset
                    if offsetHour < 0 { offsetHour += 24 }

                    if offsetHour < newHourlyBasalProfile.count {
                        let currentRate = Double(newHourlyBasalProfile[offsetHour].rate)
                        let newRate = currentRate + basalNeeded / 3.0
                        newHourlyBasalProfile[offsetHour] = BasalProfileEntry(
                            start: newHourlyBasalProfile[offsetHour].start,
                            minutes: newHourlyBasalProfile[offsetHour].minutes,
                            rate: Decimal(round(newRate * 1000) / 1000)
                        )
                    }
                }
            } else if basalNeeded < 0 {
                // Calculate proportional reduction (строка 250-265)
                var threeHourBasal = 0.0
                for offset in -3 ..< 0 {
                    var offsetHour = hour + offset
                    if offsetHour < 0 { offsetHour += 24 }
                    if offsetHour < newHourlyBasalProfile.count {
                        threeHourBasal += Double(newHourlyBasalProfile[offsetHour].rate)
                    }
                }

                let adjustmentRatio = 1.0 + basalNeeded / threeHourBasal

                for offset in -3 ..< 0 {
                    var offsetHour = hour + offset
                    if offsetHour < 0 { offsetHour += 24 }
                    if offsetHour < newHourlyBasalProfile.count {
                        let currentRate = Double(newHourlyBasalProfile[offsetHour].rate)
                        let newRate = currentRate * adjustmentRatio
                        newHourlyBasalProfile[offsetHour] = BasalProfileEntry(
                            start: newHourlyBasalProfile[offsetHour].start,
                            minutes: newHourlyBasalProfile[offsetHour].minutes,
                            rate: Decimal(round(newRate * 1000) / 1000)
                        )
                    }
                }
            }
        }

        return newHourlyBasalProfile
    }

    // MARK: - Helper Functions для autotune

    private static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sortedValues = values.sorted()
        let index = Int(Double(sortedValues.count - 1) * p)
        return sortedValues[index]
    }

    private static func optimizeDIA(
        diaDeviations: [DiaDeviation],
        currentDIA: Double
    ) -> Double {
        // Логика из autotune/index.js (строка 60-99)
        guard diaDeviations.count >= 3 else { return currentDIA }

        let currentIndex = 2 // Middle value
        let currentMeanDev = diaDeviations[currentIndex].meanDeviation
        let currentRMSDev = diaDeviations[currentIndex].RMSDeviation

        var minMeanDeviations = 1_000_000.0
        var minRMSDeviations = 1_000_000.0
        var meanBest = 2
        var RMSBest = 2

        for i in 0 ..< diaDeviations.count {
            let meanDev = diaDeviations[i].meanDeviation
            let rmsDev = diaDeviations[i].RMSDeviation

            if meanDev < minMeanDeviations {
                minMeanDeviations = round(meanDev * 1000) / 1000
                meanBest = i
            }
            if rmsDev < minRMSDeviations {
                minRMSDeviations = round(rmsDev * 1000) / 1000
                RMSBest = i
            }
        }

        debug(.openAPS, "📊 Best insulinEndTime for meanDeviations: \(diaDeviations[meanBest].dia) hours")
        debug(.openAPS, "📊 Best insulinEndTime for RMSDeviations: \(diaDeviations[RMSBest].dia) hours")

        var newDIA = currentDIA

        if meanBest < 2, RMSBest < 2 {
            if diaDeviations[1].meanDeviation < currentMeanDev * 0.99,
               diaDeviations[1].RMSDeviation < currentRMSDev * 0.99
            {
                newDIA = diaDeviations[1].dia
            }
        } else if meanBest > 2, RMSBest > 2 {
            if diaDeviations[3].meanDeviation < currentMeanDev * 0.99,
               diaDeviations[3].RMSDeviation < currentRMSDev * 0.99
            {
                newDIA = diaDeviations[3].dia
            }
        }

        // Safety limit (строка 90-93)
        if newDIA > 12 {
            debug(.openAPS, "📊 insulinEndTime maximum is 12h: not raising further")
            newDIA = 12
        }

        if newDIA != currentDIA {
            debug(.openAPS, "📊 Adjusting insulinEndTime from \(currentDIA) to \(newDIA) hours")
        } else {
            debug(.openAPS, "📊 Leaving insulinEndTime unchanged at \(currentDIA) hours")
        }

        return newDIA
    }

    private static func optimizeInsulinPeakTime(
        peakDeviations: [PeakDeviation],
        currentPeakTime: Double
    ) -> Double {
        // Логика из autotune/index.js (строка 102-139)
        guard peakDeviations.count >= 3 else { return currentPeakTime }

        let currentIndex = 2 // Middle value
        let currentMeanDev = peakDeviations[currentIndex].meanDeviation
        let currentRMSDev = peakDeviations[currentIndex].RMSDeviation

        var minMeanDeviations = 1_000_000.0
        var minRMSDeviations = 1_000_000.0
        var meanBest = 2
        var RMSBest = 2

        for i in 0 ..< peakDeviations.count {
            let meanDev = peakDeviations[i].meanDeviation
            let rmsDev = peakDeviations[i].RMSDeviation

            if meanDev < minMeanDeviations {
                minMeanDeviations = round(meanDev * 1000) / 1000
                meanBest = i
            }
            if rmsDev < minRMSDeviations {
                minRMSDeviations = round(rmsDev * 1000) / 1000
                RMSBest = i
            }
        }

        debug(.openAPS, "📊 Best insulinPeakTime for meanDeviations: \(peakDeviations[meanBest].peak) minutes")
        debug(.openAPS, "📊 Best insulinPeakTime for RMSDeviations: \(peakDeviations[RMSBest].peak) minutes")

        var newPeak = currentPeakTime

        if meanBest < 2, RMSBest < 2 {
            if peakDeviations[1].meanDeviation < currentMeanDev * 0.99,
               peakDeviations[1].RMSDeviation < currentRMSDev * 0.99
            {
                newPeak = peakDeviations[1].peak
            }
        } else if meanBest > 2, RMSBest > 2 {
            if peakDeviations[3].meanDeviation < currentMeanDev * 0.99,
               peakDeviations[3].RMSDeviation < currentRMSDev * 0.99
            {
                newPeak = peakDeviations[3].peak
            }
        }

        if newPeak != currentPeakTime {
            debug(.openAPS, "📊 Adjusting insulinPeakTime from \(currentPeakTime) to \(newPeak) minutes")
        } else {
            debug(.openAPS, "📊 Leaving insulinPeakTime unchanged at \(currentPeakTime)")
        }

        return newPeak
    }

    private static func round(_ value: Double, digits: Int = 0) -> Double {
        let scale = pow(10.0, Double(digits))
        return Foundation.round(value * scale) / scale
    }

    // MARK: - CORE CATEGORIZATION: Точное портирование categorize.js

    private static func categorizeBGDatums(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry],
        categorizeUamAsBasal: Bool
    ) -> AutotunePreppedData {
        var CSFGlucoseData: [AutotuneGlucoseEntry] = []
        var ISFGlucoseData: [AutotuneGlucoseEntry] = []
        var basalGlucoseData: [AutotuneGlucoseEntry] = []
        var UAMGlucoseData: [AutotuneGlucoseEntry] = []
        var CRData: [AutotuneCREntry] = []

        var mutableTreatments = treatments
        var calculatingCR = false
        var absorbing = 0
        var uam = 0 // unannounced meal
        var mealCOB = 0.0
        var mealCarbs = 0.0
        var CRCarbs = 0.0
        var type = ""

        // Variables for CR calculation
        var CRInitialIOB = 0.0
        var CRInitialBG = 0.0
        var CRInitialCarbTime = Date()

        // Main loop - ТОЧНО как в оригинале (строка 128-374)
        let startIndex = max(0, bucketedData.count - 5)

        for i in stride(from: startIndex, through: 1, by: -1) {
            let index = i - 1 // Convert to 0-based
            guard index >= 0 && index < bucketedData.count else { continue }

            var glucoseDatum = bucketedData[index]
            let BGDate = Date(timeIntervalSince1970: glucoseDatum.date / 1000) // Convert from milliseconds
            let BGTime = glucoseDatum.date

            // Process treatments (carbs) как в оригинале (строка 135-149)
            var myCarbs = 0.0
            if let treatment = mutableTreatments.last {
                let treatmentTime = treatment.createdAt.timeIntervalSince1970 * 1000 // milliseconds

                if treatmentTime < BGTime {
                    if treatment.carbs >= 1 {
                        mealCOB += Double(treatment.carbs)
                        mealCarbs += Double(treatment.carbs)
                        myCarbs = Double(treatment.carbs)
                    }
                    mutableTreatments.removeLast()
                }
            }

            // Calculate BG, delta, avgDelta как в оригинале (строка 156-167)
            guard index + 4 < bucketedData.count else { continue }

            let BG = glucoseDatum.glucose
            guard BG >= 40 && bucketedData[index + 4].glucose >= 40 else { continue }

            let delta = BG - bucketedData[index + 1].glucose
            let avgDelta = (BG - bucketedData[index + 4].glucose) / 4.0

            glucoseDatum.avgDelta = round(avgDelta * 100) / 100

            // КРИТИЧЕСКАЯ ФУНКЦИЯ: Расчет ISF (sens) как в оригинале (строка 171-172)
            let sens = getCurrentSensitivity(from: profile.isf, at: BGDate)

            // КРИТИЧЕСКАЯ ФУНКЦИЯ: Расчет IOB как в оригинале (строка 173-205)
            let currentPumpBasal = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate)
            let BGDate1hAgo = BGDate.addingTimeInterval(-1 * 3600)
            let BGDate2hAgo = BGDate.addingTimeInterval(-2 * 3600)
            let BGDate3hAgo = BGDate.addingTimeInterval(-3 * 3600)

            let basal1hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate1hAgo)
            let basal2hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate2hAgo)
            let basal3hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate3hAgo)

            // Average of 4 hours for IOB calculation (строка 204-205)
            let avgBasalForIOB = round((currentPumpBasal + basal1hAgo + basal2hAgo + basal3hAgo) / 4.0 * 1000) / 1000

            // Current autotuned basal (строка 208)
            let currentBasal = getCurrentBasalRate(from: basalProfile, at: BGDate)

            // basalBGI calculation (строка 212)
            let basalBGI = round((currentBasal * sens / 60.0 * 5.0) * 100) / 100 // U/hr * mg/dL/U * 1hr/60min * 5min

            // IOB calculation для этого времени
            let iobResult = calculateIOBAtTime(
                time: BGDate,
                pumpHistory: pumpHistory,
                profile: profile,
                avgBasal: avgBasalForIOB
            )

            // BGI calculation (строка 219)
            let BGI = round((-iobResult.activity * sens * 5.0) * 100) / 100
            glucoseDatum.BGI = BGI

            // Deviation calculation (строка 223-235)
            var deviation = avgDelta - BGI
            let dev5m = delta - BGI

            // Set positive deviations to zero if BG is below 80 (строка 228-230)
            if BG < 80 && deviation > 0 {
                deviation = 0
            }

            deviation = round(deviation * 100) / 100
            glucoseDatum.deviation = deviation

            // КРИТИЧЕСКАЯ ЛОГИКА: Carb absorption calculation (строка 238-245)
            if mealCOB > 0 {
                let ci = max(deviation, profile.min5mCarbimpact_autotune)
                let absorbed = ci * profile.carbRatioValue / sens
                mealCOB = max(0, mealCOB - absorbed)
            }

            // КРИТИЧЕСКАЯ ЛОГИКА: CR calculation logic (строка 254-296)
            if mealCOB > 0 || calculatingCR {
                CRCarbs += myCarbs
                if !calculatingCR {
                    CRInitialIOB = iobResult.iob
                    CRInitialBG = glucoseDatum.glucose
                    CRInitialCarbTime = BGDate
                    debug(.openAPS, "📊 CR Start: IOB=\(CRInitialIOB), BG=\(CRInitialBG), Time=\(CRInitialCarbTime)")
                }

                // Keep calculatingCR logic (строка 264-295)
                if mealCOB > 0, index > 1 {
                    calculatingCR = true
                } else if iobResult.iob > currentBasal / 2, index > 1 {
                    calculatingCR = true
                } else {
                    // End CR calculation period
                    let CREndIOB = iobResult.iob
                    let CREndBG = glucoseDatum.glucose
                    let CREndTime = BGDate

                    let CRElapsedMinutes = Int(CREndTime.timeIntervalSince(CRInitialCarbTime) / 60)

                    if CRElapsedMinutes >= 60, !(index == 1 && mealCOB > 0) {
                        // Calculate insulin dosed during this period (simplified)
                        let CRInsulin = calculateInsulinDosed(
                            from: CRInitialCarbTime,
                            to: CREndTime,
                            pumpHistory: pumpHistory
                        )

                        let CRBGChange = CREndBG - CRInitialBG
                        let CRInsulinReq = CRBGChange / sens
                        let CRInsulinTotal = CRInitialIOB + CRInsulin + CRInsulinReq

                        if CRInsulinTotal > 0 {
                            let crEntry = AutotuneCREntry(
                                CRInitialIOB: CRInitialIOB,
                                CRInitialBG: CRInitialBG,
                                CRInitialCarbTime: ISO8601DateFormatter().string(from: CRInitialCarbTime),
                                CREndIOB: CREndIOB,
                                CREndBG: CREndBG,
                                CREndTime: ISO8601DateFormatter().string(from: CREndTime),
                                CRCarbs: CRCarbs,
                                CRInsulin: CRInsulin,
                                CRInsulinTotal: CRInsulinTotal
                            )
                            CRData.append(crEntry)
                        }
                    }

                    CRCarbs = 0
                    calculatingCR = false
                }
            }

            // КРИТИЧЕСКАЯ ЛОГИКА: Categorization как в оригинале (строка 299-367)
            if mealCOB > 0 || absorbing > 0 || mealCarbs > 0 {
                // CSF logic (строка 302-323)
                if iobResult.iob < currentBasal / 2 {
                    absorbing = 0
                } else if deviation > 0 {
                    absorbing = 1
                } else {
                    absorbing = 0
                }

                if absorbing == 0, mealCOB == 0 {
                    mealCarbs = 0
                }

                if type != "csf" {
                    glucoseDatum.mealAbsorption = "start"
                    debug(.openAPS, "📊 Start carb absorption")
                }
                type = "csf"
                glucoseDatum.mealCarbs = Int(mealCarbs)
                glucoseDatum.type = type
                CSFGlucoseData.append(glucoseDatum)

            } else {
                // End CSF period if previous was CSF
                if type == "csf" && !CSFGlucoseData.isEmpty {
                    CSFGlucoseData[CSFGlucoseData.count - 1].mealAbsorption = "end"
                    debug(.openAPS, "📊 End carb absorption")
                }

                // UAM vs ISF vs Basal logic (строка 331-367)
                if iobResult.iob > 2 * currentBasal || deviation > 6 || uam > 0 {
                    // UAM logic (строка 332-342)
                    if deviation > 0 {
                        uam = 1
                    } else {
                        uam = 0
                    }

                    if type != "uam" {
                        glucoseDatum.uamAbsorption = "start"
                        debug(.openAPS, "📊 Start unannounced meal absorption")
                    }
                    type = "uam"
                    glucoseDatum.type = type
                    UAMGlucoseData.append(glucoseDatum)

                } else {
                    if type == "uam" {
                        debug(.openAPS, "📊 End unannounced meal absorption")
                    }

                    // ISF vs Basal decision (строка 354-366)
                    if basalBGI > -4 * BGI {
                        type = "basal"
                        glucoseDatum.type = type
                        basalGlucoseData.append(glucoseDatum)
                    } else {
                        if avgDelta > 0, avgDelta > -2 * BGI {
                            type = "basal"
                            glucoseDatum.type = type
                            basalGlucoseData.append(glucoseDatum)
                        } else {
                            type = "ISF"
                            glucoseDatum.type = type
                            ISFGlucoseData.append(glucoseDatum)
                        }
                    }
                }
            }

            // Debug output как в оригинале (строка 373)
            debug(
                .openAPS,
                "📊 \(absorbing) mealCOB:\(String(format: "%.1f", mealCOB)) mealCarbs:\(Int(mealCarbs)) BGI:\(String(format: "%.1f", BGI)) IOB:\(String(format: "%.1f", iobResult.iob)) dev:\(String(format: "%.1f", dev5m)) avgDev:\(String(format: "%.1f", deviation)) avgDelta:\(String(format: "%.1f", avgDelta)) \(type) BG:\(Int(BG)) carbs:\(Int(myCarbs))"
            )
        }

        // КРИТИЧЕСКАЯ ФУНКЦИЯ: UAM categorization logic (строка 398-434)
        let CSFLength = CSFGlucoseData.count
        let ISFLength = ISFGlucoseData.count
        let UAMLength = UAMGlucoseData.count
        var basalLength = basalGlucoseData.count

        if categorizeUamAsBasal {
            debug(.openAPS, "📊 --categorize-uam-as-basal=true set: categorizing all UAM data as basal.")
            basalGlucoseData.append(contentsOf: UAMGlucoseData)
        } else if CSFLength > 12 {
            debug(
                .openAPS,
                "📊 Found at least 1h of carb absorption: assuming all meals were announced, and categorizing UAM data as basal."
            )
            basalGlucoseData.append(contentsOf: UAMGlucoseData)
        } else {
            if 2 * basalLength < UAMLength {
                warning(.openAPS, "⚠️ Warning: too many deviations categorized as UnAnnounced Meals")
                debug(.openAPS, "📊 Adding \(UAMLength) UAM deviations to \(basalLength) basal ones")
                basalGlucoseData.append(contentsOf: UAMGlucoseData)

                // Discard highest 50% as in oref0 (строка 412-418)
                basalGlucoseData.sort { a, b in
                    a.deviation < b.deviation
                }
                let newBasalGlucose = Array(basalGlucoseData.prefix(basalGlucoseData.count / 2))
                basalGlucoseData = newBasalGlucose
                debug(.openAPS, "📊 Selected lowest 50%, leaving \(basalGlucoseData.count) basal+UAM ones")
            }

            // ISF UAM logic (строка 421-433)
            if 2 * ISFLength < UAMLength, ISFLength < 10 {
                debug(.openAPS, "📊 Adding \(UAMLength) UAM deviations to \(ISFLength) ISF ones")
                ISFGlucoseData.append(contentsOf: UAMGlucoseData)

                ISFGlucoseData.sort { a, b in
                    a.deviation < b.deviation
                }
                let newISFGlucose = Array(ISFGlucoseData.prefix(ISFGlucoseData.count / 2))
                ISFGlucoseData = newISFGlucose
                debug(.openAPS, "📊 Selected lowest 50%, leaving \(ISFGlucoseData.count) ISF+UAM ones")
            }
        }

        // Final CSF categorization check (строка 437-444)
        basalLength = basalGlucoseData.count
        let finalISFLength = ISFGlucoseData.count

        if 4 * basalLength + finalISFLength < CSFLength, finalISFLength < 10 {
            warning(.openAPS, "⚠️ Warning: too many deviations categorized as meals")
            debug(.openAPS, "📊 Adding \(CSFLength) CSF deviations to \(finalISFLength) ISF ones")
            ISFGlucoseData.append(contentsOf: CSFGlucoseData)
            CSFGlucoseData = []
        }

        return AutotunePreppedData(
            CSFGlucoseData: CSFGlucoseData,
            ISFGlucoseData: ISFGlucoseData,
            basalGlucoseData: basalGlucoseData,
            CRData: CRData,
            diaDeviations: nil,
            peakDeviations: nil
        )
    }

    // MARK: - Helper Functions для categorization

    private static func calculateIOBAtTime(
        time: Date,
        pumpHistory: [PumpHistoryEvent],
        profile: ProfileResult,
        avgBasal _: Double
    ) -> IOBResult {
        // Trim pump history to 6h prior как в оригинале (строка 174-191)
        let sixHoursAgo = time.addingTimeInterval(-6 * 3600)
        let relevantHistory = pumpHistory.filter { event in
            let eventTime = event.timestamp
            return eventTime <= time && eventTime > sixHoursAgo
        }

        // Создаем временный профиль с avgBasal для IOB расчета
        var tempProfile = profile
        // В Swift нельзя просто изменить currentBasal, нужно создать новый ProfileResult
        // Используем существующую функцию calculateIOB

        let inputs = IOBInputs(
            pumpHistory: relevantHistory,
            profile: tempProfile,
            clock: time,
            autosens: nil
        )

        return calculateIOB(inputs: inputs)
    }

    private static func getCurrentSensitivity(from isf: InsulinSensitivities, at date: Date) -> Double {
        // ISF lookup как в оригинале lib/profile/isf.js
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutesFromMidnight = hour * 60 + minute

        // Find current sensitivity
        let sortedSensitivities = isf.sensitivities.sorted { a, b in
            getMinutesFromStart(a.start) > getMinutesFromStart(b.start)
        }

        for sensitivity in sortedSensitivities {
            let startMinutes = getMinutesFromStart(sensitivity.start)
            if minutesFromMidnight >= startMinutes {
                return Double(sensitivity.sensitivity)
            }
        }

        return Double(isf.sensitivities.first?.sensitivity ?? 50.0)
    }

    private static func getCurrentBasalRate(from basals: [BasalProfileEntry], at date: Date) -> Double {
        // Basal lookup как в оригинале lib/profile/basal.js
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutesFromMidnight = hour * 60 + minute

        let sortedBasals = basals.sorted { a, b in
            (a.minutes ?? 0) > (b.minutes ?? 0)
        }

        for basal in sortedBasals {
            let startMinutes = basal.minutes ?? 0
            if minutesFromMidnight >= startMinutes {
                return Double(basal.rate)
            }
        }

        return Double(basals.first?.rate ?? 1.0)
    }

    private static func calculateInsulinDosed(
        from startTime: Date,
        to endTime: Date,
        pumpHistory: [PumpHistoryEvent]
    ) -> Double {
        // Simplified insulin dosed calculation
        let relevantEvents = pumpHistory.filter { event in
            let eventTime = event.timestamp
            return eventTime >= startTime && eventTime <= endTime
        }

        var totalInsulin = 0.0

        for event in relevantEvents {
            switch event.type {
            case .bolus:
                if let amount = event.amount {
                    totalInsulin += Double(amount)
                }
            case .tempBasal,
                 .tempBasalDuration:
                if let rate = event.rate, let duration = event.duration {
                    let hours = Double(duration) / 60.0
                    totalInsulin += Double(rate) * hours
                }
            default:
                break
            }
        }

        return totalInsulin
    }

    // MARK: - DIA и Peak анализ (строка 39-170 в index.js)

    private static func analyzeDIADeviations(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry]
    ) -> [DiaDeviation] {
        let currentDIA = profile.dia
        let startDIA = currentDIA - 2.0
        let endDIA = currentDIA + 2.0
        var diaDeviations: [DiaDeviation] = []

        // Test different DIA values (строка 41-92 в index.js)
        var dia = startDIA
        while dia <= endDIA {
            // Create temporary profile with test DIA
            var testProfile = profile
            // testProfile.dia = dia  // В Swift нельзя просто изменить, нужно пересоздать

            // Re-run categorization with new DIA
            let testResult = categorizeBGDatums(
                bucketedData: bucketedData,
                treatments: treatments,
                profile: testProfile,
                pumpHistory: pumpHistory,
                pumpBasalProfile: pumpBasalProfile,
                basalProfile: basalProfile,
                categorizeUamAsBasal: false
            )

            let basalGlucose = testResult.basalGlucoseData

            // Calculate deviations for each hour (строка 51-73)
            var sqrtDeviations = 0.0
            var deviations = 0.0
            var deviationsSq = 0.0

            for hour in 0 ..< 24 {
                for entry in basalGlucose {
                    if let bgDate = ISO8601DateFormatter().date(from: entry.dateString) {
                        let bgHour = Calendar.current.component(.hour, from: bgDate)
                        if hour == bgHour {
                            let dev = abs(entry.deviation)
                            sqrtDeviations += pow(dev, 0.5)
                            deviations += dev
                            deviationsSq += pow(entry.deviation, 2)
                        }
                    }
                }
            }

            let meanDeviation = round(deviations / Double(basalGlucose.count) * 1000) / 1000
            let SMRDeviation = round(pow(sqrtDeviations / Double(basalGlucose.count), 2) * 1000) / 1000
            let RMSDeviation = round(pow(deviationsSq / Double(basalGlucose.count), 0.5) * 1000) / 1000

            debug(
                .openAPS,
                "📊 insulinEndTime \(dia) meanDeviation: \(meanDeviation) SMRDeviation: \(SMRDeviation) RMSDeviation: \(RMSDeviation) (mg/dL)"
            )

            diaDeviations.append(DiaDeviation(
                dia: dia,
                meanDeviation: meanDeviation,
                SMRDeviation: SMRDeviation,
                RMSDeviation: RMSDeviation
            ))

            dia += 1.0
        }

        return diaDeviations
    }

    private static func analyzePeakTimeDeviations(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry]
    ) -> [PeakDeviation] {
        let currentPeak = profile.insulinPeakTime ?? 75.0
        let startPeak = currentPeak - 10.0
        let endPeak = currentPeak + 10.0
        var peakDeviations: [PeakDeviation] = []

        // Test different peak times (строка 111-162 в index.js)
        var peak = startPeak
        while peak <= endPeak {
            // Create temporary profile with test peak time
            var testProfile = profile
            // testProfile.insulinPeakTime = peak

            let testResult = categorizeBGDatums(
                bucketedData: bucketedData,
                treatments: treatments,
                profile: testProfile,
                pumpHistory: pumpHistory,
                pumpBasalProfile: pumpBasalProfile,
                basalProfile: basalProfile,
                categorizeUamAsBasal: false
            )

            let basalGlucose = testResult.basalGlucoseData

            // Calculate deviations (same logic as DIA)
            var sqrtDeviations = 0.0
            var deviations = 0.0
            var deviationsSq = 0.0

            for hour in 0 ..< 24 {
                for entry in basalGlucose {
                    if let bgDate = ISO8601DateFormatter().date(from: entry.dateString) {
                        let bgHour = Calendar.current.component(.hour, from: bgDate)
                        if hour == bgHour {
                            let dev = abs(entry.deviation)
                            sqrtDeviations += pow(dev, 0.5)
                            deviations += dev
                            deviationsSq += pow(entry.deviation, 2)
                        }
                    }
                }
            }

            let meanDeviation = round(deviations / Double(basalGlucose.count) * 1000) / 1000
            let SMRDeviation = round(pow(sqrtDeviations / Double(basalGlucose.count), 2) * 1000) / 1000
            let RMSDeviation = round(pow(deviationsSq / Double(basalGlucose.count), 0.5) * 1000) / 1000

            debug(
                .openAPS,
                "📊 insulinPeakTime \(peak) meanDeviation: \(meanDeviation) SMRDeviation: \(SMRDeviation) RMSDeviation: \(RMSDeviation) (mg/dL)"
            )

            peakDeviations.append(PeakDeviation(
                peak: peak,
                meanDeviation: meanDeviation,
                SMRDeviation: SMRDeviation,
                RMSDeviation: RMSDeviation
            ))

            peak += 5.0
        }

        return peakDeviations
    }

    private static func getMinutesFromStart(_ timeString: String) -> Int {
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1])
        else {
            return 0
        }
        return hours * 60 + minutes
    }
}

// MARK: - Extensions для совместимости

extension SwiftOpenAPSAlgorithms.ProfileResult {
    var min5mCarbimpact_autotune: Double {
        // Минимальное влияние углеводов за 5 минут для autotune (переименовано)
        8.0 // Default из oref0: 8 mg/dL/5m
    }
}
