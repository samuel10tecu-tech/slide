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
    static func decimal(_ value: Double, fractionDigits: Int, grouping: Bool = true, french: Bool = true) -> String {
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
        let separator: Character = french ? "," : "."
        let groupMark: Character = french ? "\u{202F}" : ","
        let body: String
        if digits == 0 {
            body = grouping ? group(intRaw, mark: groupMark) : intRaw
        } else {
            var frac = pieces.count > 1 ? String(pieces[1]) : ""
            if frac.count > digits {
                frac = String(frac.prefix(digits))
            }
            while frac.count < digits {
                frac.append("0")
            }
            let whole = grouping ? group(intRaw, mark: groupMark) : intRaw
            body = whole + String(separator) + frac
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

    static func speed(_ metersPerSecond: Double, prefs: UnitPrefs, french: Bool = true) -> String {
        if prefs.speedMetric {
            return decimal(Units.kmh(fromMps: metersPerSecond), fractionDigits: 1, french: french)
        }
        return decimal(Units.mph(fromMps: metersPerSecond), fractionDigits: 1, french: french)
    }

    static func speedUnit(_ prefs: UnitPrefs) -> String {
        prefs.speedMetric ? "km/h" : "mph"
    }

    static func distance(_ meters: Double, prefs: UnitPrefs, french: Bool = true) -> String {
        if prefs.distanceMetric {
            if meters < 1_000 {
                return decimal(meters, fractionDigits: 0, french: french) + " m"
            }
            return decimal(Units.kilometers(fromMeters: meters), fractionDigits: 1, french: french) + " km"
        }
        let miles = Units.miles(fromMeters: meters)
        if miles < 0.1 {
            let feet = Units.feet(fromMeters: meters)
            return decimal(feet, fractionDigits: 0, french: french) + " ft"
        }
        return decimal(miles, fractionDigits: 2, french: french) + " mi"
    }

    static func altitude(_ meters: Double, prefs: UnitPrefs, french: Bool = true) -> String {
        if prefs.altitudeMetric {
            return decimal(meters, fractionDigits: 0, french: french) + " m"
        }
        return decimal(Units.feet(fromMeters: meters), fractionDigits: 0, french: french) + " ft"
    }

    static func dayTitle(_ date: Date, french: Bool = true, calendar: Calendar = .zurich) -> String {
        dated(date, format: "EEEE d MMMM", french: french, calendar: calendar)
    }

    static func dayShort(_ date: Date, french: Bool = true, calendar: Calendar = .zurich) -> String {
        dated(date, format: "EEE d MMM", french: french, calendar: calendar)
    }

    static func clock(_ date: Date, calendar: Calendar = .zurich) -> String {
        dated(date, format: "HH:mm", french: true, calendar: calendar)
    }

    private static func dated(_ date: Date, format: String, french: Bool, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: french ? "fr_CH" : "en_GB")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
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

    private static func group(_ digits: String, mark: Character) -> String {
        let chars = Array(digits)
        var out: [Character] = []
        out.reserveCapacity(chars.count + chars.count / 3)
        for (offset, character) in chars.reversed().enumerated() {
            if offset > 0 && offset % 3 == 0 {
                out.append(mark)
            }
            out.append(character)
        }
        return String(out.reversed())
    }
}
