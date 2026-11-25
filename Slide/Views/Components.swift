import SwiftUI
import UIKit

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

struct BigButton: View {
    var title: String
    var systemImage: String
    var fill: Color
    var foreground: Color = .black
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .foregroundStyle(foreground)
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct PhaseBadge: View {
    var title: String
    var color: Color
    var pulsing: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .overlay {
                    if pulsing {
                        Circle()
                            .stroke(color.opacity(0.8), lineWidth: 2)
                            .scaleEffect(pulse ? 2.1 : 1)
                            .opacity(pulse ? 0 : 0.8)
                    }
                }
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
        .onAppear { pulse = true }
        .animation(pulsing ? .easeOut(duration: 1.15).repeatForever(autoreverses: false) : .default, value: pulse)
    }
}

struct Banner: View {
    var text: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScreenBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

struct SpeedGauge: View {
    var text: String
    var unit: String
    var fraction: Double
    var tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 16)
            Circle()
                .trim(from: 0.12, to: 0.12 + 0.76 * min(max(fraction, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [Theme.ice, Theme.accent, Theme.orange, Color(hex: 0xFF4D6A)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.spring(duration: 0.45), value: fraction)
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .combine)
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
