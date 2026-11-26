import ActivityKit
import Foundation

@MainActor
final class LiveActivityBridge {
    private var activity: ActivityKit.Activity<SlideActivityAttributes>?
    private var lastPush = Date.distantPast

    /// If the app is killed while tracking, the Lock Screen greys the speed out after this.
    private static var staleDate: Date { Date().addingTimeInterval(120) }

    /// End activities left over from a previous launch (app killed or out of memory).
    static func endOrphans() {
        for leftover in ActivityKit.Activity<SlideActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func start(resort: String, state: SlideActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        do {
            activity = try ActivityKit.Activity.request(
                attributes: SlideActivityAttributes(resort: resort),
                content: ActivityKit.ActivityContent(state: state, staleDate: Self.staleDate),
                pushType: nil
            )
            lastPush = Date()
        } catch {
            activity = nil
        }
    }

    func update(_ state: SlideActivityAttributes.ContentState, force: Bool = false) {
        guard let activity else { return }
        let now = Date()
        if !force && now.timeIntervalSince(lastPush) < 2 { return }
        lastPush = now
        Task {
            await activity.update(ActivityKit.ActivityContent(state: state, staleDate: Self.staleDate))
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
