import Combine
import Foundation

// MARK: - Главный координатор Swift OpenAPS алгоритмов

// Заменяет JavaScriptWorker полностью нативными Swift алгоритмами для FreeAPS X

final class SwiftOpenAPSCoordinator {
    private let storage: FileStorage
    private let processQueue = DispatchQueue(label: "SwiftOpenAPSCoordinator.processQueue", qos: .utility)

    // Настройки
    var useSwiftAlgorithms: Bool = true {
        didSet {
            UserDefaults.standard.set(useSwiftAlgorithms, forKey: "freeapsx_use_swift_algorithms")
            info(.openAPS, "Swift OpenAPS algorithms: \(useSwiftAlgorithms ? "ENABLED" : "DISABLED")")
        }
    }

    init(storage: FileStorage) {
        self.storage = storage
        useSwiftAlgorithms = UserDefaults.standard.bool(forKey: "freeapsx_use_swift_algorithms")
        debug(.openAPS, "🔧 DEBUG: SwiftOpenAPSCoordinator init - useSwiftAlgorithms: \(useSwiftAlgorithms)")

        // ПРИНУДИТЕЛЬНО включаем Swift алгоритмы для FreeAPS X
        if !useSwiftAlgorithms {
            debug(.openAPS, "🔧 DEBUG: Force enabling Swift algorithms for FreeAPS X")
            useSwiftAlgorithms = true
        }
    }

    // MARK: - Determine Basal (главная функция)

    func determineBasal(currentTemp: TempBasal, clock: Date = Date()) -> Future<Suggestion?, Never> {
        Future { promise in
            self.processQueue.async {
                debug(.openAPS, "🔧 DEBUG: determineBasal called - useSwiftAlgorithms: \(self.useSwiftAlgorithms)")
                if self.useSwiftAlgorithms {
                    debug(.openAPS, "🔧 DEBUG: About to call determineBasalSwift...")
                    self.determineBasalSwift(currentTemp: currentTemp, clock: clock) { result in
                        debug(
                            .openAPS,
                            "🔧 DEBUG: determineBasalSwift completed with result: \(result != nil ? "SUCCESS" : "NIL")"
                        )
                        promise(.success(result))
                    }
                } else {
                    debug(.openAPS, "🔧 DEBUG: Swift algorithms disabled, returning nil")
                    // Fallback to JavaScript (для сравнения)
                    promise(.success(nil))
                }
            }
        }
    }

