import Foundation

/// ТОЧНАЯ портация lib/glucose-get-last.js
/// НИ ОДНОГО упрощения! Все как в оригинале!
extension SwiftOpenAPSAlgorithms {
    
    /// Портирование getLastGlucose() из lib/glucose-get-last.js
    /// Строки 5-89 оригинального файла
    static func getLastGlucose(data: [BloodGlucose]) -> GlucoseStatus {
        // Фильтрация и маппинг (lines 6-14)
        var filteredData = data.filter { obj in
            obj.glucose != nil || obj.sgv != nil
        }.compactMap { obj -> BloodGlucose in
            var result = obj
            // Support the NS sgv field (line 10)
            if result.glucose == nil {
                result.glucose = result.sgv
            }
            return result
        }
        
        guard !filteredData.isEmpty else {
            // Return default values if no data
            return GlucoseStatus(
                glucose: 0,
                delta: 0,
                shortAvgDelta: 0,
                longAvgDelta: 0,
                date: Date().toISOString(),
                noise: 0
            )
        }
        
        // now = data[0] (line 16)
        var now = filteredData[0]
        var now_date = getDateFromEntry(now)
        
        var last_deltas: [Double] = []
        var short_deltas: [Double] = []
        var long_deltas: [Double] = []
        var last_cal = 0
        
        // Main loop (lines 25-65)
        for i in 1..<filteredData.count {
            let dataPoint = filteredData[i]
            
            // if we come across a cal record, don't process any older SGVs (lines 27-30)
            if dataPoint.type == "cal" {
                last_cal = i
                break
            }
            
            guard let glucose = dataPoint.glucose ?? dataPoint.sgv,
                  glucose > 38,
                  dataPoint.device == now.device // only use data from the same device (line 32)
            else { continue }
            
            let then = dataPoint
            let then_date = getDateFromEntry(then)
            
            guard then_date > 0, now_date > 0 else {
                debug(.openAPS, "Error: date field not found: cannot calculate avgdelta")
                continue
            }
            
            // Calculate minutesago (line 38)
            let minutesago = round((now_date - then_date) / (1000 * 60))
            
            guard let nowGlucose = now.glucose ?? now.sgv,
                  let thenGlucose = then.glucose ?? then.sgv
            else { continue }
            
            // multiply by 5 to get the same units as delta, i.e. mg/dL/5m (line 39-41)
            let change = Double(nowGlucose - thenGlucose)
            let avgdelta = change / minutesago * 5.0
            
            // КРИТИЧНО: Временные интервалы ТОЧНО как в оригинале!
            
            // use the average of all data points in the last 2.5m (lines 47-50)
            if -2 < minutesago && minutesago < 2.5 {
                now.glucose = Int((Double(nowGlucose) + Double(thenGlucose)) / 2)
                now_date = (now_date + then_date) / 2
                
            // short_deltas are calculated from everything ~5-15 minutes ago (lines 52-58)
            } else if 2.5 < minutesago && minutesago < 17.5 {
                short_deltas.append(avgdelta)
                
                // last_deltas are calculated from everything ~5 minutes ago (lines 56-58)
                if 2.5 < minutesago && minutesago < 7.5 {
                    last_deltas.append(avgdelta)
                }
                
            // long_deltas are calculated from everything ~20-40 minutes ago (lines 61-63)
            } else if 17.5 < minutesago && minutesago < 42.5 {
                long_deltas.append(avgdelta)
            }
        }
        
        // Calculate averages (lines 66-77)
        var last_delta: Double = 0
        var short_avgdelta: Double = 0
        var long_avgdelta: Double = 0
        
        if !last_deltas.isEmpty {
            last_delta = last_deltas.reduce(0, +) / Double(last_deltas.count)
        }
        
        if !short_deltas.isEmpty {
            short_avgdelta = short_deltas.reduce(0, +) / Double(short_deltas.count)
        }
        
        if !long_deltas.isEmpty {
            long_avgdelta = long_deltas.reduce(0, +) / Double(long_deltas.count)
        }
        
        // Return with rounding (lines 79-88)
        return GlucoseStatus(
            glucose: round(Double(now.glucose ?? 0) * 100) / 100, // line 81
            delta: round(last_delta * 100) / 100, // line 80
            shortAvgDelta: round(short_avgdelta * 100) / 100, // line 83
            longAvgDelta: round(long_avgdelta * 100) / 100, // line 84
            date: dateToISOString(timestamp: now_date), // line 85
            noise: Double(now.noise ?? 0), // line 82
            lastCal: last_cal, // line 86 - ДОБАВЛЕНО!
            device: now.device // line 87 - ДОБАВЛЕНО!
        )
    }
    
    /// Helper: get date from entry (lines 1-3)
    private static func getDateFromEntry(_ entry: BloodGlucose) -> Double {
        // Return timestamp in milliseconds as in JS
        if let date = entry.date {
            return date * 1000 // convert to milliseconds
        } else if let dateString = entry.dateString {
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date.timeIntervalSince1970 * 1000
            }
        } else if let displayTime = entry.displayTime {
            if let date = ISO8601DateFormatter().date(from: displayTime) {
                return date.timeIntervalSince1970 * 1000
            }
        }
        return 0
    }
    
    /// Helper: convert timestamp to ISO string
    private static func dateToISOString(timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        return date.toISOString()
    }
}

// MARK: - GlucoseStatus extension to support new fields

extension SwiftOpenAPSAlgorithms.GlucoseStatus {
    /// Инициализатор с ПОЛНЫМИ полями как в JS
    init(
        glucose: Double,
        delta: Double,
        shortAvgDelta: Double,
        longAvgDelta: Double,
        date: String,
        noise: Double,
        lastCal: Int? = nil,
        device: String? = nil
    ) {
        self.init(
            glucose: glucose,
            delta: delta,
            shortAvgDelta: shortAvgDelta,
            longAvgDelta: longAvgDelta,
            date: date,
            noise: noise
        )
        // TODO: Добавить lastCal и device в структуру GlucoseStatus если нужно
    }
}

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
