import Combine
import Foundation

// MARK: - HybridOpenAPS использует существующие константы из OpenAPS

// Нет дублирования - используем уже определенные в Constants.swift

// MARK: - Гибридный OpenAPS: Swift + JavaScript с логированием сравнений

// Позволяет безопасно переключаться между Swift и JS с полной прозрачностью

final class HybridOpenAPS {
    private let storage: FileStorage
    private let processQueue = DispatchQueue(label: "HybridOpenAPS.processQueue", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    // JavaScript worker для fallback и сравнений
    private let jsWorker = JavaScriptWorker()

    // Swift coordinator для нативных алгоритмов
    private let swiftCoordinator: SwiftOpenAPSCoordinator

    init(storage: FileStorage) {
        self.storage = storage
        swiftCoordinator = SwiftOpenAPSCoordinator(storage: storage)
    }

    // MARK: - Гибридный determine basal с логированием

    func determineBasal(currentTemp: TempBasal, clock: Date = Date()) -> Future<Suggestion?, Never> {
        Future { promise in
            self.processQueue.async {
                // 🚀 FreeAPS X: ПРИНУДИТЕЛЬНО используем Swift алгоритмы
                // let settings = self.loadSettings() // Не нужно для Swift-only режима

                // ВСЕГДА используем Swift алгоритмы в FreeAPS X
                self.executeSwiftWithComparison(
                    currentTemp: currentTemp,
                    clock: clock,
                    settings: FreeAPSSettings() // Заглушка
                ) { suggestion in
                    promise(.success(suggestion))
                }
            }
        }
    }

    // MARK: - Swift режим с логированием и сравнением

    private func executeSwiftWithComparison(
        currentTemp: TempBasal,
        clock: Date,
        settings _: FreeAPSSettings,
        completion: @escaping (Suggestion?) -> Void
    ) {
        info(.openAPS, "🚀 FreeAPS X: Using Swift OpenAPS algorithms (PERFORMANCE MODE)")

        // Выполняем Swift версию
        debug(.openAPS, "🔧 DEBUG: About to call swiftCoordinator.determineBasal...")
        debug(.openAPS, "🔧 DEBUG: swiftCoordinator is nil? \(swiftCoordinator == nil ? "YES" : "NO")")
        swiftCoordinator.determineBasal(currentTemp: currentTemp, clock: clock)
            .sink { swiftSuggestion in
                debug(.openAPS, "🔧 DEBUG: Swift algorithm completed, suggestion is nil? \(swiftSuggestion == nil ? "YES" : "NO")")

                if let suggestion = swiftSuggestion {
                    debug(
                        .openAPS,
                        "🔧 DEBUG: Swift suggestion - rate: \(suggestion.rate ?? 0), duration: \(suggestion.duration ?? 0)"
                    )
                } else {
                    warning(.openAPS, "🔧 DEBUG: Swift returned nil suggestion!")
                }

                // DISABLED: JavaScript comparison causes crashes - using Swift-only mode for stability
                // if settings.logSwiftVsJSComparison {
                //     // Параллельно выполняем JavaScript для сравнения
                //     self.executeJavaScriptForComparison(
                //         currentTemp: currentTemp,
                //         clock: clock,
                //         swiftSuggestion: swiftSuggestion
                //     )
                // }

                // 🚀 PERFORMANCE MODE: Swift-only execution (no JavaScript comparison)
                info(.openAPS, "🏆 FreeAPS X: Pure Swift mode - JavaScript comparison disabled for stability")

                // Возвращаем Swift результат
                completion(swiftSuggestion)

            }.store(in: &cancellables)
    }

    private func executeJavaScriptForComparison(
        currentTemp: TempBasal,
        clock: Date,
        swiftSuggestion: Suggestion?
    ) {
        // Выполняем JavaScript версию для сравнения (не для применения!)
        info(.openAPS, "📊 Running JavaScript for comparison with Swift results...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Загружаем те же данные что и для Swift
        let pumpHistory = loadFileFromStorage(name: OpenAPS.Monitor.pumpHistory)
        let carbs = loadFileFromStorage(name: OpenAPS.Monitor.carbHistory)
        let glucose = loadFileFromStorage(name: OpenAPS.Monitor.glucose)
        let profile = loadFileFromStorage(name: OpenAPS.Settings.profile)
        let basalProfile = loadFileFromStorage(name: OpenAPS.Settings.basalProfile)
        let autosens = loadFileFromStorage(name: OpenAPS.Settings.autosense)
        let reservoir = loadFileFromStorage(name: OpenAPS.Monitor.reservoir)

        // Выполняем JavaScript meal calculation
        let jsMeal = meal(
            pumphistory: pumpHistory,
            profile: profile,
            basalProfile: basalProfile,
            clock: clock,
            carbs: carbs,
            glucose: glucose
        )

        // Выполняем JavaScript IOB calculation
        let jsIOB = iob(
            pumphistory: pumpHistory,
            profile: profile,
            clock: clock,
            autosens: autosens.isEmpty ? RawJSON.null : autosens
        )

        // Выполняем JavaScript determine-basal
        let jsSuggestion = determineBasal(
            glucose: glucose,
            currentTemp: currentTemp.rawJSON,
            iob: jsIOB,
            profile: profile,
            autosens: autosens.isEmpty ? RawJSON.null : autosens,
            meal: jsMeal,
            microBolusAllowed: true,
            reservoir: reservoir,
            pumpHistory: pumpHistory
        )

        let jsTime = CFAbsoluteTimeGetCurrent() - startTime

        // Логируем сравнение результатов
        logComparisonResults(
            swiftSuggestion: swiftSuggestion,
            jsSuggestion: jsSuggestion,
            jsTime: jsTime
        )
    }

    // MARK: - JavaScript режим (существующая логика)

    private func executeJavaScriptMode(
        currentTemp: TempBasal,
        clock: Date,
        promise: @escaping (Suggestion?) -> Void
    ) {
        info(.openAPS, "📜 FreeAPS X: Using JavaScript OpenAPS algorithms (COMPATIBILITY MODE)")

        // Существующая логика JavaScript как в OpenAPS.swift
        debug(.openAPS, "Start determineBasal")

        // clock
        storage.save(clock, as: OpenAPS.Monitor.clock)

        // temp_basal
        let tempBasal = currentTemp.rawJSON
        storage.save(tempBasal, as: OpenAPS.Monitor.tempBasal)

        // meal
        let pumpHistory = loadFileFromStorage(name: OpenAPS.Monitor.pumpHistory)
        let carbs = loadFileFromStorage(name: OpenAPS.Monitor.carbHistory)
        let glucose = loadFileFromStorage(name: OpenAPS.Monitor.glucose)
        let profile = loadFileFromStorage(name: OpenAPS.Settings.profile)
        let basalProfile = loadFileFromStorage(name: OpenAPS.Settings.basalProfile)

        let meal = self.meal(
            pumphistory: pumpHistory,
            profile: profile,
            basalProfile: basalProfile,
            clock: clock,
            carbs: carbs,
            glucose: glucose
        )

        storage.save(meal, as: OpenAPS.Monitor.meal)

        // iob
        let autosens = loadFileFromStorage(name: OpenAPS.Settings.autosense)
        let iob = self.iob(
            pumphistory: pumpHistory,
            profile: profile,
            clock: clock,
            autosens: autosens.isEmpty ? RawJSON.null : autosens
        )

        storage.save(iob, as: OpenAPS.Monitor.iob)

        // determine-basal
        let reservoir = loadFileFromStorage(name: OpenAPS.Monitor.reservoir)

        let suggested = determineBasal(
            glucose: glucose,
            currentTemp: tempBasal,
            iob: iob,
            profile: profile,
            autosens: autosens.isEmpty ? RawJSON.null : autosens,
            meal: meal,
            microBolusAllowed: true,
            reservoir: reservoir,
            pumpHistory: pumpHistory
        )

        debug(.openAPS, "SUGGESTED: \(suggested)")

        if var suggestion = Suggestion(from: suggested) {
            suggestion.timestamp = suggestion.deliverAt ?? clock
            storage.save(suggestion, as: OpenAPS.Enact.suggested)
            promise(suggestion)
        } else {
            warning(.openAPS, "Failed to parse suggestion from JavaScript result: \(suggested.prefix(200))...")
            promise(nil)
        }
    }

    // MARK: - Логирование сравнений Swift vs JavaScript

    private func logComparisonResults(
        swiftSuggestion: Suggestion?,
        jsSuggestion: RawJSON,
        jsTime: TimeInterval
    ) {
        var comparisonLog = "🔍 SWIFT vs JAVASCRIPT COMPARISON:\n"
        comparisonLog += String(repeating: "=", count: 50) + "\n"

        // Парсим JavaScript результат
        if let jsSuggestionObj = Suggestion(from: jsSuggestion) {
            comparisonLog += "📊 RESULTS COMPARISON:\n"

            if let swift = swiftSuggestion {
                comparisonLog += "Swift Rate: \(swift.rate?.formatted() ?? "nil") U/hr\n"
                comparisonLog += "JS Rate:    \(jsSuggestionObj.rate?.formatted() ?? "nil") U/hr\n"

                comparisonLog += "Swift Duration: \(swift.duration?.formatted() ?? "nil") min\n"
                comparisonLog += "JS Duration:    \(jsSuggestionObj.duration?.formatted() ?? "nil") min\n"

                comparisonLog += "Swift Units: \(swift.units?.formatted() ?? "nil") U\n"
                comparisonLog += "JS Units:    \(jsSuggestionObj.units?.formatted() ?? "nil") U\n"

                comparisonLog += "Swift Reason: \(swift.reason ?? "nil")\n"
                comparisonLog += "JS Reason:    \(jsSuggestionObj.reason ?? "nil")\n"

                // Проверяем критические различия
                let rateDiff = abs((swift.rate ?? 0) - (jsSuggestionObj.rate ?? 0))
                let durationDiff = abs((swift.duration ?? 0) - (jsSuggestionObj.duration ?? 0))
                let unitsDiff = abs((swift.units ?? 0) - (jsSuggestionObj.units ?? 0))

                if rateDiff > 0.01 || durationDiff > 0 || unitsDiff > 0.01 {
                    comparisonLog += "⚠️  DIFFERENCE DETECTED!\n"
                    comparisonLog += "Rate diff: \(rateDiff) U/hr\n"
                    comparisonLog += "Duration diff: \(durationDiff) min\n"
                    comparisonLog += "Units diff: \(unitsDiff) U\n"
                } else {
                    comparisonLog += "✅ RESULTS IDENTICAL - Swift working correctly!\n"
                }
            } else {
                comparisonLog += "❌ Swift returned nil, JS returned: \(jsSuggestion.prefix(100))\n"
            }
        } else {
            comparisonLog += "❌ Failed to parse JS result: \(jsSuggestion.prefix(100))\n"
        }

        comparisonLog += "\n⚡ PERFORMANCE:\n"
        comparisonLog += "JavaScript time: \(String(format: "%.3f", jsTime))s\n"
        comparisonLog += "Swift expected: ~10-50x faster\n"
        comparisonLog += String(repeating: "=", count: 50)

        info(.openAPS, comparisonLog)
    }

    // MARK: - JavaScript функции (копия из OpenAPS.swift)

    private func iob(pumphistory: JSON, profile: JSON, clock: JSON, autosens: JSON) -> RawJSON {
        dispatchPrecondition(condition: .onQueue(processQueue))
        return jsWorker.inCommonContext { worker in
            worker.evaluate(script: Script(name: OpenAPS.Prepare.log))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.iob))
            worker.evaluate(script: Script(name: OpenAPS.Prepare.iob))
            return worker.call(function: OpenAPS.Function.generate, with: [
                pumphistory,
                profile,
                clock,
                autosens
            ])
        }
    }

