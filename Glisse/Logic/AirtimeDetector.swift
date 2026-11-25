import Foundation

struct AirtimeHit: Equatable {
    var duration: TimeInterval
}

/// Estime un temps de vol quand l'accéléromètre approche 0 g, puis revient.
/// Ce n'est pas une mesure exacte : le téléphone bouge dans la poche.
struct AirtimeDetector {
    var lowG = 0.42
    var highG = 0.72
    var minDuration = 0.18
    var maxDuration = 3.2

    private var belowSince: TimeInterval?
    private var startedArmed = false

    mutating func reset() {
        belowSince = nil
        startedArmed = false
    }

    mutating func ingest(time: TimeInterval, magnitudeG: Double, armed: Bool) -> AirtimeHit? {
        guard magnitudeG.isFinite, time.isFinite else { return nil }
        if magnitudeG < lowG {
            if belowSince == nil {
                belowSince = time
                startedArmed = armed
            }
            return nil
        }
        guard magnitudeG >= highG, let start = belowSince else { return nil }
        belowSince = nil
        let duration = time - start
        guard startedArmed, duration >= minDuration, duration <= maxDuration else { return nil }
        return AirtimeHit(duration: duration)
    }
}
