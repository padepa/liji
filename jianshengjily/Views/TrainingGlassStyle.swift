import SwiftUI
import UIKit

enum TrainingTheme: String, CaseIterable, Identifiable {
    case energy
    case lava
    case ocean
    case violet

    static let defaultTheme = TrainingTheme.violet

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .energy:
            return L10n.string("琥珀")
        case .lava:
            return L10n.string("熔岩")
        case .ocean:
            return L10n.string("深海")
        case .violet:
            return L10n.string("紫夜")
        }
    }

    var subtitle: String {
        switch self {
        case .energy:
            return L10n.string("暖光、力量感")
        case .lava:
            return L10n.string("更热、更有冲劲")
        case .ocean:
            return L10n.string("冷静、专注")
        case .violet:
            return L10n.string("夜训高级感")
        }
    }

    var primary: Color {
        switch self {
        case .energy:
            return Color(red: 1.00, green: 0.63, blue: 0.30)
        case .lava:
            return Color(red: 1.00, green: 0.39, blue: 0.24)
        case .ocean:
            return Color(red: 0.34, green: 0.75, blue: 0.96)
        case .violet:
            return Color(red: 0.72, green: 0.46, blue: 0.96)
        }
    }

    var success: Color {
        switch self {
        case .energy:
            return Color(red: 1.00, green: 0.78, blue: 0.42)
        case .lava:
            return Color(red: 1.00, green: 0.62, blue: 0.36)
        case .ocean:
            return Color(red: 0.58, green: 0.86, blue: 1.00)
        case .violet:
            return Color(red: 0.86, green: 0.72, blue: 1.00)
        }
    }

    var accent: Color {
        switch self {
        case .energy:
            return Color(red: 0.95, green: 0.46, blue: 0.18)
        case .lava:
            return Color(red: 0.92, green: 0.20, blue: 0.26)
        case .ocean:
            return Color(red: 0.20, green: 0.56, blue: 0.82)
        case .violet:
            return Color(red: 0.52, green: 0.36, blue: 0.92)
        }
    }

    var backgroundGlowA: Color {
        switch self {
        case .energy:
            return Color(red: 0.90, green: 0.40, blue: 0.16)
        case .lava:
            return Color(red: 0.90, green: 0.16, blue: 0.18)
        case .ocean:
            return Color(red: 0.10, green: 0.48, blue: 0.78)
        case .violet:
            return Color(red: 0.46, green: 0.28, blue: 0.88)
        }
    }

    var backgroundGlowB: Color {
        switch self {
        case .energy:
            return Color(red: 1.00, green: 0.62, blue: 0.26)
        case .lava:
            return Color(red: 1.00, green: 0.42, blue: 0.24)
        case .ocean:
            return Color(red: 0.24, green: 0.68, blue: 0.92)
        case .violet:
            return Color(red: 0.34, green: 0.24, blue: 0.74)
        }
    }

    var tickColors: [Color] {
        [primary.opacity(0.62), .white.opacity(0.84), primary]
    }

    var alternateAppIconName: String? {
        switch self {
        case .energy:
            return "AppIconAmber"
        case .lava:
            return "AppIconLava"
        case .ocean:
            return "AppIconOcean"
        case .violet:
            return nil
        }
    }

    var primaryUIColor: UIColor {
        UIColor(primary)
    }

    var successUIColor: UIColor {
        UIColor(success)
    }

    var accentUIColor: UIColor {
        UIColor(accent)
    }
}

private struct TrainingThemeKey: EnvironmentKey {
    static let defaultValue = TrainingTheme.defaultTheme
}

extension EnvironmentValues {
    var trainingTheme: TrainingTheme {
        get { self[TrainingThemeKey.self] }
        set { self[TrainingThemeKey.self] = newValue }
    }
}

