#if DEBUG
import Foundation

// Spike: can container_query enumerate other apps' containers when the query is
// built with flags (1<<32) and part 0, the same shape as a reference binary?
enum McmEnumProbe {
    static func run() {
        guard ProcessInfo.processInfo.environment["WQ_DEBUG_MCMENUM"] == "1" else { return }
        var lines: [String] = ["RUN \(Date())"]
        let combos: [(UInt64, UInt64, UInt64, String)] = [
            (2, 0, 0x1_0000_0000, "c2-p0-f32"),
            (2, 0, 0, "c2-p0-f0"),
            (2, UInt64.max, 0x1_0000_0000, "c2-pnone-f32"),
            (7, 0, 0x1_0000_0000, "c7-p0-f32"),
            (4, 0, 0x1_0000_0000, "c4-p0-f32"),
        ]
        for (cls, part, flags, label) in combos {
            let out = NSMutableArray()
            var et: Int64 = 0
            var ep: Int64 = 0
            let n = wq_list_containers(cls, part, flags, out, 600, &et, &ep)
            lines.append("LIST \(label) n=\(n) type=\(et) posix=\(ep) got=\(out.count)")
            if let arr = out as? [[String: String]] {
                for e in arr.prefix(6) {
                    lines.append("  ITEM \(e["identifier"] ?? "")|\(e["path"] ?? "")")
                }
            }
        }
        let url = URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent("mcmenum.txt")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        NSLog("WQMCMENUM %@", lines.joined(separator: " ; "))
    }
}
#endif
