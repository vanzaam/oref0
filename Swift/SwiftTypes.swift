import Foundation

// MARK: - Common Types for Swift OpenAPS Algorithms
// Эти типы должны быть заменены на реальные типы из FreeAPS X

/// Pump history event
public struct PumpHistoryEvent {
    public let type: EventType?
    public let timestamp: Date?
    public let amount: Decimal?
    public let duration: Int?
    public let rate: Decimal?
    public let temp: String?
    public let bolus: PumpHistoryEvent?
    public let eventType: String?
    public let createdAt: Date?
    public let enteredBy: String?
    public let carbs: Int?
    public let insulin: Double?
    public let absolute: Double?
    public let carbInput: Int?
    
    public enum EventType {
        case bolus
        case bolusWizard
        case tempBasal
        case pumpSuspend
        case pumpResume
        case pumpRewind // for rewind_resets_autosens
    }
    
    public init(type: EventType? = nil, timestamp: Date? = nil, amount: Decimal? = nil,
                duration: Int? = nil, rate: Decimal? = nil, temp: String? = nil,
                bolus: PumpHistoryEvent? = nil, eventType: String? = nil,
                createdAt: Date? = nil, enteredBy: String? = nil, carbs: Int? = nil,
                insulin: Double? = nil, absolute: Double? = nil, carbInput: Int? = nil) {
        self.type = type
        self.timestamp = timestamp
        self.amount = amount
        self.duration = duration
        self.rate = rate
        self.temp = temp
        self.bolus = bolus
        self.eventType = eventType
        self.createdAt = createdAt
        self.enteredBy = enteredBy
        self.carbs = carbs
        self.insulin = insulin
        self.absolute = absolute
        self.carbInput = carbInput
    }
}

/// Carbs entry
public struct CarbsEntry {
    public let carbs: Int
    public let createdAt: Date?
    
    public init(carbs: Int, createdAt: Date?) {
        self.carbs = carbs
        self.createdAt = createdAt
    }
}

/// Profile result (должен быть из SwiftProfileAlgorithms)
// NOTE: Это временная структура для компиляции standalone файлов
// В реальном FreeAPS X используется ProfileResult из SwiftProfileAlgorithms.swift
public struct ProfileResult {
    public let dia: Double
    public let current_basal: Double
    public let carbRatioValue: Double
    public let rewind_resets_autosens: Bool? // for ЭТАП 3
    public let sens: Double // ISF для autosens
    public let max_daily_basal: Double // для ratio calculation
    public let autosens_min: Double // ratio limit min (default 0.7)
    public let autosens_max: Double // ratio limit max (default 1.3)
    public let min_5m_carbimpact: Double // для COB calculation
    public let carb_ratio: Double // для carb absorption
    public let high_temptarget_raises_sensitivity: Bool? // для temp target
    public let exerciseMode: Bool? // для temp target
    
    public init(dia: Double, current_basal: Double, carbRatioValue: Double,
                rewind_resets_autosens: Bool? = nil, sens: Double = 50.0,
                max_daily_basal: Double = 1.0, autosens_min: Double = 0.7,
                autosens_max: Double = 1.3, min_5m_carbimpact: Double = 3.0,
                carb_ratio: Double = 10.0, high_temptarget_raises_sensitivity: Bool? = nil,
                exerciseMode: Bool? = nil) {
        self.dia = dia
        self.current_basal = current_basal
        self.carbRatioValue = carbRatioValue
        self.rewind_resets_autosens = rewind_resets_autosens
        self.sens = sens
        self.max_daily_basal = max_daily_basal
        self.autosens_min = autosens_min
        self.autosens_max = autosens_max
        self.min_5m_carbimpact = min_5m_carbimpact
        self.carb_ratio = carb_ratio
        self.high_temptarget_raises_sensitivity = high_temptarget_raises_sensitivity
        self.exerciseMode = exerciseMode
    }
}

/// Blood glucose entry
public struct BloodGlucose {
    public let date: Date
    public let sgv: Int
    public let glucose: Int?
    
    public init(date: Date, sgv: Int, glucose: Int?) {
        self.date = date
        self.sgv = sgv
        self.glucose = glucose
    }
}

/// Basal profile entry
public struct BasalProfileEntry {
    public let minutes: Int
    public let rate: Decimal
    
    public init(minutes: Int, rate: Decimal) {
        self.minutes = minutes
        self.rate = rate
    }
}

/// Temp targets structure
public struct TempTargets {
    public let targets: [TempTarget]
    
    public init(targets: [TempTarget]) {
        self.targets = targets
    }
}

/// Temp target
public struct TempTarget {
    public let createdAt: Date?
    public let duration: Int
    public let targetTop: Int?
    public let targetBottom: Int?
    
    public init(createdAt: Date?, duration: Int, targetTop: Int?, targetBottom: Int?) {
        self.createdAt = createdAt
        self.duration = duration
        self.targetTop = targetTop
        self.targetBottom = targetBottom
    }
}

/// Debug function placeholder
public func debug(_ category: DebugCategory, _ message: String) {
    // This should be replaced with actual logging from FreeAPS X
    print("[\(category)] \(message)")
}

public enum DebugCategory {
    case openAPS
}

/// Warning function placeholder
public func warning(_ category: DebugCategory, _ message: String) {
    // This should be replaced with actual warning from FreeAPS X
    print("[WARNING][\(category)] \(message)")
}
