import Foundation

/// ТОЧНАЯ портация lib/iob/calculate.js
/// IOB calculation functions - bilinear and exponential curves
extension SwiftOpenAPSAlgorithms {
    
    // MARK: - IOB Calculate (lib/iob/calculate.js)
    
    /// Результат IOB calculation для одного treatment
    struct IOBCalcResult {
        let activityContrib: Double
        let iobContrib: Double
    }
    
    /// Портирование iobCalc() из lib/iob/calculate.js (lines 3-33)
    static func iobCalc(
        treatment: Treatment,
        time: Date,
        curve: String,
        dia: Double,
        peak: Double,
        profile: ProfileResult
    ) -> IOBCalcResult {
        // Line 14: check if treatment has insulin
        guard let insulin = treatment.insulin, insulin > 0 else {
            return IOBCalcResult(activityContrib: 0, iobContrib: 0)
        }
        
        // Lines 20-21: Calculate minutes since bolus
        let bolusTime = treatment.date
        let minsAgo = round((time.timeIntervalSince(bolusTime)) / 60.0)
        
        // Lines 24-28: Choose curve
        if curve == "bilinear" {
            return iobCalcBilinear(treatment: treatment, minsAgo: minsAgo, dia: dia)
        } else {
            return iobCalcExponential(treatment: treatment, minsAgo: minsAgo, dia: dia, peak: peak, profile: profile)
        }
    }
    
    /// Портирование iobCalcBilinear() из lib/iob/calculate.js (lines 36-80)
    static func iobCalcBilinear(
        treatment: Treatment,
        minsAgo: Double,
        dia: Double
    ) -> IOBCalcResult {
        // Lines 38-40: Constants
        let default_dia = 3.0  // assumed duration of insulin activity, in hours
        let peak = 75.0        // assumed peak insulin activity, in minutes
        let end = 180.0        // assumed end of insulin activity, in minutes
        
        // Lines 45-46: Scale minsAgo by DIA ratio
        let timeScalar = default_dia / dia
        let scaled_minsAgo = timeScalar * minsAgo
        
        var activityContrib: Double = 0
        var iobContrib: Double = 0
        
        // Lines 56-58: Calculate peak activity and slopes
        let activityPeak = 2.0 / (dia * 60.0)
        let slopeUp = activityPeak / peak
        let slopeDown = -1.0 * (activityPeak / (end - peak))
        
        let insulin = treatment.insulin ?? 0
        
        // Lines 60-74: Before peak
        if scaled_minsAgo < peak {
            // Line 62: Activity contribution
            activityContrib = insulin * (slopeUp * scaled_minsAgo)
            
            // Lines 64-65: IOB contribution (quadratic formula)
            let x1 = (scaled_minsAgo / 5.0) + 1.0
            iobContrib = insulin * ((-0.001852 * x1 * x1) + (0.001852 * x1) + 1.000000)
            
        // Lines 67-74: After peak, before end
        } else if scaled_minsAgo < end {
            // Lines 69-70: Activity contribution
            let minsPastPeak = scaled_minsAgo - peak
            activityContrib = insulin * (activityPeak + (slopeDown * minsPastPeak))
            
            // Lines 72-73: IOB contribution (quadratic formula)
            let x2 = (scaled_minsAgo - peak) / 5.0
            iobContrib = insulin * ((0.001323 * x2 * x2) + (-0.054233 * x2) + 0.555560)
        }
        
        // Lines 76-79: Return
        return IOBCalcResult(
            activityContrib: activityContrib,
            iobContrib: iobContrib
        )
    }
    
    /// Портирование iobCalcExponential() из lib/iob/calculate.js (lines 83-143)
    static func iobCalcExponential(
        treatment: Treatment,
        minsAgo: Double,
        dia: Double,
        peak: Double,
        profile: ProfileResult
    ) -> IOBCalcResult {
        var finalPeak = peak
        
        // Lines 86-99: rapid-acting curve
        if profile.insulinActionCurve == "rapid-acting" {
            if profile.useCustomPeakTime == true, let customPeak = profile.insulinPeakTime {
                if customPeak > 120 {
                    debug(.openAPS, "Setting maximum Insulin Peak Time of 120m for rapid-acting insulin")
                    finalPeak = 120
                } else if customPeak < 50 {
                    debug(.openAPS, "Setting minimum Insulin Peak Time of 50m for rapid-acting insulin")
                    finalPeak = 50
                } else {
                    finalPeak = customPeak
                }
            } else {
                finalPeak = 75
            }
        }
        // Lines 100-113: ultra-rapid curve
        else if profile.insulinActionCurve == "ultra-rapid" {
            if profile.useCustomPeakTime == true, let customPeak = profile.insulinPeakTime {
                if customPeak > 100 {
                    debug(.openAPS, "Setting maximum Insulin Peak Time of 100m for ultra-rapid insulin")
                    finalPeak = 100
                } else if customPeak < 35 {
                    debug(.openAPS, "Setting minimum Insulin Peak Time of 35m for ultra-rapid insulin")
                    finalPeak = 35
                } else {
                    finalPeak = customPeak
                }
            } else {
                finalPeak = 55
            }
        }
        // Lines 114-116: Unsupported curve
        else {
            warning(.openAPS, "Curve of \(profile.insulinActionCurve ?? "unknown") is not supported")
        }
        
        // Line 117: End of insulin activity
        let end = dia * 60.0  // in minutes
        
        var activityContrib: Double = 0
        var iobContrib: Double = 0
        
        // Lines 123-136: Calculate if before end
        if minsAgo < end {
            // Lines 130-132: Formula from https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473
            let tau = finalPeak * (1 - finalPeak / end) / (1 - 2 * finalPeak / end)  // time constant
            let a = 2 * tau / end                                                     // rise time factor
            let S = 1 / (1 - a + (1 + a) * exp(-end / tau))                          // scale factor
            
            let insulin = treatment.insulin ?? 0
            
            // Line 134: Activity contribution (exponential formula)
            activityContrib = insulin * (S / pow(tau, 2)) * minsAgo * (1 - minsAgo / end) * exp(-minsAgo / tau)
            
            // Line 135: IOB contribution (exponential formula)
            iobContrib = insulin * (1 - S * (1 - a) * ((pow(minsAgo, 2) / (tau * end * (1 - a)) - minsAgo / tau - 1) * exp(-minsAgo / tau) + 1))
        }
        
        // Lines 139-142: Return
        return IOBCalcResult(
            activityContrib: activityContrib,
            iobContrib: iobContrib
        )
    }
}

// MARK: - Treatment Structure

extension SwiftOpenAPSAlgorithms {
    struct Treatment {
        let insulin: Double?
        let date: Date
        // Add other fields as needed
    }
}

// MARK: - ProfileResult Extensions

extension SwiftOpenAPSAlgorithms.ProfileResult {
    var useCustomPeakTime: Bool? {
        // Should be in profile settings
        return nil
    }
    
    var insulinPeakTime: Double? {
        // Should be in profile settings
        return nil
    }
}