struct TrainingGlassBackground: View {
    @Environment(\.trainingTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.014, blue: 0.022),
                    Color(red: 0.035, green: 0.030, blue: 0.052),
                    Color(red: 0.010, green: 0.011, blue: 0.016)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    theme.backgroundGlowA.opacity(0.24),
                    theme.backgroundGlowA.opacity(0.06),
                    .clear
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: 410
            )
            .offset(x: -130, y: -130)

            RadialGradient(
                colors: [
                    theme.backgroundGlowB.opacity(0.16),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 390
            )
            .offset(x: 130, y: 150)

            TrainingAtmosphereGrid()
                .opacity(0.24)

            LinearGradient(
                colors: [
                    .white.opacity(0.07),
                    .clear,
                    .black.opacity(0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct TrainingAtmosphereGrid: View {
    @Environment(\.trainingTheme) private var theme

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 44
            var path = Path()

            for x in stride(from: -spacing, through: size.width + spacing, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 84, y: size.height))
            }

            for y in stride(from: 20, through: size.height + spacing, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + 28))
            }

            context.stroke(path, with: .color(theme.primary.opacity(0.09)), lineWidth: 0.8)
        }
        .blendMode(.screen)
        .accessibilityHidden(true)
    }
}

struct GlassMetricView: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(L10n.string(title))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .black))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

struct TrainingStageLabel: View {
    @Environment(\.trainingTheme) private var theme

    let text: String

    var body: some View {
        Text(L10n.string(text))
            .font(.caption.weight(.black))
            .tracking(0.9)
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.primary.opacity(0.12), in: Capsule())
    }
}

struct TrainingMetricPill: View {
    @Environment(\.trainingTheme) private var theme

    let label: String
    let value: String
    var systemImage: String? = nil
    var tint: Color? = nil

    private var resolvedTint: Color {
        tint ?? theme.primary
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                    .foregroundStyle(resolvedTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string(label))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.075), in: Capsule())
        .overlay {
            Capsule()
                .stroke(resolvedTint.opacity(0.18), lineWidth: 1)
        }
    }
}

struct PowerTraceMarkView: View {
    @Environment(\.trainingTheme) private var theme

    var size: CGFloat = 104
    var progress: Double = 0.72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: size * 0.18, x: 0, y: size * 0.12)

            markBody
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var markBody: some View {
        let glow = max(0.58, min(progress, 1.0))

        return ZStack {
            HStack(alignment: .bottom, spacing: size * 0.075) {
                traceBar(theme.tickColors[0], height: size * 0.28, opacity: glow)
                traceBar(theme.tickColors[1], height: size * 0.41, opacity: glow)
                traceBar(theme.tickColors[2], height: size * 0.55, opacity: glow)
            }
            .frame(height: size * 0.58, alignment: .bottom)
            .offset(y: -size * 0.01)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.84, height: size * 0.09)
                .shadow(color: .black.opacity(0.34), radius: size * 0.05, x: 0, y: size * 0.035)

            plate(width: size * 0.17, height: size * 0.40)
                .offset(x: -size * 0.43)
            plate(width: size * 0.12, height: size * 0.29)
                .offset(x: -size * 0.31)

            plate(width: size * 0.17, height: size * 0.40)
                .offset(x: size * 0.43)
            plate(width: size * 0.12, height: size * 0.29)
                .offset(x: size * 0.31)
        }
        .frame(width: size, height: size)
    }

    private func traceBar(_ color: Color, height: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(color.opacity(opacity))
            .frame(width: size * 0.065, height: height)
            .shadow(color: color.opacity(0.46), radius: size * 0.05, x: 0, y: size * 0.02)
    }

    private func plate(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.45, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.black.opacity(0.22))
                    .frame(width: width * 0.72, height: height * 0.13)
                    .padding(.top, height * 0.08)
            }
    }
}

struct SetCountGlyphView: View {
    @Environment(\.trainingTheme) private var theme

    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(theme.primary.opacity(0.22), lineWidth: max(1, size * 0.035))
                }

            VStack(alignment: .leading, spacing: size * 0.09) {
                setMark(.white.opacity(0.78), widthRatio: 0.58)
                setMark(theme.primary.opacity(0.88), widthRatio: 0.42)
                setMark(.white.opacity(0.58), widthRatio: 0.66)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func setMark(_ color: Color, widthRatio: CGFloat) -> some View {
        Capsule()
            .fill(color.opacity(0.94))
            .frame(width: size * widthRatio, height: max(2, size * 0.075))
            .shadow(color: color.opacity(0.32), radius: size * 0.06, x: 0, y: size * 0.025)
    }
}

