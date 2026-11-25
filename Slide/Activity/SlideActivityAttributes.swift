import ActivityKit
import Foundation

struct SlideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var speedText: String
        var unitText: String
        var altitudeText: String
        var phaseText: String
    }

    var resort: String
}
