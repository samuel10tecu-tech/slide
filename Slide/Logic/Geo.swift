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
