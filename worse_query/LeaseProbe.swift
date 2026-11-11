#if DEBUG
import Foundation

// 对照参考实现的形状：class 2 + set_identifiers + flags 0x900000000 能否跨 App 拿容器。
enum LeaseProbe {
    private static var lines: [String] = []
    private static let outURL = URL(fileURLWithPath: WQPaths.documentsPath)
        .appendingPathComponent("lease.txt")

    static func run() {
        guard ProcessInfo.processInfo.environment["WQ_DEBUG_LEASE"] == "1" else { return }
        lines = ["RUN \(Date())"]
        flush()
        lsWorkspace()
        miLookup()
        matrix()
        enumeration()
        iconCacheDump()
        lines.append("DONE")
        flush()
        NSLog("WQLEASE %@", lines.suffix(6).joined(separator: " ; "))
    }

    private static func flush() {
        try? lines.joined(separator: "\n").write(to: outURL, atomically: true, encoding: .utf8)
    }

    private static func lsWorkspace() {
        guard let wcls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = wcls.perform(NSSelectorFromString("defaultWorkspace"))?
                .takeUnretainedValue() as? NSObject else {
            lines.append("WS unavailable")
            flush()
            return
        }
        for name in ["allInstalledApplications", "allApplications", "installedApplications"] {
            let s = NSSelectorFromString(name)
            guard ws.responds(to: s), let r = ws.perform(s)?.takeUnretainedValue() else {
                lines.append("WS \(name) missing")
                continue
            }
            let arr = r as? [Any] ?? []
            lines.append("WS \(name) n=\(arr.count)")
            for a in arr.prefix(3) {
                let o = a as AnyObject
                let bid = (o.value(forKey: "bundleIdentifier") as? String) ?? "?"
                let data = (o.value(forKey: "dataContainerURL") as? URL)?.path ?? "nil"
                lines.append("  \(bid) data=\(data)")
            }
        }
        flush()
    }

