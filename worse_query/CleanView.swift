import SwiftUI

struct CleanItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let paths: [String]
    let system: Bool
    var bytes: Int64
    var files: Int
    var selected: Bool = true
}

struct CleanView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var access = Access.shared

    @State private var items: [CleanItem] = []
    @State private var scanning = false
    @State private var scanned = false
    @State private var progress: (done: Int, total: Int) = (0, 0)
    @State private var confirmClean = false
    @State private var cleaning = false
    @State private var msg: Msg?
    @State private var lastFreed: Int64 = 0

    private var selectedItems: [CleanItem] { items.filter(\.selected) }
    private var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    private var systemItems: [CleanItem] { items.filter(\.system) }
    private var appItems: [CleanItem] { items.filter { !$0.system } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        PageHeader(title: l10n.t("clean_title"),
                                   subtitle: l10n.t("scan_hint"),
                                   icon: "sparkles")
                        hero
                        if scanning {
                            scanningCard
                        } else if scanned && items.isEmpty {
                            EmptyState(icon: "checkmark.seal", title: l10n.t("scan_done"))
                        } else if scanned {
                            if !appItems.isEmpty {
                                SectionHeader(title: l10n.t("app_caches"),
                                              trailing: l10n.f("items", appItems.count))
                                list(appItems)
                            }
                            if !systemItems.isEmpty {
                                SectionHeader(title: l10n.t("system_caches"))
                                list(systemItems)
                            }
                            notes
                        } else {
                            hintCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 140)
                }
                if cleaning {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.large).tint(.white)
                        Text(l10n.t("clean_selected")).font(.system(size: 12)).foregroundStyle(.white)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert(l10n.f("clean_confirm_title", selectedItems.count), isPresented: $confirmClean) {
                Button(l10n.t("clean_selected"), role: .destructive) { runClean() }
                Button(l10n.t("cancel"), role: .cancel) {}
            } message: {
                Text(l10n.t("clean_confirm_msg"))
            }
            .alert(item: $msg) { m in
                Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
            }
        }
        .tint(Theme.green)
        .onAppear {
            #if DEBUG
            if DebugLaunch.autoScan && !scanned && !scanning { scan() }
            #endif
        }
    }

    private var hero: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("total_reclaimable"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.sub)
                        Text(scanning || !scanned ? "—" : wqSizeString(totalBytes))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.green, Theme.cyan],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.green.opacity(0.14)).frame(width: 46, height: 46)
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.green)
                    }
                }

                if scanned && !scanning {
                    HStack(spacing: 8) {
                        StatusPill(text: l10n.t("selected") + " " + wqSizeString(selectedBytes), tint: Theme.blue)
                        StatusPill(text: "\(selectedItems.count)", tint: Theme.purple)
                        Spacer()
                        Button {
                            let all = items.allSatisfy(\.selected)
                            for i in items.indices { items[i].selected = !all }
                        } label: {
                            Text(l10n.t("select_all"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.sub)
                        }
                    }
                }

                HStack(spacing: 10) {
                    PrimaryButton(title: scanning ? l10n.t("scanning") : l10n.t("scan"),
                                  icon: "arrow.triangle.2.circlepath",
                                  tint: Theme.green,
                                  enabled: !scanning && !cleaning) {
                        scan()
                    }
                    if scanned && !scanning {
                        PrimaryButton(title: l10n.t("clean_selected"),
                                      icon: "trash",
                                      tint: Theme.orange,
                                      enabled: !selectedItems.isEmpty && !cleaning) {
                            confirmClean = true
                        }
                    }
                }

                if lastFreed > 0 && !scanning {
                    Text(l10n.f("cleaned_ok", wqSizeString(lastFreed)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.green)
                }
            }
        }
    }

    private var scanningCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l10n.t("scanning"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(progress.done) / \(progress.total)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.sub)
                }
                ProgressView(value: progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total))
                    .tint(Theme.green)
                Text(l10n.t("dry_run_note"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            }
        }
    }

    private var hintCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconTile(icon: "folder.badge.gearshape", tint: Theme.orange)
                    Text(l10n.t("scan_hint"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                Text(l10n.t("denylist_note"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.t("denylist_note"))
            Text(l10n.t("dry_run_note"))
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.faint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func list(_ rows: [CleanItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, item in
                Button {
                    if let i = items.firstIndex(where: { $0.id == item.id }) {
                        items[i].selected.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 19))
                            .foregroundStyle(item.selected ? Theme.green : Theme.faint)
                        IconTile(icon: item.system ? "photo.stack.fill" : "app.dashed",
                                 tint: item.system ? Theme.purple : Theme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 6)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(wqSizeString(item.bytes))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(item.bytes > 0 ? Theme.text : Theme.faint)
                            Text("\(item.files)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx != rows.count - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 64)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func scan() {
        scanning = true
        scanned = false
        progress = (0, 0)
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(WQPaths.appGroups)
            Access.shared.grant(WQPaths.systemData)
            Access.shared.grant(WQPaths.mgCacheDir)

            var jobs: [(title: String, subtitle: String, base: String, system: Bool)] = []
            for app in AppCatalog.load() {
                jobs.append((app.name, app.bundleID, app.dataPath, false))
            }
            for (root, system) in [(WQPaths.appGroups, false), (WQPaths.systemData, true)] {
                guard let dirs = wqReadEntries(root) else { continue }
                for d in dirs where d.isDir {
                    var title = d.name
                    if let dict = NSDictionary(contentsOfFile: d.path + "/.com.apple.mobile_container_manager.metadata.plist"),
                       let id = dict["MCMMetadataIdentifier"] as? String {
                        title = id
                    }
                    jobs.append((title, d.path, d.path, system))
                }
            }
            jobs.append(("WQ Toolkit", "com.zhangfuhao.wqtoolkit", NSHomeDirectory(), false))

            let total = jobs.count
            DispatchQueue.main.async { progress = (0, total) }
            var result: [CleanItem] = []
            for (i, job) in jobs.enumerated() {
                Access.shared.grant(job.base)
                var paths: [String] = []
                for rel in ["Library/Caches", "tmp", "Library/WebKit"] {
                    let p = job.base + "/" + rel
                    if FileManager.default.fileExists(atPath: p) { paths.append(p) }
                }
                var bytes: Int64 = 0
                var files = 0
                for p in paths {
                    let s = wqDirSize(p)
                    bytes += s.bytes
                    files += s.count
                }
                if bytes > 0 {
                    result.append(CleanItem(id: job.base, title: job.title, subtitle: job.subtitle,
                                            paths: paths, system: job.system, bytes: bytes, files: files))
                }
                let done = i + 1
                DispatchQueue.main.async { progress = (done, total) }
            }
            DispatchQueue.main.async {
                items = result.sorted { $0.bytes > $1.bytes }
                scanning = false
                scanned = true
                #if DEBUG
                NSLog("WQSCAN total=%lld %@", items.reduce(0) { $0 + $1.bytes },
                      items.map { "\($0.title)|\($0.bytes)|\($0.paths.first ?? "")" }.joined(separator: " ; "))
                if DebugLaunch.autoClean {
                    let home = NSHomeDirectory()
                    if let own = items.first(where: { $0.paths.contains { $0.hasPrefix(home) } }) {
                        for i in items.indices { items[i].selected = items[i].id == own.id }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { runClean() }
                    }
                }
                #endif
            }
        }
    }

    private func runClean() {
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        cleaning = true
        let freed = selectedBytes
        DispatchQueue.global(qos: .userInitiated).async {
            var ok = 0, bad = 0
            for item in targets {
                for p in item.paths {
                    Access.shared.grant((p as NSString).deletingLastPathComponent)
                    Access.shared.grant(p)
                    let r = wqRemoveContents(p)
                    ok += r.removed
                    bad += r.failed
                }
            }
            DispatchQueue.main.async {
                cleaning = false
                lastFreed = freed
                #if DEBUG
                NSLog("WQCLEAN removed=%d failed=%d freed=%lld targets=%@", ok, bad, freed,
                      targets.map(\.title).joined(separator: ","))
                #endif
                if bad == 0 {
                    msg = Msg(text: l10n.f("cleaned_ok", wqSizeString(freed)))
                } else {
                    msg = Msg(text: l10n.f("delete_partial", ok, bad))
                }
                scan()
            }
        }
    }
}
