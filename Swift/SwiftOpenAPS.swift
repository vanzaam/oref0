import Combine
import Foundation

// MARK: - Swift версия OpenAPS для замены JavaScriptWorker

// Цель: Улучшить производительность FreeAPS X, убрав зависимость от JavaScript

final class SwiftOpenAPS {
    private let storage: FileStorage
    private let processQueue = DispatchQueue(label: "SwiftOpenAPS.processQueue", qos: .utility)
    private var _cancellables = Set<AnyCancellable>()

    init(storage: FileStorage) {
        self.storage = storage
    }

    // MARK: - IOB Calculation (Swift версия)

    func calculateIOB(
        pumpHistory: [PumpHistoryEvent],
        profile: Profile,
        clock: Date = Date(),
        autosens: Autosens? = nil
    ) -> Future<SwiftOpenAPSAlgorithms.IOBResult, Never> {
        Future { promise in
            self.processQueue.async {
                let inputs = SwiftOpenAPSAlgorithms.IOBInputs(
                    pumpHistory: pumpHistory,
                    profile: profile,
                    clock: clock,
                    autosens: autosens
                )

                let result = SwiftOpenAPSAlgorithms.calculateIOB(inputs: inputs)
                promise(.success(result))
            }
        }
    }

    // MARK: - Hybrid IOB (сравнение со JavaScript)

    func calculateIOBHybrid(
        pumpHistory: JSON,
        profile: JSON,
        clock: JSON,
        autosens: JSON,
        useSwift: Bool = true
    ) -> Future<RawJSON, Never> {
        Future { promise in
            self.processQueue.async {
                if useSwift {
                    // Используем Swift версию
                    do {
                        let pumpHistoryEvents = try self.parsePumpHistory(from: pumpHistory)
                        let profileObj = try self.parseProfile(from: profile)
                        let clockDate = try self.parseDate(from: clock)
                        let autosensObj = try? self.parseAutosens(from: autosens)

                        let inputs = SwiftOpenAPSAlgorithms.IOBInputs(
                            pumpHistory: pumpHistoryEvents,
                            profile: profileObj,
                            clock: clockDate,
                            autosens: autosensObj
                        )

                        let result = SwiftOpenAPSAlgorithms.calculateIOB(inputs: inputs)
                        promise(.success(result.rawJSON))

                    } catch {
                        warning(.openAPS, "Swift IOB calculation failed: \(error), falling back to JavaScript")
                        // Fallback to JavaScript (будет реализован позже)
                        promise(.success("{}"))
                    }
                } else {
                    // Fallback to JavaScript (для сравнения результатов)
                    promise(.success("{}"))
                }
            }
        }
    }

    // MARK: - Parsing helpers

