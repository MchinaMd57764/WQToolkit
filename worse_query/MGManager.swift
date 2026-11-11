import Foundation
import Combine
import CoreFoundation

enum MGValue {
    case int(Int)
    case string(String)
    case array([Int])

    var plist: Any {
        switch self {
        case .int(let v): return v
        case .string(let v): return v
        case .array(let v): return v
        }
    }

    init?(plist: Any) {
        if let n = plist as? NSNumber, CFGetTypeID(n as CFTypeRef) != CFBooleanGetTypeID() {
            self = .int(n.intValue)
        } else if let s = plist as? String {
            self = .string(s)
        } else if let a = plist as? [Int] {
            self = .array(a)
        } else if let a = plist as? [NSNumber] {
            self = .array(a.map(\.intValue))
        } else {
            return nil
        }
    }

    var display: String {
        switch self {
        case .int(let v): return "\(v)"
        case .string(let v): return v
        case .array(let v): return v.map(String.init).joined(separator: ",")
        }
    }

    func matches(_ any: Any?) -> Bool {
        guard let any else { return false }
        switch self {
        case .int(let v): return (any as? NSNumber)?.intValue == v
        case .string(let v): return (any as? String) == v
        case .array(let v): return ((any as? [NSNumber])?.map(\.intValue)) == v
        }
    }
}

enum MGKeys {
    static let regionCode = "h63QSdBCiT/z0WU6rdQv6Q"
    static let regionInfo = "zHeENZu+wbg7PUprwNwBWg"
    static let legacyRegionInfo = "yK+xavymRGZ3xWc1tb8XDg"
    static let greenTea = "iyfxmLogGVIaH7aEgqwcIA"
    static let notGreenTea = "4snMZS8LJkSctKypt2m+xA"
    static let generative = "A62OafQ85EJAiiqKn4agtg"
    static let productType = "h9jDsbgj7xIVeIQ8S3/X3Q"
    static let hardware = "oYicEKzVTz4/CxxE05pEgQ"
    static let cpu = "5pYKlGnYYBzGvAlIU8RjEQ"
    static let internalInstall = "EqrsVvjcYDdxHBiQmGhAWw"
    static let srd = "XYlJKKkj2hztRP1NWWnhlw"
    static let ipadApps = "9MZ5AdH43csAUajl/dU+IQ"
    static let stageManager = "qeaj75wk3HF4DwQ8qbIi7g"
    static let dynamicIsland = "YlEtTtHlNesRBMal1CqRaA"
    static let aod = "2OOJf1VhaM7NxfRok3HbWQ"
    static let aodSuppress = "j8/Omm6s1lsmTDFsXjsBfA"
    static let pencil = "yhHcB0iH0d1XzPO/CFd3ow"
    static let actionButton = "cT44WE1EohiwRzhsZ8xEsw"
    static let chargeLimit = "37NVydb//GP/GrhuTN+exg"
    static let bootChime = "QHxt+hGLaBPbQJbXiUJX3w"
    static let crashDetection = "HCzWusHQwZDea6nNhaKndw"
    static let tapToWake = "yZf3GTRMGTuwSV/lD7Cagw"
    static let cameraControl = "CwvKxM2cEogD3p+HYgaW0Q"
    static let cameraControl2 = "oOV1jhJbdV3AddkcCg0AEA"
    static let aodHighLuminance = "7brdL5xrEUWnlF9C0kdg5A"
    static let aodFlipbook = "aoJSd/MXk7M40NgXTM6x+g"
    static let hdrPhoto = "a1r7npIrhXsZ7SmKRKC1eA"
    static let parallax = "UIParallaxCapability"
    static let audioMix = "aVL5GE3tx0LSCI/ErfrJGA"
    static let spatialFaceTime = "/EVOCjM/Nmb2roP5ebtEFA"
    static let siriOnDevice = "K/R1GfGfCkXvEhaPS2Vrng"
    static let audioIntelligence = "rb2tKZxlj0Gm2tBmUQSLqQ"
    static let personalTranslator = "M1n2sAqf33NAOgZRGxQYBA"
    static let photosCleanUp = "XNCjqOupLM/S8fNyxRNQTA"
    static let handwritingSynthesis = "YgYIIViDt1kgzyIsIV61vA"
    static let alwaysListeningSiri = "TusANsf9Lfe3P/9fIXXSrQ"
}

