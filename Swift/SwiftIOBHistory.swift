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
    
    // MARK: - TODO: splitAroundSuspends() (~90 строк)
    // MARK: - TODO: calcTempTreatments() (~200+ строк)
    
    // Эти функции будут добавлены в следующей сессии
    // splitAroundSuspends() - СЛОЖНАЯ (lines 85-159)
    // calcTempTreatments() - ГЛАВНАЯ функция (lines 161-572)
}

// MARK: - Progress Notes

/*
 IOB HISTORY ПОРТАЦИЯ - ПРОГРЕСС:
 
 ✅ ЧАСТЬ 1.1: splitTimespanWithOneSplitter() - ГОТОВО
 ✅ ЧАСТЬ 1.2: splitTimespan() - ГОТОВО
 ⏳ ЧАСТЬ 1.3: splitAroundSuspends() - TODO (90 строк)
 ⏳ ЧАСТЬ 2: calcTempTreatments initialization - TODO (50 строк)
 ⏳ ЧАСТЬ 3: calcTempTreatments main logic - TODO (100 строк)
 ⏳ ЧАСТЬ 4: calcTempTreatments finalization - TODO (70 строк)
 
 ПРОГРЕСС: ~90 строк из ~400 (22.5%)
 
 СЛЕДУЮЩАЯ СЕССИЯ:
 1. Портировать splitAroundSuspends() (lines 85-159)
 2. Портировать calcTempTreatments() (lines 161-572)
*/