struct FitnessSectionTitle: View {
    let text: String

    var body: some View {
        Text(L10n.string(text))
            .font(.title2.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrainingSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            TextField(L10n.string(prompt), text: $text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                    HapticsService.closePanel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedThemeRawValue: String

    private var selectedTheme: TrainingTheme {
        TrainingTheme(rawValue: selectedThemeRawValue) ?? .defaultTheme
    }

    var body: some View {
        ZStack {
            TrainingGlassBackground()
                .environment(\.trainingTheme, selectedTheme)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FitnessSectionTitle(text: "主题")

                    ForEach(TrainingTheme.allCases) { theme in
                        Button {
                            if selectedThemeRawValue != theme.rawValue {
                                HapticsService.themeChanged()
                            }
                            selectedThemeRawValue = theme.rawValue
                        } label: {
                            ThemeOptionRow(
                                theme: theme,
                                isSelected: theme == selectedTheme
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("主题外观")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    HapticsService.closePanel()
                    dismiss()
                }
            }
        }
    }

}

private struct ThemeOptionRow: View {
    let theme: TrainingTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 72, height: 58)

                HStack(spacing: 5) {
                    swatch(theme.primary)
                    swatch(theme.success)
                    swatch(theme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(theme.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)

                Text(theme.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? theme.primary : .secondary)
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22, tint: isSelected ? theme.primary : nil, interactive: true)
    }

    private func swatch(_ color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 11, height: 36)
            .shadow(color: color.opacity(0.45), radius: 8, x: 0, y: 4)
    }
}

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26
    var tint: Color? = nil
    var interactive = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            content
                .background {
                    shape.fill(Color.white.opacity(0.058))
                }
                .glassEffect(
                    (tint.map { Glass.regular.tint($0.opacity(0.09)) } ?? Glass.regular.tint(.white.opacity(0.045)))
                        .interactive(interactive),
                    in: shape
                )
                .overlay {
                    shape.stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 22, x: 0, y: 15)
        } else {
            content
                .background(Color.white.opacity(0.065), in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 22, x: 0, y: 14)
        }
    }
}

extension View {
    func dismissKeyboardOnDownwardDrag() -> some View {
        modifier(DownwardKeyboardDismissModifier())
    }

    func liquidGlassCard(cornerRadius: CGFloat = 28, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func liquidGlassSafeAreaBar() -> some View {
        modifier(LiquidGlassSafeAreaBarModifier())
    }

    @ViewBuilder
    func trainingButtonStyle(prominent: Bool = false, tint: Color = .orange) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .tint(tint)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .buttonStyle(.glassProminent)
            } else {
                self
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .tint(tint)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(PrimaryTrainingButtonStyle(background: tint))
            } else {
                buttonStyle(SecondaryTrainingButtonStyle(tint: tint))
            }
        }
    }
}

private struct DownwardKeyboardDismissModifier: ViewModifier {
    @State private var didDismissForCurrentDrag = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !didDismissForCurrentDrag,
                              value.translation.height > 12,
                              abs(value.translation.height) > abs(value.translation.width) else {
                            return
                        }

                        didDismissForCurrentDrag = true
                        dismissKeyboard()
                    }
                    .onEnded { _ in
                        didDismissForCurrentDrag = false
                    },
                including: .all
            )
    }

    private func dismissKeyboard() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.endEditing(true) }
    }
}

struct LiquidGlassSafeAreaBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea()
            }
    }
}

struct PrimaryTrainingButtonStyle: ButtonStyle {
    var background: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()

        if #available(iOS 26.0, *) {
            configuration.label
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .tint(background)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.vertical, 18)
                .background(background.opacity(configuration.isPressed ? 0.78 : 1), in: shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        }
    }
}

struct SecondaryTrainingButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()

        if #available(iOS 26.0, *) {
            configuration.label
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.vertical, 12)
                .tint(tint)
                .buttonStyle(.glass)
                .controlSize(.large)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.vertical, 16)
                .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.085), in: shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        }
    }
}
