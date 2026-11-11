#if DEBUG
import Foundation

// Spike probe: can an unprivileged app recover app-data container paths from
// files inside containers it can already read? Writes Documents/scanpaths.txt.
enum PathScanProbe {
    static func run() {
        guard ProcessInfo.processInfo.environment["WQ_DEBUG_SCANPATHS"] == "1" else { return }
        var lines: [String] = ["RUN \(Date())"]
        probeSelectors(&lines)
        scanContainers(&lines)
        write(lines)
    }

    private static func probeSelectors(_ lines: inout [String]) {
        let ids = Array(Set(AppCatalog.imported().map { $0.bundleID } + AppCatalog.curated)).sorted()
        var hits = 0
        for bid in ids.prefix(60) {
            guard let cls = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
                  let obj = cls.perform(NSSelectorFromString("applicationProxyForIdentifier:"), with: bid)?
                    .takeUnretainedValue() as? NSObject else { continue }
            for sel in ["dataContainerURL", "_dataContainerURL", "containerURL", "_containerURL",
                        "containerPath", "_containerPath", "bundleContainerURL", "_bundleContainerURL",
                        "groupContainerURLs", "_groupContainerURLs", "bundleURL", "_bundleURL"] {
                let s = NSSelectorFromString(sel)
                guard obj.responds(to: s) else { continue }
                let v = obj.perform(s)?.takeUnretainedValue()
                if let u = v as? URL, !u.path.isEmpty {
                    lines.append("SEL \(bid) \(sel)=\(u.path)")
                    if sel.lowercased().contains("container") { hits += 1 }
                } else if let d = v as? [String: URL], !d.isEmpty {
                    let list = d.map { "\($0.key):\($0.value.path)" }.sorted().joined(separator: "|")
                    lines.append("SEL \(bid) \(sel)=\(list)")
                    hits += 1
                }
            }
        }
        lines.append("SELHITS \(hits)")
    }

    private static let uuidRe = try! NSRegularExpression(
        pattern: "(?:/private)?/var/(?:mobile/)?Containers/Data/Application/([0-9A-Fa-f-]{36})|Data/Application/([0-9A-Fa-f-]{36})")
    private static let bidRe = try! NSRegularExpression(
        pattern: "\\b(?:com|net|org|cn|io)\\.[A-Za-z0-9_-]+(?:\\.[A-Za-z0-9_-]+)+")

    private static let roots = [
        WQPaths.appGroups,
        WQPaths.systemGroups,
        WQPaths.systemData,
        WQPaths.pluginKit,
        WQPaths.internalDaemon,
    ]

    private static let readableExts: Set<String> = [
        "plist", "json", "txt", "log", "xml", "db", "sqlite", "sqlite3",
        "strings", "conf", "cfg", "js", "html", "md", "csv", "yaml", "yml",
    ]

    private static func scanContainers(_ lines: inout [String]) {
        var mapping: [String: Set<String>] = [:]
        var files = 0
        var dirs = 0
        var grantFail = 0
        var readFail = 0
        var names: [String] = []
        for root in roots {
            guard let entries = wqReadEntries(root) else {
                lines.append("ROOT \(root) read=nil")
                continue
            }
            lines.append("ROOT \(root) n=\(entries.count)")
            if root == WQPaths.appGroups {
                names = entries.prefix(200).map { ($0.path as NSString).lastPathComponent }.sorted()
            }
            for e in entries where e.isDir {
                dirs += 1
                if !Access.shared.isGranted(e.path), !Access.shared.grant(e.path) {
                    grantFail += 1
                    if grantFail <= 8 { lines.append("GRANTFAIL \(e.path)") }
                    continue
                }
                if wqReadEntries(e.path) == nil {
                    readFail += 1
                    if readFail <= 8 { lines.append("READFAIL \(e.path)") }
                    continue
                }
                walk(e.path, depth: 0, mapping: &mapping, files: &files)
                if files > 4000 { break }
            }
        }
        lines.append("DIRS \(dirs) GRANTFAIL \(grantFail) READFAIL \(readFail)")
        lines.append("FILES \(files) ATTEMPTS \(attempts) READFAILFILES \(readFails) GRANTFILEFAIL \(grantFileFail)")
        for s in failSamples { lines.append(s) }
        lines.append("SKIP ext=\(skipExt) size=\(skipSize) depth=\(skipDepth) subdir=\(skipSubdir)")
        lines.append("SUBSTR DataApplicationHits \(substrHits)")
        lines.append("GROUPS \(names.count): \(names.prefix(12).joined(separator: " "))")
        lines.append("UUIDS \(mapping.count)")
        for (uuid, bids) in mapping.sorted(by: { $0.key < $1.key }).prefix(100) {
            let b = bids.sorted().prefix(6).joined(separator: ",")
            lines.append("HIT \(uuid) <- \(b.isEmpty ? "?" : b)")
        }
    }

