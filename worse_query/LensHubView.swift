import SwiftUI

enum LensRoute: Hashable {
    case media
    case timeline
    case storage
    case prefs
    case groups
    case transfer
    case inject
    case transferApp(AppInfo)
    case injectApp(AppInfo)
}

struct LensHubView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared
    @State private var path = NavigationPath()
    @State private var didRoute = false

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        PageHeader(title: l10n.t("lens_title"),
                                   subtitle: l10n.t("lens_sub"),
                                   icon: "eye.fill")
                        scanCard
                        SectionHeader(title: l10n.t("lens_features"),
                                      trailing: lens.scanned ? l10n.f("lens_apps_n", lens.apps.count) : nil)
                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink(value: LensRoute.media) {
                                FeatureCard(icon: "photo.stack.fill", tint: Theme.pink,
                                            title: l10n.t("lens_media_title"),
                                            subtitle: l10n.t("lens_media_sub"),
                                            badge: lens.scanned ? "\(lens.media.count)" : nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.timeline) {
                                FeatureCard(icon: "clock.arrow.circlepath", tint: Theme.cyan,
                                            title: l10n.t("lens_timeline_title"),
                                            subtitle: l10n.t("lens_timeline_sub"),
                                            badge: lens.scanned ? "\(lens.recent.count)" : nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.storage) {
                                FeatureCard(icon: "square.grid.3x3.square", tint: Theme.green,
                                            title: l10n.t("lens_storage_title"),
                                            subtitle: l10n.t("lens_storage_sub"),
                                            badge: lens.scanned ? wqSizeString(lens.totalBytes) : nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.prefs) {
                                FeatureCard(icon: "slider.horizontal.3", tint: Theme.purple,
                                            title: l10n.t("lens_prefs_title"),
                                            subtitle: l10n.t("lens_prefs_sub"),
                                            badge: lens.scanned ? "\(lens.prefs.count)" : nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.groups) {
                                FeatureCard(icon: "square.stack.3d.up.fill", tint: Theme.orange,
                                            title: l10n.t("lens_groups_title"),
                                            subtitle: l10n.t("lens_groups_sub"),
                                            badge: nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.transfer) {
                                FeatureCard(icon: "shippingbox.fill", tint: Theme.blue,
                                            title: l10n.t("lens_transfer_title"),
                                            subtitle: l10n.t("lens_transfer_sub"),
                                            badge: nil)
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: LensRoute.inject) {
                                FeatureCard(icon: "syringe.fill", tint: Theme.red,
                                            title: l10n.t("lens_inject_title"),
                                            subtitle: l10n.t("lens_inject_sub"),
                                            badge: nil)
                            }
                            .buttonStyle(.plain)
                        }
                        disclaimer
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 140)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LensRoute.self) { route in
                switch route {
                case .media: MediaView()
                case .timeline: TimelineView()
                case .storage: StorageMapView()
                case .prefs: PrefsInspectorView(app: nil)
                case .groups: SharedGroupsView()
                case .transfer: TransferView(app: nil)
                case .inject: InjectView(app: nil)
                case .transferApp(let app): TransferView(app: app)
                case .injectApp(let app): InjectView(app: app)
                }
            }
        }
        .onAppear(perform: onAppear)
    }

    private var scanCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lens.scanned ? l10n.t("lens_scanned") : l10n.t("lens_ready"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(lens.scanned ? l10n.t("lens_scan_summary") : l10n.t("lens_scan_intro"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill((lens.scanned ? Theme.green : Theme.blue).opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: lens.scanned ? "checkmark.seal.fill" : "sparkle.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(lens.scanned ? Theme.green : Theme.blue)
                    }
                }

                if lens.scanning {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(lens.currentApp.isEmpty ? l10n.t("lens_scanning_app") : lens.currentApp)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.sub)
                                .lineLimit(1)
                            Spacer()
                            Text("\(lens.progressDone) / \(lens.progressTotal)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.faint)
                        }
                        ProgressView(value: lens.progressTotal == 0 ? 0 : Double(lens.progressDone) / Double(lens.progressTotal))
                            .tint(Theme.blue)
                    }
                }

                if lens.scanned {
                    HStack(spacing: 7) {
                        StatusPill(text: l10n.f("lens_files", lens.totalFiles), tint: Theme.cyan)
                        StatusPill(text: wqSizeString(lens.totalBytes), tint: Theme.green)
                        StatusPill(text: "\(lens.media.count)", tint: Theme.pink)
                        Spacer(minLength: 0)
                    }
                    if lens.failedAppCount > 0 || lens.truncated {
                        Text(l10n.f("lens_scan_warn", lens.failedAppCount))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.orange)
                    }
                }

                HStack(spacing: 8) {
                    PrimaryButton(title: lens.scanning ? l10n.t("scanning") : (lens.scanned ? l10n.t("lens_rescan") : l10n.t("lens_scan_all")),
                                  icon: "sparkle.magnifyingglass",
                                  tint: Theme.blue,
                                  enabled: !lens.scanning) {
                        lens.scan(force: true)
                    }
                    if lens.scanning {
                        Button {
                            lens.cancel()
                        } label: {
                            Text(l10n.t("lens_cancel"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.orange)
                                .frame(width: 72, height: 50)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardLift))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l10n.t("lens_disclaimer_1"))
            Text(l10n.t("lens_disclaimer_2"))
            Text(l10n.t("lens_disclaimer_3"))
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.faint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func onAppear() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WQ_DEBUG_LENS_SCAN"] == "1", !lens.scanned, !lens.scanning {
            lens.scan(force: true)
        }
        guard !didRoute, let route = DebugLaunch.route, route.hasPrefix("lens") else { return }
        didRoute = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch route {
            case "lens-media": path.append(LensRoute.media)
            case "lens-timeline": path.append(LensRoute.timeline)
            case "lens-storage": path.append(LensRoute.storage)
            case "lens-prefs": path.append(LensRoute.prefs)
            case "lens-groups": path.append(LensRoute.groups)
            case "lens-transfer":
                if let app = debugApp() { path.append(LensRoute.transferApp(app)) }
                else { path.append(LensRoute.transfer) }
            case "lens-inject":
                if let app = debugApp() { path.append(LensRoute.injectApp(app)) }
                else { path.append(LensRoute.inject) }
            default: break
            }
        }
        #endif
    }

    #if DEBUG
    private func debugApp() -> AppInfo? {
        guard let id = ProcessInfo.processInfo.environment["WQ_DEBUG_LENS_APP"], !id.isEmpty else { return nil }
        if let hit = AppCatalog.load().first(where: { $0.bundleID == id }) { return hit }
        if let p = ProcessInfo.processInfo.environment["WQ_DEBUG_LENS_APP_PATH"], !p.isEmpty {
            return AppInfo(bundleID: id, name: id, dataPath: p)
        }
        return AppCatalog.info(id)
    }
    #endif
}

private struct FeatureCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let badge: String?

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    IconTile(icon: icon, tint: tint)
                    Spacer(minLength: 4)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(2)
                    .frame(height: 24, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
