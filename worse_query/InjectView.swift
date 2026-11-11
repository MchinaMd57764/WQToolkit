import SwiftUI
import UniformTypeIdentifiers

struct InjectView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared
    let app: AppInfo?

    @State private var picked: AppInfo?
    @State private var apps: [AppInfo] = []
    @State private var query = ""
    @State private var subfolder = "Documents"
    @State private var showImporter = false
    @State private var busy = false
    @State private var msg: Msg?
    @State private var existing: [FSEntry] = []
    @State private var injected: [String] = []
    @State private var didAutoRun = false

    private var target: AppInfo? { app ?? picked }

    private var shownApps: [AppInfo] {
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_inject_title"),
                               subtitle: target?.name ?? l10n.t("lens_inject_sub"),
                               icon: "syringe.fill",
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
                    Text(l10n.t("lens_injecting")).font(.system(size: 12)).foregroundStyle(.white)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: prepare)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importFile(url) }
            case .failure(let error):
                msg = Msg(text: l10n.f("lens_inject_failed", error.localizedDescription))
            }
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
                ProgressView().tint(Theme.pink).padding(.top, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shownApps.prefix(120).enumerated()), id: \.element.id) { idx, item in
                        Button {
                            picked = item
                            refreshExisting()
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
                }
                Text(target.dataPath)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.faint)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(.top, 6)
            }

            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("lens_inject_dest"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.sub)
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(Theme.pink)
                        TextField("Documents", text: $subfolder)
                            .font(.system(size: 12, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardLift))
                    Text(l10n.t("lens_inject_dest_note"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
            }

            HStack(spacing: 10) {
                PrimaryButton(title: l10n.t("lens_pick_file"), icon: "doc.badge.plus",
                              tint: Theme.pink, enabled: !busy) {
                    showImporter = true
                }
                PrimaryButton(title: l10n.t("lens_write_test"), icon: "square.and.pencil",
                              tint: Theme.purple, enabled: !busy) {
                    writeTestFile(target)
                }
            }

            SectionHeader(title: l10n.t("lens_injected"),
                          trailing: "\(injected.count)")
            if injected.isEmpty {
                Text(l10n.t("lens_injected_empty"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(injected, id: \.self) { path in
                        HStack(spacing: 10) {
                            IconTile(icon: "doc.fill", tint: Theme.green)
                            Text((path as NSString).lastPathComponent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                removeInjected(path)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke, lineWidth: 1))
            }

            SectionHeader(title: l10n.t("lens_dest_contents"),
                          trailing: "\(existing.count)")
            if existing.isEmpty {
                Text(l10n.t("empty_dir"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(existing.prefix(20).enumerated()), id: \.element.id) { idx, e in
                        HStack(spacing: 10) {
                            Image(systemName: e.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(e.tint)
                            Text(e.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(wqSizeString(e.size))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        if idx != min(existing.count, 20) - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke, lineWidth: 1))
            }

            Text(l10n.t("lens_inject_note"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    private func prepare() {
        if app == nil && apps.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                let list = AppCatalog.load()
                DispatchQueue.main.async { apps = list }
            }
        }
        if let target {
            refreshExisting()
            #if DEBUG
            if ProcessInfo.processInfo.environment["WQ_DEBUG_INJECT_CLEANUP"] == "1", !didAutoRun {
                didAutoRun = true
                cleanupTestFiles(target)
            } else if ProcessInfo.processInfo.environment["WQ_DEBUG_INJECT_AUTO"] == "1", !didAutoRun {
                didAutoRun = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { writeTestFile(target) }
            }
            #endif
        }
    }

    private func destDir(_ app: AppInfo) -> String? {
        var sub = subfolder.trimmingCharacters(in: .whitespacesAndNewlines)
        while sub.hasPrefix("/") { sub.removeFirst() }
        while sub.hasSuffix("/") { sub.removeLast() }
        if sub.isEmpty { sub = "Documents" }
        guard !sub.contains("..") else { return nil }
        return app.dataPath + "/" + sub
    }

    private func refreshExisting() {
        guard let target, let dir = destDir(target) else {
            existing = []
            return
        }
        DispatchQueue.global(qos: .utility).async {
            Access.shared.grant(target.dataPath)
            Access.shared.grant(dir)
            let list = wqReadEntries(dir) ?? []
            DispatchQueue.main.async { existing = list }
        }
    }

    private func writeTestFile(_ app: AppInfo) {
        guard let dir = destDir(app) else {
            msg = Msg(text: l10n.t("lens_inject_bad_dest"))
            return
        }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            Access.shared.grant(app.dataPath)
            Access.shared.grant(dir)
            var err: String?
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                let name = "wq_inject_\(Int(Date().timeIntervalSince1970)).txt"
                let path = dir + "/" + name
                let body = "WQ Toolkit inject test\napp=\(app.bundleID)\ntime=\(Date())\n"
                try Data(body.utf8).write(to: URL(fileURLWithPath: path))
                let size = ((try? fm.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.int64Value ?? 0
                #if DEBUG
                NSLog("WQINJECT write app=%@ path=%@ bytes=%lld ok=1", app.bundleID, path, size)
                #endif
                DispatchQueue.main.async {
                    busy = false
                    injected.insert(path, at: 0)
                    refreshExisting()
                    msg = Msg(text: l10n.f("lens_inject_ok", path))
                }
            } catch {
                err = error.localizedDescription
                #if DEBUG
                NSLog("WQINJECT write app=%@ err=%@", app.bundleID, err ?? "?")
                #endif
                DispatchQueue.main.async {
                    busy = false
                    msg = Msg(text: l10n.f("lens_inject_failed", err ?? "?"))
                }
            }
        }
    }

    private func importFile(_ url: URL) {
        guard let target, let dir = destDir(target) else {
            msg = Msg(text: l10n.t("lens_inject_bad_dest"))
            return
        }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            Access.shared.grant(target.dataPath)
            Access.shared.grant(dir)
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                var name = url.lastPathComponent
                var dst = dir + "/" + name
                if fm.fileExists(atPath: dst) {
                    let stamp = Int(Date().timeIntervalSince1970)
                    let base = (name as NSString).deletingPathExtension
                    let ext = (name as NSString).pathExtension
                    name = ext.isEmpty ? "\(base)-wq\(stamp)" : "\(base)-wq\(stamp).\(ext)"
                    dst = dir + "/" + name
                }
                try fm.copyItem(at: url, to: URL(fileURLWithPath: dst))
                let size = ((try? fm.attributesOfItem(atPath: dst))?[.size] as? NSNumber)?.int64Value ?? 0
                #if DEBUG
                NSLog("WQINJECT file app=%@ path=%@ bytes=%lld ok=1", target.bundleID, dst, size)
                #endif
                DispatchQueue.main.async {
                    busy = false
                    injected.insert(dst, at: 0)
                    refreshExisting()
                    msg = Msg(text: l10n.f("lens_inject_ok", dst))
                }
            } catch {
                #if DEBUG
                NSLog("WQINJECT file app=%@ err=%@", target.bundleID, error.localizedDescription)
                #endif
                DispatchQueue.main.async {
                    busy = false
                    msg = Msg(text: l10n.f("lens_inject_failed", error.localizedDescription))
                }
            }
        }
    }

    private func removeInjected(_ path: String) {
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(atPath: path)
            DispatchQueue.main.async {
                injected.removeAll { $0 == path }
                refreshExisting()
            }
        }
    }

    #if DEBUG
    private func cleanupTestFiles(_ app: AppInfo) {
        guard let dir = destDir(app) else { return }
        DispatchQueue.global(qos: .utility).async {
            Access.shared.grant(app.dataPath)
            Access.shared.grant(dir)
            let list = wqReadEntries(dir) ?? []
            var n = 0
            for e in list where e.name.hasPrefix("wq_inject_") {
                if (try? FileManager.default.removeItem(atPath: e.path)) != nil { n += 1 }
            }
            NSLog("WQINJECT cleanup app=%@ removed=%d", app.bundleID, n)
            DispatchQueue.main.async {
                refreshExisting()
            }
        }
    }
    #endif
}
