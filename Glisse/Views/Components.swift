import SwiftUI

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