struct MGRegionPreset: Identifiable, Hashable {
    let id: String
    let code: String
    let info: String
    let nameEN: String
    let nameZH: String

    static let keep = "__keep__"
    static let presets: [MGRegionPreset] = [
        .init(id: "US", code: "LL", info: "LL/A", nameEN: "United States", nameZH: "美国"),
        .init(id: "HK", code: "ZA", info: "ZA/A", nameEN: "Hong Kong", nameZH: "中国香港"),
        .init(id: "JP", code: "J", info: "J/A", nameEN: "Japan", nameZH: "日本"),
        .init(id: "CN", code: "CH", info: "CH/A", nameEN: "China (Mainland)", nameZH: "中国大陆"),
        .init(id: "TW", code: "TA", info: "TA/A", nameEN: "Taiwan", nameZH: "中国台湾"),
        .init(id: "UK", code: "B", info: "B/A", nameEN: "United Kingdom", nameZH: "英国"),
        .init(id: "CA", code: "C", info: "C/A", nameEN: "Canada", nameZH: "加拿大"),
    ]

    static func preset(id: String) -> MGRegionPreset? {
        presets.first { $0.id == id }
    }

    var localizedName: String {
        L10n.shared.effective == "zh" ? nameZH : nameEN
    }
}

struct MGTweak: Identifiable {
    let id: String
    let keys: [(String, MGValue)]
    let risk: Int
    let section: Int

    var title: String { L10n.shared.t("mg.\(id).title") }
    var detail: String { L10n.shared.t("mg.\(id).detail") }
    var icon: String {
        switch id {
        case "internal_install": return "hammer.fill"
        case "srd": return "shield.lefthalf.filled"
        case "ipad_apps": return "ipad"
        case "stage": return "rectangle.split.2x1.fill"
        case "di": return "capsule.fill"
        case "aod": return "moon.stars.fill"
        case "pencil": return "pencil.tip"
        case "action": return "button.horizontal.top.press.fill"
        case "charge": return "battery.75percent"
        case "chime": return "bell.fill"
        case "sos": return "car.side.fill"
        case "tap": return "hand.tap.fill"
        case "camera": return "camera.fill"
        case "aod_high": return "sun.max.fill"
        case "aod_flip": return "rectangle.stack.fill"
        case "hdr": return "photo.fill"
        case "parallax": return "rectangle.on.rectangle"
        case "audio_mix": return "slider.horizontal.3"
        case "spatial_ft": return "video.fill"
        case "siri_device": return "waveform"
        case "audio_intel": return "ear"
        case "translator": return "character.bubble"
        case "cleanup": return "wand.and.stars"
        case "handwriting": return "scribble"
        case "always_listen": return "mic.fill"
        default: return "switch.2"
        }
    }
}

struct MGEdit {
    let key: String
    let value: MGValue?
}

struct MGModelPreset: Identifiable, Hashable {
    let productType: String
    let hardware: String
    let name: String
    var id: String { productType }

    static let presets: [MGModelPreset] = [
        .init(productType: "iPhone18,2", hardware: "V54AP", name: "iPhone 17 Pro Max"),
        .init(productType: "iPhone18,1", hardware: "V53AP", name: "iPhone 17 Pro"),
        .init(productType: "iPhone18,4", hardware: "D23AP", name: "iPhone Air"),
        .init(productType: "iPhone18,3", hardware: "V57AP", name: "iPhone 17"),
        .init(productType: "iPhone17,2", hardware: "D94AP", name: "iPhone 16 Pro Max"),
        .init(productType: "iPhone17,1", hardware: "D93AP", name: "iPhone 16 Pro"),
        .init(productType: "iPhone17,4", hardware: "D48AP", name: "iPhone 16 Plus"),
        .init(productType: "iPhone17,3", hardware: "D47AP", name: "iPhone 16"),
        .init(productType: "iPhone16,2", hardware: "D84AP", name: "iPhone 15 Pro Max"),
        .init(productType: "iPhone16,1", hardware: "D83AP", name: "iPhone 15 Pro"),
        .init(productType: "iPhone15,3", hardware: "D74AP", name: "iPhone 14 Pro Max"),
        .init(productType: "iPhone15,2", hardware: "D73AP", name: "iPhone 14 Pro"),
    ]
}

final class MGManager: ObservableObject {
    static let shared = MGManager()

    let path = WQPaths.mgCache
    private let fm = FileManager.default

