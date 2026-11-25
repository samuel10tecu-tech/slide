import Foundation

enum SlidePreview {
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-slidePreview") }

    static var screen: String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-slidePreview"), index + 1 < args.count else { return "track" }
        return args[index + 1]
    }

    static let archive = SampleDay.make()
    static var samples: [TrackSample] { archive.samples }
}
