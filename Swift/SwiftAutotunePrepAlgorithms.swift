import Foundation

// MARK: - Autotune Prep Algorithms
// Based on lib/autotune-prep/ from oref0

extension SwiftOpenAPSAlgorithms {
    // MARK: - Main Prep Function (from lib/autotune-prep/index.js)
    
    /// Main autotune prep function - categorizes glucose data for tuning
    /// From: lib/autotune-prep/index.js
    static func autotunePrep(inputs: AutotuneInputs) -> Result<AutotunePreppedData, SwiftOpenAPSError> {
        // Sort treatments as in original (line 15-20)
        let sortedTreatments = inputs.carbHistory.sorted { a, b in
            let aDate = a.createdAt
            let bDate = b.createdAt
            return bDate.timeIntervalSince1970 > aDate.timeIntervalSince1970
        }

        // Prepare glucose data as in original (line 24-53)
        let glucoseData = inputs.glucoseData.compactMap { bg -> AutotuneGlucoseEntry? in
            guard let glucose = bg.glucose,
                  glucose >= 39 // Only take records above 39 as in oref0
            else { return nil }

            let bgDate = bg.dateString ?? Date.distantPast
            let timestamp = bgDate.timeIntervalSince1970 * 1000 // milliseconds as in JS

            return AutotuneGlucoseEntry(
                glucose: Double(glucose),
                dateString: ISO8601DateFormatter().string(from: bgDate),
                date: timestamp,
                deviation: 0, // Calculated during autotune processing
                avgDelta: 0, // Calculated during autotune processing
                BGI: 0, // Calculated during autotune processing
                mealCarbs: 0, // Calculated during autotune processing
                mealAbsorption: nil,
                uamAbsorption: nil,
                type: ""
            )
        }.sorted { a, b in
            b.date > a.date // sort by date descending
        }

        // CRITICAL FUNCTION: Bucketing data as in original (line 74-95)
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
                // average all readings within time deadband (line 89-94)
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

        // CRITICAL FUNCTION: Main categorization loop (line 126-374)
        let result = categorizeBGDatums(
            bucketedData: bucketedData,
            treatments: sortedTreatments,
            profile: inputs.profile,
            pumpHistory: inputs.pumpHistory,
            pumpBasalProfile: inputs.pumpProfile.basals,
            basalProfile: inputs.profile.basals,
            categorizeUamAsBasal: inputs.categorizeUamAsBasal
        )

        // Add DIA and Peak analysis if needed (line 25-170 in index.js)
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
    
    // MARK: - Categorization (from lib/autotune-prep/categorize.js)
    
    /// Categorizes BG datums for ISF, CSF, or basal tuning
    /// From: lib/autotune-prep/categorize.js
    private static func categorizeBGDatums(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry],
        categorizeUamAsBasal: Bool
    ) -> AutotunePreppedData {
        // NOTE: This function body needs to be copied from SwiftAutotuneAlgorithms.swift lines 741-1058
        // TODO: Copy implementation from SwiftAutotuneAlgorithms.swift
        return AutotunePreppedData(
            CSFGlucoseData: [],
            ISFGlucoseData: [],
            basalGlucoseData: [],
            CRData: [],
            diaDeviations: nil,
            peakDeviations: nil
        )
    }
    
    // MARK: - Helper Functions (from lib/autotune-prep/dosed.js and helpers)
    
    /// Calculate IOB at specific time
    private static func calculateIOBAtTime(
        time: Date,
        pumpHistory: [PumpHistoryEvent],
        profile: ProfileResult,
        avgBasal _: Double
    ) -> IOBResult {
        // Trim pump history to 6h prior as in original (line 174-191)
        let sixHoursAgo = time.addingTimeInterval(-6 * 3600)
        let relevantHistory = pumpHistory.filter { event in
            let eventTime = event.timestamp
            return eventTime <= time && eventTime > sixHoursAgo
        }

        // Create temp profile with avgBasal for IOB calculation
        var tempProfile = profile
        // In Swift we can't just change currentBasal, need to create new ProfileResult
        // Use existing calculateIOB function

        let inputs = IOBInputs(
            pumpHistory: relevantHistory,
            profile: tempProfile,
            clock: time,
            autosens: nil
        )

        return calculateIOB(inputs: inputs)
    }
    
    /// Get current sensitivity from ISF profile
    private static func getCurrentSensitivity(from isf: InsulinSensitivities, at date: Date) -> Double {
        // ISF lookup as in original lib/profile/isf.js
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
    
    /// Get current basal rate from profile
    private static func getCurrentBasalRate(from basals: [BasalProfileEntry], at date: Date) -> Double {
        // Basal lookup as in original lib/profile/basal.js
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
    
    /// Calculate insulin dosed in time period
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
    
    // MARK: - DIA and Peak Analysis (from lib/autotune-prep/categorize.js)
    
    /// Analyze DIA deviations
    private static func analyzeDIADeviations(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry]
    ) -> [DiaDeviation] {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 1168-1240
        // TODO: Copy implementation
        return []
    }
    
    /// Analyze peak time deviations
    private static func analyzePeakTimeDeviations(
        bucketedData: [AutotuneGlucoseEntry],
        treatments: [CarbsEntry],
        profile: ProfileResult,
        pumpHistory: [PumpHistoryEvent],
        pumpBasalProfile: [BasalProfileEntry],
        basalProfile: [BasalProfileEntry]
    ) -> [PeakDeviation] {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 1242-1313
        // TODO: Copy implementation
        return []
    }
    
    /// Get minutes from start time string
    private static func getMinutesFromStart(_ timeString: String) -> Int {
        // NOTE: Copy from SwiftAutotuneAlgorithms.swift lines 1315-1324
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1])
        else { return 0 }
        return hours * 60 + minutes
    }
}
