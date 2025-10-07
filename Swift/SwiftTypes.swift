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
    
    public init(dia: Double, current_basal: Double, carbRatioValue: Double) {
        self.dia = dia
        self.current_basal = current_basal
        self.carbRatioValue = carbRatioValue
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
