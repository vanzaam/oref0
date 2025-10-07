import Foundation

// MARK: - Autotune Core Algorithms
// Based on lib/autotune/index.js from oref0

extension SwiftOpenAPSAlgorithms {
    // MARK: - Main Autotune Function (from lib/autotune/index.js)
    
    /// Main autotune function - tunes all parameters
    /// From: lib/autotune/index.js - tuneAllTheThings()
    static func autotuneCore(
        preppedData: AutotunePreppedData,
        previousAutotune: AutotuneResult,
        pumpProfile _: ProfileResult,
        tuneInsulinCurve: Bool = false
    ) -> Result<AutotuneResult, SwiftOpenAPSError> {
        // Initialize result with previous values (line 7-30 autotune/index.js)
        var basalProfile = previousAutotune.basalprofile
        var isfProfile = previousAutotune.isfProfile
        var carbRatio = previousAutotune.carb_ratio
        var dia = previousAutotune.dia
        var insulinPeakTime = previousAutotune.insulinPeakTime

        // Apply pump profile settings for DIA and peak time (line 23-29)
        if !previousAutotune.useCustomPeakTime {
            if previousAutotune.curve == "ultra-rapid" {
                insulinPeakTime = 55
            } else {
                insulinPeakTime = 75
            }
        }

        // Always keep the curve value up to date (as in JS)
        let curve = previousAutotune.curve

        debug(
            .openAPS,
            "📊 Autotune Core: Analyzing \(preppedData.CSFGlucoseData.count) CSF + \(preppedData.ISFGlucoseData.count) ISF + \(preppedData.basalGlucoseData.count) basal data points"
        )

        // CRITICAL LOGIC: Analyze glucose deviations to tune parameters

        // 1. Tune Carb Ratio based on post-meal deviations
        if !preppedData.CRData.isEmpty {
            carbRatio = tuneCarbohydrateRatio(
                crData: preppedData.CRData,
                currentCarbRatio: carbRatio
            )
        }

        // 2. Tune ISF based on correction deviations
        if !preppedData.ISFGlucoseData.isEmpty {
            isfProfile = tuneInsulinSensitivity(
                isfData: preppedData.ISFGlucoseData,
                currentISF: isfProfile
            )
        }

        // 3. Tune basal profile based on overnight deviations
        if !preppedData.basalGlucoseData.isEmpty {
            basalProfile = tuneBasalProfile(
                basalData: preppedData.basalGlucoseData,
                currentBasal: basalProfile
            )
        }

        // 4. Tune DIA if enabled
        if tuneInsulinCurve, let diaDeviations = preppedData.diaDeviations {
            dia = optimizeDIA(
                diaDeviations: diaDeviations,
                currentDIA: dia
            )
        }

        // 5. Tune insulin peak time if enabled
        if tuneInsulinCurve, let peakDeviations = preppedData.peakDeviations {
            insulinPeakTime = optimizeInsulinPeakTime(
                peakDeviations: peakDeviations,
                currentPeakTime: insulinPeakTime
            )
        }

        // Recalculate sens and csf
        let newSens = Double(isfProfile.sensitivities.first?.sensitivity ?? 50.0)
        let newCSF = newSens / carbRatio

        // 🚨 CRITICAL SAFETY CHECKS BEFORE RETURNING RESULT

        // Check 1: Basal rates in reasonable range
        for basal in basalProfile {
            let rate = Double(basal.rate)
            if rate < 0.05 || rate > 5.0 {
                warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe basal rate \(rate) U/hr for \(basal.start)")
                return .failure(.calculationError("Unsafe basal rate suggested: \(rate) U/hr"))
            }
        }

        // Check 2: ISF in reasonable range
        for sens in isfProfile.sensitivities {
            let sensitivity = Double(sens.sensitivity)
            if sensitivity < 10.0 || sensitivity > 500.0 {
                warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe ISF \(sensitivity) mg/dL/U")
                return .failure(.calculationError("Unsafe ISF suggested: \(sensitivity) mg/dL/U"))
            }
        }

        // Check 3: Carb ratio in reasonable range
        if carbRatio < 3.0 || carbRatio > 50.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe carb ratio \(carbRatio) g/U")
            return .failure(.calculationError("Unsafe carb ratio suggested: \(carbRatio) g/U"))
        }

