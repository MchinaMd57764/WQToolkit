import SwiftUI

struct DiagRow: Identifiable {
    let id = UUID()
    let path: String
    let direct: Bool
    let grant: Bool
    let after: Bool
    let items: Int
}

struct SettingsView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var mg = MGManager.shared
    @ObservedObject private var appearance = Appearance.shared

    @State private var running = false
    @State private var diags: [DiagRow] = []
    @State private var restoreURL: URL?
    @State private var msg: Msg?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        PageHeader(title: l10n.t("tab_settings"),
                                   subtitle: l10n.t("privacy"),
                                   icon: "gearshape.fill")
                        languageCard
                        appearanceCard
                        diagnosticCard
                        backupCard
                        aboutCard
                        creditsCard
                        riskCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 130)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert(l10n.t("mg_rollback_confirm"), isPresented: Binding(
                get: { restoreURL != nil },
                set: { if !$0 { restoreURL = nil } }
            )) {
                Button(l10n.t("restore"), role: .destructive) {
                    if let url = restoreURL, mg.restore(url: url) {
                        msg = Msg(text: l10n.t("mg_rollback_done"))
                    } else {
                        msg = Msg(text: l10n.t("operation_failed"))
                    }
                    restoreURL = nil
                }
                Button(l10n.t("cancel"), role: .cancel) { restoreURL = nil }
            }
            .alert(item: $msg) { m in
                Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
            }
            .onAppear {
                mg.load()
            }
        }
        .tint(Theme.blue)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("language"))
            GlassCard {
                VStack(spacing: 12) {
                    Picker("", selection: Binding(
                        get: { l10n.lang },
                        set: { l10n.lang = $0 }
                    )) {
                        Text(l10n.t("lang_auto")).tag("auto")
                        Text(l10n.t("lang_zh")).tag("zh")
                        Text(l10n.t("lang_en")).tag("en")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.cyan)
                        Text(l10n.t("lang_auto") + " · " + (l10n.effective == "zh" ? "中文" : "English"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                        Spacer()
                    }
                }
            }
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("appearance"))
            GlassCard {
                VStack(spacing: 12) {
                    Picker("", selection: Binding(
                        get: { appearance.mode },
                        set: { appearance.mode = $0 }
                    )) {
                        Text(l10n.t("appear_auto")).tag("auto")
                        Text(l10n.t("appear_light")).tag("light")
                        Text(l10n.t("appear_dark")).tag("dark")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.purple)
                        Text(l10n.t("appearance_note"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }

    private var diagnosticCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("diagnostic"))
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconTile(icon: "stethoscope", tint: Theme.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("diag_title"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Text(l10n.t("diag_note"))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.sub)
                        }
                        Spacer()
                        Button {
                            runDiag()
                        } label: {
                            if running {
                                ProgressView().controlSize(.small).tint(Theme.cyan)
                            } else {
                                Text(l10n.t("diag_run"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Theme.cyan.opacity(0.14)))
                            }
                        }
                        .disabled(running)
                    }

                    if !diags.isEmpty {
                        Divider().overlay(Theme.stroke)
                        VStack(spacing: 8) {
                            ForEach(diags) { d in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(short(d.path))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Theme.sub)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    HStack(spacing: 6) {
                                        StatusPill(text: d.direct ? "DIRECT" : "—",
                                                   tint: d.direct ? Theme.green : Theme.faint)
                                        StatusPill(text: d.grant ? "TOKEN" : "DENIED",
                                                   tint: d.grant ? Theme.blue : Theme.red)
                                        if d.after {
                                            StatusPill(text: "\(d.items)", tint: Theme.purple)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("backup_list"),
                          trailing: "\(mg.backups.count)")
            GlassCard {
                VStack(spacing: 10) {
                    if mg.backups.isEmpty {
                        Text(l10n.t("no_backups"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(mg.backups.prefix(6), id: \.self) { url in
                            HStack(spacing: 10) {
                                IconTile(icon: "doc.badge.clock", tint: Theme.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.text)
                                    Text(sizeOf(url))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.faint)
                                }
                                Spacer()
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.sub)
                                }
                                Button {
                                    restoreURL = url
                                } label: {
                                    Text(l10n.t("restore"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.orange)
                                }
                            }
                            if url != mg.backups.prefix(6).last {
                                Divider().overlay(Theme.stroke)
                            }
                        }
                        if mg.baselineExists {
                            HStack(spacing: 6) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.green)
                                Text(l10n.t("mg_baseline") + ": baseline.plist")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Theme.faint)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("about"))
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueRow(key: l10n.t("version"), value: "\(l10n.t("app_name")) \(version)")
                }
            }
        }
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("credits"))
            GlassCard {
                VStack(spacing: 12) {
                    creditLink(icon: "shippingbox.fill", tint: Theme.blue,
                               title: "worse_query",
                               detail: l10n.t("credits_wq_detail"),
                               url: "https://github.com/forcequitOS/worse_query")
                    Divider().overlay(Theme.stroke)
                    creditLink(icon: "wand.and.stars", tint: Theme.purple,
                               title: "GestaltX",
                               detail: l10n.t("credits_gx_detail"),
                               url: "https://github.com/huamidev/GestaltX")
                    Divider().overlay(Theme.stroke)
                    Text(l10n.t("credits_text"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func creditLink(icon: String, tint: Color, title: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                IconTile(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("restart"))
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("risk_disclaimer"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l10n.t("restart_text"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l10n.t("privacy"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
    }

    private func sizeOf(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return wqSizeString((attrs?[.size] as? NSNumber)?.int64Value ?? 0)
    }

    private func short(_ p: String) -> String {
        p.replacingOccurrences(of: "/private/var/mobile/Containers/", with: "~/Containers/")
            .replacingOccurrences(of: "/private/var/containers/", with: "~/SystemContainers/")
            .replacingOccurrences(of: "/private/var/mobile", with: "~")
    }

    private func runDiag() {
        running = true
        diags = []
        let paths: [String] = [
            WQPaths.appData,
            WQPaths.appGroups,
            WQPaths.pluginKit,
            WQPaths.internalDaemon,
            WQPaths.systemData,
            WQPaths.systemGroups,
            WQPaths.splashSnapshots,
            WQPaths.mgCacheDir,
            "/private/etc",
            "/private/var/mobile/Library",
        ]
        DispatchQueue.global(qos: .userInitiated).async {
            var rows: [DiagRow] = []
            for p in paths {
                let direct = wqReadEntries(p) != nil
                let token = Access.shared.grant(p)
                let list = token ? wqReadEntries(p) : nil
                rows.append(DiagRow(path: p, direct: direct, grant: token,
                                    after: list != nil, items: list?.count ?? 0))
                DispatchQueue.main.async { diags = rows }
            }
            DispatchQueue.main.async { running = false }
        }
    }
}
