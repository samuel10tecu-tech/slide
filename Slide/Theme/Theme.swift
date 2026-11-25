import SwiftUI

enum Theme {
    static let background = Color(hex: 0x071526)
    static let surface = Color(hex: 0x0E2436)
    static let surface2 = Color(hex: 0x16344A)
    static let line = Color.white.opacity(0.14)
    static let accent = Color(hex: 0x7EE7FF)
    static let ice = Color(hex: 0xB9F3FF)
    static let snow = Color(hex: 0xF7FBFF)
    static let text = Color(hex: 0xF7FBFF)
    static let muted = Color(hex: 0xC5D4E4)
    static let danger = Color(hex: 0xFF5A6A)
    static let orange = Color(hex: 0xFFB15A)
    static let pink = Color(hex: 0xFF8AD4)
    static let pisteGreen = Color(hex: 0x3DDC6A)
    static let pisteBlue = Color(hex: 0x4C8DFF)
    static let pisteRed = Color(hex: 0xFF4D5E)
    static let ink = Color(hex: 0x071526)

    static func color(for band: SpeedBand) -> Color {
        switch band {
        case .slow: return pisteGreen
        case .cruise: return pisteBlue
        case .fast: return pisteRed
        case .flying: return Color(hex: 0xFFE14A)
        case .extreme: return snow
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

    static func glass<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    static func levelColor(_ level: Trick.Level) -> Color {
        switch level {
        case .debutant: return pisteGreen
        case .intermediaire: return pisteBlue
        case .avance: return pisteRed
        case .expert: return snow
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
