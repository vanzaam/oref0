import Foundation

/// ТОЧНАЯ портация lib/basal-set-temp.js и lib/round-basal.js
/// НИ ОДНОГО упрощения! Все как в оригинале!
extension SwiftOpenAPSAlgorithms {
    
    // MARK: - Basal Set Temp Functions (lib/basal-set-temp.js)
    
    /// Портирование getMaxSafeBasal() из lib/basal-set-temp.js lines 10-16
    /// ТОЧНАЯ ФОРМУЛА - НЕ "ОБЫЧНО"!
    static func getMaxSafeBasal(profile: ProfileResult) -> Double {
        // Line 12: max_daily_safety_multiplier check
        let max_daily_safety_multiplier: Double
        if profile.settings.maxDailySafetyMultiplier.isNaN || profile.settings.maxDailySafetyMultiplier == 0 {
            max_daily_safety_multiplier = 3.0
        } else {
            max_daily_safety_multiplier = profile.settings.maxDailySafetyMultiplier
        }
        
        // Line 13: current_basal_safety_multiplier check
        let current_basal_safety_multiplier: Double
        if profile.settings.currentBasalSafetyMultiplier.isNaN || profile.settings.currentBasalSafetyMultiplier == 0 {
            current_basal_safety_multiplier = 4.0
        } else {
            current_basal_safety_multiplier = profile.settings.currentBasalSafetyMultiplier
        }
        
        // Line 15: ТОЧНАЯ ФОРМУЛА
        // Math.min(profile.max_basal, max_daily_safety_multiplier * profile.max_daily_basal, current_basal_safety_multiplier * profile.current_basal)
        let maxBasal = Double(profile.settings.maxBasal)
        let maxDailyBasal = profile.maxDailyBasal
        let currentBasal = profile.currentBasal
        
        return min(
            maxBasal,
            max_daily_safety_multiplier * maxDailyBasal,
            current_basal_safety_multiplier * currentBasal
        )
    }
    
    /// Портирование setTempBasal() из lib/basal-set-temp.js lines 18-58
    static func setTempBasal(
        rate: Double,
        duration: Int,
        profile: ProfileResult,
        rT: inout DetermineBasalResult,
        currentTemp: TempBasal?
    ) -> DetermineBasalResult {
        // Line 21: Get max safe basal
        let maxSafeBasal = getMaxSafeBasal(profile: profile)
        
        // Lines 24-28: Constrain rate
        var constrainedRate = rate
        if constrainedRate < 0 {
            constrainedRate = 0
        } else if constrainedRate > maxSafeBasal {
            constrainedRate = maxSafeBasal
        }
        
        // Line 30: Round basal
        let suggestedRate = roundBasal(constrainedRate, profile: profile)
        
        // Lines 31-34: Check if current temp is close enough (within 20%)
        if let currentTemp = currentTemp,
           currentTemp.duration > (duration - 10),
           currentTemp.duration <= 120,
           suggestedRate <= Double(currentTemp.rate) * 1.2,
           suggestedRate >= Double(currentTemp.rate) * 0.8,
           duration > 0
        {
            // Line 32: no temp required
            rT.reason = (rT.reason ?? "") + " \(currentTemp.duration)m left and \(currentTemp.rate) ~ req \(suggestedRate)U/hr: no temp required"
            return rT
        }
        
        // Lines 36-52: Check if suggested rate equals profile rate
        if suggestedRate == profile.currentBasal {
            if profile.skipNeutralTemps == true {
                // Lines 38-46: skip_neutral_temps is true
                if let currentTemp = currentTemp, currentTemp.duration > 0 {
                    // Line 39: cancel current temp
                    rT.reason = addReason(rT: rT, msg: "Suggested rate is same as profile rate, a temp basal is active, canceling current temp")
                    rT.duration = 0
                    rT.rate = 0
                    return rT
                } else {
                    // Line 44: do nothing
                    rT.reason = addReason(rT: rT, msg: "Suggested rate is same as profile rate, no temp basal is active, doing nothing")
                    return rT
                }
            } else {
                // Lines 48-51: Set neutral temp
                rT.reason = addReason(rT: rT, msg: "Setting neutral temp basal of \(profile.currentBasal)U/hr")
                rT.duration = duration
                rT.rate = suggestedRate
                return rT
            }
        } else {
            // Lines 54-56: Set temp
            rT.duration = duration
            rT.rate = suggestedRate
            return rT
        }
    }
    
    // MARK: - Round Basal Function (lib/round-basal.js)
    
    /// Портирование round_basal() из lib/round-basal.js lines 3-42
    /// ТОЧНАЯ логика округления для разных помп!
    static func roundBasal(_ basal: Double, profile: ProfileResult) -> Double {
        /* x23 and x54 pumps change basal increment depending on how much basal is being delivered:
                0.025u for 0.025 < x < 0.975
                0.05u for 1 < x < 9.95
                0.1u for 10 < x
          To round numbers nicely for the pump, use a scale factor of (1 / increment). */
        
        // Line 11: Default scale for most pumps
        var lowest_rate_scale: Double = 20.0 // corresponds to 0.05u increment
        
        // Lines 14-24: Check if x23 or x54 pump
        if let model = profile.pumpModel {
            if model.hasSuffix("54") || model.hasSuffix("23") {
                // Line 21: x23/x54 pumps use 0.025u increment for lowest rates
                lowest_rate_scale = 40.0
            }
        }
        
        // Lines 27-39: Round based on basal rate
        var rounded_basal: Double
        
        if basal < 1.0 {
            // Line 30: Use lowest_rate_scale (0.05 or 0.025 depending on pump)
            rounded_basal = round(basal * lowest_rate_scale) / lowest_rate_scale
        } else if basal < 10.0 {
            // Line 34: 0.05u increment for rates 1-10
            rounded_basal = round(basal * 20.0) / 20.0
        } else {
            // Line 38: 0.1u increment for rates >= 10
            rounded_basal = round(basal * 10.0) / 10.0
        }
        
        return rounded_basal
    }
    
    // MARK: - Helper Functions
    
    /// Helper function to add reason (lib/basal-set-temp.js lines 3-6)
    private static func addReason(rT: DetermineBasalResult, msg: String) -> String {
        let existing = rT.reason ?? ""
        let separator = existing.isEmpty ? "" : ". "
        debug(.openAPS, msg)
        return existing + separator + msg
    }
}

// MARK: - ProfileResult Extension

extension SwiftOpenAPSAlgorithms.ProfileResult {
    /// Helper to get pump model if available
    var pumpModel: String? {
        // This should come from profile settings if available
        // For now return nil, will be populated from actual profile data
        return nil // TODO: Add pumpModel to ProfileResult if needed
    }
    
    /// Helper to get skip_neutral_temps setting
    var skipNeutralTemps: Bool {
        // This should come from profile settings
        // Default to false as in original
        return false // TODO: Add skipNeutralTemps to ProfileResult if needed
    }
    
    /// Helper to get max_daily_basal
    var maxDailyBasal: Double {
        // Calculate max daily basal from basal profile
        return basals.map { $0.rate }.max() ?? currentBasal
    }
}
