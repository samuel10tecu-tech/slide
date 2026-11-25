import ActivityKit
import SwiftUI
import WidgetKit

struct SlideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SlideActivityAttributes.self) { context in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.speedText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(context.state.unitText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.phaseText)
                        .font(.headline)
                    Text(context.state.altitudeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if !context.attributes.resort.isEmpty {
                        Text(context.attributes.resort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.state.speedText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(context.state.unitText)
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.phaseText)
                            .font(.headline)
                        Text(context.state.altitudeText)
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.attributes.resort.isEmpty {
                        Text(context.attributes.resort)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                Image(systemName: "gauge.with.needle.fill")
            } compactTrailing: {
                Text(context.state.speedText)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "gauge.with.needle.fill")
            }
        }
    }
}

@main
struct SlideActivityBundle: WidgetBundle {
    var body: some Widget {
        SlideLiveActivity()
    }
}
