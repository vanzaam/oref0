import Foundation

/// ТОЧНАЯ портация lib/iob/history.js
/// Обработка pump history для IOB calculations
/// ЧАСТЬ 1: Вспомогательные функции (lines 8-159)
extension SwiftOpenAPSAlgorithms {
    
    // MARK: - IOB History Helper Functions
    
    /// Event для разбивки по времени
    struct TempEvent {
        var started_at: Date
        var date: Double // milliseconds
        var duration: Double // minutes
        var timestamp: String
        var rate: Double?
        var insulin: Double?
        
        mutating func clone() -> TempEvent {
            return self
        }
    }
    
    /// Splitter для разбивки события
    struct TimeSplitter {
        let type: String // "recurring"
        let minutes: Double // minutes from midnight
    }
    
    /// Портирование splitTimespanWithOneSplitter() (lines 8-49)
    static func splitTimespanWithOneSplitter(
        event: TempEvent,
        splitter: TimeSplitter
    ) -> [TempEvent] {
        
        var resultArray = [event]
        
        // Line 12: Check if recurring
        if splitter.type == "recurring" {
            
            // Lines 14-15: Calculate start and end in minutes from midnight
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: event.started_at)
            let startMinutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            let endMinutes = startMinutes + event.duration
            
            // Lines 20: Check if event needs splitting
            // 1440 = one day
            if event.duration > 30 || 
               (startMinutes < splitter.minutes && endMinutes > splitter.minutes) || 
               (endMinutes > 1440 && splitter.minutes < (endMinutes - 1440)) {
                
                // Lines 22-23: Clone events
                var event1 = event.clone()
                var event2 = event.clone()
                
                var event1Duration: Double = 0
                
                // Lines 27-33: Calculate event1 duration
                if event.duration > 30 {
                    event1Duration = 30
                } else {
                    var splitPoint = splitter.minutes
                    if endMinutes > 1440 {
                        splitPoint = 1440
                    }
                    event1Duration = splitPoint - startMinutes
                }
                
                // Line 35: Calculate event1 end date
                let event1EndDate = event.started_at.addingTimeInterval(event1Duration * 60)
                
                // Line 37: Set event1 duration
                event1.duration = event1Duration
                
                // Lines 39-42: Set event2
                event2.duration = event.duration - event1Duration
                event2.started_at = event1EndDate
                event2.date = event1EndDate.timeIntervalSince1970 * 1000
                
                resultArray = [event1, event2]
            }
        }
        