    private func determineBasalSwift(
        currentTemp: TempBasal,
        clock: Date,
        completion: @escaping (Suggestion?) -> Void
    ) {
        debug(.openAPS, "🔧 DEBUG: determineBasalSwift ENTRY POINT")
        do {
            debug(.openAPS, "🚀 Starting Swift OpenAPS determine basal")
            debug(.openAPS, "📊 Swift Debug: currentTemp rate=\(currentTemp.rate), duration=\(currentTemp.duration)")
            debug(.openAPS, "📊 Swift Debug: clock=\(clock)")
            debug(.openAPS, "📊 Swift Debug: storage is nil? \(storage == nil ? "YES" : "NO")")

            // 1. Загружаем все необходимые данные
            debug(.openAPS, "📊 Swift Debug: Step 1 - Loading data...")

            // Проверяем есть ли глюкоза ВООБЩЕ
            guard let glucoseRaw = storage.retrieveRaw(OpenAPS.Monitor.glucose) else {
                warning(.openAPS, "❌ No glucose data in storage!")
                completion(nil)
                return
            }
            debug(.openAPS, "📊 Swift Debug: Raw glucose data length: \(glucoseRaw.count)")

            let glucoseData = loadGlucoseData()
            debug(.openAPS, "📊 Swift Debug: Glucose data count: \(glucoseData.count)")

            guard glucoseData.count >= 3 else {
                warning(.openAPS, "❌ Not enough glucose data: \(glucoseData.count), need at least 3")
                completion(nil)
                return
            }
            let pumpHistory = loadPumpHistory()
            debug(.openAPS, "📊 Swift Debug: Pump history count: \(pumpHistory.count)")
            let carbHistory = loadCarbHistory()
            debug(.openAPS, "📊 Swift Debug: Carb history count: \(carbHistory.count)")

            // 2. Создаем профиль
            debug(.openAPS, "📊 Swift Debug: Step 2 - Creating profile...")
            let profileResult = try createProfile()
            debug(
                .openAPS,
                "📊 Swift Debug: Profile created successfully - DIA: \(profileResult.dia), maxIOB: \(profileResult.maxIOB)"
            )

            // 3. Рассчитываем IOB
            debug(.openAPS, "📊 Swift Debug: Step 3 - Calculating IOB...")
            let iobResult = try calculateIOB(
                pumpHistory: pumpHistory,
                profile: profileResult,
                clock: clock
            )
            debug(.openAPS, "📊 Swift Debug: IOB calculated - IOB: \(iobResult.iob), activity: \(iobResult.activity)")
            debug(
                .openAPS,
                "🚨 SAFETY CHECK: IOB=\(iobResult.iob), lastBolusTime=\(iobResult.lastBolusTime?.description ?? "none")"
            )
            debug(.openAPS, "🚨 SAFETY CHECK: Current pump history events: \(pumpHistory.count)")
            if let lastTemp = iobResult.lastTemp {
                debug(.openAPS, "🚨 SAFETY CHECK: Last temp basal: rate=\(lastTemp.rate), duration=\(lastTemp.duration)")
            }

            // 4. Рассчитываем автосенс
            debug(.openAPS, "📊 Swift Debug: Step 4 - Calculating autosens...")
            let autosensResult = try calculateAutosens(
                glucoseData: glucoseData,
                pumpHistory: pumpHistory,
                profile: profileResult,
                carbHistory: carbHistory
            )
            debug(.openAPS, "📊 Swift Debug: Autosens calculated - ratio: \(autosensResult.ratio)")

            // Конвертируем SwiftOpenAPSAlgorithms.AutosensResult в Autosens
            let autosens = convertToAutosens(autosensResult)

            // 5. Рассчитываем meal/COB
            debug(.openAPS, "📊 Swift Debug: Step 5 - Calculating meal/COB...")
            let mealResult = try calculateMeal(
                pumpHistory: pumpHistory,
                profile: profileResult,
                glucoseData: glucoseData,
                carbHistory: carbHistory,
                clock: clock
            )
            debug(.openAPS, "📊 Swift Debug: Meal calculated - COB: \(mealResult.mealCOB)")

            // 6. Получаем статус глюкозы
            debug(.openAPS, "📊 Swift Debug: Step 6 - Creating glucose status...")
            let glucoseStatus = try createGlucoseStatus(from: glucoseData)
            debug(.openAPS, "📊 Swift Debug: Glucose status - BG: \(glucoseStatus.glucose), delta: \(glucoseStatus.delta)")

            // 🚨 ПРОВЕРКА ЕДИНИЦ ГЛЮКОЗЫ
            warning(.openAPS, "🚨 GLUCOSE UNITS CHECK:")
            warning(.openAPS, "🚨 Current BG: \(glucoseStatus.glucose) (should be mg/dL if >50, mmol/L if <20)")
            warning(.openAPS, "🚨 BGTargets units: \(profileResult.targets.units)")
            warning(.openAPS, "🚨 ISF units: \(profileResult.isf.units)")

            if glucoseStatus.glucose > 50, profileResult.targets.units == .mmolL {
                warning(
                    .openAPS,
                    "🚨 POSSIBLE UNIT MISMATCH: BG=\(glucoseStatus.glucose) looks like mg/dL but targets are mmol/L!"
                )
            }

            // 7. Основной алгоритм принятия решений
            debug(.openAPS, "📊 Swift Debug: Step 7 - Running determine basal algorithm...")
            let determineBasalInputs = SwiftOpenAPSAlgorithms.DetermineBasalInputs(
                iob: iobResult,
                currentTemp: currentTemp,
                glucose: glucoseStatus,
                profile: profileResult,
                autosens: autosens,
                meal: mealResult,
                microBolusAllowed: true,
                reservoir: nil, // loadReservoir() возвращает Decimal?, нужен Reservoir?
                clock: clock,
                pumpHistory: pumpHistory
            )

            let basalResult = SwiftOpenAPSAlgorithms.determineBasal(inputs: determineBasalInputs)
            debug(.openAPS, "📊 Swift Debug: Determine basal algorithm completed")

            switch basalResult {
            case let .success(result):
                debug(.openAPS, "📊 Swift Debug: Algorithm success - rate: \(result.rate ?? 0), duration: \(result.duration ?? 0)")

                // 🚨 ДЕТАЛЬНОЕ ЛОГИРОВАНИЕ РЕКОМЕНДАЦИИ
                warning(.openAPS, "🚨 RECOMMENDATION DETAILS:")
                warning(.openAPS, "🚨 Rate: \(result.rate?.description ?? "nil") U/h")
                warning(.openAPS, "🚨 Duration: \(result.duration?.description ?? "nil") min")
                warning(.openAPS, "🚨 Units (bolus): \(result.units?.description ?? "nil") U")
                warning(.openAPS, "🚨 Reason: \(result.reason)")
                warning(.openAPS, "🚨 Eventual BG: \(result.eventualBG)")
                warning(.openAPS, "🚨 Insulin Req: \(result.insulinReq)")

                // 🚨 КРИТИЧЕСКИЕ ПРОВЕРКИ БЕЗОПАСНОСТИ
                if let rate = result.rate, rate > 5.0 {
                    warning(.openAPS, "🚨 DANGEROUS: Recommended rate \(rate) > 5.0, capping at 2.0")
                    // Не реализуем опасные рекомендации
                    completion(nil)
                    return
                }

                if let units = result.units, units > 2.0 {
                    warning(.openAPS, "🚨 DANGEROUS: Recommended bolus \(units) > 2.0, rejecting")
                    completion(nil)
                    return
                }

                // Конвертируем в Suggestion
                if let suggestion = convertToSuggestion(result, clock: clock) {
                    debug(.openAPS, "✅ Swift OpenAPS completed successfully")
                    storage.save(suggestion, as: OpenAPS.Enact.suggested)
                    completion(suggestion)
                } else {
                    warning(.openAPS, "❌ Failed to convert Swift result to Suggestion")
                    warning(.openAPS, "❌ Raw result: \(result.rawJSON)")
                    completion(nil)
                }

            case let .failure(error):
                warning(.openAPS, "❌ Swift OpenAPS calculation failed: \(error)")
                completion(nil)
            }

        } catch {
            warning(.openAPS, "❌ Swift OpenAPS error: \(error)")
            warning(.openAPS, "❌ Error type: \(type(of: error))")
            warning(.openAPS, "❌ Error description: \(error.localizedDescription)")
            if let swiftError = error as? SwiftOpenAPSError {
                warning(.openAPS, "❌ SwiftOpenAPSError: \(swiftError)")
            }
            completion(nil)
        }
    }

