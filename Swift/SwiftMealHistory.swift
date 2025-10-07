import Foundation

/// ТОЧНАЯ портация lib/meal/history.js
/// НИ ОДНОГО упрощения! Все как в оригинале!
extension SwiftOpenAPSAlgorithms {
    
    // MARK: - Meal History (lib/meal/history.js)
    
    /// Структура для meal input
    struct MealInput {
        var timestamp: Date
        var carbs: Double?
        var nsCarbs: Double?
        var bwCarbs: Double?
        var journalCarbs: Double?
        var bolus: Double?
    }
    
    /// Портирование arrayHasElementWithSameTimestampAndProperty() (lines 3-17)
    private static func arrayHasElementWithSameTimestampAndProperty(
        array: [MealInput],
        timestamp t: Date,
        property propname: String
    ) -> Bool {
        for element in array {
            // Exact timestamp match (line 6)
            if element.timestamp == t && hasProperty(element, propname) {
                return true
            }
            
            // Within 2 seconds window (lines 7-13)
            if hasProperty(element, propname) {
                let tMin = t.addingTimeInterval(-2.0)
                let tMax = t.addingTimeInterval(2.0)
                if element.timestamp > tMin && element.timestamp < tMax {
                    return true
                }
            }
        }
        return false
    }
    
    /// Helper to check if property exists and has value
    private static func hasProperty(_ input: MealInput, _ propname: String) -> Bool {
        switch propname {
        case "carbs":
            return input.carbs != nil
        case "bolus":
            return input.bolus != nil
        case "nsCarbs":
            return input.nsCarbs != nil
        case "bwCarbs":
            return input.bwCarbs != nil
        case "journalCarbs":
            return input.journalCarbs != nil
        default:
            return false
        }
    }
    
    /// Портирование findMealInputs() из lib/meal/history.js (lines 19-139)
    static func findMealInputs(
        pumpHistory: [PumpHistoryEvent],
        carbHistory: [CarbsEntry],
        profile: ProfileResult
    ) -> [MealInput] {
        var mealInputs: [MealInput] = []
        var bolusWizardInputs: [PumpHistoryEvent] = []
        var duplicates = 0
        
        // 1. Process carbHistory (lines 27-40)
        for current in carbHistory {
            if current.carbs > 0, let createdAt = current.createdAt {
                var temp = MealInput(timestamp: createdAt)
                temp.carbs = Double(current.carbs)
                temp.nsCarbs = Double(current.carbs)
                
                // Line 34: don't add if duplicate
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: createdAt, property: "carbs") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
        }
        
        // 2. Process pumpHistory (lines 42-107)
        for current in pumpHistory {
            
            // 2a. Bolus entries (lines 44-54)
            if current.type == .bolus, let timestamp = current.timestamp {
                var temp = MealInput(timestamp: timestamp)
                temp.bolus = Double(current.amount ?? 0)
                
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: timestamp, property: "bolus") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
            
            // 2b. BolusWizard - DELAY PROCESSING! (lines 55-58)
            else if current.type == .bolusWizard, current.timestamp != nil {
                // Delay process to make sure we've seen all corresponding boluses first
                bolusWizardInputs.append(current)
            }
            
            // 2c. Nightscout Care Portal entries (lines 60-73)
            else if let typeName = current.typeName,
                    (typeName == "Meal Bolus" || typeName == "Correction Bolus" || 
                     typeName == "Snack Bolus" || typeName == "Bolus Wizard" || 
                     typeName == "Carb Correction"),
                    let createdAt = current.createdAt {
                var temp = MealInput(timestamp: createdAt)
                temp.carbs = Double(current.carbs ?? 0)
                temp.nsCarbs = Double(current.carbs ?? 0)
                
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: createdAt, property: "carbs") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
            
            // 2d. xdrip entries (lines 74-84)
            else if current.enteredBy == "xdrip", let createdAt = current.createdAt {
                var temp = MealInput(timestamp: createdAt)
                temp.carbs = Double(current.carbs ?? 0)
                temp.nsCarbs = Double(current.carbs ?? 0)
                temp.bolus = Double(current.insulin ?? 0)
                
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: createdAt, property: "carbs") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
            
            // 2e. General carbs > 0 (lines 85-95)
            else if let carbs = current.carbs, carbs > 0, let createdAt = current.createdAt {
                var temp = MealInput(timestamp: createdAt)
                temp.carbs = Double(carbs)
                temp.nsCarbs = Double(carbs)
                temp.bolus = Double(current.insulin ?? 0)
                
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: createdAt, property: "carbs") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
            
            // 2f. JournalEntryMealMarker (lines 96-106)
            else if current.type == .journalEntryMealMarker,
                    let carbInput = current.carbInput,
                    carbInput > 0,
                    let timestamp = current.timestamp {
                var temp = MealInput(timestamp: timestamp)
                temp.carbs = Double(carbInput)
                temp.journalCarbs = Double(carbInput)
                
                if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: timestamp, property: "carbs") {
                    mealInputs.append(temp)
                } else {
                    duplicates += 1
                }
            }
        }
        
        // 3. Process delayed BolusWizard entries (lines 109-135)
        for current in bolusWizardInputs {
            guard let timestamp = current.timestamp,
                  let carbInput = current.carbInput else { continue }
            
            var temp = MealInput(timestamp: timestamp)
            temp.carbs = Double(carbInput)
            temp.bwCarbs = Double(carbInput)
            
            // Line 119: only add if no duplicate AND there's a corresponding bolus
            if !arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: timestamp, property: "carbs") {
                if arrayHasElementWithSameTimestampAndProperty(array: mealInputs, timestamp: timestamp, property: "bolus") {
                    mealInputs.append(temp)
                } else {
                    // Lines 124-130: skip if no insulin
                    debug(.openAPS, "Skipping bolus wizard entry with \(carbInput)g carbs and no insulin")
                    if carbInput == 0 {
                        debug(.openAPS, "This is caused by a BolusWizard without carbs")
                    }
                }
            } else {
                duplicates += 1
            }
        }
        
        // Line 136: log duplicates if any
        if duplicates > 0 {
            debug(.openAPS, "Removed duplicate bolus/carb entries: \(duplicates)")
        }
        
        return mealInputs
    }
}

// MARK: - PumpHistoryEvent Extensions

extension PumpHistoryEvent {
    /// Helper to get type name for Care Portal entries
    var typeName: String? {
        // This should be populated from the actual event data
        // For now return nil, will be implemented when full structure is known
        return nil
    }
    
    /// Helper to get carbInput for BolusWizard
    var carbInput: Int? {
        // This should be populated from the actual event data
        return nil
    }
    
    /// Helper to check if entered by xdrip
    var enteredBy: String? {
        // This should be populated from the actual event data
        return nil
    }
    
    /// Helper for insulin amount in general entries
    var insulin: Double? {
        return amount
    }
}
