import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum Route: Hashable {
    case dir(String)
    case file(String)
    case apps
    case documents
    case devinfo
}

#if DEBUG
enum DebugLaunch {
    static var route: String? {
        ProcessInfo.processInfo.environment["WQ_DEBUG_ROUTE"]
    }
    static var autoScan: Bool {
        ProcessInfo.processInfo.environment["WQ_DEBUG_AUTOSCAN"] == "1"
    }
    static var autoClean: Bool {
        ProcessInfo.processInfo.environment["WQ_DEBUG_AUTOCLEAN"] == "1"
    }
    static func runProbes() {
        let env = ProcessInfo.processInfo.environment
        if env["WQ_DEBUG_LEASE"] == "1" { LeaseProbe.run() }
        if env["WQ_DEBUG_MCMENUM"] == "1" { McmEnumProbe.run() }
        if env["WQ_DEBUG_SCANPATHS"] == "1" { PathScanProbe.run() }
        if env["WQ_DEBUG_LSPROBE"] == "1" { LsProbe.run() }
    }
}
#endif

struct Msg: Identifiable {
    let id = UUID()
    let text: String
}

struct FilesView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var access = Access.shared
    var onOpenClean: () -> Void

    @State private var pulse = false
    @State private var path = NavigationPath()

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        PageHeader(
                            title: l10n.t("tab_files"),
                            icon: "folder.fill"
                        )
                        statusCard
                        deviceCard
                        SectionHeader(title: l10n.t("containers"), trailing: l10n.t("granted_paths").replacingOccurrences(of: "%d", with: "\(access.grantedCount)"))
                        containerGrid
                        SectionHeader(title: l10n.t("tools"))
                        toolsCard
                        disclaimer
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 130)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .dir(let p): BrowserView(path: p)
                case .file(let p): PreviewView(path: p)
                case .apps: AppsView()
                case .documents:
                    BrowserView(path: WQPaths.documentsPath)
                case .devinfo: DeviceInfoView()
                }
            }
        }
        .onAppear {
            access.grantAll([WQPaths.appGroups, WQPaths.systemData, WQPaths.mgCacheDir])
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            #if DEBUG
            switch DebugLaunch.route {
            case .some("apps"): path.append(Route.apps)
            case .some("devinfo"): path.append(Route.devinfo)
            case .some("dual"): path.append(Route.dir(WQPaths.documentsPath))
            case .some(let r) where r.hasPrefix("dir:"):
                path.append(Route.dir(String(r.dropFirst(4))))
            default: break
            }
            #endif
        }
        .tint(Theme.blue)
    }

    private var statusCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            access.grantAll([WQPaths.appGroups, WQPaths.systemData, WQPaths.mgCacheDir])
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((access.active ? Theme.green : Theme.orange).opacity(0.16))
                        .frame(width: 52, height: 52)
                    if access.active {
                        Circle()
                            .stroke(Theme.green.opacity(0.35), lineWidth: 1)
                            .frame(width: 52, height: 52)
                            .scaleEffect(pulse ? 1.18 : 1.0)
                            .opacity(pulse ? 0 : 1)
                    }
                    Image(systemName: access.active ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(access.active ? Theme.green : Theme.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(access.active ? l10n.t("status_granted") : l10n.t("status_not_granted"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(l10n.f("granted_paths", access.grantedCount))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                    Text(access.note)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [(access.active ? Theme.green : Theme.orange).opacity(0.45), Theme.stroke],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var deviceCard: some View {
        NavigationLink(value: Route.devinfo) {
            HStack(spacing: 12) {
                IconTile(icon: "iphone.gen3", tint: Theme.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.t("device_info"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(DeviceInfoGather.summary())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var containerGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(WQPaths.zones) { zone in
                if zone.apps {
                    NavigationLink(value: Route.apps) {
                        zoneCard(zone)
                    }
                    .buttonStyle(.plain)
                } else if let p = zone.path {
                    NavigationLink(value: Route.dir(p)) {
                        zoneCard(zone)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func zoneCard(_ zone: WQPaths.Zone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconTile(icon: zone.icon, tint: tint(for: zone.key))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            Text(l10n.t(zone.key))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(zone.apps ? l10n.t("apps_hint") : shortPath(zone.path ?? "/"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var toolsCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                NavigationLink(value: Route.apps) {
                    ToolRow(icon: "square.grid.2x2.fill", tint: Theme.purple,
                            title: l10n.t("apps"), subtitle: l10n.t("apps_hint"))
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.stroke)

                Button { onOpenClean() } label: {
                    ToolRow(icon: "sparkles", tint: Theme.green,
                            title: l10n.t("cache_clean"), subtitle: l10n.t("scan_hint"))
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.stroke)

                NavigationLink(value: Route.documents) {
                    ToolRow(icon: "tray.full.fill", tint: Theme.orange,
                            title: l10n.t("documents"), subtitle: l10n.t("documents_hint"))
                }
                .buttonStyle(.plain)

                Divider().overlay(Theme.stroke)

                NavigationLink(value: Route.dir("/")) {
                    ToolRow(icon: "internaldrive.fill", tint: Theme.cyan,
                            title: l10n.t("full_disk"), subtitle: "/")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
            Text(l10n.t("risk_disclaimer"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
    }

    private func tint(for key: String) -> Color {
        switch key {
        case "app_data": return Theme.blue
        case "app_groups": return Theme.purple
        case "system_data": return Theme.pink
        case "mg_title": return Theme.orange
        case "documents": return Theme.cyan
        default: return Theme.green
        }
    }

    private func shortPath(_ p: String) -> String {
        p.replacingOccurrences(of: "/private/var/mobile/Containers/", with: "~/Containers/")
            .replacingOccurrences(of: "/private/var/containers/", with: "~/SystemContainers/")
            .replacingOccurrences(of: "/private/var/mobile", with: "~")
    }
}

// MARK: - 浏览器

struct BrowserView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var access = Access.shared
    let path: String

    @State private var entries: [FSEntry] = []
    @State private var loading = true
    @State private var denied = false
    @State private var query = ""
    @State private var selectMode = false
    @State private var selected: Set<String> = []
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var msg: Msg?
    @State private var showDual = false

    private var shown: [FSEntry] {
        query.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var title: String {
        path == "/" ? "/" : (path as NSString).lastPathComponent
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    pathBar
                    if loading {
                        ProgressView().tint(Theme.blue).padding(.top, 40)
                    } else if denied {
                        GlassCard {
                            VStack(spacing: 12) {
                                EmptyState(icon: "lock.fill", title: l10n.t("denied"), detail: l10n.t("denied_detail"))
                                PrimaryButton(title: l10n.t("grant_action"), icon: "lock.open", tint: Theme.orange) {
                                    load(forceGrant: true)
                                }
                            }
                        }
                    } else if shown.isEmpty {
                        EmptyState(icon: query.isEmpty ? "folder" : "magnifyingglass",
                                   title: query.isEmpty ? l10n.t("empty_dir") : l10n.t("no_apps"))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, entry in
                                row(entry)
                                if idx != shown.count - 1 {
                                    Divider().overlay(Theme.stroke).padding(.leading, 58)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 130)
            }
            if busy {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: l10n.t("search"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showDual = true
                    } label: {
                        Label(l10n.t("dual_title"), systemImage: "rectangle.split.2x1")
                    }
                    Button {
                        load(forceGrant: false)
                    } label: {
                        Label(l10n.t("refresh"), systemImage: "arrow.clockwise")
                    }
                    Button {
                        selectMode.toggle()
                        if !selectMode { selected.removeAll() }
                    } label: {
                        Label(l10n.t("select"), systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectMode {
                HStack(spacing: 12) {
                    Button {
                        if selected.count == shown.count { selected.removeAll() }
                        else { selected = Set(shown.map(\.path)) }
                    } label: {
                        Text(l10n.t("select_all"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text)
                    }
                    Spacer()
                    Button {
                        confirmDelete = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text(l10n.f("delete_n", selected.count))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(selected.isEmpty ? Theme.cardLift : Theme.red))
                    }
                    .disabled(selected.isEmpty)
                    Button {
                        selectMode = false
                        selected.removeAll()
                    } label: {
                        Text(l10n.t("cancel"))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showDual) {
            DualPaneView(startPath: path)
        }
        .alert(l10n.f("delete_confirm_title", selected.count), isPresented: $confirmDelete) {
            Button(l10n.t("backup_and_delete"), role: .destructive) { deleteSelected(backup: true) }
            Button(l10n.t("permanent_delete"), role: .destructive) { deleteSelected(backup: false) }
            Button(l10n.t("cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t("delete_confirm_msg"))
        }
        .alert(item: $msg) { m in
            Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
        }
        .onAppear { load(forceGrant: false) }
        #if DEBUG
        .task {
            if DebugLaunch.route == "dual" { showDual = true }
        }
        #endif
    }

    private var pathBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.blue)
            Text(path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Text(l10n.f("items", entries.count))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func row(_ entry: FSEntry) -> some View {
        let isSelected = selected.contains(entry.path)
        let content = HStack(spacing: 12) {
            if selectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Theme.blue : Theme.faint)
            }
            IconTile(icon: entry.icon, tint: entry.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if entry.isLink, let t = entry.linkTarget {
                        Text("→ \(t)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if entry.isDir {
                        Text(wqDateString(entry.mtime))
                    } else {
                        Text(wqSizeString(entry.size))
                        Text("·")
                        Text(wqDateString(entry.mtime))
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.faint)
            }
            Spacer(minLength: 6)
            if !selectMode {
                Image(systemName: entry.isDir ? "chevron.right" : "doc.text.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())

        if selectMode {
            Button {
                toggle(entry.path)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else if entry.isDir {
            NavigationLink(value: Route.dir(entry.path)) { content }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        selected = [entry.path]
                        confirmDelete = true
                    } label: {
                        Label(l10n.t("delete"), systemImage: "trash")
                    }
                }
        } else {
            NavigationLink(value: Route.file(entry.path)) { content }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        selected = [entry.path]
                        confirmDelete = true
                    } label: {
                        Label(l10n.t("delete"), systemImage: "trash")
                    }
                }
        }
    }

    private func toggle(_ p: String) {
        if selected.contains(p) { selected.remove(p) } else { selected.insert(p) }
    }

    private func load(forceGrant: Bool) {
        loading = true
        denied = false
        let p = path
        DispatchQueue.global(qos: .userInitiated).async {
            if forceGrant || !Access.shared.isGranted(p) { Access.shared.grant(p) }
            let list = wqReadEntries(p)
            DispatchQueue.main.async {
                entries = list ?? []
                denied = (list == nil)
                loading = false
            }
        }
    }

    private func deleteSelected(backup: Bool) {
        let targets = Array(selected)
        guard !targets.isEmpty else { return }
        busy = true
        let l = l10n
        let parent = path
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(parent)
            var ok = 0, bad = 0
            var backupDir: String?
            for t in targets {
                if backup {
                    if let u = wqBackup(t) {
                        if backupDir == nil { backupDir = u.deletingLastPathComponent().path }
                    }
                }
                do {
                    try FileManager.default.removeItem(atPath: t)
                    ok += 1
                } catch {
                    bad += 1
                }
            }
            let list = wqReadEntries(parent) ?? []
            DispatchQueue.main.async {
                entries = list
                selected.removeAll()
                selectMode = false
                busy = false
                if bad == 0 {
                    var text = l.f("deleted_ok", ok, bad)
                    if let b = backupDir { text += "\n" + l.f("backup_done", b) }
                    msg = Msg(text: text)
                } else {
                    msg = Msg(text: l.f("delete_partial", ok, bad))
                }
            }
        }
    }
}

// MARK: - 预览

struct PreviewView: View {
    @EnvironmentObject private var l10n: L10n
    let path: String
    @State private var text: String?
    @State private var image: UIImage?
    @State private var info: String = ""

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let text {
                        Text(text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                    } else {
                        EmptyState(icon: "doc.questionmark", title: l10n.t("preview_unsupported"))
                    }
                    if !info.isEmpty {
                        Text(info)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle((path as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: URL(fileURLWithPath: path)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let p = path
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant((p as NSString).deletingLastPathComponent)
            let attrs = try? FileManager.default.attributesOfItem(atPath: p)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let ext = (p as NSString).pathExtension.lowercased()
            var outText: String?
            var outImage: UIImage?

            if ["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff"].contains(ext) {
                outImage = UIImage(contentsOfFile: p)
            }
            if outImage == nil {
                if ["plist"].contains(ext) || p.hasSuffix(".plist") {
                    if let dict = NSDictionary(contentsOfFile: p),
                       let xml = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
                        outText = String(data: xml.prefix(400_000), encoding: .utf8)
                    } else if let d = try? Data(contentsOf: URL(fileURLWithPath: p), options: .mappedIfSafe) {
                        outText = hexDump(d.prefix(4096))
                    }
                } else if let fh = FileHandle(forReadingAtPath: p) {
                    let d = fh.readData(ofLength: 160_000)
                    try? fh.close()
                    if let s = String(data: d, encoding: .utf8), !s.isEmpty {
                        outText = s
                    } else {
                        outText = hexDump(d.prefix(4096))
                    }
                }
            }
            let head = "\(wqSizeString(size))"
            DispatchQueue.main.async {
                text = outText
                image = outImage
                info = head
            }
        }
    }

    private func hexDump(_ data: Data) -> String {
        var lines: [String] = []
        var offset = 0
        let bytes = [UInt8](data)
        while offset < bytes.count {
            let chunk = bytes[offset..<min(offset + 16, bytes.count)]
            let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = chunk.map { ($0 >= 32 && $0 < 127) ? String(UnicodeScalar($0)) : "." }.joined()
            lines.append(String(format: "%08x  %-47s  %@", offset, (hex as NSString).utf8String!, ascii))
            offset += 16
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 应用列表

struct AppsView: View {
    @EnvironmentObject private var l10n: L10n
    @State private var apps: [AppInfo] = []
    @State private var loading = true
    @State private var query = ""
    @State private var showAdd = false
    @State private var showImporter = false
    @State private var bundleInput = ""
    @State private var msg: Msg?
    @State private var actionsApp: AppInfo?

    private var shown: [AppInfo] {
        query.isEmpty ? apps : apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if loading {
                        ProgressView().tint(Theme.blue).padding(.top, 40)
                    } else if shown.isEmpty {
                        VStack(spacing: 12) {
                            EmptyState(icon: "square.grid.2x2", title: l10n.t("no_apps"), detail: l10n.t("apps_hint"))
                            PrimaryButton(title: l10n.t("import_list"), icon: "square.and.arrow.down", tint: Theme.blue) {
                                showImporter = true
                            }
                            PrimaryButton(title: l10n.t("add_bundle"), icon: "plus", tint: Theme.purple) {
                                showAdd = true
                            }
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, app in
                                HStack(spacing: 0) {
                                    NavigationLink(value: Route.dir(app.dataPath)) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                    .fill(
                                                        LinearGradient(colors: [app.tint.opacity(0.9), app.tint.opacity(0.55)],
                                                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    )
                                                Text(app.initial)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(width: 38, height: 38)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(app.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(Theme.text)
                                                    .lineLimit(1)
                                                Text(app.bundleID)
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(Theme.faint)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            Spacer(minLength: 6)
                                        }
                                        .padding(.leading, 14)
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Button {
                                        actionsApp = app
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(Theme.faint)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 4)
                                }
                                if idx != shown.count - 1 {
                                    Divider().overlay(Theme.stroke).padding(.leading, 64)
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    Text(l10n.t("apps_device_note"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 130)
            }
        }
        .navigationTitle(l10n.t("apps_title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: l10n.t("search"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importList(url) }
            case .failure:
                msg = Msg(text: l10n.t("import_list_failed"))
            }
        }
        .alert(l10n.t("add_bundle"), isPresented: $showAdd) {
            TextField("com.example.app", text: $bundleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(l10n.t("open")) { addManual() }
            Button(l10n.t("cancel"), role: .cancel) { bundleInput = "" }
        } message: {
            Text(l10n.t("bundle_id_hint"))
        }
        .alert(item: $msg) { m in
            Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
        }
        .sheet(item: $actionsApp) { app in
            AppQuickSheet(app: app)
                .environmentObject(l10n)
        }
        .onAppear {
            guard loading else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let list = AppCatalog.load()
                DispatchQueue.main.async {
                    apps = list
                    loading = false
                    #if DEBUG
                    if let p = ProcessInfo.processInfo.environment["WQ_DEBUG_ADDAPP"], !p.isEmpty {
                        add(p)
                    }
                    if let p = ProcessInfo.processInfo.environment["WQ_DEBUG_IMPORT"], !p.isEmpty {
                        let url = p.hasPrefix("/")
                            ? URL(fileURLWithPath: p)
                            : URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent(p)
                        importList(url)
                    }
                    #endif
                }
            }
        }
    }
    private func addManual() {
        let raw = bundleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        bundleInput = ""
        add(raw)
    }

    private func importList(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let count = AppCatalog.installImport(from: url) else {
                DispatchQueue.main.async {
                    msg = Msg(text: l10n.t("import_list_failed"))
                }
                return
            }
            let list = AppCatalog.load()
            DispatchQueue.main.async {
                apps = list
                loading = false
                msg = Msg(text: l10n.f("import_list_ok", count))
            }
        }
    }

    private func add(_ raw: String) {
        guard !raw.isEmpty else { return }
        if raw.hasPrefix("/") {
            var path = raw
            while path.count > 1, path.hasSuffix("/") { path.removeLast() }
            Access.shared.grant(path)
            guard wqReadEntries(path) != nil else {
                msg = Msg(text: l10n.f("path_not_found", path))
                return
            }
            var name = (path as NSString).lastPathComponent
            var bid = path
            let meta = path + "/.com.apple.mobile_container_manager.metadata.plist"
            Access.shared.grant(meta)
            if let d = NSDictionary(contentsOfFile: meta),
               let id = d["MCMMetadataIdentifier"] as? String, !id.isEmpty {
                bid = id
                name = id
            }
            let hit = AppInfo(bundleID: bid, name: name, dataPath: path)
            if !apps.contains(where: { $0.dataPath == hit.dataPath }) {
                apps.insert(hit, at: 0)
            }
            return
        }
        guard let hit = AppCatalog.info(raw) else {
            msg = Msg(text: l10n.f("app_not_found", raw))
            return
        }
        if !apps.contains(where: { $0.dataPath == hit.dataPath }) {
            apps.insert(hit, at: 0)
        }
    }

}