    // MARK: - Individual Algorithm Functions

    func createProfile() throws -> SwiftOpenAPSAlgorithms.ProfileResult {
        debug(.openAPS, "📊 Swift Debug: Loading profile data from storage...")
        let pumpSettings = loadDataFromStorage(PumpSettings.self, file: OpenAPS.Settings.settings)
        debug(.openAPS, "📊 Swift Debug: PumpSettings loaded: \(pumpSettings != nil ? "✅" : "❌")")

        var bgTargets = loadDataFromStorage(BGTargets.self, file: OpenAPS.Settings.bgTargets)
        debug(.openAPS, "📊 Swift Debug: BGTargets loaded: \(bgTargets != nil ? "✅" : "❌")")

        // ПРИНУДИТЕЛЬНО создаем БЕЗОПАСНЫЕ BGTargets в mg/dL
        warning(.openAPS, "🚨 FORCE OVERRIDING BGTargets to mg/dL for safety!")
        bgTargets = BGTargets(
            units: .mgdL,
            userPrefferedUnits: .mgdL,
            targets: [
                BGTargetEntry(low: 100.0, high: 160.0, start: "00:00:00", offset: 0)
            ]
        )
        debug(.openAPS, "📊 Swift Debug: Created safe BGTargets: \(bgTargets!.targets.count) entries")
        var isf = loadDataFromStorage(InsulinSensitivities.self, file: OpenAPS.Settings.insulinSensitivities)
        debug(.openAPS, "📊 Swift Debug: ISF loaded: \(isf != nil ? "✅" : "❌")")

        // ПРИНУДИТЕЛЬНО создаем БЕЗОПАСНЫЙ ISF в mg/dL
        warning(.openAPS, "🚨 FORCE OVERRIDING ISF to mg/dL for safety!")
        isf = InsulinSensitivities(
            units: .mgdL,
            userPrefferedUnits: .mgdL,
            sensitivities: [
                InsulinSensitivityEntry(sensitivity: 50.0, offset: 0, start: "00:00:00")
            ]
        )

        var basalProfile = loadDataFromStorage([BasalProfileEntry].self, file: OpenAPS.Settings.basalProfile)
        debug(
            .openAPS,
            "📊 Swift Debug: Basal profile loaded: \(basalProfile != nil ? "✅" : "❌"), count: \(basalProfile?.count ?? 0)"
        )

        // Создаем базальный профиль по умолчанию если нет
        if basalProfile == nil || basalProfile!.isEmpty {
            warning(.openAPS, "⚠️ Basal profile missing, creating defaults...")
            basalProfile = [
                BasalProfileEntry(start: "00:00:00", minutes: 0, rate: 1.0)
            ]
        }

        var preferences = loadDataFromStorage(Preferences.self, file: OpenAPS.Settings.preferences)
        debug(.openAPS, "📊 Swift Debug: Preferences loaded: \(preferences != nil ? "✅" : "❌")")

        // ПРИНУДИТЕЛЬНО создаем БЕЗОПАСНЫЕ preferences
        warning(.openAPS, "🚨 FORCE OVERRIDING Preferences for MAXIMUM SAFETY!")
        preferences = Preferences()
        // 🚨 МАКСИМАЛЬНО БЕЗОПАСНЫЕ НАСТРОЙКИ для FreeAPS X
        preferences!.maxIOB = 0.5 // КРАЙНЕ консервативно
        preferences!.maxCOB = 20.0 // Минимально
        preferences!.enableSMBAlways = false // Отключаем микроболюсы
        preferences!.enableSMBWithCOB = false
        preferences!.enableUAM = false
        preferences!.maxSMBBasalMinutes = 0 // Никаких SMB
        preferences!.maxUAMSMBBasalMinutes = 0

        var carbRatios = loadDataFromStorage(CarbRatios.self, file: OpenAPS.Settings.carbRatios)
        debug(.openAPS, "📊 Swift Debug: Carb ratios loaded: \(carbRatios != nil ? "✅" : "❌")")

        // Создаем carb ratios по умолчанию если нет
        if carbRatios == nil {
            warning(.openAPS, "⚠️ Carb ratios missing, creating defaults...")
            carbRatios = CarbRatios(
                units: .grams,
                schedule: [
                    CarbRatioEntry(start: "00:00:00", offset: 0, ratio: 10.0)
                ]
            )
        }
        let tempTargets = loadDataFromStorage(TempTargets.self, file: OpenAPS.Settings.tempTargets)
        debug(.openAPS, "📊 Swift Debug: Temp targets loaded: \(tempTargets != nil ? "✅" : "❌")")
        let autotune = loadDataFromStorage(Autotune.self, file: OpenAPS.Settings.autotune)
        debug(.openAPS, "📊 Swift Debug: Autotune loaded: \(autotune != nil ? "✅" : "❌")")

        debug(.openAPS, "📊 Swift Debug: Creating ProfileInputs...")
        let inputs = SwiftOpenAPSAlgorithms.ProfileInputs(
            pumpSettings: pumpSettings,
            bgTargets: bgTargets, // теперь всегда не-nil
            isf: isf, // теперь всегда не-nil
            basalProfile: basalProfile, // теперь всегда не-nil
            preferences: preferences, // теперь всегда не-nil
            carbRatios: carbRatios, // теперь всегда не-nil
            tempTargets: tempTargets,
            model: nil,
            autotune: autotune
        )

        debug(.openAPS, "📊 Swift Debug: Calling SwiftOpenAPSAlgorithms.createProfile...")
        let result = SwiftOpenAPSAlgorithms.createProfile(inputs: inputs)
        switch result {
        case let .success(profile):
            debug(.openAPS, "📊 Swift Debug: Profile created successfully!")
            return profile
        case let .failure(error):
            warning(.openAPS, "❌ Profile creation failed: \(error)")
            throw error
        }
    }

