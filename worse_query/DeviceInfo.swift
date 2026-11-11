import SwiftUI
import UIKit

struct DeviceSnapshot {
    let modelName: String
    let modelCode: String
    let osVersion: String
    let build: String
    let regionCode: String
    let regionInfo: String
    let udid: String?
    let idfv: String
}

enum DeviceInfoGather {
    private static let modelNames: [String: String] = [
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone14,6": "iPhone SE (3rd)",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone19,7": "iPhone 18 Pro Max",
    ]

    static func machineCode() -> String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else { return "—" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &buf, &size, nil, 0) == 0 else { return "—" }
        return String(cString: buf)
    }

    private static func answer(_ key: String) -> String? {
        guard let value = MGCacheLayoutResolver.copyAnswer(key) as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func systemVersionFile() -> (version: String, build: String)? {
        guard let d = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist"),
              let v = d["ProductVersion"] as? String,
              let b = d["ProductBuildVersion"] as? String else { return nil }
        return (v, b)
    }

    static func summary() -> String {
        let code = answer("ProductType") ?? machineCode()
        return "\(modelNames[code] ?? code) · iOS \(UIDevice.current.systemVersion)"
    }

    static func snapshot() -> DeviceSnapshot {
        let code = answer("ProductType") ?? machineCode()
        let file = systemVersionFile()
        let regionRaw = answer("RegionCode") ?? Locale.current.region?.identifier ?? "—"
        let regionInfo = answer("RegionInfo") ?? "—"
        let udid = answer("UniqueDeviceID") ?? answer("DeviceUDID")
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "—"
        return DeviceSnapshot(
            modelName: modelNames[code] ?? code,
            modelCode: code,
            osVersion: file?.version ?? UIDevice.current.systemVersion,
            build: file?.build ?? "—",
            regionCode: regionRaw,
            regionInfo: regionInfo,
            udid: udid,
            idfv: idfv
        )
    }
}

struct DeviceInfoView: View {
    @EnvironmentObject private var l10n: L10n
    @State private var info: DeviceSnapshot?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PageHeader(title: l10n.t("device_info"), subtitle: l10n.t("device_info_hint"),
                               icon: "iphone.gen3", showsBack: true)
                    if let info {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                KeyValueRow(key: l10n.t("di_model"), value: info.modelName)
                                Divider().overlay(Theme.stroke)
                                KeyValueRow(key: l10n.t("di_model_code"), value: info.modelCode)
                                Divider().overlay(Theme.stroke)
                                KeyValueRow(key: l10n.t("di_os"), value: "\(info.osVersion) (\(info.build))")
                                Divider().overlay(Theme.stroke)
                                KeyValueRow(key: l10n.t("di_region"), value: "\(info.regionCode) · \(info.regionInfo)")
                                Divider().overlay(Theme.stroke)
                                KeyValueRow(key: l10n.t("di_udid"), value: info.udid ?? l10n.t("di_udid_blocked"))
                                if info.udid == nil {
                                    Text(l10n.t("di_udid_note"))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.faint)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Divider().overlay(Theme.stroke)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(l10n.t("di_idfv"))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.sub)
                                        Text(info.idfv)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Theme.text)
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView().tint(Theme.blue).padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let snap = await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    cont.resume(returning: DeviceInfoGather.snapshot())
                }
            }
            info = snap
            #if DEBUG
            if ProcessInfo.processInfo.environment["WQ_DEBUG_DEVTEST"] == "1" {
                let keys = ["UniqueDeviceID", "DeviceUDID", "ProductType", "ProductVersion",
                            "BuildVersion", "RegionCode", "RegionInfo", "DeviceClass",
                            "ProductName", "MarketingName", "SerialNumber"]
                let answers = MGCacheLayoutResolver.debugAnswers(for: keys)
                let lines = keys.map { "\($0)=\(String(describing: answers[$0]))" }
                try? lines.joined(separator: "\n")
                    .write(toFile: WQPaths.documentsPath + "/devprobe.txt", atomically: true, encoding: .utf8)
            }
            #endif
        }
    }
}
