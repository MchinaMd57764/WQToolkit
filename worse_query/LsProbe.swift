#if DEBUG
import Foundation

enum LsProbe {
    static func run() {
        var out: [String] = []
        guard let wcls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = wcls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            out.append("WS unavailable")
            write(out)
            return
        }
        for name in ["allApplications", "allInstalledApplications", "applicationIdentifiers",
                     "installedApplications", "applications"] {
            let s = NSSelectorFromString(name)
            guard ws.responds(to: s) else { out.append("WS \(name) missing"); continue }
            guard let r = ws.perform(s)?.takeUnretainedValue() else { out.append("WS \(name) nil"); continue }
            let arr = r as? [Any]
            out.append("WS \(name) type=\(type(of: r)) n=\(arr?.count ?? -1)")
            if let arr, !arr.isEmpty {
                for a in arr.prefix(3) {
                    let o = a as AnyObject
                    let bid = (o.value(forKey: "bundleIdentifier") as? String) ?? "?"
                    let url = (o.value(forKey: "dataContainerURL") as? URL)?.path ?? "nil"
                    out.append("  sample \(bid) data=\(url)")
                }
            }
        }

        let ids = AppCatalog.imported().map { $0.bundleID }
        var ok = 0, nilCount = 0
        var samples: [String] = []
        for bid in ids {
            let obj = (NSClassFromString("LSApplicationProxy") as? NSObject.Type)?
                .perform(NSSelectorFromString("applicationProxyForIdentifier:"), with: bid)?
                .takeUnretainedValue() as? NSObject
            let url = obj?.value(forKey: "dataContainerURL") as? URL
            if let p = url?.path, !p.isEmpty {
                ok += 1
                if samples.count < 5 { samples.append("OK \(bid)=\(p)") }
            } else {
                nilCount += 1
                if samples.count < 10 { samples.append("NIL \(bid)") }
            }
        }
        out.append("proxy resolve ok=\(ok) nil=\(nilCount) of \(ids.count)")
        out.append(contentsOf: samples)

        out.append("== LS classes ==")
        out.append(wq_ls_methods() ?? "nil")
        out.append("== LS enumerate ==")
        out.append(wq_ls_enumerate() ?? "nil")
        out.append("== LS records ==")
        out.append(wq_ls_records() ?? "nil")
        out.append("== XPC lookup ==")
        for svc in ["com.apple.launchservicesd", "com.apple.lsd", "com.apple.lsd.mapdb",
                    "com.apple.mobile.installd", "com.apple.mobile.installation_proxy",
                    "com.apple.mobile.container_manager", "com.apple.frontboard.systemappservices"] {
            out.append("\(svc): \(wq_xpc_lookup(svc) ?? "nil")")
        }
        out.append("== XPC ping ==")
        for svc in ["com.apple.lsd.mapdb", "com.apple.mobile.installd", "com.apple.frontboard.systemappservices"] {
            out.append("\(svc): \(wq_xpc_ping(svc) ?? "nil")")
        }
        write(out)
    }

    private static func write(_ lines: [String]) {
        let p = WQPaths.documentsPath + "/ls_probe.txt"
        try? lines.joined(separator: "\n").write(toFile: p, atomically: true, encoding: .utf8)
    }
}
#endif
