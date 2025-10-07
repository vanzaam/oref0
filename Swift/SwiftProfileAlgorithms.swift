import Foundation

// MARK: - TempTargets type definition

struct TempTargets: Codable {
    let targets: [TempTarget]
}

// MARK: - Swift портирование profile.js алгоритма

// Создает профили пользователя с настройками помпы, целями глюкозы, чувствительностью к инсулину

extension SwiftOpenAPSAlgorithms {
    // MARK: - Profile Creation Input Structures

    struct ProfileInputs {
        let pumpSettings: PumpSettings?
        let bgTargets: BGTargets?
        let isf: InsulinSensitivities?
        let basalProfile: [BasalProfileEntry]?
        let preferences: Preferences?
        let carbRatios: CarbRatios?
        let tempTargets: TempTargets?
        let model: String?
        let autotune: Autotune?
    }

    struct ProfileResult {
        let settings: PumpSettings
        let targets: BGTargets
        let basals: [BasalProfileEntry]
        let isf: InsulinSensitivities
        let carbRatio: CarbRatios
        let tempTargets: TempTargets
        let model: String
        let autotune: Autotune?

        // Все preferences также включены в профиль (как в исходном oref0)
        let maxIOB: Double
        let maxCOB: Double
        let dia: Double
        let sens: Double
        let carbRatioValue: Double
        let currentBasal: Double

        // КРИТИЧЕСКОЕ ПОЛЕ из profile/index.js:153
        // Определяет единицы вывода для всех BG-значений
        let outUnits: String  // "mg/dL" или "mmol/L"

        // КРИТИЧЕСКИЕ параметры безопасности из исходного oref0
        let exerciseMode: Bool
        let highTemptargetRaisesSensitivity: Bool
        let lowTemptargetLowersSensitivity: Bool
        let sensitivityRaisesTarget: Bool
        let resistanceLowersTarget: Bool
        let temptargetSet: Bool
        let autosensMax: Double
        let halfBasalExerciseTarget: Double?

        // Микроболюсные параметры (из profile/index.js)
        let maxSMBBasalMinutes: Double?
        let maxUAMSMBBasalMinutes: Double?
        
        // SMB enable/disable флаги (из enable_smb функции determine-basal.js:51-126)
        let allowSMBWithHighTemptarget: Bool?  // allowSMB_with_high_temptarget
        let a52RiskEnable: Bool?               // A52_risk_enable
        let enableSMBAlways: Bool?             // enableSMB_always
        let enableSMBWithCOB: Bool?            // enableSMB_with_COB
        let enableSMBAfterCarbs: Bool?         // enableSMB_after_carbs
        let enableSMBWithTemptarget: Bool?     // enableSMB_with_temptarget
        let enableSMBHighBG: Bool?             // enableSMB_high_bg
        let enableSMBHighBGTarget: Double?     // enableSMB_high_bg_target (строка 240)
        let enableUAM: Bool?                   // enableUAM (строка 461)
        let maxDeltaBGThreshold: Double?       // maxDelta_bg_threshold (строка 870-875)
        let bolusIncrement: Double?            // bolus_increment (строка 1097-1098)
        let smbInterval: Double?               // SMBInterval (строка 1132-1137)
        let skipNeutralTemps: Bool?            // skip_neutral_temps (строка 925)
        let carbsReqThreshold: Double?         // carbsReqThreshold (строка 900)

        // Дополнительные параметры безопасности
        let advTargetAdjustments: Bool
        let noisyCGMTargetMultiplier: Double

        var rawJSON: String {
            // Возвращаем упрощенный JSON без Encodable
            """
            {
                "maxIOB": \(maxIOB),
                "maxCOB": \(maxCOB),
                "dia": \(dia),
                "sens": \(sens),
                "carb_ratio": \(carbRatioValue),
                "current_basal": \(currentBasal)
            }
            """
        }
    }

