import SwiftUI

struct PrefsInspectorView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared
    let app: AppInfo?

    @State private var query = ""
    @State private var autoFile: PrefFile?

    private var source: [PrefFile] {
        lens.prefs(app: app?.bundleID)
    }

    private var shown: [PrefFile] {
        guard !query.isEmpty else { return source }
        return source.filter {
            $0.domain.localizedCaseInsensitiveContains(query)
                || $0.appName.localizedCaseInsensitiveContains(query)
                || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    private var grouped: [(id: String, name: String, files: [PrefFile])] {
        var dict: [String: [PrefFile]] = [:]
        for file in shown { dict[file.bundleID, default: []].append(file) }
        return dict.map { entry in
            let raw = entry.value.first?.appName.trimmingCharacters(in: .whitespaces) ?? ""
            return (id: entry.key, name: raw.isEmpty ? entry.key : raw, files: entry.value)
        }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_prefs_title"),
                               subtitle: app?.name ?? l10n.t("lens_prefs_sub"),
                               icon: "slider.horizontal.3",
                               showsBack: true)

                    if lens.scanning {
                        ProgressView().tint(Theme.purple).padding(.top, 30)
                    } else if !lens.scanned {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(l10n.t("lens_need_scan"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.sub)
                                PrimaryButton(title: l10n.t("lens_scan_all"), icon: "sparkle.magnifyingglass",
                                              tint: Theme.purple) {
                                    lens.scan(force: true)
                                }
                            }
                        }
                    } else {
                        searchBar
                        if shown.isEmpty {
                            EmptyState(icon: "list.bullet.rectangle", title: l10n.t("lens_prefs_empty"),
                                       detail: l10n.t("lens_prefs_empty_sub"))
                        } else {
                            if app == nil {
                                ForEach(grouped, id: \.id) { group in
                                    SectionHeader(title: group.name,
                                                  trailing: "\(group.files.count)")
                                    card(group.files)
                                }
                            } else {
                                card(shown)
                            }
                        }
                        Text(l10n.t("lens_prefs_note"))
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
        .navigationDestination(item: $autoFile) { file in
            PrefDetailView(file: file)
        }
        .onAppear(perform: autoOpen)
        .onChange(of: lens.scanned) { _, _ in autoOpen() }
    }

    private func autoOpen() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["WQ_DEBUG_PREFS_OPEN"] == "1",
              autoFile == nil, let first = shown.first else { return }
        autoFile = first
        #endif
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.faint)
            TextField(l10n.t("search"), text: $query)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
            }
            Text("\(shown.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func card(_ files: [PrefFile]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(files.enumerated()), id: \.element.id) { idx, file in
                NavigationLink {
                    PrefDetailView(file: file)
                } label: {
                    HStack(spacing: 11) {
                        IconTile(icon: "list.bullet.rectangle", tint: Theme.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.domain)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(file.bundleID)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(wqSizeString(file.bytes))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.sub)
                            Text(wqDateString(file.mtime))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx != files.count - 1 {
                    Divider().overlay(Theme.stroke).padding(.leading, 59)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct PrefDetailView: View {
    @EnvironmentObject private var l10n: L10n
    let file: PrefFile

    @State private var rows: [(key: String, value: String)] = []
    @State private var loading = true
    @State private var error: String?
    @State private var query = ""
    @State private var totalKeys = 0

    private var shown: [(key: String, value: String)] {
        guard !query.isEmpty else { return rows }
        return rows.filter {
            $0.key.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: file.domain,
                               subtitle: file.appName,
                               icon: "list.bullet.rectangle",
                               showsBack: true)

                    if loading {
                        ProgressView().tint(Theme.orange).padding(.top, 30)
                    } else if let error {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(l10n.t("lens_prefs_unreadable"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.orange)
                                Text(error)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.faint)
                            }
                        }
                    } else {
                        GlassCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                KeyValueRow(key: l10n.t("lens_keys"), value: "\(totalKeys)")
                                KeyValueRow(key: l10n.t("lens_size"), value: wqSizeString(file.bytes))
                                KeyValueRow(key: l10n.t("lens_modified"), value: wqDateString(file.mtime))
                                Text(file.path)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(Theme.faint)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                        }

                        if totalKeys > 8 {
                            searchBar
                        }

                        if shown.isEmpty {
                            EmptyState(icon: "magnifyingglass", title: l10n.t("lens_prefs_empty"))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(shown.enumerated()), id: \.offset) { idx, row in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.key)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Theme.cyan)
                                            .textSelection(.enabled)
                                        Text(row.value)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.text)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    if idx != shown.count - 1 {
                                        Divider().overlay(Theme.stroke)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        Text(l10n.t("lens_prefs_readonly"))
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
        .onAppear(perform: load)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
            TextField(l10n.t("lens_filter_keys"), text: $query)
                .font(.system(size: 12))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func load() {
        loading = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(file.path)
            Access.shared.grant((file.path as NSString).deletingLastPathComponent)
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: file.path)) else {
                DispatchQueue.main.async {
                    loading = false
                    error = "READ FAILED"
                }
                return
            }
            guard data.count <= 16 * 1024 * 1024 else {
                DispatchQueue.main.async {
                    loading = false
                    error = "TOO LARGE: \(data.count) bytes"
                }
                return
            }
            let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            var out: [(String, String)] = []
            if let dict = obj as? [String: Any] {
                for key in dict.keys.sorted() {
                    out.append((key, Self.format(dict[key])))
                }
            } else if let arr = obj as? [Any] {
                for (i, v) in arr.enumerated() {
                    out.append(("[\(i)]", Self.format(v)))
                }
            }
            let parsed = !out.isEmpty || obj != nil
            let final = out
            DispatchQueue.main.async {
                loading = false
                rows = final
                totalKeys = final.count
                error = parsed ? nil : "NOT A PLIST"
                #if DEBUG
                NSLog("WQPFX %@ keys=%d bytes=%d parsed=%d", file.path, final.count, data.count, parsed ? 1 : 0)
                #endif
            }
        }
    }

    private static func format(_ value: Any?) -> String {
        guard let value else { return "nil" }
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let d = value as? Data { return "<data \(d.count) bytes> \(d.prefix(24).map { String(format: "%02x", $0) }.joined())" }
        if let date = value as? Date { return wqDateString(date) }
        if let arr = value as? [Any] {
            let inner = arr.prefix(6).map { format($0) }.joined(separator: ", ")
            return "[" + inner + (arr.count > 6 ? ", … \(arr.count)]" : "]")
        }
        if let dict = value as? [String: Any] {
            let inner = dict.keys.sorted().prefix(6).map { "\($0): \(format(dict[$0]))" }.joined(separator: ", ")
            return "{" + inner + (dict.count > 6 ? ", … \(dict.count)}" : "}")
        }
        return String(describing: value)
    }
}
