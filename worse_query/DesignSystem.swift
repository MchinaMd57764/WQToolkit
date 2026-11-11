import SwiftUI
import UIKit
import Combine

enum Theme {
    private static func dyn(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let bg = dyn(UIColor(red: 0.953, green: 0.965, blue: 0.984, alpha: 1),
                        UIColor(red: 0.035, green: 0.043, blue: 0.058, alpha: 1))
    static let bgLift = dyn(UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                            UIColor(red: 0.062, green: 0.076, blue: 0.098, alpha: 1))
    static let card = dyn(UIColor(white: 0.0, alpha: 0.045),
                          UIColor(white: 1.0, alpha: 0.055))
    static let cardLift = dyn(UIColor(white: 0.0, alpha: 0.075),
                              UIColor(white: 1.0, alpha: 0.09))
    static let stroke = dyn(UIColor(white: 0.0, alpha: 0.09),
                            UIColor(white: 1.0, alpha: 0.09))
    static let gloss = dyn(UIColor(white: 1.0, alpha: 0.55),
                           UIColor(white: 1.0, alpha: 0.05))
    static let text = dyn(UIColor(red: 0.067, green: 0.086, blue: 0.129, alpha: 1),
                          UIColor(red: 0.94, green: 0.955, blue: 0.975, alpha: 1))
    static let sub = dyn(UIColor(red: 0.353, green: 0.392, blue: 0.455, alpha: 1),
                         UIColor(red: 0.55, green: 0.60, blue: 0.67, alpha: 1))
    static let faint = dyn(UIColor(red: 0.541, green: 0.576, blue: 0.639, alpha: 1),
                           UIColor(red: 0.36, green: 0.40, blue: 0.46, alpha: 1))
    static let blue = dyn(UIColor(red: 0.18, green: 0.486, blue: 0.965, alpha: 1),
                          UIColor(red: 0.29, green: 0.61, blue: 1.0, alpha: 1))
    static let cyan = dyn(UIColor(red: 0.055, green: 0.624, blue: 0.710, alpha: 1),
                          UIColor(red: 0.25, green: 0.82, blue: 0.92, alpha: 1))
    static let green = dyn(UIColor(red: 0.078, green: 0.627, blue: 0.353, alpha: 1),
                           UIColor(red: 0.24, green: 0.82, blue: 0.54, alpha: 1))
    static let orange = dyn(UIColor(red: 0.878, green: 0.518, blue: 0.071, alpha: 1),
                            UIColor(red: 1.0, green: 0.67, blue: 0.28, alpha: 1))
    static let red = dyn(UIColor(red: 0.871, green: 0.231, blue: 0.231, alpha: 1),
                         UIColor(red: 1.0, green: 0.36, blue: 0.36, alpha: 1))
    static let purple = dyn(UIColor(red: 0.482, green: 0.322, blue: 0.910, alpha: 1),
                            UIColor(red: 0.69, green: 0.53, blue: 1.0, alpha: 1))
    static let pink = dyn(UIColor(red: 0.878, green: 0.227, blue: 0.471, alpha: 1),
                          UIColor(red: 1.0, green: 0.44, blue: 0.64, alpha: 1))
    static let yellow = dyn(UIColor(red: 0.788, green: 0.604, blue: 0.039, alpha: 1),
                            UIColor(red: 0.98, green: 0.83, blue: 0.35, alpha: 1))

    static let tabPillTop = dyn(UIColor(red: 0.18, green: 0.486, blue: 0.965, alpha: 0.20),
                                UIColor(white: 1.0, alpha: 0.22))
    static let tabPillBottom = dyn(UIColor(red: 0.18, green: 0.486, blue: 0.965, alpha: 0.10),
                                   UIColor(white: 1.0, alpha: 0.09))
    static let tabPillStroke = dyn(UIColor(red: 0.18, green: 0.486, blue: 0.965, alpha: 0.30),
                                   UIColor(white: 1.0, alpha: 0.22))
    static let tabPillShadow = dyn(UIColor(white: 0.0, alpha: 0.10), UIColor(white: 0.0, alpha: 0.24))
    static let tabSelected = dyn(UIColor(red: 0.10, green: 0.36, blue: 0.82, alpha: 1),
                                 UIColor(red: 0.94, green: 0.955, blue: 0.975, alpha: 1))
    static let barShadow = dyn(UIColor(white: 0.0, alpha: 0.12), UIColor(white: 0.0, alpha: 0.40))
}

final class Appearance: ObservableObject {
    static let shared = Appearance()
    static let key = "wq.appearance"
    static let options = ["auto", "light", "dark"]

    @Published var mode: String {
        didSet { if !debugLocked { UserDefaults.standard.set(mode, forKey: Self.key) } }
    }
    private var debugLocked = false

    init() {
        mode = UserDefaults.standard.string(forKey: Self.key) ?? "auto"
        #if DEBUG
        if let m = ProcessInfo.processInfo.environment["WQ_DEBUG_APPEARANCE"],
           Self.options.contains(m) {
            debugLocked = true
            mode = m
        }
        #endif
    }

    var scheme: ColorScheme? {
        switch mode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.bg
            GeometryReader { geo in
                Circle()
                    .fill(Theme.blue.opacity(scheme == .dark ? 0.20 : 0.13))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 90)
                    .offset(x: -geo.size.width * 0.45, y: -geo.size.height * 0.28)
                Circle()
                    .fill(Theme.purple.opacity(scheme == .dark ? 0.14 : 0.10))
                    .frame(width: geo.size.width * 0.95)
                    .blur(radius: 100)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.05)
                Circle()
                    .fill(Theme.cyan.opacity(scheme == .dark ? 0.08 : 0.06))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 120)
                    .offset(x: -geo.size.width * 0.15, y: geo.size.height * 0.62)
            }
            LinearGradient(
                colors: [Color.black.opacity(0.0), Theme.bg.opacity(scheme == .dark ? 0.85 : 0.75)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.gloss, Color.clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.sub)
                .textCase(.uppercase)
                .kerning(0.6)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String = ""
    var icon: String
    var showsBack: Bool = false

    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(l10n.t("back"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sub)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.card))
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.blue.opacity(0.85), Theme.purple.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: Theme.blue.opacity(0.35), radius: 14, y: 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(Theme.text)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                    }
                }
                Spacer()
            }
        }
        .padding(.top, 8)
    }
}

struct IconTile: View {
    let icon: String
    var tint: Color = Theme.blue

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.16))
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 36, height: 36)
    }
}

struct StatusPill: View {
    let text: String
    var tint: Color = Theme.green

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct RiskBadge: View {
    let level: Int
    @EnvironmentObject private var l10n: L10n

    private var tint: Color {
        switch level {
        case 2: return Theme.red
        case 1: return Theme.orange
        default: return Theme.green
        }
    }

    private var label: String {
        switch level {
        case 2: return l10n.t("high_risk")
        case 1: return l10n.t("medium_risk")
        default: return l10n.t("low_risk")
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct ToolRow: View {
    let icon: String
    var tint: Color = Theme.blue
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            IconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let badge {
                StatusPill(text: badge, tint: tint)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
        .contentShape(Rectangle())
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.blue
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(enabled ? Color.white : Theme.sub)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: enabled ? [tint, tint.opacity(0.72)] : [Theme.cardLift, Theme.cardLift],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(enabled ? Color.white.opacity(0.18) : Theme.stroke, lineWidth: 1)
            )
            .shadow(color: enabled ? tint.opacity(0.35) : .clear, radius: 16, y: 8)
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var mono: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, design: mono ? .monospaced : .default))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.faint)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.sub)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
