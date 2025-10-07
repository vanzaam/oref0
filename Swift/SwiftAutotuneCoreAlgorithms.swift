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
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 420-450
        // TODO: Copy implementation
        return currentCarbRatio
    }
    
    /// Tune insulin sensitivity
    private static func tuneInsulinSensitivity(
        isfData: [AutotuneGlucoseEntry],
        currentISF: InsulinSensitivities
    ) -> InsulinSensitivities {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 452-502
        // TODO: Copy implementation
        return currentISF
    }
    
    /// Tune basal profile
    private static func tuneBasalProfile(
        basalData: [AutotuneGlucoseEntry],
        currentBasal: [BasalProfileEntry]
    ) -> [BasalProfileEntry] {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 504-601
        // TODO: Copy implementation
        return currentBasal
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
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 612-674
        // TODO: Copy implementation
        return currentDIA
    }
    
    /// Optimize insulin peak time
    private static func optimizeInsulinPeakTime(
        peakDeviations: [PeakDeviation],
        currentPeakTime: Double
    ) -> Double {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 676-732
        // TODO: Copy implementation
        return currentPeakTime
    }
    
    // MARK: - Helper Functions
    
    /// Round value to specified digits
    private static func round(_ value: Double, digits: Int = 0) -> Double {
        let scale = pow(10.0, Double(digits))
        return Foundation.round(value * scale) / scale
    }
}
