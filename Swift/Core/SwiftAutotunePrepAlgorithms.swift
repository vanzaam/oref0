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

        // Main loop - exactly as in original (line 128-374)
        let startIndex = max(0, bucketedData.count - 5)

        for i in stride(from: startIndex, through: 1, by: -1) {
            let index = i - 1 // Convert to 0-based
            guard index >= 0 && index < bucketedData.count else { continue }

            var glucoseDatum = bucketedData[index]
            let BGDate = Date(timeIntervalSince1970: glucoseDatum.date / 1000) // Convert from milliseconds
            let BGTime = glucoseDatum.date

            // Process treatments (carbs) as in original (line 135-149)
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

            // Calculate BG, delta, avgDelta as in original (line 156-167)
            guard index + 4 < bucketedData.count else { continue }

            let BG = glucoseDatum.glucose
            guard BG >= 40 && bucketedData[index + 4].glucose >= 40 else { continue }

            let delta = BG - bucketedData[index + 1].glucose
            let avgDelta = (BG - bucketedData[index + 4].glucose) / 4.0

            glucoseDatum.avgDelta = round(avgDelta * 100) / 100

            // CRITICAL FUNCTION: Calculate ISF (sens) as in original (line 171-172)
            let sens = getCurrentSensitivity(from: profile.isf, at: BGDate)

            // CRITICAL FUNCTION: Calculate IOB as in original (line 173-205)
            let currentPumpBasal = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate)
            let BGDate1hAgo = BGDate.addingTimeInterval(-1 * 3600)
            let BGDate2hAgo = BGDate.addingTimeInterval(-2 * 3600)
            let BGDate3hAgo = BGDate.addingTimeInterval(-3 * 3600)

            let basal1hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate1hAgo)
            let basal2hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate2hAgo)
            let basal3hAgo = getCurrentBasalRate(from: pumpBasalProfile, at: BGDate3hAgo)

            // Average of 4 hours for IOB calculation (line 204-205)
            let avgBasalForIOB = round((currentPumpBasal + basal1hAgo + basal2hAgo + basal3hAgo) / 4.0 * 1000) / 1000

            // Current autotuned basal (line 208)
            let currentBasal = getCurrentBasalRate(from: basalProfile, at: BGDate)

            // basalBGI calculation (line 212)
            let basalBGI = round((currentBasal * sens / 60.0 * 5.0) * 100) / 100 // U/hr * mg/dL/U * 1hr/60min * 5min

            // IOB calculation for this time
            let iobResult = calculateIOBAtTime(
                time: BGDate,
                pumpHistory: pumpHistory,
                profile: profile,
                avgBasal: avgBasalForIOB
            )

            // BGI calculation (line 219)
            let BGI = round((-iobResult.activity * sens * 5.0) * 100) / 100
            glucoseDatum.BGI = BGI

            // Deviation calculation (line 223-235)
            var deviation = avgDelta - BGI
            let dev5m = delta - BGI

            // Set positive deviations to zero if BG is below 80 (line 228-230)
            if BG < 80 && deviation > 0 {
                deviation = 0
            }

            deviation = round(deviation * 100) / 100
            glucoseDatum.deviation = deviation

            // CRITICAL LOGIC: Carb absorption calculation (line 238-245)
            if mealCOB > 0 {
                let ci = max(deviation, profile.min5mCarbimpact_autotune)
                let absorbed = ci * profile.carbRatioValue / sens
                mealCOB = max(0, mealCOB - absorbed)
            }

            // CRITICAL LOGIC: CR calculation logic (line 254-296)
            if mealCOB > 0 || calculatingCR {
                CRCarbs += myCarbs
                if !calculatingCR {
                    CRInitialIOB = iobResult.iob
                    CRInitialBG = glucoseDatum.glucose
                    CRInitialCarbTime = BGDate
                    debug(.openAPS, "📊 CR Start: IOB=\(CRInitialIOB), BG=\(CRInitialBG), Time=\(CRInitialCarbTime)")
                }

                // Keep calculatingCR logic (line 264-295)
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
                        // Calculate insulin dosed during this period
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

            // CRITICAL LOGIC: Categorization as in original (line 299-367)
            if mealCOB > 0 || absorbing > 0 || mealCarbs > 0 {
                // CSF logic (line 302-323)
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

                // UAM vs ISF vs Basal logic (line 331-367)
                if iobResult.iob > 2 * currentBasal || deviation > 6 || uam > 0 {
                    // UAM logic (line 332-342)
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

                    // ISF vs Basal decision (line 354-366)
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

            // Debug output as in original (line 373)
            debug(
                .openAPS,
                "📊 \(absorbing) mealCOB:\(String(format: "%.1f", mealCOB)) mealCarbs:\(Int(mealCarbs)) BGI:\(String(format: "%.1f", BGI)) IOB:\(String(format: "%.1f", iobResult.iob)) dev:\(String(format: "%.1f", dev5m)) avgDev:\(String(format: "%.1f", deviation)) avgDelta:\(String(format: "%.1f", avgDelta)) \(type) BG:\(Int(BG)) carbs:\(Int(myCarbs))"
            )
        }

        // CRITICAL FUNCTION: UAM categorization logic (line 398-434)
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

                // Discard highest 50% as in oref0 (line 412-418)
                basalGlucoseData.sort { a, b in
                    a.deviation < b.deviation
                }
                let newBasalGlucose = Array(basalGlucoseData.prefix(basalGlucoseData.count / 2))
                basalGlucoseData = newBasalGlucose
                debug(.openAPS, "📊 Selected lowest 50%, leaving \(basalGlucoseData.count) basal+UAM ones")
            }

            // ISF UAM logic (line 421-433)
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

        // Final CSF categorization check (line 437-444)
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
        let currentDIA = profile.dia
        let startDIA = currentDIA - 2.0
        let endDIA = currentDIA + 2.0
        var diaDeviations: [DiaDeviation] = []

        // Test different DIA values (line 41-92 in index.js)
        var dia = startDIA
        while dia <= endDIA {
            // Create temporary profile with test DIA
            var testProfile = profile
            // testProfile.dia = dia  // In Swift we can't just change, need to recreate

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

            // Calculate deviations for each hour (line 51-73)
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
    
    /// Analyze peak time deviations
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

        // Test different peak times (line 111-162 in index.js)
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
