import SwiftUI
import UIKit

// MARK: - 备份仓库

struct WQBackupInfo: Identifiable, Hashable {
    let url: URL
    let bundleID: String
    let appName: String
    let date: Date
    let bytes: Int64
    let files: Int
    let preRestore: Bool

    var id: String { url.path }
}

enum WQTransferStore {
    static let manifestName = "wq_backup.json"

    static var root: URL {
        URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent("WQTransfers", isDirectory: true)
    }

    private struct Manifest: Codable {
        let bundleID: String
        let appName: String
        let source: String
        let createdAt: Double
        let bytes: Int64
        let files: Int
        let preRestore: Bool
    }

    static func list() -> [WQBackupInfo] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        var out: [WQBackupInfo] = []
        for dir in dirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let manifestURL = dir.appendingPathComponent(manifestName)
            guard let data = try? Data(contentsOf: manifestURL),
                  let m = try? JSONDecoder().decode(Manifest.self, from: data) else { continue }
            out.append(WQBackupInfo(url: dir, bundleID: m.bundleID, appName: m.appName,
                                    date: Date(timeIntervalSince1970: m.createdAt),
                                    bytes: m.bytes, files: m.files, preRestore: m.preRestore))
        }
        return out.sorted { $0.date > $1.date }
    }

    static func delete(_ info: WQBackupInfo) -> Bool {
        do {
            try FileManager.default.removeItem(at: info.url)
            return true
        } catch {
            return false
        }
    }

    static func sanitize(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let s = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(s).prefix(80).isEmpty ? "app" : String(String(s).prefix(80))
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    @discardableResult
    static func create(app: AppInfo, preRestore: Bool = false) -> (info: WQBackupInfo?, ok: Int, bad: Int, error: String?) {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        if app.dataPath == home || app.dataPath.hasPrefix(WQPaths.documentsPath) {
            return (nil, 0, 0, "SELF")
        }
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        var dir = root.appendingPathComponent("\(sanitize(app.bundleID))-\(preRestore ? "pre-restore-" : "")\(stamp())")
        var n = 1
        while fm.fileExists(atPath: dir.path) {
            dir = dir.deletingLastPathComponent()
                .appendingPathComponent("\(sanitize(app.bundleID))-\(preRestore ? "pre-restore-" : "")\(stamp())-\(n)")
            n += 1
        }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return (nil, 0, 0, "MKDIR \(error.localizedDescription)")
        }

        Access.shared.grant(app.dataPath)
        guard let names = try? fm.contentsOfDirectory(atPath: app.dataPath) else {
            return (nil, 0, 0, "READ CONTAINER")
        }

        var ok = 0
        var bad = 0
        var bytes: Int64 = 0
        var files = 0
        for name in names {
            let src = app.dataPath + "/" + name
            let dst = dir.appendingPathComponent(name)
            let sz = wqDirSize(src)
            do {
                try fm.copyItem(atPath: src, toPath: dst.path)
                ok += 1
                bytes += sz.bytes
                files += sz.count
            } catch {
                bad += 1
            }
        }

        let manifest = Manifest(bundleID: app.bundleID, appName: app.name, source: app.dataPath,
                                createdAt: Date().timeIntervalSince1970, bytes: bytes, files: files,
                                preRestore: preRestore)
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: dir.appendingPathComponent(manifestName))
        }
        let info = WQBackupInfo(url: dir, bundleID: app.bundleID, appName: app.name,
                                date: Date(), bytes: bytes, files: files, preRestore: preRestore)
        #if DEBUG
        NSLog("WQXFER backup app=%@ bytes=%lld files=%d ok=%d bad=%d dir=%@",
              app.bundleID, bytes, files, ok, bad, dir.path)
        #endif
        return (info, ok, bad, bad == 0 ? nil : "PARTIAL")
    }

    @discardableResult
    static func restore(_ info: WQBackupInfo, to app: AppInfo) -> (ok: Int, bad: Int, error: String?, safety: WQBackupInfo?) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: info.url.path) else { return (0, 0, "BACKUP MISSING", nil) }
        Access.shared.grant(app.dataPath)
        guard fm.fileExists(atPath: app.dataPath) else { return (0, 0, "CONTAINER MISSING", nil) }

        let safety = create(app: app, preRestore: true).info

        guard let names = try? fm.contentsOfDirectory(atPath: info.url.path) else {
            return (0, 0, "READ BACKUP", safety)
        }
        var ok = 0
        var bad = 0
        for name in names where name != manifestName {
            let src = info.url.appendingPathComponent(name)
            let dst = app.dataPath + "/" + name
            do {
                if fm.fileExists(atPath: dst) {
                    try fm.removeItem(atPath: dst)
                }
                try fm.copyItem(atPath: src.path, toPath: dst)
                ok += 1
            } catch {
                bad += 1
            }
        }
        #if DEBUG
        NSLog("WQXFER restore app=%@ ok=%d bad=%d safety=%@", app.bundleID, ok, bad, safety?.url.path ?? "nil")
        #endif
        return (ok, bad, bad == 0 ? nil : "PARTIAL", safety)
    }
}