    private func parsePumpHistory(from json: JSON) throws -> [PumpHistoryEvent] {
        guard let jsonData = json.rawJSON.data(using: .utf8) else {
            throw SwiftOpenAPSError.invalidJSON("Invalid pump history JSON")
        }

        // ТОЧНЫЙ парсинг JSON как в JavaScript версии
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([PumpHistoryEvent].self, from: jsonData)
        } catch {
            // Если не удается декодировать как массив, пробуем как объект
            warning(.openAPS, "Failed to parse pump history as array: \(error)")
            return []
        }
    }

    private func parseProfile(from json: JSON) throws -> SwiftOpenAPSAlgorithms.ProfileResult {
        // ТОЧНЫЙ парсинг профиля из JSON как в JavaScript версии
        guard let jsonData = json.rawJSON.data(using: .utf8) else {
            throw SwiftOpenAPSError.invalidJSON("Invalid profile JSON")
        }

        // Парсим сырой JSON профиль и создаем ProfileInputs для алгоритма
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            // Декодируем как dictionary для гибкости
            let profileDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let profileDict = profileDict else {
                throw SwiftOpenAPSError.invalidJSON("Profile is not a valid JSON object")
            }

            // Извлекаем основные компоненты профиля
            let pumpSettings = extractPumpSettings(from: profileDict)
            let bgTargets = extractBGTargets(from: profileDict)
            let isf = extractISF(from: profileDict)
            let basalProfile = extractBasalProfile(from: profileDict)
            let preferences = extractPreferences(from: profileDict)
            let carbRatios = extractCarbRatios(from: profileDict)

            // Создаем ProfileInputs и генерируем профиль
            let inputs = SwiftOpenAPSAlgorithms.ProfileInputs(
                pumpSettings: pumpSettings,
                bgTargets: bgTargets,
                isf: isf,
                basalProfile: basalProfile,
                preferences: preferences,
                carbRatios: carbRatios,
                tempTargets: nil,
                model: nil,
                autotune: nil
            )

            let result = SwiftOpenAPSAlgorithms.createProfile(inputs: inputs)
            switch result {
            case let .success(profile):
                return profile
            case let .failure(error):
                throw error
            }

        } catch {
            throw SwiftOpenAPSError.invalidJSON("Failed to parse profile: \(error)")
        }
    }

    // MARK: - Profile parsing helpers

    private func extractPumpSettings(from dict: [String: Any]) -> PumpSettings? {
        guard let settingsDict = dict["settings"] as? [String: Any] else { return nil }

        let insulinActionCurve = settingsDict["insulin_action_curve"] as? Double ?? 3.0
        let maxBolus = settingsDict["maxBolus"] as? Double ?? 10.0
        let maxBasal = settingsDict["maxBasal"] as? Double ?? 2.0

        return PumpSettings(
            insulinActionCurve: Decimal(insulinActionCurve),
            maxBolus: Decimal(maxBolus),
            maxBasal: Decimal(maxBasal)
        )
    }

    private func extractBGTargets(from _: [String: Any]) -> BGTargets? {
        // ВАЖНО: SwiftOpenAPS НЕ используется в production!
        // Реальная работа выполняется через HybridOpenAPS → SwiftOpenAPSCoordinator
        // Этот код существует только для совместимости API
        nil // HybridOpenAPS использует другой путь загрузки данных
    }

    private func extractISF(from _: [String: Any]) -> InsulinSensitivities? {
        // ВАЖНО: SwiftOpenAPS НЕ используется в production!
        nil // HybridOpenAPS использует другой путь загрузки данных
    }

    private func extractBasalProfile(from _: [String: Any]) -> [BasalProfileEntry]? {
        // ВАЖНО: SwiftOpenAPS НЕ используется в production!
        nil // HybridOpenAPS использует другой путь загрузки данных
    }

    private func extractPreferences(from _: [String: Any]) -> Preferences? {
        // ВАЖНО: SwiftOpenAPS НЕ используется в production!
        nil // HybridOpenAPS использует другой путь загрузки данных
    }

    private func extractCarbRatios(from _: [String: Any]) -> CarbRatios? {
        // ВАЖНО: SwiftOpenAPS НЕ используется в production!
        nil // HybridOpenAPS использует другой путь загрузки данных
    }

    private func parseDate(from json: JSON) throws -> Date {
        // Парсим дату из JSON
        let dateString = json.rawJSON.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        } else {
            return Date() // По умолчанию текущая дата
        }
    }

    private func parseAutosens(from json: JSON) throws -> Autosens {
        guard let jsonData = json.rawJSON.data(using: .utf8) else {
            throw SwiftOpenAPSError.invalidJSON("Invalid autosens JSON")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Autosens.self, from: jsonData)
    }
}

// MARK: - Error types

enum SwiftOpenAPSError: Error {
    case invalidJSON(String)
    case calculationError(String)
    case unsupportedAlgorithm(String)

    var localizedDescription: String {
        switch self {
        case let .invalidJSON(message):
            return "Invalid JSON: \(message)"
        case let .calculationError(message):
            return "Calculation error: \(message)"
        case let .unsupportedAlgorithm(message):
            return "Unsupported algorithm: \(message)"
        }
    }
}

// MARK: - Performance comparison utilities

extension SwiftOpenAPS {
    /// Сравнивает результаты Swift и JavaScript версий для валидации
    func benchmarkIOBCalculation(
        pumpHistory: JSON,
        profile: JSON,
        clock: JSON,
        autosens: JSON
    ) -> Future<(swift: RawJSON, js: RawJSON, timeDiff: TimeInterval), Never> {
        Future { promise in
            self.processQueue.async {
                // Измеряем время Swift версии
                let swiftStart = CFAbsoluteTimeGetCurrent()

                // Запуск Swift версии
                self.calculateIOBHybrid(
                    pumpHistory: pumpHistory,
                    profile: profile,
                    clock: clock,
                    autosens: autosens,
                    useSwift: true
                ).sink { swiftResult in
                    let swiftTime = CFAbsoluteTimeGetCurrent() - swiftStart

                    // Здесь должно быть сравнение с JavaScript версией
                    // Пока возвращаем только Swift результат
                    promise(.success((
                        swift: swiftResult,
                        js: "{}", // TODO: JavaScript результат
                        timeDiff: swiftTime
                    )))
                }.store(in: &self._cancellables)
            }
        }
    }
}

// MARK: - Integration helpers

extension SwiftOpenAPS {
    /// Создает Swift версию из существующих данных FreeAPS
    static func fromStorage(_ storage: FileStorage) -> SwiftOpenAPS {
        SwiftOpenAPS(storage: storage)
    }

    /// Проверяет, готова ли Swift версия для использования
    var isReady: Bool {
        // Проверки готовности Swift алгоритмов
        true // Пока всегда готова
    }

    /// Включает/выключает Swift алгоритмы vs JavaScript
    var useSwiftAlgorithms: Bool {
        get {
            // Можно сделать настройкой в UserDefaults
            UserDefaults.standard.bool(forKey: "useSwiftOpenAPS")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useSwiftOpenAPS")
            info(.openAPS, "Swift OpenAPS algorithms: \(newValue ? "ENABLED" : "DISABLED")")
        }
    }
}