    /// Портирование freeaps_profile функции из JavaScript
    /// Создает полный профиль для OpenAPS из входных данных
    static func createProfile(inputs: ProfileInputs) -> Result<ProfileResult, SwiftOpenAPSError> {
        // Валидация и конвертация BG Targets
        guard var bgTargets = inputs.bgTargets else {
            return .failure(.calculationError("BG Targets are required"))
        }

        // Валидация BG Targets (конвертация выполняется в другом месте)
        if bgTargets.units != .mgdL, bgTargets.units != .mmolL {
            return .failure(.calculationError("BG Target units must be mg/dL or mmol/L. Found: \(bgTargets.units.rawValue)"))
        }

        // Валидация ISF (конвертация выполняется в другом месте)
        guard let isf = inputs.isf else {
            return .failure(.calculationError("Insulin Sensitivity Factor is required"))
        }

        if isf.units != .mgdL, isf.units != .mmolL {
            return .failure(.calculationError("ISF units must be mg/dL or mmol/L. Found: \(isf.units.rawValue)"))
        }

        // Валидация Carb Ratios
        guard let carbRatios = inputs.carbRatios else {
            return .failure(.calculationError("Carb Ratios are required"))
        }

        let carbValidationResult = validateCarbRatios(carbRatios)
        if case let .failure(error) = carbValidationResult {
            return .failure(error)
        }

        // Получаем базальный профиль
        guard var basalProfile = inputs.basalProfile else {
            return .failure(.calculationError("Basal Profile is required"))
        }

        // Применяем autotune если есть (упрощенная логика для совместимости)
        // В реальности autotune применяется на уровне данных, а не здесь

        // Создаем результирующий профиль со ВСЕМИ параметрами безопасности
        let profile = ProfileResult(
            settings: inputs.pumpSettings ?? PumpSettings.default,
            targets: bgTargets,
            basals: basalProfile,
            isf: isf,
            carbRatio: carbRatios,
            tempTargets: inputs.tempTargets ?? TempTargets.default,
            model: inputs.model ?? "",
            autotune: inputs.autotune,
            maxIOB: Double(inputs.preferences?.maxIOB ?? 0.0),
            maxCOB: Double(inputs.preferences?.maxCOB ?? 120.0),
            dia: Double(inputs.pumpSettings?.insulinActionCurve ?? 4.0),
            sens: getCurrentSensitivity(from: isf),
            carbRatioValue: getCurrentCarbRatio(from: carbRatios),
            currentBasal: getCurrentBasalRate(from: basalProfile),

            // КРИТИЧЕСКОЕ ПОЛЕ из profile/index.js:153
            // profile.out_units = inputs.targets.user_preferred_units
            outUnits: bgTargets.units == .mmolL ? "mmol/L" : "mg/dL",

            // КРИТИЧЕСКИЕ параметры безопасности из oref0
            exerciseMode: inputs.preferences?.exerciseMode ?? false,
            highTemptargetRaisesSensitivity: inputs.preferences?.highTemptargetRaisesSensitivity ?? false,
            lowTemptargetLowersSensitivity: inputs.preferences?.lowTemptargetLowersSensitivity ?? false,
            sensitivityRaisesTarget: inputs.preferences?.sensitivityRaisesTarget ?? false,
            resistanceLowersTarget: inputs.preferences?.resistanceLowersTarget ?? false,
            temptargetSet: checkTempTargetSet(tempTargets: inputs.tempTargets),
            autosensMax: Double(inputs.preferences?.autosensMax ?? 1.2),
            halfBasalExerciseTarget: Double(inputs.preferences?.halfBasalExerciseTarget ?? 160.0),

            // Микроболюсные параметры
            maxSMBBasalMinutes: Double(inputs.preferences?.maxSMBBasalMinutes ?? 30),
            maxUAMSMBBasalMinutes: Double(inputs.preferences?.maxUAMSMBBasalMinutes ?? 30),
            
            // SMB enable/disable флаги (точно по оригиналу из enable_smb)
            allowSMBWithHighTemptarget: inputs.preferences?.allowSMBWithHighTemptarget,
            a52RiskEnable: inputs.preferences?.a52RiskEnable,
            enableSMBAlways: inputs.preferences?.enableSMBAlways,
            enableSMBWithCOB: inputs.preferences?.enableSMBWithCOB,
            enableSMBAfterCarbs: inputs.preferences?.enableSMBAfterCarbs,
            enableSMBWithTemptarget: inputs.preferences?.enableSMBWithTemptarget,
            enableSMBHighBG: inputs.preferences?.enableSMBHighBG,
            enableSMBHighBGTarget: inputs.preferences?.enableSMBHighBGTarget,
            enableUAM: inputs.preferences?.enableUAM,
            maxDeltaBGThreshold: inputs.preferences?.maxDeltaBGThreshold,
            bolusIncrement: inputs.preferences?.bolusIncrement,
            smbInterval: inputs.preferences?.smbInterval,
            skipNeutralTemps: inputs.preferences?.skipNeutralTemps,
            carbsReqThreshold: inputs.preferences?.carbsReqThreshold,

            // Дополнительные параметры безопасности
            advTargetAdjustments: inputs.preferences?.advTargetAdjustments ?? false,
            noisyCGMTargetMultiplier: Double(inputs.preferences?.noisyCGMTargetMultiplier ?? 1.3)
        )

        return .success(profile)
    }

