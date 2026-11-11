import SwiftUI
import Combine

struct TweaksView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var mg = MGManager.shared

    @State private var featureStates: [String: Bool] = [:]
    @State private var regionCodeID = MGRegionPreset.keep
    @State private var salesRegionID = MGRegionPreset.keep
    @State private var showRegionCodeSheet = false
    @State private var showSalesRegionSheet = false
    @State private var aiOn = false
    @State private var modelID = Self.modelKeep
    @State private var showModelSheet = false
    @State private var confirmApply = false
    @State private var confirmRestore = false
    @State private var confirmESIM = false
    @State private var esimWanted = true
    @State private var esimBusy = false
    @State private var applying = false
    @State private var synced = false
    @State private var msg: Msg?

    static let modelKeep = "__keep__"

    private let featureTweaks: [MGTweak] = MGManager.shared.tweaks.filter { $0.section == 1 }
    private let devTweaks: [MGTweak] = MGManager.shared.tweaks.filter { $0.section == 2 }
    private let intelTweaks: [MGTweak] = MGManager.shared.tweaks.filter { $0.section == 3 }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            PageHeader(title: l10n.t("mg_title"),
                                       subtitle: l10n.t("mg_safe_note"),
                                       icon: "wand.and.stars")
                            warningCard
                            statusCard
                            if mg.readable {
                                identityCard
                                aiCard
                                esimCard
                                    .id("esim")
                                group(title: l10n.t("mg_section_intel"), tweaks: intelTweaks)
                                    .id("intel")
                                group(title: l10n.t("mg_section_features"), tweaks: featureTweaks)
                                group(title: l10n.t("mg_section_dev"), tweaks: devTweaks)
                                footerNote
                            } else {
                                GlassCard {
                                    VStack(spacing: 10) {
                                        EmptyState(icon: "lock.slash", title: l10n.t("mg_not_writable"),
                                                   detail: l10n.t("mg_bootloop_warning"))
                                        PrimaryButton(title: l10n.t("retry"), icon: "arrow.clockwise", tint: Theme.orange) {
                                            mg.load()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 190)
                    }
                    #if DEBUG
                    .onAppear {
                        if let anchor = ProcessInfo.processInfo.environment["WQ_DEBUG_SCROLL"],
                           !anchor.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                proxy.scrollTo(anchor, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: mg.readable) { _, ready in
                        guard ready,
                              let anchor = ProcessInfo.processInfo.environment["WQ_DEBUG_SCROLL"],
                              !anchor.isEmpty else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
                    #endif
                }
                if applying {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.large).tint(.white)
                        Text(l10n.t("mg_pending")).font(.system(size: 11)).foregroundStyle(.white)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if pendingCount > 0 && mg.readable {
                    applyBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pendingCount)
            .alert(l10n.f("mg_confirm_title", pendingCount), isPresented: $confirmApply) {
                Button(l10n.t("apply"), role: .destructive, action: runApply)
                Button(l10n.t("cancel"), role: .cancel) {}
            } message: {
                Text(l10n.t("mg_confirm_msg"))
            }
            .alert(l10n.t("mg_rollback_confirm"), isPresented: $confirmRestore) {
                Button(l10n.t("restore"), role: .destructive) {
                    let ok = mg.restoreLatest()
                    if ok {
                        syncFromManager()
                        msg = Msg(text: l10n.t("mg_rollback_done"))
                    } else {
                        msg = Msg(text: l10n.t("operation_failed"))
                    }
                }
                Button(l10n.t("cancel"), role: .cancel) {}
            }
            .alert(l10n.t(esimWanted ? "mg_esim_enable_confirm" : "mg_esim_disable_confirm"),
                   isPresented: $confirmESIM) {
                Button(l10n.t(esimWanted ? "mg_esim_enable" : "mg_esim_disable"), role: .destructive) {
                    runESIM(esimWanted)
                }
                Button(l10n.t("cancel"), role: .cancel) {}
            } message: {
                Text(l10n.t("mg_esim_confirm_msg"))
            }
            .alert(item: $msg) { m in
                Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
            }
            .sheet(isPresented: $showModelSheet) {
                ModelPickerSheet(modelID: $modelID)
            }
            .sheet(isPresented: $showRegionCodeSheet) {
                RegionPickerSheet(selectedID: regionCodeID, isCode: true,
                                  current: mg.currentRegionCode) { id in
                    regionCodeID = id
                }
            }
            .sheet(isPresented: $showSalesRegionSheet) {
                RegionPickerSheet(selectedID: salesRegionID, isCode: false,
                                  current: mg.currentRegionInfo) { id in
                    salesRegionID = id
                    if id != MGRegionPreset.keep { regionCodeID = id }
                }
            }
            .onAppear {
                if !synced {
                    synced = true
                    mg.load()
                }
            }
            .onReceive(mg.$loading) { loading in
                if !loading { syncFromManager() }
            }
        }
        .tint(Theme.purple)
    }

    // MARK: 卡片

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 5) {
                Text(l10n.t("mg_bootloop_warning"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(l10n.t("mg_untested_27"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    IconTile(icon: "cpu", tint: mg.readable ? Theme.green : Theme.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mg.readable ? l10n.t("mg_writable") : l10n.t("mg_not_writable"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(l10n.t("mg_path"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                    }
                    Spacer()
                    Button {
                        mg.load()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.sub)
                    }
                }

                Text(mg.path)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    StatusPill(text: l10n.t("mg_baseline") + " " + (mg.baselineExists ? "✓" : "—"),
                               tint: mg.baselineExists ? Theme.green : Theme.orange)
                    StatusPill(text: l10n.t("backups") + " \(mg.backups.count)", tint: Theme.blue)
                    Spacer()
                    Button {
                        confirmRestore = true
                    } label: {
                        Text(l10n.t("mg_rollback"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mg.backups.isEmpty ? Theme.faint : Theme.orange)
                    }
                    .disabled(mg.backups.isEmpty)
                }

                if let err = mg.lastError {
                    Text(err)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.red)
                }
            }
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("mg_section_identity"))
            GlassCard {
                VStack(spacing: 14) {
                    Button {
                        showModelSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(icon: "iphone.gen3", tint: Theme.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l10n.t("mg_model.title"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text(modelLabel)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.sub)
                            }
                            Spacer()
                            RiskBadge(level: 2)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.faint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Theme.stroke)

                    regionSelectRow(title: l10n.t("mg_region_code"),
                                    detail: l10n.t("mg_region_code_detail"),
                                    icon: "globe.americas.fill", tint: Theme.cyan,
                                    current: mg.currentRegionCode,
                                    target: regionCodeTarget) {
                        showRegionCodeSheet = true
                    }

                    Divider().overlay(Theme.stroke)

                    regionSelectRow(title: l10n.t("mg_region_sales"),
                                    detail: l10n.t("mg_region_sales_detail"),
                                    icon: "shippingbox.fill", tint: Theme.cyan,
                                    current: mg.currentRegionInfo,
                                    target: salesRegionTarget) {
                        showSalesRegionSheet = true
                    }

                    Text(l10n.t("mg_model.detail"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("mg_section_ai"))
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    toggleRow(title: l10n.t("mg.ai.title"), detail: l10n.t("mg.ai.detail"),
                              icon: "sparkles", tint: Theme.purple, risk: 2,
                              isOn: $aiOn, pending: aiOn != mg.isAIOn)
                    Text(l10n.t("mg_ai_warning"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var esimCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: l10n.t("mg_esim.title"))
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        IconTile(icon: "simcard.fill", tint: Theme.cyan)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(l10n.t("mg_esim.title"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                RiskBadge(level: 2)
                                StatusPill(text: mg.esimUnlocked ? l10n.t("mg_esim_on") : l10n.t("mg_esim_off"),
                                           tint: mg.esimUnlocked ? Theme.green : Theme.sub)
                            }
                            Text(l10n.t("mg_esim.detail"))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.sub)
                                .fixedSize(horizontal: false, vertical: true)
                            if let layout = mg.esimLayout {
                                Text(l10n.f("mg_esim_layout", layout.slotCount,
                                            layout.greenTeaIndex, layout.notGreenTeaIndex))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Theme.faint)
                            }
                        }
                        Spacer(minLength: 8)
                        if esimBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { mg.esimUnlocked },
                                set: { want in
                                    esimWanted = want
                                    confirmESIM = true
                                }
                            ))
                            .labelsHidden()
                            .tint(Theme.cyan)
                            .disabled(!mg.esimSupported)
                        }
                    }
                    if !mg.esimSupported {
                        Text(l10n.t("mg_esim_unsupported"))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(l10n.t("mg_esim.warning"))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func group(title: String, tweaks: [MGTweak]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            GlassCard {
                VStack(spacing: 14) {
                    ForEach(Array(tweaks.enumerated()), id: \.element.id) { idx, tw in
                        toggleRow(title: tw.title, detail: tw.detail, icon: tw.icon,
                                  tint: tw.risk == 2 ? Theme.orange : Theme.blue,
                                  risk: tw.risk,
                                  isOn: binding(for: tw),
                                  pending: (featureStates[tw.id] ?? mg.isOn(tw)) != mg.isOn(tw))
                            .id(tw.id)
                        if idx != tweaks.count - 1 {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
            }
        }
    }

    private func toggleRow(title: String, detail: String, icon: String, tint: Color, risk: Int,
                           isOn: Binding<Bool>, pending: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if risk == 2 { RiskBadge(level: 2) }
                    if pending { StatusPill(text: l10n.t("mg_pending"), tint: Theme.orange) }
                }
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.vertical, 2)
    }

    private func regionSelectRow(title: String, detail: String, icon: String, tint: Color,
                                 current: String, target: String?,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        RiskBadge(level: 2)
                        if target != nil { StatusPill(text: l10n.t("mg_pending"), tint: Theme.orange) }
                    }
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        Text(current)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.sub)
                        if let target {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Theme.orange)
                            Text(target)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.orange)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.t("mg_safe_note"))
            Text(l10n.t("mg_risk_note"))
            Text(l10n.t("restart_hint"))
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.faint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var applyBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.f("mg_pending_n", pendingCount))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(l10n.t("mg_bootloop_warning"))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                confirmApply = true
            } label: {
                Text(l10n.t("apply"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.purple))
                    .shadow(color: Theme.purple.opacity(0.4), radius: 14, y: 6)
            }
            Button {
                syncFromManager()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .padding(10)
                    .background(Circle().fill(Theme.cardLift))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))
        )
    }

    // MARK: 逻辑

    private func binding(for tw: MGTweak) -> Binding<Bool> {
        Binding(
            get: { featureStates[tw.id] ?? mg.isOn(tw) },
            set: { featureStates[tw.id] = $0 }
        )
    }

    private var modelLabel: String {
        if modelID == Self.modelKeep {
            return "\(mg.currentProductType) · \(mg.currentHardware)"
        }
        if let p = mg.preset(for: modelID) {
            return "\(p.name) · \(p.productType) · \(p.hardware)"
        }
        return l10n.t("mg_keep_original")
    }

    private var regionCodeTarget: String? {
        guard let p = MGRegionPreset.preset(id: regionCodeID),
              p.code != mg.currentRegionCode else { return nil }
        return p.code
    }

    private var salesRegionTarget: String? {
        guard let p = MGRegionPreset.preset(id: salesRegionID) else { return nil }
        let present = [MGKeys.regionInfo, MGKeys.legacyRegionInfo]
            .filter { mg.currentExtra[$0] != nil }
        let keys = present.isEmpty ? [MGKeys.regionInfo] : present
        return keys.contains { (mg.currentExtra[$0] as? String) != p.info } ? p.info : nil
    }

    private var pendingEdits: [MGEdit] {
        var out: [MGEdit] = []
        for tw in mg.tweaks {
            let on = featureStates[tw.id] ?? mg.isOn(tw)
            for (key, value) in tw.keys {
                let target = mg.targetValue(key, on: on, onValue: value)
                if !mg.matchesTarget(key, target) {
                    out.append(MGEdit(key: key, value: target))
                }
            }
        }

        if let p = MGRegionPreset.preset(id: regionCodeID), p.code != mg.currentRegionCode {
            out.append(MGEdit(key: MGKeys.regionCode, value: .string(p.code)))
        }

        if let p = MGRegionPreset.preset(id: salesRegionID) {
            let present = [MGKeys.regionInfo, MGKeys.legacyRegionInfo]
                .filter { mg.currentExtra[$0] != nil }
            for key in (present.isEmpty ? [MGKeys.regionInfo] : present)
            where (mg.currentExtra[key] as? String) != p.info {
                out.append(MGEdit(key: key, value: .string(p.info)))
            }
        }

        let aiTarget = mg.targetValue(MGKeys.generative, on: aiOn, onValue: .int(1))
        if !mg.matchesTarget(MGKeys.generative, aiTarget) {
            out.append(MGEdit(key: MGKeys.generative, value: aiTarget))
        }

        out.append(contentsOf: modelEdits())
        return out
    }

    private var pendingCount: Int { pendingEdits.count }

    private func modelEdits() -> [MGEdit] {
        var out: [MGEdit] = []
        if let p = mg.preset(for: modelID) {
            if mg.currentProductType != p.productType {
                out.append(MGEdit(key: MGKeys.productType, value: .string(p.productType)))
            }
            if mg.currentHardware != p.hardware {
                out.append(MGEdit(key: MGKeys.hardware, value: .string(p.hardware)))
            }
            return out
        }
        guard modelID.isEmpty else { return out }
        let basePT = mg.baselineExtra[MGKeys.productType] as? String
        let baseHW = mg.baselineExtra[MGKeys.hardware] as? String
        if mg.currentExtra[MGKeys.productType] != nil {
            out.append(MGEdit(key: MGKeys.productType, value: basePT.map(MGValue.string)))
        }
        if mg.currentExtra[MGKeys.hardware] != nil {
            out.append(MGEdit(key: MGKeys.hardware, value: baseHW.map(MGValue.string)))
        }
        return out
    }

    private func syncFromManager() {
        var next: [String: Bool] = [:]
        for tw in mg.tweaks { next[tw.id] = mg.isOn(tw) }
        featureStates = next
        regionCodeID = MGRegionPreset.keep
        salesRegionID = MGRegionPreset.keep
        aiOn = mg.isAIOn
        modelID = mg.currentPresetID.isEmpty ? Self.modelKeep : mg.currentPresetID
    }

    private func runESIM(_ unlock: Bool) {
        guard mg.esimSupported else { return }
        esimBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let err = MGManager.shared.applyESIM(unlock: unlock)
            DispatchQueue.main.async {
                esimBusy = false
                if let err {
                    msg = Msg(text: l10n.f("mg_esim_failed", err))
                } else {
                    msg = Msg(text: l10n.t(unlock ? "mg_esim_enabled" : "mg_esim_disabled"))
                }
            }
        }
    }

    private func runApply() {
        let edits = pendingEdits
        guard !edits.isEmpty else { return }
        applying = true
        DispatchQueue.global(qos: .userInitiated).async {
            let err = MGManager.shared.apply(edits)
            DispatchQueue.main.async {
                applying = false
                if let err {
                    msg = Msg(text: l10n.f("mg_apply_failed", err))
                } else {
                    msg = Msg(text: l10n.t("mg_applied") + "\n" + l10n.t("mg_backup_created")
                        .replacingOccurrences(of: "%@", with: "Documents/WQBackups/MG"))
                    mg.load()
                }
            }
        }
    }
}