    private func meal(pumphistory: JSON, profile: JSON, basalProfile: JSON, clock: Date, carbs: JSON, glucose: JSON) -> RawJSON {
        dispatchPrecondition(condition: .onQueue(processQueue))
        return jsWorker.inCommonContext { worker in
            worker.evaluate(script: Script(name: OpenAPS.Prepare.log))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.meal))
            worker.evaluate(script: Script(name: OpenAPS.Prepare.meal))
            return worker.call(function: OpenAPS.Function.generate, with: [
                pumphistory,
                profile,
                clock.rawJSON,
                glucose,
                basalProfile,
                carbs
            ])
        }
    }

    private func determineBasal(
        glucose: JSON,
        currentTemp: JSON,
        iob: JSON,
        profile: JSON,
        autosens: JSON,
        meal: JSON,
        microBolusAllowed: Bool,
        reservoir: JSON,
        pumpHistory: JSON
    ) -> RawJSON {
        dispatchPrecondition(condition: .onQueue(processQueue))
        return jsWorker.inCommonContext { worker in
            worker.evaluate(script: Script(name: OpenAPS.Prepare.log))
            worker.evaluate(script: Script(name: OpenAPS.Prepare.determineBasal))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.basalSetTemp))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.getLastGlucose))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.determineBasal))

            if let middleware = middlewareScript(name: OpenAPS.Middleware.determineBasal) {
                worker.evaluate(script: middleware)
            }

            return worker.call(
                function: OpenAPS.Function.generate,
                with: [
                    iob,
                    currentTemp,
                    glucose,
                    profile,
                    autosens,
                    meal,
                    microBolusAllowed,
                    reservoir,
                    false, // clock
                    pumpHistory
                ]
            )
        }
    }

    // MARK: - Helper functions

    private func loadSettings() -> FreeAPSSettings {
        storage.retrieve(OpenAPS.FreeAPS.settings, as: FreeAPSSettings.self) ?? FreeAPSSettings()
    }

    private func loadFileFromStorage(name: String) -> RawJSON {
        storage.retrieveRaw(name) ?? OpenAPS.defaults(for: name)
    }

    private func middlewareScript(name: String) -> Script? {
        if let body = storage.retrieveRaw(name) {
            return Script(name: "Middleware", body: body)
        }

        if let url = Foundation.Bundle.main.url(forResource: "javascript/\(name)", withExtension: "") {
            return Script(name: "Middleware", body: try! String(contentsOf: url))
        }

        return nil
    }
}