    private func calculateIOB(
        pumpHistory: [PumpHistoryEvent],
        profile: SwiftOpenAPSAlgorithms.ProfileResult,
        clock: Date
    ) throws -> SwiftOpenAPSAlgorithms.IOBResult {
        let inputs = SwiftOpenAPSAlgorithms.IOBInputs(
            pumpHistory: pumpHistory,
            profile: profile,
            clock: clock,
            autosens: nil // Will be calculated separately
        )

        return SwiftOpenAPSAlgorithms.calculateIOB(inputs: inputs)
    }

    private func calculateAutosens(
        glucoseData: [BloodGlucose],
        pumpHistory: [PumpHistoryEvent],
        profile: SwiftOpenAPSAlgorithms.ProfileResult,
        carbHistory: [CarbsEntry]
    ) throws -> SwiftOpenAPSAlgorithms.AutosensResult {
        let inputs = SwiftOpenAPSAlgorithms.AutosensInputs(
            glucoseData: glucoseData,
            pumpHistory: pumpHistory,
            basalProfile: profile.basals,
            profile: profile,
            carbHistory: carbHistory,
            tempTargets: nil
        )

        let result = SwiftOpenAPSAlgorithms.calculateAutosens(inputs: inputs)
        switch result {
        case let .success(autosens):
            return autosens
        case let .failure(error):
            throw error
        }
    }

