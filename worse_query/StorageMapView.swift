import SwiftUI

struct StorageMapView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared
    @State private var selected: AppUsage?

    private var items: [AppUsage] { lens.usage.filter { $0.bytes > 0 } }
    private var top: [AppUsage] { Array(items.prefix(40)) }
    private var maxBytes: Int64 { items.first?.bytes ?? 1 }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_storage_title"),
                               subtitle: l10n.t("lens_storage_sub"),
                               icon: "square.grid.3x3.square",
                               showsBack: true)
                    if lens.scanning {
                        ProgressView().tint(Theme.green).padding(.top, 30)
                    } else if !lens.scanned {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(l10n.t("lens_need_scan"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.sub)
                                PrimaryButton(title: l10n.t("lens_scan_all"), icon: "sparkle.magnifyingglass",
                                              tint: Theme.green) {
                                    lens.scan(force: true)
                                }
                            }
                        }
                    } else {
                        summary
                        SectionHeader(title: l10n.t("lens_storage_map"),
                                      trailing: l10n.f("lens_containers", items.count))
                        treemap
                        SectionHeader(title: l10n.t("lens_storage_rank"))
                        rank
                        Text(l10n.t("lens_storage_note"))
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
        .sheet(item: $selected) { app in
            AppQuickSheet(app: AppInfo(bundleID: app.bundleID, name: app.name, dataPath: app.path))
                .environmentObject(l10n)
        }
    }

    private var summary: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l10n.t("lens_all_data"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.sub)
                        Text(wqSizeString(lens.totalBytes))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.green, Theme.cyan],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.green.opacity(0.14)).frame(width: 46, height: 46)
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.green)
                    }
                }
                HStack(spacing: 8) {
                    StatusPill(text: l10n.f("lens_containers", items.count), tint: Theme.blue)
                    StatusPill(text: l10n.f("lens_files", lens.totalFiles), tint: Theme.purple)
                    StatusPill(text: l10n.t("lens_cache") + " " + wqSizeString(lens.totalCacheBytes), tint: Theme.orange)
                }
            }
        }
    }

    private var treemap: some View {
        GeometryReader { geo in
            let tiles = Self.layout(top, in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
                ForEach(tiles) { tile in
                    let w = max(tile.rect.width - 2, 0)
                    let h = max(tile.rect.height - 2, 0)
                    Button {
                        selected = tile.app
                    } label: {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(tile.app.tint.opacity(0.26))
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(tile.app.tint.opacity(0.55), lineWidth: 1)
                            if w > 62 && h > 34 {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tile.app.name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    if h > 50 {
                                        Text(wqSizeString(tile.app.bytes))
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Theme.sub)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(5)
                            }
                        }
                        .frame(width: w, height: h)
                    }
                    .buttonStyle(.plain)
                    .offset(x: tile.rect.minX + 1, y: tile.rect.minY + 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .frame(height: 260)
    }

    private var rank: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.prefix(20).enumerated()), id: \.element.id) { idx, app in
                Button {
                    selected = app
                } label: {
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                            .frame(width: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(wqSizeString(app.bytes))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.text)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.cardLift)
                                    Capsule()
                                        .fill(app.tint.opacity(0.75))
                                        .frame(width: max(3, g.size.width * CGFloat(Double(app.bytes) / Double(maxBytes))))
                                }
                            }
                            .frame(height: 4)
                            HStack(spacing: 6) {
                                Text(app.bundleID)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                                if app.cacheBytes > 0 {
                                    Text(l10n.t("lens_cache") + " " + wqSizeString(app.cacheBytes))
                                }
                            }
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx != min(items.count, 20) - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 42)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private struct Tile: Identifiable {
        let app: AppUsage
        let rect: CGRect
        var id: String { app.id }
    }

    private static func layout(_ apps: [AppUsage], in rect: CGRect) -> [Tile] {
        guard !apps.isEmpty, rect.width > 1, rect.height > 1 else { return [] }
        var remaining = apps
        var total = remaining.reduce(0.0) { $0 + Double($1.bytes) }
        guard total > 0 else { return [] }
        var current = rect
        var out: [Tile] = []
        var horizontal = rect.width >= rect.height

        while !remaining.isEmpty {
            let app = remaining.removeFirst()
            let frac = Double(app.bytes) / total
            if horizontal {
                let w = current.width * CGFloat(frac)
                out.append(Tile(app: app, rect: CGRect(x: current.minX, y: current.minY,
                                                       width: w, height: current.height)))
                current = CGRect(x: current.minX + w, y: current.minY,
                                 width: max(0, current.width - w), height: current.height)
            } else {
                let h = current.height * CGFloat(frac)
                out.append(Tile(app: app, rect: CGRect(x: current.minX, y: current.minY,
                                                       width: current.width, height: h)))
                current = CGRect(x: current.minX, y: current.minY + h,
                                 width: current.width, height: max(0, current.height - h))
            }
            total -= Double(app.bytes)
            if total <= 0 { break }
            horizontal.toggle()
        }
        return out
    }
}

// MARK: - 应用快捷操作

struct AppQuickSheet: View {
    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss
    let app: AppInfo
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        GlassCard {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(app.tint.opacity(0.85))
                                    Text(app.initial)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(app.bundleID)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Theme.faint)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                            }
                        }

                        VStack(spacing: 0) {
                            NavigationLink {
                                BrowserView(path: app.dataPath)
                            } label: {
                                ToolRow(icon: "folder.fill", tint: Theme.blue,
                                        title: l10n.t("lens_browse"), subtitle: app.dataPath)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Theme.stroke).padding(.leading, 64)

                            NavigationLink {
                                TransferView(app: app)
                            } label: {
                                ToolRow(icon: "shippingbox.fill", tint: Theme.orange,
                                        title: l10n.t("lens_transfer_title"), subtitle: l10n.t("lens_transfer_sub"))
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Theme.stroke).padding(.leading, 64)

                            NavigationLink {
                                InjectView(app: app)
                            } label: {
                                ToolRow(icon: "syringe.fill", tint: Theme.pink,
                                        title: l10n.t("lens_inject_title"), subtitle: l10n.t("lens_inject_sub"))
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Theme.stroke).padding(.leading, 64)

                            NavigationLink {
                                PrefsInspectorView(app: app)
                            } label: {
                                ToolRow(icon: "slider.horizontal.3", tint: Theme.purple,
                                        title: l10n.t("lens_prefs_title"), subtitle: l10n.t("lens_prefs_sub"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))

                        Button {
                            UIPasteboard.general.string = app.dataPath
                            copied = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? l10n.t("lens_copied") : l10n.t("lens_copy_path"))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(copied ? Theme.green : Theme.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(l10n.t("lens_app_actions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("close")) { dismiss() }
                }
            }
        }
        .tint(Theme.blue)
    }
}