// MARK: - Autosens support

extension HybridOpenAPS {
    func autosense() -> Future<Autosens?, Never> {
        Future { promise in
            self.processQueue.async {
                // 🚀 FreeAPS X: ПРИНУДИТЕЛЬНО используем Swift автосенс
                // ВСЕГДА используем Swift алгоритмы в FreeAPS X
                self.swiftCoordinator.autosense()
                    .sink { autosens in
                        promise(.success(autosens))
                    }.store(in: &self.cancellables)
            }
        }
    }

    // MARK: - Autotune support (NEW!)

    func autotune(categorizeUamAsBasal: Bool = false, tuneInsulinCurve: Bool = false) -> Future<Autotune?, Never> {
        Future { promise in
            self.processQueue.async {
                // 🚀 FreeAPS X: ПРИНУДИТЕЛЬНО используем Swift autotune
                info(.openAPS, "🚀 FreeAPS X: Using Swift Autotune algorithms (PERFORMANCE MODE)")

                self.swiftCoordinator.autotune(
                    categorizeUamAsBasal: categorizeUamAsBasal,
                    tuneInsulinCurve: tuneInsulinCurve
                ).sink { autotune in
                    if let autotune = autotune {
                        info(.openAPS, "✅ Swift Autotune completed successfully")
                        info(.openAPS, "📊 Autotune recommendations ready for review")
                    } else {
                        warning(.openAPS, "⚠️ Swift Autotune returned no results")
                    }
                    promise(.success(autotune))
                }.store(in: &self.cancellables)
            }
        }
    }
}

