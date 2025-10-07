import Foundation

// MARK: - Shared Autotune Structures
// Based on lib/autotune-prep/ and lib/autotune/ from oref0

extension SwiftOpenAPSAlgorithms {
    // MARK: - Input Structures (from autotune-prep and autotune)
    
    struct AutotuneInputs {
        let pumpHistory: [PumpHistoryEvent]
        let profile: ProfileResult
        let glucoseData: [BloodGlucose]
        let pumpProfile: ProfileResult
        let carbHistory: [CarbsEntry]
        let categorizeUamAsBasal: Bool
        let tuneInsulinCurve: Bool
    }
    
    // MARK: - Prepared Data Structure (from autotune-prep/categorize.js)
    
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
    
    // MARK: - Data Entry Structures
    
    struct AutotuneGlucoseEntry: Codable {
        var glucose: Double
        let dateString: String
        let date: Double // timestamp in milliseconds as in JS
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
    
    // MARK: - Result Structure (from autotune/index.js)
    
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
}

// MARK: - Extensions for compatibility

extension SwiftOpenAPSAlgorithms.ProfileResult {
    var min5mCarbimpact_autotune: Double {
        // Minimum carb impact per 5 minutes for autotune
        8.0 // Default from oref0: 8 mg/dL/5m
    }
}