// MARK: - 界面

struct TransferView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared
    let app: AppInfo?

    @State private var picked: AppInfo?
    @State private var apps: [AppInfo] = []
    @State private var query = ""
    @State private var backups: [WQBackupInfo] = []
    @State private var busy = false
    @State private var busyText = ""
    @State private var msg: Msg?
    @State private var confirmBackup = false
    @State private var pendingRestore: WQBackupInfo?
    @State private var pendingDelete: WQBackupInfo?
    @State private var sizeInfo: (bytes: Int64, count: Int) = (0, 0)
    @State private var didAutoRun = false

    private var target: AppInfo? { app ?? picked }

    private var shownApps: [AppInfo] {
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    private var myBackups: [WQBackupInfo] {
        guard let target else { return [] }
        return backups.filter { $0.bundleID == target.bundleID }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_transfer_title"),
                               subtitle: target?.name ?? l10n.t("lens_transfer_sub"),
                               icon: "shippingbox.fill",
                               showsBack: true)
                    if let target {
                        detail(target)
                    } else {
                        picker
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }
            if busy {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text(busyText).font(.system(size: 12)).foregroundStyle(.white)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: prepare)
        .alert(l10n.t("lens_transfer_confirm_title"), isPresented: $confirmBackup) {
            Button(l10n.t("confirm")) { startBackup() }
            Button(l10n.t("cancel"), role: .cancel) {}
        } message: {
            Text(l10n.f("lens_transfer_confirm_msg", target?.name ?? "", wqSizeString(sizeInfo.bytes)))
        }
        .alert(l10n.t("lens_restore_confirm_title"), isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )) {
            Button(l10n.t("lens_restore"), role: .destructive) {
                if let backup = pendingRestore { startRestore(backup) }
            }
            Button(l10n.t("cancel"), role: .cancel) { pendingRestore = nil }
        } message: {
            Text(l10n.t("lens_restore_confirm_msg"))
        }
        .alert(l10n.t("lens_backup_delete_title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(l10n.t("delete"), role: .destructive) {
                if let b = pendingDelete, WQTransferStore.delete(b) {
                    backups = WQTransferStore.list()
                }
                pendingDelete = nil
            }
            Button(l10n.t("cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(l10n.t("lens_backup_delete_msg"))
        }
        .alert(item: $msg) { m in
            Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
        }
    }

    private var picker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField(l10n.t("search"), text: $query)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("\(shownApps.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke, lineWidth: 1))

            if apps.isEmpty {
                ProgressView().tint(Theme.orange).padding(.top, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shownApps.prefix(120).enumerated()), id: \.element.id) { idx, item in
                        Button {
                            picked = item
                            loadSize(item)
                            backups = WQTransferStore.list()
                        } label: {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(item.tint.opacity(0.8))
                                    Text(item.initial)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 34, height: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    Text(item.bundleID)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Theme.faint)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.faint)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx != min(shownApps.count, 120) - 1 {
                            Divider().overlay(Theme.stroke).padding(.leading, 57)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
    }

    private func detail(_ target: AppInfo) -> some View {
        VStack(spacing: 14) {
            GlassCard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(target.tint.opacity(0.85))
                        Text(target.initial)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(target.bundleID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(wqSizeString(sizeInfo.bytes))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.orange)
                        Text(l10n.f("lens_files", sizeInfo.count))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }

            PrimaryButton(title: l10n.t("lens_backup_now"), icon: "shippingbox.fill",
                          tint: Theme.orange, enabled: !busy) {
                confirmBackup = true
            }

            if app == nil {
                Button {
                    picked = nil
                } label: {
                    Text(l10n.t("lens_choose_other"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                .buttonStyle(.plain)
            }

            SectionHeader(title: l10n.t("lens_backups"), trailing: "\(myBackups.count)")
            if myBackups.isEmpty {
                EmptyState(icon: "shippingbox", title: l10n.t("lens_no_backups"),
                           detail: l10n.t("lens_no_backups_sub"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(myBackups.enumerated()), id: \.element.id) { idx, b in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                IconTile(icon: b.preRestore ? "arrow.uturn.backward.circle.fill" : "shippingbox.fill",
                                         tint: b.preRestore ? Theme.purple : Theme.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    Text("\(wqSizeString(b.bytes)) · \(l10n.f("lens_files", b.files))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Theme.faint)
                                }
                                Spacer()
                                if b.preRestore {
                                    StatusPill(text: l10n.t("lens_pre_restore"), tint: Theme.purple)
                                }
                            }
                            HStack(spacing: 8) {
                                ShareLink(item: b.url) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text(l10n.t("lens_export"))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Theme.cardLift))
                                }
                                Button {
                                    pendingRestore = b
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.uturn.backward")
                                        Text(l10n.t("lens_restore"))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Theme.orange.opacity(0.14)))
                                }
                                .buttonStyle(.plain)
                                if !b.preRestore {
                                    Button {
                                        pendingDelete = b
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.red)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(Theme.red.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if idx != myBackups.count - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
            }

            Text(l10n.t("lens_transfer_note"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    private func prepare() {
        backups = WQTransferStore.list()
        if app == nil && apps.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                let list = AppCatalog.load()
                DispatchQueue.main.async { apps = list }
            }
        }
        if let target {
            loadSize(target)
            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if env["WQ_DEBUG_TRANSFER_AUTO"] == "1", !didAutoRun {
                didAutoRun = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { startBackup() }
            } else if env["WQ_DEBUG_TRANSFER_RESTORE"] == "1", !didAutoRun {
                didAutoRun = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    backups = WQTransferStore.list()
                    if let latest = myBackups.first(where: { !$0.preRestore }) {
                        startRestore(latest)
                    }
                }
            } else if env["WQ_DEBUG_TRANSFER_DELETE"] == "1", !didAutoRun {
                didAutoRun = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    backups = WQTransferStore.list()
                    for info in myBackups where !info.preRestore { _ = WQTransferStore.delete(info) }
                    backups = WQTransferStore.list()
                    msg = Msg(text: "deleted")
                }
            }
            #endif
        }
    }

    private func loadSize(_ app: AppInfo) {
        sizeInfo = (0, 0)
        DispatchQueue.global(qos: .utility).async {
            Access.shared.grant(app.dataPath)
            let s = wqDirSize(app.dataPath)
            DispatchQueue.main.async { sizeInfo = s }
        }
    }

    private func startBackup() {
        guard let target else { return }
        busy = true
        busyText = l10n.t("lens_backing_up")
        DispatchQueue.global(qos: .userInitiated).async {
            let r = WQTransferStore.create(app: target)
            DispatchQueue.main.async {
                busy = false
                backups = WQTransferStore.list()
                if let info = r.info {
                    msg = Msg(text: l10n.f("lens_backup_done", wqSizeString(info.bytes), info.files))
                } else {
                    msg = Msg(text: l10n.f("lens_backup_failed", r.error ?? "?"))
                }
            }
        }
    }

    private func startRestore(_ backup: WQBackupInfo) {
        pendingRestore = nil
        guard let target else { return }
        busy = true
        busyText = l10n.t("lens_restoring")
        DispatchQueue.global(qos: .userInitiated).async {
            let r = WQTransferStore.restore(backup, to: target)
            DispatchQueue.main.async {
                busy = false
                backups = WQTransferStore.list()
                if r.bad == 0 {
                    msg = Msg(text: l10n.f("lens_restore_done", r.ok))
                } else {
                    msg = Msg(text: l10n.f("lens_restore_partial", r.ok, r.bad))
                }
            }
        }
    }
}