    @Published private(set) var readable = false
    @Published private(set) var currentExtra: [String: Any] = [:]
    @Published private(set) var baselineExtra: [String: Any] = [:]
    @Published private(set) var backups: [URL] = []
    @Published private(set) var baselineExists = false
    @Published private(set) var lastError: String?
    @Published private(set) var loading = false
    @Published private(set) var esimLayout: MGCacheLayout?
    @Published private(set) var esimFlags: (greenTea: Bool, notGreenTea: Bool)?

    let tweaks: [MGTweak] = [
        MGTweak(id: "internal_install", keys: [(MGKeys.internalInstall, .int(1))], risk: 2, section: 2),
        MGTweak(id: "srd", keys: [(MGKeys.srd, .int(1))], risk: 2, section: 2),
        MGTweak(id: "ipad_apps", keys: [(MGKeys.ipadApps, .array([1, 2]))], risk: 1, section: 2),
        MGTweak(id: "stage", keys: [(MGKeys.stageManager, .int(1))], risk: 2, section: 1),
        MGTweak(id: "di", keys: [(MGKeys.dynamicIsland, .int(1))], risk: 1, section: 1),
        MGTweak(id: "aod", keys: [(MGKeys.aod, .int(1)), (MGKeys.aodSuppress, .int(1))], risk: 1, section: 1),
        MGTweak(id: "pencil", keys: [(MGKeys.pencil, .int(1))], risk: 0, section: 1),
        MGTweak(id: "action", keys: [(MGKeys.actionButton, .int(1))], risk: 0, section: 1),
        MGTweak(id: "charge", keys: [(MGKeys.chargeLimit, .int(1))], risk: 0, section: 1),
        MGTweak(id: "chime", keys: [(MGKeys.bootChime, .int(1))], risk: 0, section: 1),
        MGTweak(id: "sos", keys: [(MGKeys.crashDetection, .int(1))], risk: 0, section: 1),
        MGTweak(id: "tap", keys: [(MGKeys.tapToWake, .int(1))], risk: 0, section: 1),
        MGTweak(id: "camera", keys: [(MGKeys.cameraControl, .int(1)), (MGKeys.cameraControl2, .int(1))], risk: 1, section: 1),
        MGTweak(id: "aod_high", keys: [(MGKeys.aodHighLuminance, .int(1))], risk: 1, section: 1),
        MGTweak(id: "aod_flip", keys: [(MGKeys.aodFlipbook, .int(1))], risk: 1, section: 1),
        MGTweak(id: "hdr", keys: [(MGKeys.hdrPhoto, .int(1))], risk: 1, section: 1),
        MGTweak(id: "parallax", keys: [(MGKeys.parallax, .int(0))], risk: 0, section: 1),
        MGTweak(id: "audio_mix", keys: [(MGKeys.audioMix, .int(1))], risk: 0, section: 1),
        MGTweak(id: "spatial_ft", keys: [(MGKeys.spatialFaceTime, .int(1))], risk: 0, section: 1),
        MGTweak(id: "siri_device", keys: [(MGKeys.siriOnDevice, .int(1))], risk: 2, section: 3),
        MGTweak(id: "audio_intel", keys: [(MGKeys.audioIntelligence, .int(1))], risk: 2, section: 3),
        MGTweak(id: "translator", keys: [(MGKeys.personalTranslator, .int(1))], risk: 2, section: 3),
        MGTweak(id: "cleanup", keys: [(MGKeys.photosCleanUp, .int(1))], risk: 2, section: 3),
        MGTweak(id: "handwriting", keys: [(MGKeys.handwritingSynthesis, .int(1))], risk: 2, section: 3),
        MGTweak(id: "always_listen", keys: [(MGKeys.alwaysListeningSiri, .int(1))], risk: 2, section: 3),
    ]

