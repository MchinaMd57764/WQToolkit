import Foundation
import Combine
import SwiftUI
import UIKit
import ImageIO
import AVFoundation
import Photos

// MARK: - 媒体分类

enum MediaKind {
    static let imageExts: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "avif",
    ]
    static let videoExts: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "3gp", "mpg", "mpeg",
    ]
    static let all = imageExts.union(videoExts)

    static func isVideo(_ ext: String) -> Bool { videoExts.contains(ext) }
}

nonisolated func wqAppTint(_ id: String) -> Color {
    let palette: [Color] = [Theme.blue, Theme.purple, Theme.cyan, Theme.green, Theme.orange, Theme.pink]
    var h: UInt64 = 5381
    for b in id.utf8 { h = (h &* 33) &+ UInt64(b) }
    return palette[Int(h % UInt64(palette.count))]
}

// MARK: - 索引模型

struct MediaItem: Identifiable, Hashable {
    let path: String
    let appName: String
    let bundleID: String
    let bytes: Int64
    let mtime: Date
    let isVideo: Bool

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var ext: String { (path as NSString).pathExtension.lowercased() }
}

struct RecentItem: Identifiable, Hashable {
    let path: String
    let appName: String
    let bundleID: String
    let bytes: Int64
    let mtime: Date

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var ext: String { (path as NSString).pathExtension.lowercased() }

    var icon: String {
        if MediaKind.imageExts.contains(ext) { return "photo.fill" }
        if MediaKind.videoExts.contains(ext) { return "film.fill" }
        switch ext {
        case "plist", "strings", "json", "xml": return "list.bullet.rectangle"
        case "db", "sqlite", "sqlite3", "db-wal", "db-shm": return "cylinder.split.1x2.fill"
        case "log", "txt", "md": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
}

struct AppUsage: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let path: String
    let bytes: Int64
    let cacheBytes: Int64
    let files: Int

    var id: String { path }
    var tint: Color { wqAppTint(bundleID) }
}

struct PrefFile: Identifiable, Hashable {
    let path: String
    let appName: String
    let bundleID: String
    let bytes: Int64
    let mtime: Date

    var id: String { path }
    var domain: String { ((path as NSString).lastPathComponent as NSString).deletingPathExtension }
}

// MARK: - 扫描引擎

final class LensStore: ObservableObject {
    static let shared = LensStore()

    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var media: [MediaItem] = []
    @Published private(set) var recent: [RecentItem] = []
    @Published private(set) var usage: [AppUsage] = []
    @Published private(set) var prefs: [PrefFile] = []
    @Published private(set) var scanning = false
    @Published private(set) var scanned = false
    @Published private(set) var progressDone = 0
    @Published private(set) var progressTotal = 0
    @Published private(set) var currentApp = ""
    @Published private(set) var lastScan: Date?
    @Published private(set) var failedAppCount = 0
    @Published private(set) var truncated = false

    private let cancelLock = NSLock()
    private var cancelFlag = false
    private let recentWindow: TimeInterval = 7 * 86400

    private init() {}

    var totalBytes: Int64 { usage.reduce(0) { $0 + $1.bytes } }
    var totalFiles: Int { usage.reduce(0) { $0 + $1.files } }
    var totalCacheBytes: Int64 { usage.reduce(0) { $0 + $1.cacheBytes } }

    func media(app: String?) -> [MediaItem] {
        guard let app else { return media }
        return media.filter { $0.bundleID == app }
    }

    func recent(app: String?, since: Date) -> [RecentItem] {
        recent.filter { ($0.mtime >= since) && (app == nil || $0.bundleID == app) }
    }

    func prefs(app: String?) -> [PrefFile] {
        guard let app else { return prefs }
        return prefs.filter { $0.bundleID == app }
    }

    func cancel() {
        cancelLock.lock()
        cancelFlag = true
        cancelLock.unlock()
    }

    private var isCancelled: Bool {
        cancelLock.lock()
        let v = cancelFlag
        cancelLock.unlock()
        return v
    }

