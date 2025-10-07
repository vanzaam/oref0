import Foundation

/// ТОЧНАЯ портация lib/iob/total.js
/// Total IOB calculation with DIA validation and curve support
enum SwiftIOBTotal {
    
    // MARK: - IOB Total (lib/iob/total.js)
    
    /// Curve defaults из lib/iob/total.js (lines 29-44)
    struct CurveDefaults {
        let requireLongDia: Bool
        let peak: Double
        let tdMin: Double?
        
        static let bilinear = CurveDefaults(requireLongDia: false, peak: 75, tdMin: nil)
        static let rapidActing = CurveDefaults(requireLongDia: true, peak: 75, tdMin: 300)
        static let ultraRapid = CurveDefaults(requireLongDia: true, peak: 55, tdMin: 300)
        
        static func getCurve(_ name: String) -> CurveDefaults {
            switch name.lowercased() {
            case "bilinear":
                return .bilinear
            case "rapid-acting":
                return .rapidActing
            case "ultra-rapid":
                return .ultraRapid
            default:
                warning(.openAPS, "Unsupported curve function: \"\(name)\". Defaulting to rapid-acting")
                return .rapidActing
            }
        }
    }
    
    /// Портирование iobTotal() из lib/iob/total.js (lines 3-103)
    static func iobTotal(
        treatments: [Treatment],
        profile: ProfileResult,
        time: Date,
        calculate: (Treatment, Date, String, Double, Double, ProfileResult) -> IOBCalcResult
    ) -> IOBTotalResult {
        
        let now = time.timeIntervalSince1970 * 1000 // milliseconds
        
        // Line 9: Get DIA
        var dia = profile.dia
        
        // Lines 23-27: force minimum DIA of 3h
        if dia < 3.0 {
            dia = 3.0
        }
        
        // Lines 46-50: Get curve
        let curveName = profile.insulinActionCurve ?? "bilinear"
        let curve = curveName.lowercased()
        
        // Lines 52-55: Validate curve
        let defaults = CurveDefaults.getCurve(curve)
        
        // Lines 59-63: Force minimum of 5 hour DIA for exponential curves
        if defaults.requireLongDia && dia < 5.0 {
            dia = 5.0
        }
        
        let peak = defaults.peak
        
        // Lines 10-17: Initialize accumulators
        var iob: Double = 0
        var basaliob: Double = 0
        var bolusiob: Double = 0
        var netbasalinsulin: Double = 0
        var bolusinsulin: Double = 0
        var activity: Double = 0
        
        // Lines 67-92: Process each treatment
        for treatment in treatments {
            let treatmentTime = treatment.date.timeIntervalSince1970 * 1000
            
            // Line 68: Only treatments in the past
            if treatmentTime <= now {
                // Line 69: DIA-based window
                let dia_ago = now - dia * 60 * 60 * 1000
                
                if treatmentTime > dia_ago {
                    // Line 72: Calculate IOB for this treatment
                    let tIOB = calculate(treatment, time, curve, dia, peak, profile)
                    
                    // Lines 73-74: Accumulate IOB and activity
                    if tIOB.iobContrib > 0 {
                        iob += tIOB.iobContrib
                    }
                    if tIOB.activityContrib > 0 {
                        activity += tIOB.activityContrib
                    }
                    
                    // Lines 80-88: Split basal vs bolus IOB
                    if let insulin = treatment.insulin, insulin > 0, tIOB.iobContrib > 0 {
                        if insulin < 0.1 {
                            // Basal
                            basaliob += tIOB.iobContrib
                            netbasalinsulin += insulin
                        } else {
                            // Bolus
                            bolusiob += tIOB.iobContrib
                            bolusinsulin += insulin
                        }
                    }
                }
            }
        }
        
        // Lines 94-102: Return with rounding
        return IOBTotalResult(
            iob: round(iob * 1000) / 1000,
            activity: round(activity * 10000) / 10000,
            basaliob: round(basaliob * 1000) / 1000,
            bolusiob: round(bolusiob * 1000) / 1000,
            netbasalinsulin: round(netbasalinsulin * 1000) / 1000,
            bolusinsulin: round(bolusinsulin * 1000) / 1000,
            time: time
        )
    }
    
    // MARK: - Result Structure
    
    struct IOBTotalResult {
        let iob: Double
        let activity: Double
        let basaliob: Double
        let bolusiob: Double
        let netbasalinsulin: Double
        let bolusinsulin: Double
        let time: Date
    }
}