    private var backupDir: URL {
        let dir = WQPaths.backupRoot().appendingPathComponent("MG", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(self.path)
            var ok = false
            var extra: [String: Any] = [:]
            var error: String?
            var layout: MGCacheLayout?
            var flags: (greenTea: Bool, notGreenTea: Bool)?
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.path)),
               let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
                extra = (root["CacheExtra"] as? [String: Any]) ?? [:]
                ok = true
                _ = self.ensureBaseline(data: data)
                if let uuid = root["CacheUUID"] as? String,
                   let cacheData = root["CacheData"] as? Data,
                   let resolved = MGCacheLayoutResolver.resolve(uuid: uuid, data: cacheData, extra: extra) {
                    layout = resolved
                    flags = resolved.flags(in: cacheData)
                }
            } else {
                error = "READ FAILED"
            }
            let base = self.readBaselineExtra() ?? [:]
            let list = self.listBackups()
            let hasBaseline = self.fm.fileExists(atPath: self.backupDir.appendingPathComponent("baseline.plist").path)
            #if DEBUG
            if ProcessInfo.processInfo.environment["WQ_DEBUG_MG"] == "1", let data = try? Data(contentsOf: URL(fileURLWithPath: self.path)) {
                let docs = WQPaths.documentsPath
                try? data.write(to: URL(fileURLWithPath: docs + "/mg_current.plist"))
                let names = (try? self.fm.contentsOfDirectory(atPath: self.backupDir.path)) ?? []
                try? names.sorted().joined(separator: "\n")
                    .write(toFile: docs + "/mg_backups.txt", atomically: true, encoding: .utf8)
                NSLog("WQMG size=%d region=%@ info=%@ ai=%@ backups=%@",
                      data.count,
                      String(describing: extra[MGKeys.regionCode]),
                      String(describing: extra[MGKeys.regionInfo]),
                      String(describing: extra[MGKeys.generative]),
                      names.sorted().joined(separator: ","))
            }
            if ProcessInfo.processInfo.environment["WQ_DEBUG_MG_KEYS"] == "1",
               let data = try? Data(contentsOf: URL(fileURLWithPath: self.path)),
               let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
                let docs = WQPaths.documentsPath
                let keys: Set<String> = [MGKeys.generative, MGKeys.regionCode, MGKeys.regionInfo,
                                         MGKeys.greenTea, MGKeys.notGreenTea, MGKeys.productType,
                                         MGKeys.hardware, MGKeys.internalInstall]
                let slots = MGCacheLayoutResolver.debugSlots(for: keys)
                let cacheData = (root["CacheData"] as? Data) ?? Data()
                let slotCount = cacheData.count / 9
                var lines: [String] = ["cacheData=\(cacheData.count) slotCount=\(slotCount)"]
                for key in keys.sorted() {
                    let extraValue = String(describing: (root["CacheExtra"] as? [String: Any])?[key])
                    if let info = slots[key] {
                        var value = "OOR"
                        var valid = "OOR"
                        if info.index >= 0, info.index < slotCount {
                            let start = info.index * 8
                            value = cacheData[start..<start + 8].map { String(format: "%02x", $0) }.joined()
                            valid = "\(cacheData[slotCount * 8 + info.index])"
                        }
                        lines.append("\(key) slot=\(info.index) type=0x\(String(info.type, radix: 16)) value=\(value) valid=\(valid) extra=\(extraValue)")
                    } else {
                        lines.append("\(key) NO_SLOT extra=\(extraValue)")
                    }
                }
                let answers = MGCacheLayoutResolver.debugAnswers(for: keys.sorted())
                for key in keys.sorted() {
                    lines.append("answer \(key)=\(String(describing: answers[key]))")
                }
                try? lines.joined(separator: "\n").write(toFile: docs + "/mg_keys.txt", atomically: true, encoding: .utf8)
            }
            if ProcessInfo.processInfo.environment["WQ_DEBUG_LISTAPPS"] == "1" {
                let docs = WQPaths.documentsPath
                var scan: [String] = []
                for p in [WQPaths.appGroups, WQPaths.appData,
                          "/private/var/mobile/Containers/Bundle/Application",
                          "/private/var/mobile/Library/MobileInstallation"] {
                    let entries = wqReadEntries(p)
                    scan.append("\(p) read=\(entries?.count ?? -1)")
                    if let entries, p == WQPaths.appData {
                        var ids: [String] = []
                        for e in entries.prefix(400) {
                            let meta = e.path + "/.com.apple.mobile_container_manager.metadata.plist"
                            if let d = NSDictionary(contentsOfFile: meta),
                               let id = d["MCMMetadataIdentifier"] as? String {
                                ids.append(id)
                            }
                        }
                        scan.append("appData ids=\(ids.count) \(ids.prefix(60).joined(separator: ","))")
                    }
                }
                if let wcls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
                   let ws = wcls.perform(NSSelectorFromString("defaultWorkspace"))?
                    .takeUnretainedValue() as? NSObject {
                    for sel in ["applicationIdentifiers", "allInstalledApplications", "allApplications"] {
                        let s = NSSelectorFromString(sel)
                        if ws.responds(to: s) {
                            let r = ws.perform(s)?.takeUnretainedValue()
                            scan.append("WS \(sel) n=\((r as? [Any])?.count ?? -1)")
                        } else {
                            scan.append("WS \(sel) missing")
                        }
                    }
                } else {
                    scan.append("WS unavailable")
                }
                try? scan.joined(separator: "\n").write(toFile: docs + "/mg_scan.txt", atomically: true, encoding: .utf8)
            }
            #endif
            DispatchQueue.main.async {
                self.readable = ok
                self.currentExtra = extra
                self.baselineExtra = base
                self.lastError = error
                self.backups = list
                self.baselineExists = hasBaseline
                self.esimLayout = layout
                self.esimFlags = flags
                self.loading = false
                #if DEBUG
                if ProcessInfo.processInfo.environment["WQ_DEBUG_MG"] == "1" {
                    NSLog("WQESIM layout=%@ flags=%@", String(describing: layout), String(describing: flags))
                }
                #endif
            }
        }
    }

    func isOn(_ tweak: MGTweak) -> Bool {
        tweak.keys.allSatisfy { pair in pair.1.matches(currentExtra[pair.0]) }
    }

    var currentRegionCode: String {
        (currentExtra[MGKeys.regionCode] as? String) ?? "—"
    }

    var currentRegionInfo: String {
        (currentExtra[MGKeys.regionInfo] as? String) ?? "—"
    }

    var esimUnlocked: Bool {
        guard let flags = esimFlags else { return false }
        return !flags.greenTea && flags.notGreenTea
    }

    var esimIsChina: Bool {
        guard let flags = esimFlags else { return false }
        return flags.greenTea && !flags.notGreenTea
    }

    var esimSupported: Bool {
        esimLayout != nil && (esimUnlocked || esimIsChina)
    }

    var isAIOn: Bool {
        MGValue.int(1).matches(currentExtra[MGKeys.generative])
    }

    var currentProductType: String {
        (currentExtra[MGKeys.productType] as? String) ?? "—"
    }

    var currentHardware: String {
        (currentExtra[MGKeys.hardware] as? String) ?? "—"
    }

    var currentPresetID: String {
        MGModelPreset.presets.first {
            $0.productType == currentProductType && $0.hardware == currentHardware
        }?.id ?? ""
    }

    func preset(for id: String) -> MGModelPreset? {
        MGModelPreset.presets.first { $0.id == id }
    }

    func targetValue(_ key: String, on: Bool, onValue: MGValue) -> MGValue? {
        if on { return onValue }
        if let b = baselineExtra[key], let v = MGValue(plist: b) { return v }
        return nil
    }

    func matchesTarget(_ key: String, _ target: MGValue?) -> Bool {
        let current = currentExtra[key]
        switch (target, current) {
        case (nil, nil): return true
        case (nil, _): return false
        case (let t?, let c?): return t.matches(c)
        default: return false
        }
    }

    func applyESIM(unlock: Bool) -> String? {
        guard let layout = esimLayout else { return "layout" }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
              let uuid = root["CacheUUID"] as? String,
              let cacheData = root["CacheData"] as? Data else { return "read" }
        let extra = (root["CacheExtra"] as? [String: Any]) ?? [:]
        guard layout.matches(uuid: uuid, data: cacheData, extra: extra) else { return "layout" }

        var patched = cacheData
        patched[layout.greenTeaOffset] = unlock ? 0 : 1
        patched[layout.notGreenTeaOffset] = unlock ? 1 : 0
        guard patched != cacheData else { return nil }

        root["CacheData"] = patched
        guard let out = try? PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0) else {
            return "serialize"
        }
        _ = ensureBaseline(data: data)
        guard writeBackup(data) else { return "backup" }
        guard write(out) else { return "write" }
        guard verifyESIM(original: cacheData, unlock: unlock, layout: layout) else {
            _ = write(data)
            return "verify"
        }
        load()
        return nil
    }

    private func verifyESIM(original: Data, unlock: Bool, layout: MGCacheLayout) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
              let uuid = root["CacheUUID"] as? String,
              let now = root["CacheData"] as? Data else { return false }
        let extra = (root["CacheExtra"] as? [String: Any]) ?? [:]
        guard layout.matches(uuid: uuid, data: now, extra: extra),
              now.count == original.count else { return false }
        for index in now.indices where now[index] != original[index] {
            if index != layout.greenTeaOffset && index != layout.notGreenTeaOffset {
                return false
            }
        }
        let green = now[layout.greenTeaOffset]
        let notGreen = now[layout.notGreenTeaOffset]
        return unlock ? (green == 0 && notGreen == 1) : (green == 1 && notGreen == 0)
    }

    func apply(_ edits: [MGEdit]) -> String? {        guard !edits.isEmpty else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return "read"
        }
        let cacheData = root["CacheData"] as? Data
        var extra = (root["CacheExtra"] as? [String: Any]) ?? [:]
        for e in edits {
            if let v = e.value {
                extra[e.key] = v.plist
            } else if let b = baselineExtra[e.key] {
                extra[e.key] = b
            } else {
                extra.removeValue(forKey: e.key)
            }
        }
        root["CacheExtra"] = extra
        guard let out = try? PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0) else {
            return "serialize"
        }
        _ = ensureBaseline(data: data)
        guard writeBackup(data) else { return "backup" }
        #if DEBUG
        NSLog("WQMG apply edits=%d orig=%d new=%d", edits.count, data.count, out.count)
        #endif
        guard write(out) else { return "write" }
        guard verify(cacheData: cacheData, expect: edits) else {
            #if DEBUG
            NSLog("WQMG apply verify FAILED")
            #endif
            _ = write(data)
            return "verify"
        }
        #if DEBUG
        NSLog("WQMG apply OK")
        #endif
        load()
        return nil
    }

    @discardableResult
    func restoreLatest() -> Bool {
        guard let latest = backups.first else { return false }
        return restore(url: latest)
    }

    @discardableResult
    func restore(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        guard write(data) else { return false }
        load()
        return true
    }

    // 直接覆盖原文件，保留 inode 的属主、权限与 ACL；重命名会把这些丢掉
    private func write(_ data: Data) -> Bool {
        do {
            let fh = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            try fh.truncate(atOffset: 0)
            try fh.write(contentsOf: data)
            try fh.synchronize()
            try fh.close()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func verify(cacheData: Data?, expect: [MGEdit]) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return false
        }
        if let cacheData, (root["CacheData"] as? Data) != cacheData {
            #if DEBUG
            NSLog("WQMG verify cacheData mismatch")
            #endif
            return false
        }
        let extra = (root["CacheExtra"] as? [String: Any]) ?? [:]
        for e in expect {
            if let v = e.value {
                if !v.matches(extra[e.key]) {
                    #if DEBUG
                    NSLog("WQMG verify key %@ want=%@ got=%@", e.key, v.display, String(describing: extra[e.key]))
                    #endif
                    return false
                }
            } else if let b = baselineExtra[e.key] {
                if let v = MGValue(plist: b), !v.matches(extra[e.key]) {
                    #if DEBUG
                    NSLog("WQMG verify key %@ wantBase=%@ got=%@", e.key, v.display, String(describing: extra[e.key]))
                    #endif
                    return false
                }
            } else if extra[e.key] != nil {
                #if DEBUG
                NSLog("WQMG verify key %@ wantAbsent got=%@", e.key, String(describing: extra[e.key]))
                #endif
                return false
            }
        }
        return true
    }

    @discardableResult
    private func ensureBaseline(data: Data) -> URL? {
        let url = backupDir.appendingPathComponent("baseline.plist")
        if fm.fileExists(atPath: url.path) { return url }
        do {
            try data.write(to: url)
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            return url
        } catch {
            return nil
        }
    }

    private func readBaselineExtra() -> [String: Any]? {
        let url = backupDir.appendingPathComponent("baseline.plist")
        guard let data = try? Data(contentsOf: url),
              let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return nil
        }
        return (root["CacheExtra"] as? [String: Any]) ?? [:]
    }

    private func writeBackup(_ data: Data) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let url = backupDir.appendingPathComponent("backup-\(f.string(from: Date())).plist")
        do {
            try data.write(to: url)
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            return true
        } catch {
            return false
        }
    }

    private func listBackups() -> [URL] {
        let names = (try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)) ?? []
        return names
            .filter { $0.lastPathComponent.hasPrefix("backup-") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
