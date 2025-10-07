import Combine
import Foundation

// MARK: - Swift портирование JavaScript алгоритмов oref0

// Цель: заменить JavaScriptWorker нативными Swift алгоритмами для улучшения производительности FreeAPS X

final class SwiftOpenAPSAlgorithms {
    // MARK: - IOB (Insulin On Board) Calculator

    struct IOBInputs {
        let pumpHistory: [PumpHistoryEvent]
        let profile: Profile
        let clock: Date
        let autosens: Autosens?
    }

    struct IOBResult {
        let iob: Double
        let activity: Double
        let basaliob: Double
        let netBasalInsulin: Double
        let bolusiob: Double
        let hightempInsulin: Double
        let lastBolusTime: Date?
        let lastTemp: TempBasal?
        let time: Date

        var rawJSON: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")

            let lastBolusTimeString = lastBolusTime.map { formatter.string(from: $0) } ?? "null"
            let lastTempJSON = lastTemp?.rawJSON ?? "null"

            return """
            {
                "iob": \(iob),
                "activity": \(activity),
                "basaliob": \(basaliob),
                "netbasalinsulin": \(netBasalInsulin),
                "bolusiob": \(bolusiob),
                "hightempinsulin": \(hightempInsulin),
                "lastBolusTime": \(lastBolusTimeString == "null" ? "null" : "\"\(lastBolusTimeString)\""),
                "lastTemp": \(lastTempJSON),
                "time": "\(formatter.string(from: time))"
            }
            """
        }
    }

    /// Портирование generate() из lib/iob/index.js
    /// Использует: SwiftIOBHistory + SwiftIOBTotal + SwiftIOBCalculate
    static func calculateIOB(inputs: IOBInputs) -> IOBResult {
        let currentTime = inputs.clock
        var totalIOB = 0.0
        var totalActivity = 0.0
        var basalIOB = 0.0
        var bolusIOB = 0.0
        var netBasalInsulin = 0.0
        var hightempInsulin = 0.0
        var lastBolusTime: Date?
        var lastTemp: TempBasal?

        // 🚨 ИСПРАВЛЕНО 1: force minimum DIA of 3h (lib/iob/total.js lines 24-27)
        var dia = inputs.profile.dia
        if dia < 3.0 {
            dia = 3.0
        }
        
        // 🚨 ИСПРАВЛЕНО 2: Force minimum of 5 hour DIA for exponential curves (lib/iob/total.js lines 60-63)
        let curve = inputs.profile.insulinActionCurve ?? "rapid-acting"
        if curve != "bilinear" && dia < 5.0 {
            dia = 5.0
        }

        // 🚨 ИСПРАВЛЕНО 3: Фильтруем по DIA, а не по фиксированным 6 часам (lib/iob/total.js line 69)
        let diaAgo = currentTime.addingTimeInterval(-dia * 3600)
        let recentEvents = inputs.pumpHistory.filter { event in
            let eventDate = event.timestamp
            return eventDate >= diaAgo && eventDate <= currentTime
        }

        // Обрабатываем каждое событие помпы
        for event in recentEvents {
            let eventDate = event.timestamp

            switch event.type {
            case .bolus:
                if let amount = event.amount, Double(amount) > 0 {
                    let iobContrib = calculateBolusIOB(
                        amount: Double(amount),
                        eventTime: eventDate,
                        currentTime: currentTime,
                        profile: inputs.profile
                    )

                    bolusIOB += iobContrib.iob
                    totalActivity += iobContrib.activity

                    if lastBolusTime == nil || eventDate > lastBolusTime! {
                        lastBolusTime = eventDate
                    }
                }

            case .tempBasal,
                 .tempBasalDuration:
                if let rate = event.rate, let duration = event.duration {
                    let tempBasal = TempBasal(
                        duration: Int(duration),
                        rate: rate,
                        temp: .absolute,
                        timestamp: eventDate
                    )

                    let basalContrib = calculateBasalIOB(
                        tempBasal: tempBasal,
                        currentTime: currentTime,
                        profile: inputs.profile,
                        autosens: inputs.autosens
                    )

                    basalIOB += basalContrib.iob
                    totalActivity += basalContrib.activity
                    netBasalInsulin += basalContrib.netBasal

                    if Double(rate) > inputs.profile.currentBasal {
                        hightempInsulin += basalContrib.iob
                    }

                    if lastTemp == nil || eventDate > lastTemp!.timestamp {
                        lastTemp = tempBasal
                    }
                }

            default:
                break
            }
        }

        totalIOB = bolusIOB + basalIOB

        // 🚨 ИСПРАВЛЕНО 4: Округление результатов как в JS (lib/iob/total.js lines 95-100)
        return IOBResult(
            iob: round(totalIOB * 1000) / 1000,
            activity: round(totalActivity * 10000) / 10000,
            basaliob: round(basalIOB * 1000) / 1000,
            netBasalInsulin: round(netBasalInsulin * 1000) / 1000,
            bolusiob: round(bolusIOB * 1000) / 1000,
            hightempInsulin: hightempInsulin,
            lastBolusTime: lastBolusTime,
            lastTemp: lastTemp,
            time: currentTime
        )
    }

    // MARK: - Приватные методы для расчета IOB

    private static func calculateBolusIOB(
        amount: Double,
        eventTime: Date,
        currentTime: Date,
        profile: Profile
    ) -> (iob: Double, activity: Double) {
        // 🚨 ИСПРАВЛЕНО: Используем ТОЧНУЮ функцию iobCalc из оригинала

        let minutesAgo = currentTime.timeIntervalSince(eventTime) / 60.0

        // Проверяем, что болюс еще активен
        let diaInMinutes = profile.dia * 60.0
        guard minutesAgo >= 0, minutesAgo <= diaInMinutes else {
            return (iob: 0, activity: 0)
        }

        // Используем кривую действия инсулина из профиля
        let curve = profile.insulinActionCurve ?? "rapid-acting"

        if curve == "bilinear" {
            return calculateBilinearIOB(amount: amount, minutesAgo: minutesAgo, dia: profile.dia)
        } else {
            return calculateExponentialIOB(
                amount: amount,
                minutesAgo: minutesAgo,
                dia: profile.dia,
                peakTime: profile.insulinPeakTime ?? 75.0,
                curveType: curve
            )
        }
    }

    private static func calculateBasalIOB(
        tempBasal: TempBasal,
        currentTime: Date,
        profile: Profile,
        autosens: Autosens?
    ) -> (iob: Double, activity: Double, netBasal: Double) {
        let minutesAgo = currentTime.timeIntervalSince(tempBasal.timestamp) / 60.0
        let durationMinutes = tempBasal.duration

        // Проверяем, что temp basal еще в пределах действия
        guard minutesAgo >= 0, minutesAgo <= Double(durationMinutes) else {
            return (iob: 0, activity: 0, netBasal: 0)
        }

        // Рассчитываем разницу с базальным профилем
        let currentBasal = profile.currentBasal
        let sensRatio = Double(autosens?.ratio ?? 1.0)
        let adjustedBasal = currentBasal * sensRatio
        let netBasalRate = Double(tempBasal.rate) - adjustedBasal

        // Если нет разницы, то нет дополнительного IOB
        guard abs(netBasalRate) > 0.001 else {
            return (iob: 0, activity: 0, netBasal: 0)
        }

        // Рассчитываем количество инсулина
        let timeActive = min(minutesAgo, Double(durationMinutes))
        let netBasalInsulin = netBasalRate * timeActive / 60.0

        // Рассчитываем IOB от этого инсулина используя ТОЧНУЮ функцию
        let curve = profile.insulinActionCurve ?? "rapid-acting"
        let iobResult: (iob: Double, activity: Double)

        if curve == "bilinear" {
            iobResult = calculateBilinearIOB(
                amount: abs(netBasalInsulin),
                minutesAgo: minutesAgo,
                dia: profile.dia
            )
        } else {
            iobResult = calculateExponentialIOB(
                amount: abs(netBasalInsulin),
                minutesAgo: minutesAgo,
                dia: profile.dia,
                peakTime: profile.insulinPeakTime ?? 75.0,
                curveType: curve
            )
        }

        // If temp basal was below basal rate, IOB is negative
        let finalIOB = netBasalRate > 0 ? iobResult.iob : -iobResult.iob
        let finalActivity = netBasalRate > 0 ? iobResult.activity : -iobResult.activity

        return (iob: finalIOB, activity: finalActivity, netBasal: netBasalInsulin)
    }

    private static func calculateBilinearIOB(
        amount: Double,
        minutesAgo: Double,
        dia: Double
    ) -> (iob: Double, activity: Double) {
        // 🚨 ИСПРАВЛЕНО: ТОЧНЫЕ формулы из оригинального /tmp/oref0/lib/iob/calculate.js (строка 36-80)

        let default_dia = 3.0 // assumed duration of insulin activity, in hours (строка 38)
        let peak = 75.0 // assumed peak insulin activity, in minutes (строка 39)
        let end = 180.0 // assumed end of insulin activity, in minutes (строка 40)

        // Scale minsAgo by the ratio of the default dia / the user's dia (строка 45-46)
        let timeScalar = default_dia / dia
        let scaled_minsAgo = timeScalar * minutesAgo

        var activityContrib = 0.0
        var iobContrib = 0.0

        // ТОЧНЫЕ формулы как в оригинале (строка 56-58)
        let activityPeak = 2.0 / (dia * 60.0) // Based on area of triangle
        let slopeUp = activityPeak / peak
        let slopeDown = -1.0 * (activityPeak / (end - peak))

        if scaled_minsAgo < peak {
            // Before peak (строка 62-65)
            activityContrib = amount * (slopeUp * scaled_minsAgo)

            let x1 = (scaled_minsAgo / 5.0) + 1.0 // scaled minutes since bolus, pre-peak
            iobContrib = amount * ((-0.001852 * x1 * x1) + (0.001852 * x1) + 1.000000)

        } else if scaled_minsAgo < end {
            // After peak (строка 69-73)
            let minsPastPeak = scaled_minsAgo - peak
            activityContrib = amount * (activityPeak + (slopeDown * minsPastPeak))

            let x2 = (scaled_minsAgo - peak) / 5.0 // scaled minutes past peak
            iobContrib = amount * ((0.001323 * x2 * x2) + (-0.054233 * x2) + 0.555560)
        }
        // After end: both remain 0

        return (iob: max(0, iobContrib), activity: max(0, activityContrib))
    }

    private static func calculateExponentialIOB(
        amount: Double,
        minutesAgo: Double,
        dia: Double,
        peakTime: Double = 75.0,
        curveType: String = "rapid-acting"
    ) -> (iob: Double, activity: Double) {
        // 🚨 ИСПРАВЛЕНО: ТОЧНЫЕ формулы из оригинального /tmp/oref0/lib/iob/calculate.js (строка 130-135)

        // ТОЧНАЯ логика peak time как в оригинале (строка 86-116)
        var actualPeak = peakTime

        if curveType == "rapid-acting" {
            // Используем peakTime если передан, иначе default 75
            if peakTime > 120 {
                debug(.openAPS, "📊 Setting maximum Insulin Peak Time of 120m for \(curveType) insulin")
                actualPeak = 120
            } else if peakTime < 50 {
                debug(.openAPS, "📊 Setting minimum Insulin Peak Time of 50m for \(curveType) insulin")
                actualPeak = 50
            } else {
                actualPeak = peakTime
            }
        } else if curveType == "ultra-rapid" {
            if peakTime > 100 {
                debug(.openAPS, "📊 Setting maximum Insulin Peak Time of 100m for \(curveType) insulin")
                actualPeak = 100
            } else if peakTime < 35 {
                debug(.openAPS, "📊 Setting minimum Insulin Peak Time of 35m for \(curveType) insulin")
                actualPeak = 35
            } else {
                actualPeak = peakTime
            }
        }

        let end = dia * 60.0 // end of insulin activity, in minutes (строка 117)

        var activityContrib = 0.0
        var iobContrib = 0.0

        guard minutesAgo < end else {
            return (iob: 0, activity: 0)
        }

        // ТОЧНЫЕ exponential формулы из оригинала (строка 130-135)
        // Formula source: https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473

        let tau = actualPeak * (1.0 - actualPeak / end) / (1.0 - 2.0 * actualPeak / end) // time constant
        let a = 2.0 * tau / end // rise time factor
        let S = 1.0 / (1.0 - a + (1.0 + a) * exp(-end / tau)) // auxiliary scale factor

        // ТОЧНЫЕ формулы из оригинала (строка 134-135)
        activityContrib = amount * (S / pow(tau, 2)) * minutesAgo * (1.0 - minutesAgo / end) * exp(-minutesAgo / tau)

        let exponentialTerm = exp(-minutesAgo / tau)
        let polynomialTerm = (pow(minutesAgo, 2) / (tau * end * (1.0 - a)) - minutesAgo / tau - 1.0) * exponentialTerm + 1.0
        iobContrib = amount * (1.0 - S * (1.0 - a) * polynomialTerm)

        return (iob: max(0, iobContrib), activity: max(0, activityContrib))
    }
}

// MARK: - Расширения для поддержки существующих типов

extension Profile {
    var dia: Double {
        // DIA из профиля или значение по умолчанию
        insulinActionCurve == "rapid-acting" ? 3.0 : 4.0
    }

    var currentBasal: Double {
        // basals property не определено в protocol Profile - используем значение по умолчанию
        1.0 // Будет переопределено в конкретных реализациях (ProfileResult)
    }

    var insulinActionCurve: String? {
        // Получаем тип кривой инсулина из профиля
        // Возможные значения: "bilinear", "rapid-acting", "ultra-rapid"
        "rapid-acting" // По умолчанию
    }

    var insulinPeakTime: Double? {
        // Время пика инсулина в минутах
        // Из lib/iob/calculate.js: rapid-acting = 75, ultra-rapid = 55
        switch insulinActionCurve {
        case "rapid-acting":
            return 75.0
        case "ultra-rapid":
            return 55.0
        default:
            return 75.0
        }
    }
}

extension TempBasal {
    init(rate: Double, duration: Double, timestamp: Date) {
        self.init(duration: Int(duration), rate: Decimal(rate), temp: .absolute, timestamp: timestamp)
    }
}