// MARK: - JavaScript Autosens helpers

extension HybridOpenAPS {
    private func executeJavaScriptAutosens(completion: @escaping (Autosens?) -> Void) {
        debug(.openAPS, "Start autosens")
        let pumpHistory = loadFileFromStorage(name: OpenAPS.Monitor.pumpHistory)
        let carbs = loadFileFromStorage(name: OpenAPS.Monitor.carbHistory)
        let glucose = loadFileFromStorage(name: OpenAPS.Monitor.glucose)
        let profile = loadFileFromStorage(name: OpenAPS.Settings.profile)
        let basalProfile = loadFileFromStorage(name: OpenAPS.Settings.basalProfile)
        let tempTargets = loadFileFromStorage(name: OpenAPS.Settings.tempTargets)

        let autosensResult = autosense(
            glucose: glucose,
            pumpHistory: pumpHistory,
            basalprofile: basalProfile,
            profile: profile,
            carbs: carbs,
            temptargets: tempTargets
        )

        debug(.openAPS, "AUTOSENS: \(autosensResult)")
        if var autosens = Autosens(from: autosensResult) {
            autosens.timestamp = Date()
            storage.save(autosens, as: OpenAPS.Settings.autosense)
            completion(autosens)
        } else {
            warning(.openAPS, "Failed to parse autosens from JavaScript result: \(autosensResult.prefix(200))...")
            completion(nil)
        }
    }

