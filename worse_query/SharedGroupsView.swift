import SwiftUI
import Combine

struct SharedGroup: Identifiable, Hashable {
    let path: String
    let groupID: String
    let bytes: Int64
    let files: Int

    var id: String { path }
}

final class SharedGroupStore: ObservableObject {
    static let shared = SharedGroupStore()

    @Published private(set) var groups: [SharedGroup] = []
    @Published private(set) var scanning = false
    @Published private(set) var scanned = false
    @Published private(set) var progressDone = 0
    @Published private(set) var progressTotal = 0

    private init() {}

    var totalBytes: Int64 { groups.reduce(0) { $0 + $1.bytes } }
    var totalFiles: Int { groups.reduce(0) { $0 + $1.files } }

    func scan(force: Bool = false) {
        if scanning { return }
        if scanned && !force { return }
        scanning = true
        scanned = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Access.shared.grant(WQPaths.appGroups)
            let dirs = (wqReadEntries(WQPaths.appGroups) ?? []).filter(\.isDir)
            DispatchQueue.main.async {
                self.progressTotal = dirs.count
                self.progressDone = 0
            }

            var out: [SharedGroup] = []
            var logLines: [String] = ["# WQ groups \(Date())"]
            for (idx, dir) in dirs.enumerated() {
                Access.shared.grant(dir.path)
                let meta = dir.path + "/.com.apple.mobile_container_manager.metadata.plist"
                Access.shared.grant(meta)
                var gid = dir.name
                var keys = "-"
                let metaData = try? Data(contentsOf: URL(fileURLWithPath: meta))
                if let data = metaData,
                   let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                   let dict = obj as? [String: Any] {
                    keys = dict.keys.joined(separator: ",")
                    if let id = dict["MCMMetadataIdentifier"] as? String, !id.isEmpty { gid = id }
                }
                logLines.append("\(dir.name)|exists=\(FileManager.default.fileExists(atPath: meta) ? 1 : 0)|meta=\(metaData?.count ?? -1)|keys=\(keys)")

                var bytes: Int64 = 0
                var files = 0
                var label = ""
                let root = URL(fileURLWithPath: dir.path, isDirectory: true)
                if let walker = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) {
                    while let url = walker.nextObject() as? URL {
                        let name = url.lastPathComponent
                        if label.isEmpty, name.hasPrefix("group."), name != "group." {
                            label = (name as NSString).deletingPathExtension
                        }
                        var st = stat()
                        guard lstat(url.path, &st) == 0 else { continue }
                        let kind = st.st_mode & S_IFMT
                        if kind == S_IFLNK || kind == S_IFDIR { continue }
                        bytes += Int64(st.st_size)
                        files += 1
                        if files >= 100_000 { break }
                    }
                }
                if gid == dir.name, !label.isEmpty { gid = label }

                if files > 0 {
                    out.append(SharedGroup(path: dir.path, groupID: gid, bytes: bytes, files: files))
                }
                let done = idx + 1
                DispatchQueue.main.async { self.progressDone = done }
            }

            let sorted = out.sorted { $0.bytes > $1.bytes }
            #if DEBUG
            logLines.append("# n=\(sorted.count)")
            let logURL = URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent("wq_groups.log")
            try? logLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
            #endif
            DispatchQueue.main.async {
                self.groups = sorted
                self.scanning = false
                self.scanned = true
                self.progressDone = dirs.count
                #if DEBUG
                NSLog("WQGROUPS n=%d bytes=%lld files=%d", sorted.count,
                      sorted.reduce(0) { $0 + $1.bytes }, sorted.reduce(0) { $0 + $1.files })
                #endif
            }
        }
    }
}

struct SharedGroupsView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var store = SharedGroupStore.shared

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_groups_title"),
                               subtitle: l10n.t("lens_groups_sub"),
                               icon: "square.stack.3d.up.fill",
                               showsBack: true)

                    summaryCard

                    if store.scanning {
                        scanningCard
                    } else if store.scanned && store.groups.isEmpty {
                        EmptyState(icon: "square.stack.3d.up.slash",
                                   title: l10n.t("lens_groups_empty"),
                                   detail: l10n.t("lens_groups_empty_sub"))
                    } else if store.scanned {
                        SectionHeader(title: l10n.t("lens_groups_title"),
                                      trailing: l10n.f("lens_groups_n", store.groups.count))
                        list
                    }

                    Text(l10n.t("lens_groups_note"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["WQ_DEBUG_GROUPS_SCAN"] == "1", !store.scanned, !store.scanning {
                store.scan(force: true)
            }
            #endif
        }
    }

    private var summaryCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("lens_groups_title"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.sub)
                        Text(store.scanned ? wqSizeString(store.totalBytes) : "—")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.orange, Theme.pink],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.orange.opacity(0.14)).frame(width: 44, height: 44)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                }

                if store.scanned {
                    HStack(spacing: 7) {
                        StatusPill(text: "\(store.groups.count)", tint: Theme.orange)
                        StatusPill(text: "\(store.totalFiles)", tint: Theme.cyan)
                        Spacer(minLength: 0)
                    }
                }

                PrimaryButton(title: store.scanning ? l10n.t("lens_groups_scanning")
                                                    : (store.scanned ? l10n.t("lens_groups_rescan") : l10n.t("lens_groups_scan")),
                              icon: "sparkle.magnifyingglass",
                              tint: Theme.orange,
                              enabled: !store.scanning) {
                    store.scan(force: true)
                }
            }
        }
    }

    private var scanningCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l10n.t("lens_groups_scanning"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(store.progressDone) / \(store.progressTotal)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.sub)
                }
                ProgressView(value: store.progressTotal == 0 ? 0 : Double(store.progressDone) / Double(store.progressTotal))
                    .tint(Theme.orange)
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.groups.enumerated()), id: \.element.id) { idx, group in
                NavigationLink {
                    BrowserView(path: group.path)
                } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: "square.stack.3d.up.fill", tint: Theme.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.groupID)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(group.files)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer(minLength: 6)
                        Text(wqSizeString(group.bytes))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(group.bytes > 0 ? Theme.text : Theme.faint)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx != store.groups.count - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 64)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}
