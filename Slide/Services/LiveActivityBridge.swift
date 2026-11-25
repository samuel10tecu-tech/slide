import ActivityKit
import Foundation

@MainActor
final class LiveActivityBridge {
    private var activity: Activity<SlideActivityAttributes>?
    private var lastPush = Date.distantPast

    func start(resort: String, state: SlideActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        do {
            activity = try Activity.request(
                attributes: SlideActivityAttributes(resort: resort),
                content: ActivityContent(state: state, staleDate: nil),
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
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            let empty: ActivityContent<SlideActivityAttributes.ContentState>? = nil
            await activity.end(empty, dismissalPolicy: .immediate)
        }
    }
}