    // MARK: - Helper Functions

    private static func checkTempTargetSet(tempTargets: TempTargets?) -> Bool {
        // Проверяем, установлен ли активный temp target
        guard let tempTargets = tempTargets else { return false }

        let now = Date()
        return tempTargets.targets.contains { target in
            let startDate = target.createdAt
            let duration = target.duration

            let endDate = startDate.addingTimeInterval(TimeInterval(Double(duration) * 60))
            return startDate <= now && now <= endDate
        }
    }

    // ВАЖНО: Конвертация единиц выполняется на уровне UI/данных
    // Swift алгоритмы работают с данными как есть
    private static func convertBGTargetsToMgdL(_ bgTargets: BGTargets) -> BGTargets {
        // Для совместимости возвращаем как есть
        bgTargets
    }

    private static func convertISFToMgdL(_ isf: InsulinSensitivities) -> InsulinSensitivities {
        // Для совместимости возвращаем как есть
        isf
    }

    private static func validateCarbRatios(_ carbRatios: CarbRatios) -> Result<Void, SwiftOpenAPSError> {
        var errors: [String] = []

        // Проверяем, что есть schedule с start и ratio
        if carbRatios.schedule.isEmpty {
            errors.append("Carb ratio data should have an array called schedule with a start and ratio fields.")
        } else {
            let firstSchedule = carbRatios.schedule[0]
            if firstSchedule.start.isEmpty || firstSchedule.ratio <= 0 {
                errors.append("Carb ratio data should have an array called schedule with a start and ratio fields.")
            }
        }

        // Проверяем units
        if carbRatios.units != .grams, carbRatios.units != .exchanges {
            errors.append("Carb ratio should have units field set to 'grams' or 'exchanges'.")
        }

        if !errors.isEmpty {
            return .failure(.calculationError(errors.joined(separator: " ")))
        }

        return .success(())
    }

    private static func getCurrentSensitivity(from isf: InsulinSensitivities) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let minutesFromMidnight = hour * 60 + minute

        // Находим текущую чувствительность
        let sortedSensitivities = isf.sensitivities.sorted {
            getMinutesFromStart($0.start) > getMinutesFromStart($1.start)
        }

        for sensitivity in sortedSensitivities {
            let startMinutes = getMinutesFromStart(sensitivity.start)
            if minutesFromMidnight >= startMinutes {
                return Double(sensitivity.sensitivity)
            }
        }

        return Double(isf.sensitivities.first?.sensitivity ?? 50.0)
    }

    private static func getCurrentCarbRatio(from carbRatios: CarbRatios) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let minutesFromMidnight = hour * 60 + minute

        // Находим текущий carb ratio
        let sortedRatios = carbRatios.schedule.sorted {
            getMinutesFromStart($0.start) > getMinutesFromStart($1.start)
        }

        for ratio in sortedRatios {
            let startMinutes = getMinutesFromStart(ratio.start)
            if minutesFromMidnight >= startMinutes {
                return Double(ratio.ratio)
            }
        }

        return Double(carbRatios.schedule.first?.ratio ?? 10.0)
    }

    private static func getCurrentBasalRate(from basals: [BasalProfileEntry]) -> Double {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let minutesFromMidnight = hour * 60 + minute

        // Находим текущий базал
        let sortedBasals = basals.sorted { ($0.minutes ?? 0) > ($1.minutes ?? 0) }

        for basal in sortedBasals {
            let startMinutes = basal.minutes ?? 0
            if minutesFromMidnight >= startMinutes {
                return Double(basal.rate)
            }
        }

        return Double(basals.first?.rate ?? 1.0)
    }

    private static func getMinutesFromStart(_ timeString: String) -> Int {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1])
        else {
            return 0
        }
        return hours * 60 + minutes
    }
}

// MARK: - Default values for missing data

extension PumpSettings {
    static var `default`: PumpSettings {
        PumpSettings(
            insulinActionCurve: 3,
            maxBolus: 10.0,
            maxBasal: 2.0
        )
    }
}

extension TempTargets {
    static var `default`: TempTargets {
        TempTargets(targets: [])
    }
}

// MARK: - Codable support for ProfileResult

// ProfileResult не требует Codable - используется только внутри Swift алгоритмов