struct RegionPickerSheet: View {
    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss

    let selectedID: String
    let isCode: Bool
    let current: String
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        row(id: MGRegionPreset.keep, name: l10n.t("mg_region_keep"),
                            detail: l10n.f("mg_region_keep_detail", current), tint: Theme.green)
                        SectionHeader(title: l10n.t("mg_region_presets"))
                        ForEach(MGRegionPreset.presets) { p in
                            row(id: p.id, name: p.localizedName,
                                detail: isCode ? p.code : p.info, tint: Theme.cyan)
                        }
                        Text(l10n.t("mg_region_detail"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isCode ? l10n.t("mg_region_code") : l10n.t("mg_region_sales"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("done")) { dismiss() }
                }
            }
        }
    }

    private func row(id: String, name: String, detail: String, tint: Color) -> some View {
        Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedID == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(selectedID == id ? Theme.cyan : Theme.faint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Circle().fill(tint.opacity(0.7)).frame(width: 6, height: 6)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }
}

struct ModelPickerSheet: View {
    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mg = MGManager.shared
    @Binding var modelID: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        row(id: TweaksView.modelKeep, name: l10n.t("mg_current_model"),
                            detail: "\(mg.currentProductType) · \(mg.currentHardware)", tint: Theme.green)
                        row(id: "", name: l10n.t("mg_keep_original"),
                            detail: l10n.t("mg_baseline"), tint: Theme.orange)
                        SectionHeader(title: l10n.t("verified_device"))
                        ForEach(MGModelPreset.presets) { p in
                            row(id: p.id, name: p.name, detail: "\(p.productType) · \(p.hardware)", tint: Theme.blue)
                        }
                        Text(l10n.t("mg_model.detail"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(l10n.t("mg_choose_model"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("done")) { dismiss() }
                }
            }
        }
    }

    private func row(id: String, name: String, detail: String, tint: Color) -> some View {
        Button {
            modelID = id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: modelID == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(modelID == id ? Theme.blue : Theme.faint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Circle().fill(tint.opacity(0.7)).frame(width: 6, height: 6)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }
}