    private static func miLookup() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_NOW) else {
            lines.append("MI dlopen failed")
            flush()
            return
        }
        defer { dlclose(h) }
        guard let sym = dlsym(h, "MobileInstallationLookup") else {
            lines.append("MI symbol missing")
            flush()
            return
        }
        typealias LookupFn = @convention(c) (CFDictionary?, UnsafeMutablePointer<Unmanaged<CFString>?>?) -> Unmanaged<CFArray>?
        let fn = unsafeBitCast(sym, to: LookupFn.self)
        var err: Unmanaged<CFString>?
        guard let r = fn(nil, &err) else {
            let msg = err.map { "\($0.takeRetainedValue())" } ?? "nil"
            lines.append("MI lookup nil err=\(msg)")
            flush()
            return
        }
        let arr = (r.takeRetainedValue() as NSArray) as? [Any] ?? []
        lines.append("MI lookup n=\(arr.count)")
        for a in arr.prefix(4) {
            guard let d = a as? [String: Any] else { lines.append("  raw \(type(of: a))"); continue }
            let bid = d["CFBundleIdentifier"] as? String ?? "?"
            let data = (d["DataContainer"] as? String) ?? (d["Container"] as? String) ?? "nil"
            let kind = d["ApplicationType"] as? String ?? "?"
            lines.append("  \(bid) type=\(kind) data=\(data)")
        }
        flush()
    }

    private static let f900: UInt64 = 0x9_0000_0000
    private static let f800: UInt64 = 0x8_0000_0000
    private static let f100: UInt64 = 0x1_0000_0000
    private static let f8000: UInt64 = 0x80_0000_0000

    private static func matrix() {
        let own = Bundle.main.bundleIdentifier ?? "com.linyun9287.wqtmx"
        let targets: [(String, UInt64, String, Bool, UInt64, UInt64)] = [
            ("own-c2", 2, own, false, 0, f900),
            ("cvechain-c2-900", 2, "com.research.cvechaintest5", false, 0, f900),
            ("webprobe-c2-900", 2, "com.zhangfuhao.wqtoolkit", false, 0, f900),
            ("cvechain-c2-900-p3", 2, "com.research.cvechaintest5", false, 3, f900),
            ("cvechain-c2-100", 2, "com.research.cvechaintest5", false, 0, f100),
            ("cvechain-c2-8000", 2, "com.research.cvechaintest5", false, 0, f8000),
            ("prefs-c2-900", 2, "com.apple.Preferences", false, 0, f900),
            ("prefs-c2-900-p3", 2, "com.apple.Preferences", false, 3, f900),
            ("safari-c2-900", 2, "com.apple.mobilesafari", false, 0, f900),
            ("lsd-c7-900", 7, "systemgroup.com.apple.lsd", true, 0, f900),
            ("lsd-c7-900-p3", 7, "systemgroup.com.apple.lsd", true, 3, f900),
            ("lsdicons-c13-900", 13, "systemgroup.com.apple.lsd.iconscache", true, 0, f900),
            ("lsdicons-c13-8000", 13, "systemgroup.com.apple.lsd.iconscache", true, 0, f8000),
            ("lsd-c13-900", 13, "systemgroup.com.apple.lsd", true, 0, f900),
            ("mailgrp-c13-900", 13, "systemgroup.com.apple.mobilemail", true, 0, f900),
            ("cfgprof-c13-900", 13, "systemgroup.com.apple.configurationprofiles", true, 0, f900),
            ("spotlight-c13-900", 13, "systemgroup.com.apple.spotlight", true, 0, f900),
            ("webkit-c13-900", 13, "systemgroup.com.apple.webkit", true, 0, f900),
            ("pegasus-c13-900", 13, "systemgroup.com.apple.PegasusConfiguration", true, 0, f900),
            ("devmgmt-c13-900", 13, "systemgroup.com.apple.DeviceManagement", true, 0, f900),
            ("siri-c13-900", 13, "systemgroup.com.apple.siri", true, 0, f900),
            ("keyboard-c13-900", 13, "systemgroup.com.apple.keyboard", true, 0, f900),
            ("security-c13-900", 13, "systemgroup.com.apple.security", true, 0, f900),
            ("lsdicons-c13-900-p1", 13, "systemgroup.com.apple.lsd.iconscache", true, 1, f900),
            ("lsdicons-c13-900-p2", 13, "systemgroup.com.apple.lsd.iconscache", true, 2, f900),
            ("lsdicons-c13-900-p3", 13, "systemgroup.com.apple.lsd.iconscache", true, 3, f900),
            ("lsdicons-c13-900-p4", 13, "systemgroup.com.apple.lsd.iconscache", true, 4, f900),
            ("lsd-c12-900", 12, "com.apple.lsd", false, 0, f900),
            ("mail-c12-900", 12, "com.apple.mobilemail", false, 0, f900),
            ("lsd-c10-900", 10, "com.apple.lsd", false, 0, f900),
            ("lsd-c6-900", 6, "com.apple.lsd", false, 0, f900),
            ("lsd-c15-900", 15, "systemgroup.com.apple.lsd", true, 0, f900),
            ("lsdicons-c15-900", 15, "systemgroup.com.apple.lsd.iconscache", true, 0, f900),
        ]
        for (label, cls, ident, isGroup, part, flags) in targets {
            var handle: Int64 = 0
            var et: Int64 = 0
            var ep: Int64 = 0
            let path = wq_lease_probe(cls, ident, isGroup, part, flags, nil, &handle, &et, &ep)
            var detail = ""
            if let p = path {
                let n = (try? FileManager.default.contentsOfDirectory(atPath: p))?.count ?? -1
                let ro = open(p, O_RDONLY)
                let wo = open(p, O_WRONLY)
                let errnoW = errno
                if ro >= 0 { close(ro) }
                if wo >= 0 { close(wo) }
                detail = " dir=\(n) ro=\(ro >= 0 ? 1 : 0) wo=\(wo >= 0 ? 1 : 0)/\(wo >= 0 ? 0 : errnoW)"
                if let subs = try? FileManager.default.contentsOfDirectory(atPath: p) {
                    detail += " top=\(subs.prefix(6).joined(separator: ","))"
                    for sub in subs where ["Library", "Caches", "Preferences"].contains(sub) {
                        let sp = (p as NSString).appendingPathComponent(sub)
                        if let deeper = try? FileManager.default.contentsOfDirectory(atPath: sp) {
                            detail += " \(sub)=\(deeper.prefix(6).joined(separator: ","))"
                        }
                    }
                }
            }
            lines.append("T \(label) cls=\(cls) id=\(ident) part=\(part) f=0x\(String(flags, radix: 16)) path=\(path ?? "nil") h=\(handle) et=\(et) ep=\(ep)\(detail)")
            flush()
        }
    }

    private static func describe(_ p: String, depth: Int) {
        let fm = FileManager.default
        let base = (p as NSString).lastPathComponent
        guard let items = try? fm.contentsOfDirectory(atPath: p) else {
            lines.append("D \(p) LIST-FAIL errno=\(errno)")
            flush()
            return
        }
        lines.append("D \(p) n=\(items.count) [\(items.prefix(12).joined(separator: ","))]")
        flush()
        for item in items.prefix(6) {
            let full = (p as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                if depth > 0 { describe(full, depth: depth - 1) }
            } else {
                let attrs = try? fm.attributesOfItem(atPath: full)
                let size = (attrs?[.size] as? NSNumber)?.intValue ?? -1
                let fd = open(full, O_RDONLY)
                var head = "open-fail errno=\(errno)"
                if fd >= 0 {
                    var buf = [UInt8](repeating: 0, count: 16)
                    let n = read(fd, &buf, 16)
                    close(fd)
                    head = n > 0 ? "head=\(Data(buf.prefix(n)).map { String(format: "%02x", $0) }.joined())" : "read=\(n)"
                }
                lines.append("F \(item) size=\(size) \(head)")
                flush()
            }
        }
        _ = base
    }

    private static func iconCacheDump() {
        let p = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.lsd.iconscache"
        describe(p, depth: 2)
        describe(p + "/Library/Caches", depth: 2)
        describe(p + "/Library/Preferences", depth: 0)
    }

    private static func enumeration() {
        let cases: [(String, UInt64, UInt64, UInt64)] = [
            ("c2-100-p0", 2, 0, f100),
            ("c2-900-p0", 2, 0, f900),
            ("c7-900-p0", 7, 0, f900),
            ("c13-900-p0", 13, 0, f900),
            ("c15-900-p0", 15, 0, f900),
        ]
        for (label, cls, part, flags) in cases {
            let out = NSMutableArray()
            var et: Int64 = 0
            var ep: Int64 = 0
            var iterOK: Int64 = -1
            let n = wq_iterate_containers(cls, part, flags, out, 5, &et, &ep, &iterOK)
            let rows = (out as? [[String: String]]) ?? []
            let ids = rows.map { r in
                let ident = r["identifier"] ?? ""
                let path = r["path"] ?? ""
                return "\(ident.isEmpty ? "?" : ident)@\(path.isEmpty ? "-" : path)"
            }.joined(separator: " | ")
            lines.append("E \(label) cls=\(cls) n=\(n) iter=\(iterOK) et=\(et) ep=\(ep) \(ids)")
            flush()
        }
    }
}
#endif