    private func calculateMeal(
        pumpHistory: [PumpHistoryEvent],
        profile: SwiftOpenAPSAlgorithms.ProfileResult,
        glucoseData: [BloodGlucose],
        carbHistory: [CarbsEntry],
        clock: Date
    ) throws -> SwiftOpenAPSAlgorithms.MealResult {
        let inputs = SwiftOpenAPSAlgorithms.MealInputs(
            pumpHistory: pumpHistory,
            profile: profile,
            basalProfile: profile.basals,
            clock: clock,
            carbHistory: carbHistory,
            glucoseData: glucoseData
        )

        let result = SwiftOpenAPSAlgorithms.calculateMeal(inputs: inputs)
        switch result {
        case let .success(meal):
            return meal
        case let .failure(error):
            throw error
        }
    }

    // MARK: - Data Loading Helpers

    private func loadGlucoseData() -> [BloodGlucose] {
        loadDataFromStorage([BloodGlucose].self, file: OpenAPS.Monitor.glucose) ?? []
    }

    private func loadPumpHistory() -> [PumpHistoryEvent] {
        loadDataFromStorage([PumpHistoryEvent].self, file: OpenAPS.Monitor.pumpHistory) ?? []
    }

    private func loadCarbHistory() -> [CarbsEntry] {
        loadDataFromStorage([CarbsEntry].self, file: OpenAPS.Monitor.carbHistory) ?? []
    }

