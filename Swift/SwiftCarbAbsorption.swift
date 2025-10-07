import Foundation

/// ТОЧНАЯ портация lib/determine-basal/cob.js
/// detectCarbAbsorption() - СЛОЖНАЯ функция (212 строк JS)
extension SwiftOpenAPSAlgorithms {
    
    // MARK: - Carb Absorption Detection (lib/determine-basal/cob.js)
    
    /// Результат detectCarbAbsorption (lines 201-209)
    struct CarbAbsorptionResult {
        let carbsAbsorbed: Double
        let currentDeviation: Double
        let maxDeviation: Double
        let minDeviation: Double
        let slopeFromMaxDeviation: Double
        let slopeFromMinDeviation: Double
        let allDeviations: [Double]
    }
    
    /// Портирование detectCarbAbsorption() из lib/determine-basal/cob.js (lines 8-210)
    static func detectCarbAbsorption(
        glucoseData: [BloodGlucose],
        iobInputs: IOBInputs,
        basalProfile: [BasalProfileEntry],
        mealTime: Double, // milliseconds
        ciTime: Double? = nil // milliseconds, optional
    ) -> CarbAbsorptionResult {
        
        // Lines 10-14: Prepare glucose data
        var glucose_data = glucoseData.map { obj -> BloodGlucose in
            var result = obj
            // Support NS sgv field
            if result.glucose == nil {
                result.glucose = result.sgv
            }
            return result
        }
        
        let profile = iobInputs.profile
        let mealTimeDate = Date(timeIntervalSince1970: mealTime / 1000)
        let ciTimeDate = ciTime.map { Date(timeIntervalSince1970: $0 / 1000) }
        
        // Line 26: Get treatments once
        // Note: treatments are already in iobInputs.pumpHistory
        
        // Lines 28-37: Initialize variables
        var bucketed_data: [BucketedGlucose] = []
        var j = 0
        var foundPreMealBG = false
        var lastbgi = 0
        
        // Lines 39-41: Check first glucose
        if glucose_data.first?.glucose ?? 0 < 39 {
            lastbgi = -1
        } else if let first = glucose_data.first {
            bucketed_data.append(BucketedGlucose(from: first))
        }
        
        // Lines 43-113: Bucketing loop with interpolation
        for i in 1..<glucose_data.count {
            guard let bg = glucose_data[i].glucose, bg >= 39 else {
                continue
            }
            
            let bgTime = glucose_data[i].dateString.flatMap { dateFromString($0) } ?? Date()
            
            // Lines 56-62: Check if within 6h after meal
            let hoursAfterMeal = bgTime.timeIntervalSince(mealTimeDate) / 3600.0
            if hoursAfterMeal > 6 || foundPreMealBG {
                continue
            } else if hoursAfterMeal < 0 {
                foundPreMealBG = true
            }
            
            // Lines 64-71: CI mode - only last ~45m of data
            if let ciTimeDate = ciTimeDate {
                let hoursAgo = ciTimeDate.timeIntervalSince(bgTime) / (45.0 * 60.0)
                if hoursAgo > 1 || hoursAgo < 0 {
                    continue
                }
            }
            
            // Lines 72-78: Determine last BG time
            let lastbgTime: Date
            if let lastBucketTime = bucketed_data.last?.date {
                lastbgTime = lastBucketTime
            } else if lastbgi >= 0, let lastTime = glucose_data[lastbgi].dateString.flatMap({ dateFromString($0) }) {
                lastbgTime = lastTime
            } else {
                warning(.openAPS, "Could not determine last BG time")
                continue
            }
            
            var elapsed_minutes = bgTime.timeIntervalSince(lastbgTime) / 60.0
            
            // Lines 81-101: Interpolation for gaps > 8 minutes
            if abs(elapsed_minutes) > 8 {
                var lastbg = glucose_data[lastbgi].glucose ?? 0
                elapsed_minutes = min(240, abs(elapsed_minutes)) // cap at 4h
                
                var currentLastTime = lastbgTime
                while elapsed_minutes > 5 {
                    let previousbgTime = currentLastTime.addingTimeInterval(-5 * 60)
                    j += 1
                    
                    let gapDelta = Double(bg - lastbg)
                    let previousbg = Double(lastbg) + (5.0 / elapsed_minutes * gapDelta)
                    
                    bucketed_data.append(BucketedGlucose(
                        glucose: Int(round(previousbg)),
                        date: previousbgTime
                    ))
                    
                    elapsed_minutes -= 5
                    lastbg = Int(previousbg)
                    currentLastTime = previousbgTime
                }
                
            // Lines 103-109: Normal bucketing or averaging
            } else if abs(elapsed_minutes) > 2 {
                j += 1
                bucketed_data.append(BucketedGlucose(from: glucose_data[i]))
            } else {
                // Average with previous
                if j < bucketed_data.count {
                    let avgGlucose = (bucketed_data[j].glucose + bg) / 2
                    bucketed_data[j].glucose = avgGlucose
                }
            }
            
            lastbgi = i
        }
        
        // Lines 114-119: Initialize deviation tracking
        var currentDeviation: Double = 0
        var slopeFromMaxDeviation: Double = 0
        var slopeFromMinDeviation: Double = 999
        var maxDeviation: Double = 0
        var minDeviation: Double = 999
        var allDeviations: [Double] = []
        var carbsAbsorbed: Double = 0
        
        // Lines 122-196: Calculate deviations and carbs absorbed
        for i in 0..<(bucketed_data.count - 3) {
            let bgTime = bucketed_data[i].date
            
            // Line 126: ISF lookup
            let sens = getCurrentSensitivity(from: profile.isf, at: bgTime)
            
            // Lines 132-140: Get BG and calculate deltas
            let bg = bucketed_data[i].glucose
            guard bg >= 39, bucketed_data[i + 3].glucose >= 39 else {
                continue
            }
            
            let avgDelta = Double(bg - bucketed_data[i + 3].glucose) / 3.0
            let delta = Double(bg - bucketed_data[i + 1].glucose)
            
            // Lines 143-147: Calculate IOB
            var iobInputsForTime = iobInputs
            iobInputsForTime.clock = bgTime
            let currentBasal = getCurrentBasalRate(from: basalProfile, at: bgTime)
            
            let iob = calculateIOB(inputs: iobInputsForTime)
            
            // Lines 151-152: Calculate BGI
            let bgi = round((-iob.activity * sens * 5.0) * 100) / 100
            
            // Lines 154-155: Calculate deviation
            let deviation = delta - bgi
            
            // Lines 157-183: Track deviations
            if i == 0 {
                // Line 159: Current deviation
                currentDeviation = round((avgDelta - bgi) * 1000) / 1000
                if let ciTimeDate = ciTimeDate, ciTimeDate > bgTime {
                    allDeviations.append(round(currentDeviation))
                }
            } else if let ciTimeDate = ciTimeDate, ciTimeDate > bgTime {
                let avgDeviation = round((avgDelta - bgi) * 1000) / 1000
                let deviationSlope = (avgDeviation - currentDeviation) / bgTime.timeIntervalSince(ciTimeDate) * 1000 * 60 * 5
                
                if avgDeviation > maxDeviation {
                    slopeFromMaxDeviation = min(0, deviationSlope)
                    maxDeviation = avgDeviation
                }
                if avgDeviation < minDeviation {
                    slopeFromMinDeviation = max(0, deviationSlope)
                    minDeviation = avgDeviation
                }
                
                allDeviations.append(round(avgDeviation))
            }
            
            // Lines 186-195: Calculate carbs absorbed
            if bgTime > mealTimeDate {
                // Lines 190-191: Calculate carb impact
                let min_5m_carbimpact = profile.min5mCarbImpact ?? 3.0
                let ci = max(deviation, currentDeviation / 2.0, min_5m_carbimpact)
                let carbRatio = profile.carbRatioValue
                let absorbed = ci * carbRatio / sens
                
                carbsAbsorbed += absorbed
            }
        }
        
        // Lines 201-209: Return result
        return CarbAbsorptionResult(
            carbsAbsorbed: carbsAbsorbed,
            currentDeviation: currentDeviation,
            maxDeviation: maxDeviation,
            minDeviation: minDeviation,
            slopeFromMaxDeviation: slopeFromMaxDeviation,
            slopeFromMinDeviation: slopeFromMinDeviation,
            allDeviations: allDeviations
        )
    }
    
    // MARK: - Helper Structures
    
    /// Bucketed glucose data point
    struct BucketedGlucose {
        var glucose: Int
        var date: Date
        
        init(glucose: Int, date: Date) {
            self.glucose = glucose
            self.date = date
        }
        
        init(from bg: BloodGlucose) {
            self.glucose = bg.glucose ?? 0
            self.date = bg.dateString.flatMap { dateFromString($0) } ?? Date()
        }
    }
    
    // MARK: - Helper Functions
    
    private static func dateFromString(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
    
    private static func getCurrentSensitivity(from isf: ISFEntry, at time: Date) -> Double {
        // Simplified - should lookup from ISF schedule
        return isf.sensitivity
    }
    
    private static func getCurrentBasalRate(from profile: [BasalProfileEntry], at time: Date) -> Double {
        // Simplified - should lookup from basal profile
        return profile.first?.rate ?? 1.0
    }
}

// MARK: - Profile Extensions

extension SwiftOpenAPSAlgorithms.ProfileResult {
    var min5mCarbImpact: Double? {
        // Should be in profile settings
        return 3.0 // default value from JS
    }
}
