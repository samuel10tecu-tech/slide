import Foundation

struct UnitPrefs: Equatable {
    var speedMetric = true
    var distanceMetric = true
    var altitudeMetric = true

    static let metric = UnitPrefs()
}

enum Units {
    static func kmh(fromMps value: Double) -> Double { value * 3.6 }
    static func mph(fromMps value: Double) -> Double { value * 2.2369362920544 }
    static func feet(fromMeters value: Double) -> Double { value * 3.2808398950131 }
    static func miles(fromMeters value: Double) -> Double { value / 1_609.344 }
    static func kilometers(fromMeters value: Double) -> Double { value / 1_000 }
}

enum FormatFR {
    static func decimal(_ value: Double, fractionDigits: Int, grouping: Bool = true) -> String {
        let digits = max(0, min(fractionDigits, 6))
        var decimal = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, digits, .plain)
        let negative = rounded < 0
        if negative {
            rounded *= -1
        }
        let raw = NSDecimalNumber(decimal: rounded).stringValue
        let pieces = raw.split(separator: ".", omittingEmptySubsequences: false)
        let intRaw = String(pieces.first ?? "0")
        let body: String
        if digits == 0 {
            body = grouping ? group(intRaw) : intRaw
        } else {
            var frac = pieces.count > 1 ? String(pieces[1]) : ""
            if frac.count > digits {
                frac = String(frac.prefix(digits))
            }
            while frac.count < digits {
                frac.append("0")
            }
            let whole = grouping ? group(intRaw) : intRaw
            body = whole + "," + frac
        }
        return negative ? "-" + body : body
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours):" + two(minutes) + ":" + two(seconds)
        }
        return "\(minutes):" + two(seconds)
    }

    static func speed(_ metersPerSecond: Double, prefs: UnitPrefs) -> String {
        if prefs.speedMetric {
            return decimal(Units.kmh(fromMps: metersPerSecond), fractionDigits: 1)
        }
        return decimal(Units.mph(fromMps: metersPerSecond), fractionDigits: 1)
    }

    static func speedUnit(_ prefs: UnitPrefs) -> String {
        prefs.speedMetric ? "km/h" : "mph"
    }

    static func distance(_ meters: Double, prefs: UnitPrefs) -> String {
        if prefs.distanceMetric {
            if meters < 1_000 {
                return decimal(meters, fractionDigits: 0) + " m"
            }
            return decimal(Units.kilometers(fromMeters: meters), fractionDigits: 1) + " km"
        }
        let miles = Units.miles(fromMeters: meters)
        if miles < 0.1 {
            let feet = Units.feet(fromMeters: meters)
            return decimal(feet, fractionDigits: 0) + " ft"
        }
        return decimal(miles, fractionDigits: 2) + " mi"
    }

    static func altitude(_ meters: Double, prefs: UnitPrefs) -> String {
        if prefs.altitudeMetric {
            return decimal(meters, fractionDigits: 0) + " m"
        }
        return decimal(Units.feet(fromMeters: meters), fractionDigits: 0) + " ft"
    }

    static func dayTitle(_ date: Date, calendar: Calendar = .zurich) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    static func dayShort(_ date: Date, calendar: Calendar = .zurich) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    static func clock(_ date: Date, calendar: Calendar = .zurich) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func fileStamp(_ date: Date, calendar: Calendar = .zurich) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func group(_ digits: String) -> String {
        let chars = Array(digits)
        var out: [Character] = []
        out.reserveCapacity(chars.count + chars.count / 3)
        for (offset, character) in chars.reversed().enumerated() {
            if offset > 0 && offset % 3 == 0 {
                out.append("\u{202F}")
            }
            out.append(character)
        }
        return String(out.reversed())
    }
}