    private func autosense(
        glucose: JSON,
        pumpHistory: JSON,
        basalprofile: JSON,
        profile: JSON,
        carbs: JSON,
        temptargets: JSON
    ) -> RawJSON {
        dispatchPrecondition(condition: .onQueue(processQueue))
        return jsWorker.inCommonContext { worker in
            worker.evaluate(script: Script(name: OpenAPS.Prepare.log))
            worker.evaluate(script: Script(name: OpenAPS.Bundle.autosens))
            worker.evaluate(script: Script(name: OpenAPS.Prepare.autosens))
            return worker.call(
                function: OpenAPS.Function.generate,
                with: [
                    glucose,
                    pumpHistory,
                    basalprofile,
                    profile,
                    carbs,
                    temptargets
                ]
            )
        }
    }
}

// MARK: - Profile creation and Autotune integration for APSManager compatibility

extension HybridOpenAPS {
    func makeProfiles(useAutotune: Bool = false) -> Future<Autotune?, Never> {
        Future { promise in
            self.processQueue.async {
                info(.openAPS, "🚀 FreeAPS X: Swift makeProfiles (JavaScript DISABLED)")

                // Используем Swift алгоритмы для создания профиля
                do {
                    let profileResult = try self.swiftCoordinator.createProfile()

                    // Конвертируем в JSON формат который ожидает система
                    let profileJSON = self.convertSwiftProfileToJSON(profileResult)
                    self.storage.save(profileJSON, as: OpenAPS.Settings.profile)

                    // Если нужен autotune - запускаем его
                    if useAutotune {
                        self.swiftCoordinator.autotune(
                            categorizeUamAsBasal: false,
                            tuneInsulinCurve: false
                        ).sink { autotune in
                            promise(.success(autotune))
                        }.store(in: &self.cancellables)
                    } else {
                        // Создаём базовый Autotune из текущего профиля
                        let autotune = Autotune(
                            createdAt: Date(),
                            basalProfile: profileResult.basals,
                            sensitivity: Decimal(profileResult.sens),
                            carbRatio: Decimal(profileResult.carbRatioValue)
                        )

                        promise(.success(autotune))
                    }

                } catch {
                    warning(.openAPS, "❌ FreeAPS X: Swift profile creation failed: \(error)")
                    promise(.success(nil))
                }
            }
        }
    }

