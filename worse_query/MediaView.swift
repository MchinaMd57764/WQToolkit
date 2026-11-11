import SwiftUI
import UIKit
import Photos

struct MediaView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var lens = LensStore.shared

    @State private var appFilter: String?
    @State private var typeFilter = 0
    @State private var selected: MediaItem?
    @State private var confirmSave = false
    @State private var saving = false
    @State private var msg: Msg?

    private var appsWithMedia: [(id: String, name: String, count: Int)] {
        var dict: [String: (String, Int)] = [:]
        for m in lens.media {
            let old = dict[m.bundleID] ?? (m.appName, 0)
            dict[m.bundleID] = (old.0, old.1 + 1)
        }
        return dict.map { (id: $0.key, name: $0.value.0, count: $0.value.1) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var shown: [MediaItem] {
        lens.media.filter { item in
            if let appFilter, item.bundleID != appFilter { return false }
            if typeFilter == 1 && item.isVideo { return false }
            if typeFilter == 2 && !item.isVideo { return false }
            return true
        }
    }

    private var shownBytes: Int64 { shown.reduce(0) { $0 + $1.bytes } }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("lens_media_title"),
                               subtitle: l10n.t("lens_media_sub"),
                               icon: "photo.stack.fill",
                               showsBack: true)
                    if lens.scanning {
                        scanCard
                    } else if !lens.scanned {
                        emptyScanCard
                    } else {
                        statsCard
                        filters
                        if shown.isEmpty {
                            EmptyState(icon: "photo.on.rectangle.angled", title: l10n.t("lens_media_empty"),
                                       detail: l10n.t("lens_media_empty_sub"))
                        } else {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(shown) { item in
                                    MediaCell(item: item)
                                        .onTapGesture { selected = item }
                                }
                            }
                            Text(l10n.f("lens_media_more", shown.count))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.faint)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }
            if saving {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text(l10n.t("lens_saving_photos")).font(.system(size: 12)).foregroundStyle(.white)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selected) { item in
            MediaDetailView(item: item)
                .environmentObject(l10n)
        }
        .alert(l10n.f("lens_save_photos_n", min(shown.count, 200)), isPresented: $confirmSave) {
            Button(l10n.t("lens_save_photos")) { saveShown() }
            Button(l10n.t("cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t("lens_save_photos_msg"))
        }
        .alert(item: $msg) { m in
            Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
        }
        .onAppear(perform: autoOpen)
        .onChange(of: lens.scanned) { _, _ in autoOpen() }
    }

    private func autoOpen() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["WQ_DEBUG_MEDIA_OPEN"] == "1",
              selected == nil, let first = shown.first else { return }
        selected = first
        #endif
    }

    private var scanCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l10n.t("lens_scanning_app"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Text("\(lens.progressDone) / \(lens.progressTotal)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.sub)
                }
                ProgressView(value: lens.progressTotal == 0 ? 0 : Double(lens.progressDone) / Double(lens.progressTotal))
                    .tint(Theme.pink)
                Text(lens.currentApp)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
        }
    }

    private var emptyScanCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.t("lens_need_scan"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                PrimaryButton(title: l10n.t("lens_scan_all"), icon: "sparkle.magnifyingglass", tint: Theme.pink) {
                    lens.scan(force: true)
                }
            }
        }
    }

    private var statsCard: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 16) {
                stat(value: wqSizeString(shownBytes), label: l10n.t("lens_total_size"), tint: Theme.pink)
                Divider().overlay(Theme.stroke).frame(height: 34)
                stat(value: "\(shown.count)", label: l10n.t("lens_items"), tint: Theme.cyan)
                Divider().overlay(Theme.stroke).frame(height: 34)
                stat(value: "\(Set(shown.map(\.bundleID)).count)", label: l10n.t("lens_apps"), tint: Theme.purple)
            }
        }
    }

    private func stat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
            Menu {
                Button {
                    appFilter = nil
                } label: {
                    Label(l10n.t("lens_all_apps"), systemImage: appFilter == nil ? "checkmark" : "square.grid.2x2")
                }
                Divider()
                ForEach(appsWithMedia, id: \.id) { app in
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
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(appFilter == nil ? l10n.t("lens_all_apps") : (appsWithMedia.first { $0.id == appFilter }?.name ?? l10n.t("lens_all_apps")))
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.card))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }

            Spacer(minLength: 4)

            Button {
                confirmSave = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.pink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.card))
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .disabled(shown.isEmpty)
            }
            Picker("", selection: $typeFilter) {
                Text(l10n.t("lens_all")).tag(0)
                Text(l10n.t("lens_images")).tag(1)
                Text(l10n.t("lens_videos")).tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private func saveShown() {
        let items = Array(shown.prefix(200))
        guard !items.isEmpty else { return }
        saving = true
        WQPhotoSaver.save(items) { ok, bad, err in
            saving = false
            if let err {
                msg = Msg(text: err == "denied" ? l10n.t("lens_photos_denied") : l10n.f("lens_save_result", ok, bad))
            } else {
                msg = Msg(text: l10n.f("lens_save_result", ok, bad))
            }
        }
    }
}

private struct MediaCell: View {
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.cardLift)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.isVideo ? "film" : "photo")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.faint)
            }
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(item.appName)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if item.isVideo {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .task(id: item.id) {
            WQThumbCache.shared.load(item, px: 360) { img in
                image = img
            }
        }
    }
}

struct MediaDetailView: View {
    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    @State private var image: UIImage?
    @State private var saving = false
    @State private var msg: Msg?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                        KeyValueRow(key: l10n.t("lens_app"), value: item.appName, mono: false)
                        KeyValueRow(key: l10n.t("lens_size"), value: wqSizeString(item.bytes))
                        KeyValueRow(key: l10n.t("lens_modified"), value: wqDateString(item.mtime))
                        Text(item.path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .truncationMode(.middle)

                        HStack(spacing: 10) {
                            PrimaryButton(title: l10n.t("lens_save_photos"), icon: "square.and.arrow.down",
                                          tint: Theme.pink, enabled: !saving) {
                                saving = true
                                WQPhotoSaver.save([item]) { ok, bad, err in
                                    saving = false
                                    if let err {
                                        msg = Msg(text: err == "denied" ? l10n.t("lens_photos_denied") : l10n.f("lens_save_result", ok, bad))
                                    } else {
                                        msg = Msg(text: l10n.f("lens_save_result", ok, bad))
                                    }
                                }
                            }
                            ShareLink(item: URL(fileURLWithPath: item.path)) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(l10n.t("share"))
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 112, height: 50)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardLift))
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.bg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("close")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert(item: $msg) { m in
                Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
            }
            .task(id: item.id) {
                if !item.isVideo {
                    WQThumbCache.shared.load(item, px: 2200) { img in image = img }
                }
            }
        }
    }
}
