import SwiftUI

enum Theme {
    static let background = Color(hex: 0x090B10)
    static let surface = Color(hex: 0x141824)
    static let surface2 = Color(hex: 0x1C2230)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(hex: 0xC6FF3D)
    static let ice = Color(hex: 0x6AD7FF)
    static let text = Color(hex: 0xF4F7FB)
    static let muted = Color(hex: 0x9AA3B8)
    static let danger = Color(hex: 0xFF5D6C)
    static let orange = Color(hex: 0xFF9A3C)
    static let pink = Color(hex: 0xFF7AD9)

    static func color(for band: SpeedBand) -> Color {
        switch band {
        case .slow: return ice
        case .cruise: return accent
        case .fast: return Color(hex: 0xFFE14A)
        case .flying: return orange
        case .extreme: return Color(hex: 0xFF4D6A)
        }
    }

    static func color(for phase: TrackPhase) -> Color {
        switch phase {
        case .unknown: return muted
        case .skiing: return accent
        case .lift: return ice
        case .rest: return muted
        }
    }

    static func levelColor(_ level: Trick.Level) -> Color {
        switch level {
        case .debutant: return ice
        case .intermediaire: return accent
        case .avance: return orange
        case .expert: return pink
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum PhaseCopy {
    static func title(_ phase: TrackPhase, active: Bool) -> String {
        guard active else { return "Prêt" }
        switch phase {
        case .unknown: return "Calibration"
        case .skiing: return "Descente"
        case .lift: return "Remontée"
        case .rest: return "Repos"
        }
    }
}