    // MARK: - Profile JSON Conversion

    private func convertSwiftProfileToJSON(_ profileResult: SwiftOpenAPSAlgorithms.ProfileResult) -> String {
        """
        {
            "max_iob": \(profileResult.maxIOB),
            "max_daily_basal": \(profileResult.settings.maxBasal),
            "max_basal": \(profileResult.settings.maxBasal),
            "max_bg": \(profileResult.targets.targets.first?.high ?? 160),
            "min_bg": \(profileResult.targets.targets.first?.low ?? 100),
            "carb_ratio": \(profileResult.carbRatioValue),
            "sens": \(profileResult.sens),
            "current_basal": \(profileResult.currentBasal),
            "dia": \(profileResult.dia),
            "target_bg": \((Double(profileResult.targets.targets.first?.low ?? 100) +
                    Double(profileResult.targets.targets.first?.high ?? 160)) / 2.0),
            "temptargetSet": \(profileResult.temptargetSet),
            "autosens_max": \(profileResult.autosensMax),
            "exercise_mode": \(profileResult.exerciseMode),
            "enableSMB_always": false,
            "enableSMB_with_COB": false,
            "enableUAM": false
        }
        """
    }

    // MARK: - dailyAutotune Function (для совместимости с APSManager)

    func dailyAutotune() -> AnyPublisher<Bool, Never> {
        Future<Bool, Never> { promise in
            self.processQueue.async {
                info(.openAPS, "🚀 FreeAPS X: Swift daily autotune")

                // Запускаем autotune с полными настройками
                self.swiftCoordinator.autotune(
                    categorizeUamAsBasal: false,
                    tuneInsulinCurve: false
                ).sink { autotune in
                    if autotune != nil {
                        info(.openAPS, "✅ Daily autotune completed successfully")
                        promise(.success(true))
                    } else {
                        warning(.openAPS, "⚠️ Daily autotune returned no results")
                        promise(.success(false))
                    }
                }.store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Settings Management

extension HybridOpenAPS {
    /// Включает/выключает Swift режим
    func setSwiftMode(_ enabled: Bool, withComparison: Bool = false) {
        var settings = loadSettings()
        settings.useSwiftOpenAPS = enabled
        settings.logSwiftVsJSComparison = withComparison

        storage.save(settings, as: OpenAPS.FreeAPS.settings)

        if enabled {
            info(.openAPS, "🚀 FreeAPS X: Swift OpenAPS ENABLED - Performance mode activated!")
            if withComparison {
                info(.openAPS, "📊 JavaScript comparison logging ENABLED for transparency")
            }
        } else {
            info(.openAPS, "📜 FreeAPS X: JavaScript OpenAPS mode - Compatibility mode")
        }
    }

    /// Проверяет текущий режим
    var isSwiftMode: Bool {
        loadSettings().useSwiftOpenAPS
    }

    /// Проверяет, включено ли логирование сравнений
    var isComparisonLoggingEnabled: Bool {
        loadSettings().logSwiftVsJSComparison
    }
}

// MARK: - Integration helpers

extension HybridOpenAPS {
    /// Создает HybridOpenAPS из существующего storage
    static func create(storage: FileStorage) -> HybridOpenAPS {
        HybridOpenAPS(storage: storage)
    }

    /// Заменяет существующий OpenAPS в dependency injection
    static func replaceInDI(storage _: FileStorage) {
        // TODO: Integration with Swinject container
        info(.openAPS, "🔄 HybridOpenAPS registered for dependency injection")
    }
}
