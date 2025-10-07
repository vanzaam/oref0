import XCTest
@testable import SwiftOpenAPS

/// Unit tests для проверки портации oref0 → Swift
/// Проверяем критические функции на соответствие оригинальному JavaScript
class SwiftOpenAPSTests: XCTestCase {
    
    // MARK: - Tests for convertBG function
    
    func testConvertBG_mgdL_roundsToInteger() {
        // Arrange
        let profile = createTestProfile(outUnits: "mg/dL")
        
        // Act & Assert
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(120.7, profile: profile), 121.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(120.3, profile: profile), 120.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(100.0, profile: profile), 100.0)
    }
    
    func testConvertBG_mmolL_convertsAndRoundsToOneDecimal() {
        // Arrange
        let profile = createTestProfile(outUnits: "mmol/L")
        
        // Act & Assert
        // 120 mg/dL = 6.666... mmol/L → 6.7
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(120.0, profile: profile), 6.7, accuracy: 0.01)
        
        // 100 mg/dL = 5.555... mmol/L → 5.6
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(100.0, profile: profile), 5.6, accuracy: 0.01)
        
        // 180 mg/dL = 10.0 mmol/L
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(180.0, profile: profile), 10.0, accuracy: 0.01)
        
        // 90 mg/dL = 5.0 mmol/L
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(90.0, profile: profile), 5.0, accuracy: 0.01)
    }
    
    func testConvertBG_edgeCases() {
        let profileMgdL = createTestProfile(outUnits: "mg/dL")
        let profileMmolL = createTestProfile(outUnits: "mmol/L")
        
        // Very low BG
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(40.0, profile: profileMgdL), 40.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(40.0, profile: profileMmolL), 2.2, accuracy: 0.01)
        
        // Very high BG
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(400.0, profile: profileMgdL), 400.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.convertBG(400.0, profile: profileMmolL), 22.2, accuracy: 0.01)
    }
    
    // MARK: - Tests for round function
    
    func testRound_noDigits_roundsToInteger() {
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.4), 1.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.5), 2.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.6), 2.0)
    }
    
    func testRound_oneDigit() {
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.44, digits: 1), 1.4)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.45, digits: 1), 1.5)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.46, digits: 1), 1.5)
    }
    
    func testRound_twoDigits() {
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.444, digits: 2), 1.44)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.445, digits: 2), 1.45)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(1.446, digits: 2), 1.45)
    }
    
    func testRound_negativeNumbers() {
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(-1.4), -1.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(-1.5), -2.0)
        XCTAssertEqual(SwiftOpenAPSAlgorithms.round(-1.44, digits: 1), -1.4)
    }
    
    // MARK: - Tests for calculateExpectedDelta
    
    func testCalculateExpectedDelta_targetAboveEventual() {
        // BG needs to rise to reach target
        // target = 100, eventual = 80, bgi = -2
        // targetDelta = 100 - 80 = 20
        // fiveMinBlocks = 24
        // expectedDelta = -2 + (20 / 24) = -2 + 0.833 = -1.167 → -1.2
        let result = SwiftOpenAPSAlgorithms.calculateExpectedDelta(
            targetBG: 100.0,
            eventualBG: 80.0,
            bgi: -2.0
        )
        XCTAssertEqual(result, -1.2, accuracy: 0.01)
    }
    
    func testCalculateExpectedDelta_targetBelowEventual() {
        // BG needs to fall to reach target
        // target = 100, eventual = 120, bgi = 1
        // targetDelta = 100 - 120 = -20
        // expectedDelta = 1 + (-20 / 24) = 1 - 0.833 = 0.167 → 0.2
        let result = SwiftOpenAPSAlgorithms.calculateExpectedDelta(
            targetBG: 100.0,
            eventualBG: 120.0,
            bgi: 1.0
        )
        XCTAssertEqual(result, 0.2, accuracy: 0.01)
    }
    
    func testCalculateExpectedDelta_atTarget() {
        // BG already at target
        // target = 100, eventual = 100, bgi = 0
        // expectedDelta = 0 + (0 / 24) = 0
        let result = SwiftOpenAPSAlgorithms.calculateExpectedDelta(
            targetBG: 100.0,
            eventualBG: 100.0,
            bgi: 0.0
        )
        XCTAssertEqual(result, 0.0, accuracy: 0.01)
    }
    
    // MARK: - Tests for ProfileResult with outUnits
    
    func testProfileResult_hasOutUnitsField() {
        let profile = createTestProfile(outUnits: "mg/dL")
        XCTAssertEqual(profile.outUnits, "mg/dL")
        
        let profileMmol = createTestProfile(outUnits: "mmol/L")
        XCTAssertEqual(profileMmol.outUnits, "mmol/L")
    }
    
    // MARK: - Integration Tests
    
    func testDetermineBasal_mmolL_allValuesConverted() {
        // TODO: Создать полный тест с реальными данными
        // Проверить, что все BG-значения в результате конвертированы
        // - bg
        // - eventualBG
        // - predBGs arrays
        // - reason string
    }
    
    // MARK: - Helper Functions
    
    private func createTestProfile(outUnits: String) -> SwiftOpenAPSAlgorithms.ProfileResult {
        // Создаем минимальный профиль для тестов
        return SwiftOpenAPSAlgorithms.ProfileResult(
            settings: PumpSettings.default,
            targets: BGTargets.default,
            basals: [],
            isf: InsulinSensitivities.default,
            carbRatio: CarbRatios.default,
            tempTargets: TempTargets.default,
            model: "test",
            autotune: nil,
            maxIOB: 0.0,
            maxCOB: 120.0,
            dia: 4.0,
            sens: 50.0,
            carbRatioValue: 10.0,
            currentBasal: 1.0,
            outUnits: outUnits,  // ✅ КРИТИЧЕСКОЕ ПОЛЕ
            exerciseMode: false,
            highTemptargetRaisesSensitivity: false,
            lowTemptargetLowersSensitivity: false,
            sensitivityRaisesTarget: false,
            resistanceLowersTarget: false,
            temptargetSet: false,
            autosensMax: 1.2,
            halfBasalExerciseTarget: 160.0,
            maxSMBBasalMinutes: 30.0,
            maxUAMSMBBasalMinutes: 30.0,
            advTargetAdjustments: false,
            noisyCGMTargetMultiplier: 1.3
        )
    }
}

// MARK: - Test Data Extensions

extension PumpSettings {
    static var `default`: PumpSettings {
        // Создаем дефолтный PumpSettings для тестов
        // TODO: Реализовать согласно вашей структуре PumpSettings
        fatalError("Implement PumpSettings.default")
    }
}

extension BGTargets {
    static var `default`: BGTargets {
        // TODO: Реализовать
        fatalError("Implement BGTargets.default")
    }
}

extension InsulinSensitivities {
    static var `default`: InsulinSensitivities {
        // TODO: Реализовать
        fatalError("Implement InsulinSensitivities.default")
    }
}

extension CarbRatios {
    static var `default`: CarbRatios {
        // TODO: Реализовать
        fatalError("Implement CarbRatios.default")
    }
}

extension TempTargets {
    static var `default`: TempTargets {
        // TODO: Реализовать
        fatalError("Implement TempTargets.default")
    }
}