        // Line 48
        return resultArray
    }
    
    /// Портирование splitTimespan() (lines 51-80)
    static func splitTimespan(
        event: TempEvent,
        splitterMoments: [TimeSplitter]
    ) -> [TempEvent] {
        
        var results = [event]
        var splitFound = true
        
        // Lines 57-77: while loop для рекурсивной разбивки
        while splitFound {
            var resultArray: [TempEvent] = []
            splitFound = false
            
            // Line 62: forEach results
            for o in results {
                var wasSplit = false
                
                // Line 63: forEach splitterMoments
                for p in splitterMoments {
                    let splitResult = splitTimespanWithOneSplitter(event: o, splitter: p)
                    
                    // Lines 65-68: If split found
                    if splitResult.count > 1 {
                        resultArray.append(contentsOf: splitResult)
                        splitFound = true
                        wasSplit = true
                        break
                    }
                }
                
                // Line 72: If not split, add original
                if !wasSplit {
                    resultArray.append(o)
                }
            }
            
            results = resultArray
        }
        
        // Line 79
        return results
    }
    
    /// Suspend event для разбивки
    struct PumpSuspend {
        let date: Double // milliseconds
        let duration: Double // minutes
        let started_at: Date
    }
    
    /// Портирование splitAroundSuspends() (lines 85-159)
    /// СЛОЖНАЯ функция - разбивает event вокруг pump suspends
    static func splitAroundSuspends(
        currentEvent: TempEvent,
        pumpSuspends: [PumpSuspend],
        firstResumeTime: String?,
        suspendedPrior: Bool,
        lastSuspendTime: String?,
        currentlySuspended: Bool
    ) -> [TempEvent] {
        
        var events: [TempEvent] = []
        var event = currentEvent
        
        // Lines 88-92: Parse resume and suspend times
        let firstResumeDate: Double
        if let firstResumeTime = firstResumeTime, let date = dateFromString(firstResumeTime) {
            firstResumeDate = date.timeIntervalSince1970 * 1000
        } else {
            firstResumeDate = 0
        }
        
        let lastSuspendDate: Double
        if let lastSuspendTime = lastSuspendTime, let date = dateFromString(lastSuspendTime) {
            lastSuspendDate = date.timeIntervalSince1970 * 1000
        } else {
            lastSuspendDate = 0
        }
        
        // Lines 94-103: Handle suspendedPrior
        if suspendedPrior && (event.date < firstResumeDate) {
            let eventEnd = event.date + event.duration * 60 * 1000
            
            if eventEnd < firstResumeDate {
                // Line 96: Event entirely before resume
                event.duration = 0
            } else {
                // Lines 98-101: Event crosses resume time
                event.duration = (eventEnd - firstResumeDate) / 60 / 1000
                if let resumeDate = dateFromString(firstResumeTime ?? "") {
                    event.started_at = resumeDate
                    event.date = firstResumeDate
                }
            }
        }
        
        // Lines 105-111: Handle currentlySuspended
        if currentlySuspended {
            let eventEnd = event.date + event.duration * 60 * 1000
            
            if eventEnd > lastSuspendDate {
                if event.date > lastSuspendDate {
                    // Line 107: Event starts after suspend
                    event.duration = 0
                } else {
                    // Line 109: Event crosses suspend time
                    event.duration = (firstResumeDate - event.date) / 60 / 1000
                }
            }
        }
        
        // Line 113
        events.append(event)
        
        // Lines 115-118: Bail out if duration is 0
        if event.duration == 0 {
            return events
        }
        
        // Lines 120-156: Loop through pump suspends
        for suspend in pumpSuspends {
            var eventsToAdd: [TempEvent] = []
            
            for j in 0..<events.count {
                let eventStart = events[j].date
                let eventEnd = events[j].date + events[j].duration * 60 * 1000
                let suspendEnd = suspend.date + suspend.duration * 60 * 1000
                
                // Lines 125-142: Event started before suspend, but finished after suspend started
                if (eventStart <= suspend.date) && (eventEnd > suspend.date) {
                    
                    // Line 128: Event extends past end of suspend
                    if eventEnd > suspendEnd {
                        // Clone event for part after suspend
                        var event2 = events[j].clone()
                        
                        let event2StartDate = suspend.started_at.addingTimeInterval(suspend.duration * 60)
                        event2.started_at = event2StartDate
                        event2.date = suspendEnd
                        event2.duration = (eventEnd - suspendEnd) / 60 / 1000
                        
                        eventsToAdd.append(event2)
                    }
                    
                    // Line 142: Trim first event to end at suspend start
                    events[j].duration = (suspend.date - eventStart) / 60 / 1000
                    
                // Lines 144-154: Suspend started before event, but finished after event started
                } else if (suspend.date <= eventStart) && (suspendEnd > eventStart) {
                    
                    // Line 147: Adjust event duration
                    events[j].duration = (eventEnd - suspendEnd) / 60 / 1000
                    
                    // Lines 149-153: Adjust event start time
                    let eventStartDate = suspend.started_at.addingTimeInterval(suspend.duration * 60)
                    events[j].started_at = eventStartDate
                    events[j].date = suspendEnd
                }
            }
            
            // Add new events created during this iteration
            events.append(contentsOf: eventsToAdd)
        }
        
        // Line 158
        return events
    }
    
    /// Helper: parse date from ISO string
    private static func dateFromString(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
    
    // MARK: - calcTempTreatments() - ГЛАВНАЯ ФУНКЦИЯ
    
    /// Inputs для calcTempTreatments
    struct IOBHistoryInputs {
        let history: [PumpHistoryEvent]
        let history24: [PumpHistoryEvent]?
        let profile: ProfileResult
        let autosens: AutosensResult?
        let clock: String
    }
    
    /// Портирование calcTempTreatments() из lib/iob/history.js (lines 161-572)
    /// ГЛАВНАЯ функция - обработка pump history для IOB
    /// БЛОКИ 1-2: Initialization + Suspend/Resume matching (lines 161-260)
    static func calcTempTreatments(
        inputs: IOBHistoryInputs,
        zeroTempDuration: Double? = nil
    ) -> [Treatment] {
        
        // БЛОК 1: Initialization (lines 161-200)
        
        // Lines 162-165
        var pumpHistory = inputs.history
        let profile_data = inputs.profile
        let autosens_data = inputs.autosens
        
        // Lines 166-173
        var tempHistory: [TempEvent] = []
        var tempBoluses: [TempEvent] = []
        var pumpSuspends: [PumpSuspend] = []
        var pumpResumes: [PumpSuspend] = []
        var suspendedPrior = false
        var firstResumeTime: String?
        var lastSuspendTime: String?
        var currentlySuspended = false
        
        // Line 175
        let now = dateFromString(inputs.clock) ?? Date()
        
        // Lines 177-179: Concat history + history24
        if let history24 = inputs.history24 {
            pumpHistory = inputs.history + history24
        }
        
        // Line 181
        var lastRecordTime = now
        
        // Lines 183-200: Gather PumpSuspend and PumpResume
        for current in pumpHistory {
            if current._type == "PumpSuspend" {
                if let timestamp = current.timestamp,
                   let started_at = dateFromString(timestamp) {
                    let suspend = PumpSuspend(
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0, // will be calculated later
                        started_at: started_at
                    )
                    pumpSuspends.append(suspend)
                }
            } else if current._type == "PumpResume" {
                if let timestamp = current.timestamp,
                   let started_at = dateFromString(timestamp) {
                    let resume = PumpSuspend(
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0,
                        started_at: started_at
                    )
                    pumpResumes.append(resume)
                }
            }
        }
        
        // БЛОК 2: Suspend/Resume matching (lines 201-260)
        
        // Lines 202-204: Sort by date
        pumpSuspends.sort { $0.date < $1.date }
        pumpResumes.sort { $0.date < $1.date }
        
        // Lines 206-215: Check if suspended prior
        if !pumpResumes.isEmpty {
            if let timestamp = pumpResumes[0].started_at.ISO8601Format() as String? {
                firstResumeTime = timestamp
            }
            
            // Check if first resume was before first suspend
            if pumpSuspends.isEmpty || (pumpResumes[0].date < pumpSuspends[0].date) {
                suspendedPrior = true
            }
        }
        
        // Line 217
        var j = 0 // matching pumpResumes entry
        
        // Lines 219-241: Match resumes with suspends
        var i = 0
        while i < pumpSuspends.count {
            // Find matching resume
            while j < pumpResumes.count {
                if pumpResumes[j].date > pumpSuspends[i].date {
                    break
                }
                j += 1
            }
            
            // Lines 227-237: Check if we've reached final suspend
            if j >= pumpResumes.count && !currentlySuspended {
                currentlySuspended = true
                if let timestamp = pumpSuspends[i].started_at.ISO8601Format() as String? {
                    lastSuspendTime = timestamp
                }
                break
            }
            
            // Line 239: Calculate suspend duration
            if j < pumpResumes.count {
                var suspend = pumpSuspends[i]
                suspend.duration = (pumpResumes[j].date - pumpSuspends[i].date) / 60 / 1000
                pumpSuspends[i] = suspend
            }
            
            i += 1
        }
        
        // Lines 243-253: Error checking for mismatches
        if !suspendedPrior && !currentlySuspended && (pumpResumes.count != pumpSuspends.count) {
            warning(.openAPS, "Mismatched number of resumes(\(pumpResumes.count)) and suspends(\(pumpSuspends.count))!")
        } else if suspendedPrior && !currentlySuspended && ((pumpResumes.count - 1) != pumpSuspends.count) {
            warning(.openAPS, "Mismatched resumes(\(pumpResumes.count)) and suspends(\(pumpSuspends.count)) assuming suspended prior!")
        } else if !suspendedPrior && currentlySuspended && (pumpResumes.count != (pumpSuspends.count - 1)) {
            warning(.openAPS, "Mismatched resumes(\(pumpResumes.count)) and suspends(\(pumpSuspends.count)) assuming suspended past end!")
        } else if suspendedPrior && currentlySuspended && (pumpResumes.count != pumpSuspends.count) {
            warning(.openAPS, "Mismatched resumes(\(pumpResumes.count)) and suspends(\(pumpSuspends.count)) assuming suspended prior and past end!")
        }
        
        // Lines 255-259: Truncate extra suspends
        if i < (pumpSuspends.count - 1) {
            pumpSuspends = Array(pumpSuspends[0...i])
        }
        
        // БЛОК 3: Process temp basals and boluses (lines 260-399)
        
        // Lines 263-380: Pick relevant events and clean data
        for current in pumpHistory {
            // Line 265-268: Handle bolus wrapper
            var event = current
            if let bolus = current.bolus, bolus._type == "Bolus" {
                event = bolus
            }
            
            // Lines 269-271: Use created_at if available
            if let created_at = event.created_at {
                event.timestamp = created_at
            }
            
            guard let timestamp = event.timestamp,
                  let currentRecordTime = dateFromString(timestamp) else {
                continue
            }
            
            // Lines 275-282: Ignore duplicate or out-of-order records
            if currentRecordTime > lastRecordTime {
                continue
            }
            lastRecordTime = currentRecordTime
            
            // Lines 283-294: Process Bolus events
            if event._type == "Bolus" {
                let started_at = dateFromString(event.timestamp ?? "") ?? Date()
                
                if started_at > now {
                    warning(.openAPS, "Ignoring \(event.amount ?? 0)U bolus in future at \(started_at)")
                } else {
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0,
                        timestamp: event.timestamp ?? "",
                        rate: nil,
                        insulin: event.amount
                    )
                    tempBoluses.append(temp)
                }
            }
            // Lines 295-303: Nightscout Care Portal boluses
            else if event.eventType == "Meal Bolus" || event.eventType == "Correction Bolus" || 
                    event.eventType == "Snack Bolus" || event.eventType == "Bolus Wizard" {
                if let created_at = event.created_at,
                   let started_at = dateFromString(created_at) {
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0,
                        timestamp: created_at,
                        rate: nil,
                        insulin: event.insulin
                    )
                    tempBoluses.append(temp)
                }
            }
            // Lines 304-310: xdrip entries
            else if event.enteredBy == "xdrip" {
                if let timestamp = event.timestamp,
                   let started_at = dateFromString(timestamp) {
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0,
                        timestamp: timestamp,
                        rate: nil,
                        insulin: event.insulin
                    )
                    tempBoluses.append(temp)
                }
            }
            // Lines 311-317: HAPP_App entries
            else if event.enteredBy == "HAPP_App", event.insulin != nil {
                if let created_at = event.created_at,
                   let started_at = dateFromString(created_at) {
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: 0,
                        timestamp: created_at,
                        rate: nil,
                        insulin: event.insulin
                    )
                    tempBoluses.append(temp)
                }
            }
            // Lines 318-325: HAPP_App / AndroidAPS temp basals
            else if event.eventType == "Temp Basal" && 
                    (event.enteredBy == "HAPP_App" || event.enteredBy == "openaps://AndroidAPS") {
                if let created_at = event.created_at,
                   let started_at = dateFromString(created_at) {
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: event.duration ?? 0,
                        timestamp: created_at,
                        rate: event.absolute,
                        insulin: nil
                    )
                    tempHistory.append(temp)
                }
            }
            // Lines 326-338: Regular Temp Basal events
            else if event.eventType == "Temp Basal" {
                if let timestamp = event.timestamp,
                   let started_at = dateFromString(timestamp) {
                    var rate = event.rate
                    
                    // Lines 330-334: Loop temp basals with amount
                    if let amount = event.amount, let duration = event.duration, duration > 0 {
                        rate = amount / duration * 60
                    }
                    
                    var temp = TempEvent(
                        started_at: started_at,
                        date: started_at.timeIntervalSince1970 * 1000,
                        duration: event.duration ?? 0,
                        timestamp: timestamp,
                        rate: rate,
                        insulin: nil
                    )
                    tempHistory.append(temp)
                }
            }
            // Lines 339-367: Medtronic TempBasal (skip percent temps)
            else if event._type == "TempBasal" {
                if event.temp == "percent" {
                    continue
                }
                
                // TODO: Match with TempBasalDuration (complex logic, lines 346-359)
                // For now, skip if no duration
                guard let rate = event.rate,
                      let timestamp = event.timestamp,
                      let started_at = dateFromString(timestamp) else {
                    continue
                }
                
                var temp = TempEvent(
                    started_at: started_at,
                    date: started_at.timeIntervalSince1970 * 1000,
                    duration: event.duration ?? 0,
                    timestamp: timestamp,
                    rate: rate,
                    insulin: nil
                )
                tempHistory.append(temp)
            }
        }
        
        // Lines 369-379: Add zero temp for future prediction
        var zeroTemp = TempEvent(
            started_at: now.addingTimeInterval(60), // 1m in future
            date: (now.timeIntervalSince1970 + 60) * 1000,
            duration: zeroTempDuration ?? 0,
            timestamp: now.addingTimeInterval(60).ISO8601Format(),
            rate: 0,
            insulin: nil
        )
        tempHistory.append(zeroTemp)
        
        // Lines 384-394: Sort and fix overlaps
        tempHistory.sort { $0.date < $1.date }
        
        var i = 0
        while i + 1 < tempHistory.count {
            let currentEnd = tempHistory[i].date + tempHistory[i].duration * 60 * 1000
            let nextStart = tempHistory[i + 1].date
            
            if currentEnd > nextStart {
                // Adjust duration to not overlap
                tempHistory[i].duration = (nextStart - tempHistory[i].date) / 60 / 1000
                
                // Delete null duration AndroidAPS cancel records
                if tempHistory[i + 1].duration == 0 {
                    tempHistory.remove(at: i + 1)
                    continue
                }
            }
            i += 1
        }
        
        // TODO: БЛОКИ 4-5 (lines 400-572)
        // - More processing
        // - Finalization
        
        // Temporary return
        return []
    }
}

// MARK: - Progress Notes

/*
 IOB HISTORY ПОРТАЦИЯ - ПРОГРЕСС:
 
 ✅ ЧАСТЬ 1.1: splitTimespanWithOneSplitter() - ГОТОВО (~50 строк)
 ✅ ЧАСТЬ 1.2: splitTimespan() - ГОТОВО (~40 строк)
 ✅ ЧАСТЬ 1.3: splitAroundSuspends() - ГОТОВО (~120 строк)
 🔄 ЧАСТЬ 2: calcTempTreatments() - В ПРОЦЕССЕ
    ✅ БЛОК 1-2: Initialization + Suspend matching (~140 строк)
    ✅ БЛОК 3: Process temp basals + boluses (~185 строк) ← ТОЛЬКО ЧТО ДОБАВЛЕНО!
    ⏳ БЛОК 4-5: Finalization (~130 строк осталось)
 
 ПРОГРЕСС: ~535 строк из ~600 (89%)! 🚀🚀🚀
 
 ОСТАЛОСЬ:
 1. Портировать calcTempTreatments БЛОКИ 4-5 (lines 400-572)
    - More processing + finalization
    - ~130 строк Swift
*/