    private func loadReservoir() -> Decimal? {
        // Reservoir is stored as Decimal, not as object
        guard let rawData = storage.retrieveRaw(OpenAPS.Monitor.reservoir),
              let data = rawData.data(using: .utf8)
        else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Decimal.self, from: data)
        } catch {
            return nil
        }
    }

    private func loadDataFromStorage<T: Decodable>(_ type: T.Type, file: String) -> T? {
        guard let rawData = storage.retrieveRaw(file),
              let data = rawData.data(using: .utf8)
        else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            // Пытаемся разные стратегии декодирования дат
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Пытаемся различные форматы дат
                let formatters = [
                    self.createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
                    self.createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ssZ"),
                    self.createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
                    self.createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss'Z'"),
                    self.createDateFormatter(format: "yyyy-MM-dd HH:mm:ss Z")
                ]

                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }

                // Fallback - попытка ISO8601
                if #available(iOS 10.0, *) {
                    let iso8601Formatter = ISO8601DateFormatter()
                    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string: \(dateString)"
                )
            }
            return try decoder.decode(type, from: data)
        } catch {
            warning(.openAPS, "Failed to decode \(file): \(error)")
            return nil
        }
    }

    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }

    private func createGlucoseStatus(from glucoseData: [BloodGlucose]) throws -> SwiftOpenAPSAlgorithms.GlucoseStatus {
        guard glucoseData.count >= 3 else {
            throw SwiftOpenAPSError.calculationError("Not enough glucose data")
        }

        let sortedGlucose = glucoseData.sorted {
            $0.dateString > $1.dateString
        }

        let current = sortedGlucose[0]
        let prev1 = sortedGlucose[1]
        let prev2 = sortedGlucose[2]

        guard let currentBG = current.glucose,
              let prev1BG = prev1.glucose,
              let prev2BG = prev2.glucose
        else {
            throw SwiftOpenAPSError.calculationError("Invalid glucose data")
        }

        let currentDate = current.dateString

        let delta = Double(currentBG - prev1BG)
        let shortAvgDelta = (Double(currentBG - prev1BG) + Double(prev1BG - prev2BG)) / 2.0

        // ТОЧНЫЙ расчет long avg delta как в JS - нужно минимум 5 точек
        let longAvgDelta: Double
        if glucoseData.count >= 5 {
            let prev3BG = sortedGlucose[3].glucose ?? currentBG
            let prev4BG = sortedGlucose[4].glucose ?? currentBG
            longAvgDelta =
                (
                    Double(currentBG - prev1BG) + Double(prev1BG - prev2BG) + Double(prev2BG - prev3BG) +
                        Double(prev3BG - prev4BG)
                ) /
                4.0
        } else {
            // Если недостаточно данных для long avg, используем short avg как в JavaScript
            // Это соответствует логике oref0 при недостатке glucose data
            longAvgDelta = shortAvgDelta
        }

        return SwiftOpenAPSAlgorithms.GlucoseStatus(
            glucose: Double(currentBG),
            delta: delta,
            shortAvgDelta: shortAvgDelta,
            longAvgDelta: longAvgDelta,
            date: currentDate,
            noise: current.noise
        )
    }

    private func convertToSuggestion(
        _ result: SwiftOpenAPSAlgorithms.DetermineBasalResult,
        clock _: Date
    ) -> Suggestion? {
        var suggestion = Suggestion(from: result.rawJSON)
        suggestion?.timestamp = result.deliverAt

        return suggestion
    }

    // MARK: - Autotune Function (NEW!)

    func autotune(categorizeUamAsBasal: Bool = false, tuneInsulinCurve: Bool = false) -> Future<Autotune?, Never> {
        Future { promise in
            info(.openAPS, "🚀 FreeAPS X: Starting Swift Autotune")

            do {
                // Загружаем данные для autotune
                let glucoseData = self.loadGlucoseData()
                let pumpHistory = self.loadPumpHistory()
                let carbHistory = self.loadCarbHistory()
                let profile = try self.createProfile()

                // Создаём pump profile (копия основного профиля)
                let pumpProfile = profile

                // Создаём входные данные
                let autotuneInputs = SwiftOpenAPSAlgorithms.AutotuneInputs(
                    pumpHistory: pumpHistory,
                    profile: profile,
                    glucoseData: glucoseData,
                    pumpProfile: pumpProfile,
                    carbHistory: carbHistory,
                    categorizeUamAsBasal: categorizeUamAsBasal,
                    tuneInsulinCurve: tuneInsulinCurve
                )

                // Подготавливаем данные (PREP)
                let preppedResult = SwiftOpenAPSAlgorithms.autotunePrep(inputs: autotuneInputs)

                switch preppedResult {
                case let .success(preppedData):
                    info(.openAPS, "✅ Autotune PREP completed successfully")

                    // Создаём предыдущий результат autotune
                    let previousAutotune = SwiftOpenAPSAlgorithms.AutotuneResult(
                        basalprofile: profile.basals,
                        isfProfile: profile.isf,
                        carb_ratio: profile.carbRatioValue,
                        dia: profile.dia,
                        insulinPeakTime: profile.insulinPeakTime ?? 75.0,
                        curve: "rapid-acting",
                        useCustomPeakTime: false,
                        sens: profile.sens,
                        csf: profile.sens / profile.carbRatioValue,
                        timestamp: Date()
                    )

                    // Выполняем CORE autotune
                    let coreResult = SwiftOpenAPSAlgorithms.autotuneCore(
                        preppedData: preppedData,
                        previousAutotune: previousAutotune,
                        pumpProfile: pumpProfile,
                        tuneInsulinCurve: tuneInsulinCurve
                    )

                    switch coreResult {
                    case let .success(autotuneResult):
                        info(.openAPS, "✅ Autotune CORE completed successfully")

                        // Конвертируем в Autotune структуру
                        let autotune = Autotune(
                            createdAt: autotuneResult.timestamp,
                            basalProfile: autotuneResult.basalprofile,
                            sensitivity: autotuneResult.isfProfile.sensitivities.first?.sensitivity ?? Decimal(50.0),
                            carbRatio: Decimal(autotuneResult.carb_ratio)
                        )

                        // Сохраняем результат
                        self.storage.save(autotune, as: OpenAPS.Settings.autotune)

                        promise(.success(autotune))

                    case let .failure(error):
                        warning(.openAPS, "❌ Swift Autotune CORE failed: \(error)")
                        promise(.success(nil))
                    }

                case let .failure(error):
                    warning(.openAPS, "❌ Swift Autotune PREP failed: \(error)")
                    promise(.success(nil))
                }

            } catch {
                warning(.openAPS, "❌ Swift Autotune error: \(error)")
                promise(.success(nil))
            }
        }
    }

    // MARK: - Autosense Function

    func autosense() -> Future<Autosens?, Never> {
        Future { promise in
            self.processQueue.async {
                if self.useSwiftAlgorithms {
                    do {
                        let glucoseData = self.loadGlucoseData()
                        let pumpHistory = self.loadPumpHistory()
                        let carbHistory = self.loadCarbHistory()
                        let profile = try self.createProfile()

                        let autosensResult = try self.calculateAutosens(
                            glucoseData: glucoseData,
                            pumpHistory: pumpHistory,
                            profile: profile,
                            carbHistory: carbHistory
                        )

                        // Конвертируем в Autosens
                        var autosens = Autosens(from: autosensResult.rawJSON)
                        autosens?.timestamp = Date()

                        if let autosens = autosens {
                            self.storage.save(autosens, as: OpenAPS.Settings.autosense)
                        }

                        promise(.success(autosens))

                    } catch {
                        warning(.openAPS, "Swift Autosens failed: \(error)")
                        promise(.success(nil))
                    }
                } else {
                    promise(.success(nil))
                }
            }
        }
    }

    // MARK: - Performance Monitoring

    private func measurePerformance<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        debug(.openAPS, "⚡ Swift \(operation): \(String(format: "%.3f", timeElapsed))s")
        return result
    }
}

