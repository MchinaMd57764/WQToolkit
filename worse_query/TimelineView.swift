import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared

    @State private var window = 1
    @State private var appFilter: String?

    private var since: Date {
        switch window {
        case 0: return Date().addingTimeInterval(-3600)
        case 2: return Date().addingTimeInterval(-7 * 86400)
        default: return Date().addingTimeInterval(-86400)
        }
    }

    private var filtered: [RecentItem] {
        lens.recent.filter { item in
            item.mtime >= since && (appFilter == nil || item.bundleID == appFilter)
        }
    }

    private var apps: [(id: String, name: String, count: Int)] {
        var dict: [String: (String, Int)] = [:]
        for item in lens.recent where item.mtime >= since {
            let old = dict[item.bundleID] ?? (item.appName, 0)
            dict[item.bundleID] = (old.0, old.1 + 1)
        }
        return dict.map { (id: $0.key, name: $0.value.0, count: $0.value.1) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var shown: [RecentItem] { Array(filtered.prefix(400)) }
    private var bytes: Int64 { filtered.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_timeline_title"),
                               subtitle: l10n.t("lens_timeline_sub"),
                               icon: "clock.arrow.circlepath",
                               showsBack: true)

                    if lens.scanning {
                        ProgressView().tint(Theme.cyan).padding(.top, 30)
                    } else if !lens.scanned {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(l10n.t("lens_need_scan"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.sub)
                                PrimaryButton(title: l10n.t("lens_scan_all"), icon: "sparkle.magnifyingglass",
                                              tint: Theme.cyan) {
                                    lens.scan(force: true)
                                }
                            }
                        }
                    } else {
                        stats
                        chips
                        if shown.isEmpty {
                            EmptyState(icon: "clock.badge.questionmark", title: l10n.t("lens_timeline_empty"),
                                       detail: l10n.t("lens_timeline_empty_sub"))
                        } else {
                            list
                            Text(l10n.f("lens_timeline_more", shown.count))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.faint)
                        }
                        Text(l10n.t("lens_timeline_note"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        .onAppear {
            if let v = ProcessInfo.processInfo.environment["WQ_DEBUG_TIMELINE_WINDOW"], let n = Int(v) {
                window = n
            }
        }
        #endif
    }

    private var stats: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(filtered.count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.cyan)
                    Text(l10n.t("lens_changes"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
                Divider().overlay(Theme.stroke).frame(height: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(wqSizeString(bytes))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.green)
                    Text(l10n.t("lens_total_size"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
                Divider().overlay(Theme.stroke).frame(height: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Set(filtered.map(\.bundleID)).count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.purple)
                    Text(l10n.t("lens_apps"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach([(0, "lens_1h"), (1, "lens_24h"), (2, "lens_7d")], id: \.0) { item in
                Button {
                    window = item.0
                } label: {
                    Text(l10n.t(item.1))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(window == item.0 ? Theme.bg : Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(window == item.0 ? Theme.cyan : Theme.card)
                        )
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            Menu {
                Button {
                    appFilter = nil
                } label: {
                    Label(l10n.t("lens_all_apps"), systemImage: appFilter == nil ? "checkmark" : "square.grid.2x2")
                }
                Divider()
                ForEach(apps, id: \.id) { app in
                    Button {
                        appFilter = app.id
                    } label: {
                        if appFilter == app.id {
                            Label("\(app.name) (\(app.count))", systemImage: "checkmark")
                        } else {
                            Text("\(app.name) (\(app.count))")
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(appFilter == nil ? l10n.t("lens_all_apps")
                                         : (apps.first { $0.id == appFilter }?.name ?? l10n.t("lens_all_apps")))
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.card))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: 11) {
                    VStack(spacing: 2) {
                        Text(timeString(item.mtime))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text)
                        Text(dayString(item.mtime))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                    }
                    .frame(width: 48, alignment: .leading)

                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(wqAppTint(item.bundleID).opacity(0.16))
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(wqAppTint(item.bundleID))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(item.appName)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(wqSizeString(item.bytes))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                if idx != shown.count - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 103)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }

    private func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f.string(from: d)
    }
}