    func scan(force: Bool = false) {
        if scanning { return }
        if scanned && !force { return }

        cancelLock.lock()
        cancelFlag = false
        cancelLock.unlock()

        scanning = true
        scanned = false
        progressDone = 0
        progressTotal = 0
        currentApp = ""
        failedAppCount = 0
        truncated = false
        media = []
        recent = []
        usage = []
        prefs = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let list = AppCatalog.load()
            self.runScan(list)
        }
    }

    private func runScan(_ list: [AppInfo]) {
        let total = list.count
        DispatchQueue.main.async {
            self.apps = list
            self.progressTotal = total
        }

        var mediaOut: [MediaItem] = []
        var recentOut: [RecentItem] = []
        var usageOut: [AppUsage] = []
        var prefOut: [PrefFile] = []
        var failed = 0
        var didTruncate = false
        let cutoff = Date().addingTimeInterval(-recentWindow)
        var logLines: [String] = ["# WQ lens scan \(Date())"]

        for (idx, app) in list.enumerated() {
            if isCancelled { break }

            DispatchQueue.main.async {
                self.progressDone = idx
                self.currentApp = app.name
            }

            let granted = Access.shared.grant(app.dataPath)
            var bytes: Int64 = 0
            var cacheBytes: Int64 = 0
            var files = 0
            let cachePrefix = app.dataPath + "/Library/Caches/"
            let tmpPrefix = app.dataPath + "/tmp/"
            let root = URL(fileURLWithPath: app.dataPath, isDirectory: true)
            var firstError: String?

            if let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants],
                errorHandler: { _, error in
                    if firstError == nil { firstError = error.localizedDescription }
                    return true
                }
            ) {
                while let url = walker.nextObject() as? URL {
                    if isCancelled { break }
                    let path = url.path
                    var st = stat()
                    guard lstat(path, &st) == 0 else { continue }
                    let kind = st.st_mode & S_IFMT
                    if kind == S_IFLNK || kind == S_IFDIR { continue }

                    let size = Int64(st.st_size)
                    let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                    bytes += size
                    files += 1
                    if path.hasPrefix(cachePrefix) || path.hasPrefix(tmpPrefix) {
                        cacheBytes += size
                    }

                    let ext = (path as NSString).pathExtension.lowercased()
                    if MediaKind.all.contains(ext) {
                        if mediaOut.count < 12000 {
                            mediaOut.append(MediaItem(path: path, appName: app.name, bundleID: app.bundleID,
                                                      bytes: size, mtime: mtime,
                                                      isVideo: MediaKind.isVideo(ext)))
                        } else {
                            didTruncate = true
                        }
                    }

                    if mtime >= cutoff {
                        if recentOut.count < 20000 {
                            recentOut.append(RecentItem(path: path, appName: app.name, bundleID: app.bundleID,
                                                        bytes: size, mtime: mtime))
                        } else {
                            didTruncate = true
                        }
                    }

                    if path.contains("/Library/Preferences/"), ext == "plist" {
                        if prefOut.count < 8000 {
                            prefOut.append(PrefFile(path: path, appName: app.name, bundleID: app.bundleID,
                                                    bytes: size, mtime: mtime))
                        } else {
                            didTruncate = true
                        }
                    }
                }
            } else {
                if firstError == nil { firstError = "ENUMERATOR NIL" }
            }
            if files == 0 {
                if !granted || firstError != nil { failed += 1 }
                if firstError == nil { firstError = "EMPTY" }
            }