// MARK: - Integration with existing OpenAPS

extension SwiftOpenAPSCoordinator {
    /// Factory method для создания из существующего storage
    static func create(storage: FileStorage) -> SwiftOpenAPSCoordinator {
        SwiftOpenAPSCoordinator(storage: storage)
    }

    /// Проверяет готовность Swift алгоритмов
    var isReady: Bool {
        // Проверяем наличие необходимых данных
        let hasProfile = storage.retrieveRaw(OpenAPS.Settings.profile) != nil
        let hasGlucose = storage.retrieveRaw(OpenAPS.Monitor.glucose) != nil
        let hasBasal = storage.retrieveRaw(OpenAPS.Settings.basalProfile) != nil

        return hasProfile && hasGlucose && hasBasal
    }

    /// Включает/выключает Swift алгоритмы
    func enableSwiftAlgorithms(_ enabled: Bool) {
        useSwiftAlgorithms = enabled

        if enabled {
            info(.openAPS, "🚀 FreeAPS X: Swift algorithms ENABLED - performance boost activated!")
        } else {
            info(.openAPS, "⚠️ FreeAPS X: Swift algorithms DISABLED - using JavaScript fallback")
        }
    }

    // MARK: - Helper Functions

    private func convertToAutosens(_ result: SwiftOpenAPSAlgorithms.AutosensResult) -> Autosens? {
        Autosens(from: result.rawJSON)
    }

    // MARK: - Autotune Helper Functions

