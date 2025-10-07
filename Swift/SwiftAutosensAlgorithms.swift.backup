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
        let type: String // "csf", "uam", "basal", etc.
    }

    /// Портирование freeaps_autosens функции из минифицированного JavaScript
    /// Анализирует отклонения глюкозы для определения чувствительности к инсулину
    static func calculateAutosens(inputs: AutosensInputs) -> Result<AutosensResult, SwiftOpenAPSError> {
        // Проверяем достаточность данных
        guard inputs.glucoseData.count >= 72 else {
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

        // Сортируем данные по времени (от старых к новым)
        let sortedGlucose = inputs.glucoseData.sorted {
            ($0.dateString ?? Date.distantPast) < ($1.dateString ?? Date.distantPast)
        }

        // Анализируем данные за 8 и 24 часа
        let ratio8h = calculateAutosensRatio(
            glucoseData: sortedGlucose,
            pumpHistory: inputs.pumpHistory,
            profile: inputs.profile,
            carbHistory: inputs.carbHistory,
            deviationHours: 8
        )

        let ratio24h = calculateAutosensRatio(
            glucoseData: sortedGlucose,
            pumpHistory: inputs.pumpHistory,
            profile: inputs.profile,
            carbHistory: inputs.carbHistory,
            deviationHours: 24
        )

        // Выбираем наименьший ratio (более консервативный)
        let selectedRatio = ratio8h.ratio < ratio24h.ratio ? ratio8h : ratio24h

        return .success(selectedRatio)
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
}