    private static func walk(_ dir: String, depth: Int,
                             mapping: inout [String: Set<String>], files: inout Int) {
        guard depth <= 3, files <= 4000 else { return }
        if !Access.shared.isGranted(dir) { _ = Access.shared.grant(dir) }
        guard let entries = wqReadEntries(dir) else { return }
        for e in entries {
            if files > 4000 { return }
            if e.isDir {
                if e.isLink { skipSubdir += 1; continue }
                if depth < 3 { walk(e.path, depth: depth + 1, mapping: &mapping, files: &files) }
                else { skipDepth += 1 }
            } else if e.isLink {
                continue
            } else if e.size <= 0 || e.size > 4_000_000 {
                skipSize += 1
            } else if !e.ext.isEmpty, !readableExts.contains(e.ext) {
                skipExt += 1
            } else {
                let g = Access.shared.isGranted(e.path) ? true : Access.shared.grant(e.path)
                if !g { grantFileFail += 1 }
                scanFile(e.path, granted: g, &mapping, &files)
            }
        }
    }

    private static var attempts = 0
    private static var readFails = 0
    private static var skipExt = 0
    private static var skipSize = 0
    private static var skipDepth = 0
    private static var skipSubdir = 0
    private static var substrHits = 0
    private static var grantFileFail = 0
    private static var failSamples: [String] = []

    private static func scanFile(_ path: String, granted: Bool, _ mapping: inout [String: Set<String>], _ files: inout Int) {
        attempts += 1
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe),
              !data.isEmpty else {
            readFails += 1
            if failSamples.count < 10 { failSamples.append("FAILFILE g=\(granted ? 1 : 0) \(path)") }
            if readFails <= 6 { NSLog("WQSCANREADFAIL %@", path) }
            return
        }
        files += 1
        let text = String(decoding: data, as: UTF8.self)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if text.contains("Data/Application") { substrHits += 1 }
        let uuids = uuidRe.matches(in: text, range: full)
        guard !uuids.isEmpty else { return }
        let bids = bidRe.matches(in: text, range: full)
        for u in uuids.prefix(50) {
            let group = u.range(at: 1).location != NSNotFound ? 1 : 2
            guard let r = Range(u.range(at: group), in: text) else { continue }
            let uuid = String(text[r])
            let lo = max(0, u.range.location - 300)
            let hi = min(ns.length, u.range.location + u.range.length + 300)
            var near: Set<String> = []
            for b in bids where b.range.location >= lo && b.range.location + b.range.length <= hi {
                if let br = Range(b.range, in: text) { near.insert(String(text[br])) }
            }
            mapping[uuid, default: []].formUnion(near)
        }
    }

    private static func write(_ lines: [String]) {
        let url = URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent("scanpaths.txt")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        NSLog("WQSCANPATHS %@", lines.prefix(8).joined(separator: " ; "))
    }
}
#endif