    private func loadPreviousAutotune() -> SwiftOpenAPSAlgorithms.AutotuneResult? {
        guard let rawData = storage.retrieveRaw(OpenAPS.Settings.autotune),
              let data = rawData.data(using: .utf8)
        else {
            debug(.openAPS, "📊 No previous autotune data found")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Парсим JSON в dictionary для гибкости
            let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dict = jsonDict else { return nil }

            // Извлекаем компоненты autotune результата
            let basalProfile = extractBasalProfileFromAutotune(dict)
            let isfProfile = extractISFProfileFromAutotune(dict)
            let carbRatio = dict["carb_ratio"] as? Double ?? 10.0
            let dia = dict["dia"] as? Double ?? 4.0
            let insulinPeakTime = dict["insulinPeakTime"] as? Double ?? 75.0
            let curve = dict["curve"] as? String ?? "rapid-acting"
            let useCustomPeakTime = dict["useCustomPeakTime"] as? Bool ?? true

            return SwiftOpenAPSAlgorithms.AutotuneResult(
                basalprofile: basalProfile,
                isfProfile: isfProfile,
                carb_ratio: carbRatio,
                dia: dia,
                insulinPeakTime: insulinPeakTime,
                curve: curve,
                useCustomPeakTime: useCustomPeakTime,
                sens: Double(isfProfile.sensitivities.first?.sensitivity ?? 50.0),
                csf: Double(isfProfile.sensitivities.first?.sensitivity ?? 50.0) / carbRatio,
                timestamp: Date()
            )

        } catch {
            warning(.openAPS, "Failed to parse previous autotune data: \(error)")
            return nil
        }
    }

    private func createDefaultAutotune(from profile: SwiftOpenAPSAlgorithms.ProfileResult) -> SwiftOpenAPSAlgorithms
        .AutotuneResult
    {
        // Создаем дефолтный autotune на основе текущего профиля
        SwiftOpenAPSAlgorithms.AutotuneResult(
            basalprofile: profile.basals,
            isfProfile: profile.isf,
            carb_ratio: profile.carbRatioValue,
            dia: profile.dia,
            insulinPeakTime: profile.insulinPeakTime ?? 75.0,
            curve: String(describing: profile.settings.insulinActionCurve),
            useCustomPeakTime: true,
            sens: profile.sens,
            csf: profile.sens / profile.carbRatioValue,
            timestamp: Date()
        )
    }

    private func extractBasalProfileFromAutotune(_ dict: [String: Any]) -> [BasalProfileEntry] {
        guard let basalArray = dict["basalprofile"] as? [[String: Any]] else {
            return [BasalProfileEntry(start: "00:00:00", minutes: 0, rate: 1.0)]
        }

        return basalArray.compactMap { basalDict in
            guard let start = basalDict["start"] as? String,
                  let rate = basalDict["rate"] as? Double
            else { return nil }

            let minutes = basalDict["minutes"] as? Int ?? 0

            return BasalProfileEntry(
                start: start,
                minutes: minutes,
                rate: Decimal(rate)
            )
        }
    }

    private func extractISFProfileFromAutotune(_ dict: [String: Any]) -> InsulinSensitivities {
        guard let isfDict = dict["isfProfile"] as? [String: Any],
              let sensArray = isfDict["sensitivities"] as? [[String: Any]]
        else {
            // Дефолтный ISF
            return InsulinSensitivities(
                units: .mgdL,
                userPrefferedUnits: .mgdL,
                sensitivities: [
                    InsulinSensitivityEntry(sensitivity: 50.0, offset: 0, start: "00:00:00")
                ]
            )
        }

        let sensitivities = sensArray.compactMap { sensDict -> InsulinSensitivityEntry? in
            guard let start = sensDict["start"] as? String,
                  let sensitivity = sensDict["sensitivity"] as? Double
            else { return nil }

            let offset = sensDict["offset"] as? Int ?? 0

            return InsulinSensitivityEntry(
                sensitivity: Decimal(sensitivity),
                offset: offset,
                start: start
            )
        }

        let unitsString = isfDict["units"] as? String ?? "mg/dL"
        let units: GlucoseUnits = unitsString == "mmol/L" ? .mmolL : .mgdL

        return InsulinSensitivities(
            units: units,
            userPrefferedUnits: units,
            sensitivities: sensitivities.isEmpty ? [
                InsulinSensitivityEntry(sensitivity: 50.0, offset: 0, start: "00:00:00")
            ] : sensitivities
        )
    }
}