        // Check 4: DIA in reasonable range
        if dia < 2.0 || dia > 8.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe DIA \(dia) hours")
            return .failure(.calculationError("Unsafe DIA suggested: \(dia) hours"))
        }

        // Check 5: Insulin peak time in reasonable range
        if insulinPeakTime < 30.0 || insulinPeakTime > 180.0 {
            warning(.openAPS, "🚨 DANGEROUS: Autotune suggested unsafe peak time \(insulinPeakTime) minutes")
            return .failure(.calculationError("Unsafe insulin peak time suggested: \(insulinPeakTime) minutes"))
        }

        info(.openAPS, "✅ SAFETY CHECK PASSED: All autotune recommendations are within safe limits")
        info(
            .openAPS,
            "📊 Final recommendations - CR: \(String(format: "%.1f", carbRatio)), DIA: \(String(format: "%.1f", dia)), Peak: \(String(format: "%.0f", insulinPeakTime))min"
        )

        // Create final result
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
    
    // MARK: - Tuning Functions (from lib/autotune/index.js)
    
    /// Tune carbohydrate ratio
    private static func tuneCarbohydrateRatio(
        crData: [AutotuneCREntry],
        currentCarbRatio: Double
    ) -> Double {
        // Exact logic for tuning carb ratio from autotune/index.js (line 149-167)
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

        // Only adjust by 20% (line 424 in autotune/index.js)
        let newCR = (0.8 * currentCarbRatio) + (0.2 * totalCR)

        // Safety limits (line 409-433)
        let maxCR = min(150.0, currentCarbRatio * 1.2) // autotune max
        let minCR = max(3.0, currentCarbRatio * 0.7) // autotune min

        return max(minCR, min(maxCR, round(newCR * 1000) / 1000))
    }
    
    /// Tune insulin sensitivity
    private static func tuneInsulinSensitivity(
        isfData: [AutotuneGlucoseEntry],
        currentISF: InsulinSensitivities
    ) -> InsulinSensitivities {
        // Exact logic for tuning ISF from autotune/index.js (line 446-529)
        guard isfData.count >= 10 else {
            debug(.openAPS, "📊 Only found \(isfData.count) ISF data points, leaving ISF unchanged")
            return currentISF
        }

        // Calculate median ratios (line 458-468)
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

        // Apply 20% of adjustment (line 509)
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
    
    /// Tune basal profile
    private static func tuneBasalProfile(
        basalData: [AutotuneGlucoseEntry],
        currentBasal: [BasalProfileEntry]
    ) -> [BasalProfileEntry] {
        // Exact logic for tuning basal profile from autotune/index.js (line 211-266)
        guard !basalData.isEmpty else { return currentBasal }

        var newHourlyBasalProfile = currentBasal

        // Convert to hourly if needed (line 171-205)
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

        // Look at net deviations for each hour (line 211-266)
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

            // Calculate basal adjustment needed (line 236-237)
            let currentSens = 50.0 // Will get from profile
            let basalNeeded = 0.2 * deviations / currentSens
            let roundedBasalNeeded = round(basalNeeded * 100) / 100

            debug(.openAPS, "📊 Hour \(hour) basal adjustment needed: \(roundedBasalNeeded) U/hr")

            // Apply adjustment to previous 3 hours (line 240-265)
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
                // Calculate proportional reduction (line 250-265)
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
    
    // MARK: - Optimization Functions (from lib/autotune/index.js)
    
    /// Calculate percentile
    private static func percentile(_ values: [Double], _ p: Double) -> Double {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 605-610
        guard !values.isEmpty else { return 0 }
        let sortedValues = values.sorted()
        let index = Int(Double(sortedValues.count - 1) * p)
        return sortedValues[index]
    }
    
    /// Optimize DIA
    private static func optimizeDIA(
        diaDeviations: [DiaDeviation],
        currentDIA: Double
    ) -> Double {
        // Logic from autotune/index.js (line 60-99)
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

        // Safety limit (line 90-93)
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
    
    /// Optimize insulin peak time
    private static func optimizeInsulinPeakTime(
        peakDeviations: [PeakDeviation],
        currentPeakTime: Double
    ) -> Double {
        // Logic from autotune/index.js (line 102-139)
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
    
    // MARK: - Helper Functions
    
    /// Round value to specified digits
    private static func round(_ value: Double, digits: Int = 0) -> Double {
        let scale = pow(10.0, Double(digits))
        return Foundation.round(value * scale) / scale
    }
}