            usageOut.append(AppUsage(bundleID: app.bundleID, name: app.name, path: app.dataPath,
                                     bytes: bytes, cacheBytes: cacheBytes, files: files))
            logLines.append("\(app.bundleID)|grant=\(granted ? 1 : 0)|bytes=\(bytes)|files=\(files)|cache=\(cacheBytes)|err=\(firstError ?? "-")")
        }

        let mediaSorted = mediaOut.sorted { $0.mtime > $1.mtime }
        let recentSorted = recentOut.sorted { $0.mtime > $1.mtime }
        let usageSorted = usageOut.sorted { $0.bytes > $1.bytes }
        let prefSorted = prefOut.sorted { $0.domain.localizedStandardCompare($1.domain) == .orderedAscending }
        let finalFailed = failed
        let finalTruncated = didTruncate
        logLines.append("# summary apps=\(list.count) failed=\(failed) truncated=\(didTruncate ? 1 : 0) media=\(mediaOut.count) recent=\(recentOut.count) prefs=\(prefOut.count)")
        #if DEBUG
        let logURL = URL(fileURLWithPath: WQPaths.documentsPath).appendingPathComponent("wq_lens_scan.log")
        try? logLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
        #endif

        DispatchQueue.main.async {
            self.media = mediaSorted
            self.recent = recentSorted
            self.usage = usageSorted
            self.prefs = prefSorted
            self.failedAppCount = finalFailed
            self.truncated = finalTruncated
            self.progressDone = list.count
            self.currentApp = ""
            self.scanned = true
            self.scanning = false
            self.lastScan = Date()
            #if DEBUG
            NSLog("WQLENS apps=%d files=%d bytes=%lld cache=%lld media=%d recent=%d prefs=%d failed=%d truncated=%d",
                  list.count, usageSorted.reduce(0) { $0 + $1.files }, usageSorted.reduce(0) { $0 + $1.bytes },
                  usageSorted.reduce(0) { $0 + $1.cacheBytes }, mediaSorted.count, recentSorted.count,
                  prefSorted.count, finalFailed, finalTruncated ? 1 : 0)
            if let top = usageSorted.first {
                NSLog("WQLENS top=%@ %lld cache=%lld files=%d", top.bundleID, top.bytes, top.cacheBytes, top.files)
            }
            #endif
        }
    }
}

// MARK: - 缩略图

final class WQThumbCache {
    static let shared = WQThumbCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
    }

    func load(_ item: MediaItem, px: CGFloat, done: @escaping (UIImage?) -> Void) {
        let key = "\(item.path)#\(Int(px))" as NSString
        if let img = cache.object(forKey: key) {
            done(img)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let img = item.isVideo ? Self.videoThumb(item.path, px: px) : Self.imageThumb(item.path, px: px)
            DispatchQueue.main.async {
                if let img { self.cache.setObject(img, forKey: key) }
                done(img)
            }
        }
    }

    private static func imageThumb(_ path: String, px: CGFloat) -> UIImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let src = CGImageSourceCreateWithURL(url, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(px),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func videoThumb(_ path: String, px: CGFloat) -> UIImage? {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: px, height: px)
        let time = CMTime(seconds: 0.3, preferredTimescale: 600)
        guard let cg = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 存相册

enum WQPhotoSaver {
    static func save(_ items: [MediaItem], completion: @escaping (Int, Int, String?) -> Void) {
        let batch = Array(items.prefix(200))
        guard !batch.isEmpty else {
            completion(0, 0, "empty")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(0, 0, "denied") }
                return
            }
            var ok = 0
            var bad = 0
            let countLock = NSLock()
            let group = DispatchGroup()
            for item in batch {
                guard FileManager.default.fileExists(atPath: item.path) else {
                    countLock.lock(); bad += 1; countLock.unlock()
                    continue
                }
                group.enter()
                PHPhotoLibrary.shared().performChanges {
                    let req = PHAssetCreationRequest.forAsset()
                    let opts = PHAssetResourceCreationOptions()
                    opts.originalFilename = (item.path as NSString).lastPathComponent
                    req.addResource(with: item.isVideo ? .video : .photo,
                                    fileURL: URL(fileURLWithPath: item.path),
                                    options: opts)
                } completionHandler: { success, error in
                    countLock.lock()
                    if success { ok += 1 } else { bad += 1 }
                    countLock.unlock()
                    if let error {
                        #if DEBUG
                        NSLog("WQPHOTO fail %@ %@", item.path, error.localizedDescription)
                        #endif
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                #if DEBUG
                NSLog("WQPHOTO saved=%d failed=%d", ok, bad)
                #endif
                completion(ok, bad, nil)
            }
        }
    }
}
