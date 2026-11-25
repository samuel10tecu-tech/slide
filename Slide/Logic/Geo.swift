import Foundation

enum Geo {
    static let earthRadius = 6_371_000.0

    static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dP = (lat2 - lat1) * .pi / 180
        let dL = (lon2 - lon1) * .pi / 180
        let a = sin(dP / 2) * sin(dP / 2) + cos(p1) * cos(p2) * sin(dL / 2) * sin(dL / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadius * c
    }

    /// Déplace un point d'un nombre de mètres vers le nord et l'est.
    static func project(lat: Double, lon: Double, north: Double, east: Double) -> (lat: Double, lon: Double) {
        let dLat = north / earthRadius * (180 / .pi)
        let cosLat = cos(lat * .pi / 180)
        let dLon = east / (earthRadius * max(cosLat, 0.2)) * (180 / .pi)
        return (lat + dLat, lon + dLon)
    }
}

extension Calendar {
    /// Calendrier de Genève : la saison et les dates affichées suivent l'heure locale.
    static var zurich: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .gmt
        calendar.locale = Locale(identifier: "fr_CH")
        return calendar
    }
}

struct Season: Equatable, Identifiable, Hashable {
    var start: Date
    var end: Date
    var title: String

    var id: String { title }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Saison alpine : 1er septembre → 31 août.
    static func containing(_ date: Date, calendar: Calendar = .zurich) -> Season {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let startYear = month >= 9 ? year : year - 1
        let start = dateAt(year: startYear, month: 9, day: 1, calendar: calendar) ?? date
        let end = dateAt(year: startYear + 1, month: 9, day: 1, calendar: calendar) ?? date
        return Season(start: start, end: end, title: "Saison \(startYear)–\(startYear + 1)")
    }

    private static func dateAt(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 0
        parts.minute = 0
        parts.second = 0
        return calendar.date(from: parts)
    }
}

enum SpeedBand: Int, CaseIterable, Equatable {
    case slow
    case cruise
    case fast
    case flying
    case extreme

    static func forSpeed(_ metersPerSecond: Double) -> SpeedBand {
        let kmh = metersPerSecond * 3.6
        switch kmh {
        case ..<20: return .slow
        case ..<40: return .cruise
        case ..<60: return .fast
        case ..<80: return .flying
        default: return .extreme
        }
    }
}

/// Display colours for a ski speed. Absolute km/h stops, or stretched so the day's max sits near the top.
enum SpeedPaint {
    static let stops: [(kmh: Double, hex: UInt32)] = [
        (0, 0x3B82F6),
        (15, 0x14C8C0),
        (30, 0x3DDC6A),
        (45, 0xFFE14A),
        (60, 0xFF9A2E),
        (75, 0xFF3B4E),
        (90, 0xE23BFF),
    ]

    static func paintedKmh(_ metersPerSecond: Double, dayMaxKmh: Double?) -> Double {
        let raw = max(0, metersPerSecond * 3.6)
        guard let dayMaxKmh, dayMaxKmh > 20 else { return raw }
        return min(100, raw / dayMaxKmh * 90)
    }

    static func rgb(_ metersPerSecond: Double, dayMaxKmh: Double?) -> (Double, Double, Double) {
        let kmh = paintedKmh(metersPerSecond, dayMaxKmh: dayMaxKmh)
        let upper = stops.lastIndex { $0.kmh <= kmh } ?? 0
        let next = min(upper + 1, stops.count - 1)
        let a = stops[upper]
        let b = stops[next]
        let span = max(0.001, b.kmh - a.kmh)
        let t = upper == next ? 0 : min(1, max(0, (kmh - a.kmh) / span))
        let ar = Double((a.hex >> 16) & 0xFF), ag = Double((a.hex >> 8) & 0xFF), ab = Double(a.hex & 0xFF)
        let br = Double((b.hex >> 16) & 0xFF), bg = Double((b.hex >> 8) & 0xFF), bb = Double(b.hex & 0xFF)
        return ((ar + (br - ar) * t) / 255, (ag + (bg - ag) * t) / 255, (ab + (bb - ab) * t) / 255)
    }
}
