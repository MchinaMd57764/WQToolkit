import SwiftUI
import UIKit

enum WQTab: String, CaseIterable, Hashable {
    case files, clean, lens, tweaks, settings

    var icon: String {
        switch self {
        case .files: return "folder.fill"
        case .clean: return "sparkles"
        case .lens: return "eye.fill"
        case .tweaks: return "wand.and.stars"
        case .settings: return "gearshape.fill"
        }
    }

    var key: String {
        switch self {
        case .files: return "tab_files"
        case .clean: return "tab_clean"
        case .lens: return "tab_lens"
        case .tweaks: return "tab_tweaks"
        case .settings: return "tab_settings"
        }
    }
}

struct RootView: View {
    @StateObject private var l10n = L10n.shared
    @ObservedObject private var appearance = Appearance.shared
    @State private var tab: WQTab = .files

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                FilesView(onOpenClean: { tab = .clean })
                    .opacity(tab == .files ? 1 : 0)
                    .allowsHitTesting(tab == .files)
                CleanView()
                    .opacity(tab == .clean ? 1 : 0)
                    .allowsHitTesting(tab == .clean)
                LensHubView()
                    .opacity(tab == .lens ? 1 : 0)
                    .allowsHitTesting(tab == .lens)
                TweaksView()
                    .opacity(tab == .tweaks ? 1 : 0)
                    .allowsHitTesting(tab == .tweaks)
                SettingsView()
                    .opacity(tab == .settings ? 1 : 0)
                    .allowsHitTesting(tab == .settings)
            }
            WQTabBar(selection: $tab)
                .padding(.horizontal, 22)
                .padding(.bottom, 2)
        }
        .environmentObject(l10n)
        .preferredColorScheme(appearance.scheme)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            #if DEBUG
            DebugLaunch.runProbes()
            switch DebugLaunch.route {
            case .some("clean"): tab = .clean
            case .some("settings"): tab = .settings
            case .some("tweaks"): tab = .tweaks
            case .some(let r) where r.hasPrefix("lens"): tab = .lens
            default: break
            }
            #endif
        }
    }
}

struct WQTabBar: View {
    @EnvironmentObject private var l10n: L10n
    @Binding var selection: WQTab
    @Namespace private var ns
    @State private var barWidth: CGFloat = 0
    @State private var scrubIndex: Int?

    private let inset: CGFloat = 5
    private var tabs: [WQTab] { WQTab.allCases }

    var body: some View {
        GlassBar {
            HStack(spacing: 2) {
                ForEach(tabs, id: \.self) { t in
                    let selected = selection == t
                    Button {
                        if !selected {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selection = t
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon)
                                .font(.system(size: 15, weight: .semibold))
                            Text(l10n.t(t.key))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selected ? Theme.tabSelected : Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.tabPillTop, Theme.tabPillBottom],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .overlay(Capsule().strokeBorder(Theme.tabPillStroke, lineWidth: 1))
                                    .shadow(color: Theme.tabPillShadow, radius: 8, y: 3)
                                    .matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(inset)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: BarWidthKey.self, value: g.size.width)
                }
            )
            .onPreferenceChange(BarWidthKey.self) { barWidth = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { v in scrub(to: v.location.x) }
                    .onEnded { _ in scrubIndex = nil }
            )
        }
    }

    private func scrub(to x: CGFloat) {
        let inner = barWidth - inset * 2
        guard inner > 0 else { return }
        let seg = inner / CGFloat(tabs.count)
        let idx = min(max(Int((x - inset) / seg), 0), tabs.count - 1)
        guard scrubIndex != idx else { return }
        scrubIndex = idx
        let target = tabs[idx]
        guard selection != target else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selection = target
        }
    }
}

private struct BarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct GlassBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            content
                .glassEffect(.regular.tint(Theme.bg.opacity(0.55)).interactive(), in: Capsule())
                .shadow(color: Theme.barShadow, radius: 22, y: 10)
        }
    }
}
