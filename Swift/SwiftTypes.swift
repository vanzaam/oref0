import Foundation

// MARK: - Common Types for Swift OpenAPS Algorithms
// Эти типы должны быть заменены на реальные типы из FreeAPS X

/// Pump history event
struct PumpHistoryEvent {
    let type: EventType?
    let timestamp: Date?
    let amount: Decimal?
    let duration: Int?
    let rate: Decimal?
    let temp: String?
    let bolus: PumpHistoryEvent?
    let eventType: String?
    let createdAt: Date?
    let enteredBy: String?
    let carbs: Int?
    let insulin: Double?
    let absolute: Double?
    let carbInput: Int?
    
    enum EventType {
        case bolus
        case bolusWizard
        case tempBasal
        case pumpSuspend
        case pumpResume
    }
}

/// Carbs entry
struct CarbsEntry {
    let carbs: Int
    let createdAt: Date?
}

/// Profile result (должен быть из SwiftProfileAlgorithms)
// NOTE: Это временная структура, нужно использовать ProfileResult из SwiftProfileAlgorithms.swift
typealias ProfileResult = SwiftOpenAPSAlgorithms.ProfileResult

/// Blood glucose entry
struct BloodGlucose {
    let date: Date
    let sgv: Int
    let glucose: Int?
}

/// Basal profile entry
struct BasalProfileEntry {
    let minutes: Int
    let rate: Decimal
}

/// Debug function placeholder
func debug(_ category: DebugCategory, _ message: String) {
    // This should be replaced with actual logging from FreeAPS X
    print("[\(category)] \(message)")
}

enum DebugCategory {
    case openAPS
}

/// Warning function placeholder
func warning(_ category: DebugCategory, _ message: String) {
    // This should be replaced with actual warning from FreeAPS X
    print("[WARNING][\(category)] \(message)")
}
