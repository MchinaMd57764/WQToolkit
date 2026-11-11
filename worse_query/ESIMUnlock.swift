import Foundation
import MachO
import Darwin

// CacheData slot layout for the GreenTea (mainland China) device flags.
// Standard MobileGestalt cache: 8 bytes of value + 1 validity byte per slot.
struct MGCacheLayout: Equatable {
    let uuid: String
    let slotCount: Int
    let greenTeaIndex: Int
    let notGreenTeaIndex: Int

    static let known = MGCacheLayout(uuid: "7F1DF278-18B7-4E5A-8425-09E8830DE9AF",
                                     slotCount: 720, greenTeaIndex: 383, notGreenTeaIndex: 506)

    var byteCount: Int { slotCount * 9 }
    var greenTeaOffset: Int { greenTeaIndex * 8 }
    var notGreenTeaOffset: Int { notGreenTeaIndex * 8 }
    func validityOffset(for index: Int) -> Int { slotCount * 8 + index }

    func flags(in data: Data) -> (greenTea: Bool, notGreenTea: Bool)? {
        guard data.count == byteCount,
              data[greenTeaOffset] <= 1,
              data[notGreenTeaOffset] <= 1,
              data[(greenTeaOffset + 1)..<(greenTeaOffset + 8)].allSatisfy({ $0 == 0 }),
              data[(notGreenTeaOffset + 1)..<(notGreenTeaOffset + 8)].allSatisfy({ $0 == 0 }),
              data[validityOffset(for: greenTeaIndex)] == 1,
              data[validityOffset(for: notGreenTeaIndex)] == 1 else { return nil }
        return (data[greenTeaOffset] == 1, data[notGreenTeaOffset] == 1)
    }

    func matches(uuid: String, data: Data, extra: [String: Any]) -> Bool {
        guard self.uuid.caseInsensitiveCompare(uuid) == .orderedSame,
              (1...16384).contains(slotCount),
              greenTeaIndex != notGreenTeaIndex,
              extra[MGKeys.greenTea] == nil,
              extra[MGKeys.notGreenTea] == nil,
              extra["green-tea"] == nil,
              extra["not-green-tea"] == nil,
              flags(in: data) != nil else { return false }
        return true
    }
}

enum MGCacheLayoutResolver {
    static func resolve(uuid: String, data: Data, extra: [String: Any]) -> MGCacheLayout? {
        for layout in [runtimeProfile(), MGCacheLayout.known].compactMap({ $0 }) {
            if layout.matches(uuid: uuid, data: data, extra: extra) { return layout }
        }
        return nil
    }

    private static let cachedRuntime: MGCacheLayout? = buildRuntimeProfile()

    private static func runtimeProfile() -> MGCacheLayout? { cachedRuntime }

    struct MGImageSections {
        let strings: Data
        let address: UInt64
        let constants: [Data]
    }

    static func loadImageSections() -> MGImageSections? {
        let path = "/usr/lib/libMobileGestalt.dylib"
        guard dlopen(path, RTLD_LAZY | RTLD_LOCAL) != nil else { return nil }
        for i in 0..<_dyld_image_count() {
            guard let cname = _dyld_get_image_name(i), String(cString: cname) == path,
                  let rawHeader = _dyld_get_image_header(i) else { continue }
            let header = UnsafeRawPointer(rawHeader).assumingMemoryBound(to: mach_header_64.self)
            guard header.pointee.magic == MH_MAGIC_64 else { continue }
            let slide = _dyld_get_image_vmaddr_slide(i)
            guard let strings = section(header, slide: slide, segment: "__TEXT", name: "__cstring") else {
                return nil
            }
            var constants: [Data] = []
            for segment in ["__AUTH_CONST", "__DATA_CONST", "__DATA"] {
                if let found = section(header, slide: slide, segment: segment, name: "__const") {
                    constants.append(found.data)
                }
            }
            guard !constants.isEmpty else { return nil }
            return MGImageSections(strings: strings.data, address: strings.address, constants: constants)
        }
        return nil
    }

    private static func buildRuntimeProfile() -> MGCacheLayout? {
        guard let image = loadImageSections() else { return nil }
        return scan(strings: image.strings, address: image.address, constants: image.constants)
    }

    // Read-only: ask MobileGestalt itself what value it currently answers.
    static func copyAnswer(_ key: String) -> Any? {
        guard let handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY),
              let symbol = dlsym(handle, "MGCopyAnswer") else { return nil }
        typealias CopyAnswer = @convention(c) (CFString) -> CFTypeRef?
        return unsafeBitCast(symbol, to: CopyAnswer.self)(key as CFString)
    }

    #if DEBUG
    struct MGSlotInfo {
        let key: String
        let index: Int
        let type: UInt32
    }

    // Read-only: find the signed cache slot and query type for arbitrary keys.
    static func debugSlots(for keys: Set<String>) -> [String: MGSlotInfo] {
        guard let image = loadImageSections(), !keys.isEmpty else { return [:] }
        let bytes = [UInt8](image.strings)
        var hashes: [UInt64: String] = [:]
        var start = 0
        for end in 0..<bytes.count where bytes[end] == 0 {
            let length = end - start
            if length == 22, bytes[start..<end].allSatisfy(isHashChar) {
                hashes[image.address &+ UInt64(start)] = String(decoding: bytes[start..<end], as: UTF8.self)
            }
            start = end + 1
        }
        guard !hashes.isEmpty else { return [:] }
        var out: [String: MGSlotInfo] = [:]
        for section in image.constants where section.count >= 64 {
            section.withUnsafeBytes { raw in
                for offset in stride(from: 0, through: section.count - 64, by: 8) {
                    let pointer = UInt64(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset, as: UInt64.self)) & 0x0000_FFFF_FFFF_FFFF
                    guard let key = hashes[pointer], keys.contains(key), out[key] == nil else { continue }
                    let index = Int(Int16(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset + 0x3A, as: Int16.self)))
                    let type = UInt32(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset + 0x3C, as: UInt32.self))
                    out[key] = MGSlotInfo(key: key, index: index, type: type)
                }
            }
        }
        return out
    }

    // Read-only: ask MobileGestalt itself what value it currently answers.
    static func debugAnswers(for keys: [String]) -> [String: Any] {
        var out: [String: Any] = [:]
        for key in keys {
            if let value = copyAnswer(key) {
                out[key] = value
            }
        }
        return out
    }
    #endif

    private static func section(_ header: UnsafePointer<mach_header_64>, slide: Int,
                                segment: String, name: String) -> (data: Data, address: UInt64)? {
        var command = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<header.pointee.ncmds {
            let load = command.load(as: load_command.self)
            guard load.cmdsize >= MemoryLayout<load_command>.size else { return nil }
            if load.cmd == LC_SEGMENT_64 {
                let segmentCommand = command.load(as: segment_command_64.self)
                if tupleName(segmentCommand.segname) == segment {
                    var sectionPointer = UnsafeRawPointer(command)
                        .advanced(by: MemoryLayout<segment_command_64>.size)
                    for _ in 0..<Int(segmentCommand.nsects) {
                        let sectionCommand = sectionPointer.load(as: section_64.self)
                        if tupleName(sectionCommand.sectname) == name {
                            guard sectionCommand.size > 0,
                                  sectionCommand.size <= 32 * 1024 * 1024 else { return nil }
                            let address = sectionCommand.addr &+ UInt64(bitPattern: Int64(slide))
                            guard let pointer = UnsafeRawPointer(bitPattern: UInt(address)) else {
                                return nil
                            }
                            return (Data(bytes: pointer, count: Int(sectionCommand.size)), address)
                        }
                        sectionPointer = sectionPointer.advanced(by: MemoryLayout<section_64>.size)
                    }
                }
            }
            command = command.advanced(by: Int(load.cmdsize))
        }
        return nil
    }

    private static func tupleName<T>(_ value: T) -> String {
        withUnsafeBytes(of: value) { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            let end = bytes.firstIndex(of: 0) ?? bytes.count
            return String(decoding: bytes[..<end], as: UTF8.self)
        }
    }

    private static func isHashChar(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
            || byte == 43 || byte == 47
    }

    private static func scan(strings: Data, address: UInt64, constants: [Data]) -> MGCacheLayout? {
        guard !strings.isEmpty, strings.count <= 32 * 1024 * 1024 else { return nil }
        let bytes = [UInt8](strings)
        var hashes: [UInt64: String] = [:]
        var uuids = Set<String>()
        var start = 0
        for end in 0..<bytes.count where bytes[end] == 0 {
            let length = end - start
            if length == 22, bytes[start..<end].allSatisfy(isHashChar) {
                hashes[address &+ UInt64(start)] = String(decoding: bytes[start..<end], as: UTF8.self)
            } else if length == 36,
                      let text = String(bytes: bytes[start..<end], encoding: .utf8),
                      let uuid = UUID(uuidString: text) {
                uuids.insert(uuid.uuidString)
            }
            start = end + 1
        }
        guard uuids.count == 1, let uuid = uuids.first else { return nil }

        var indices = Set<Int>()
        var green = Set<Int>()
        var notGreen = Set<Int>()
        var greenLocations = Set<String>()
        var notGreenLocations = Set<String>()

        for (sectionID, section) in constants.enumerated() where section.count >= 64 {
            let valid = section.withUnsafeBytes { raw -> Bool in
                for offset in stride(from: 0, through: section.count - 64, by: 8) {
                    let pointer = UInt64(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset, as: UInt64.self)) & 0x0000_FFFF_FFFF_FFFF
                    guard let key = hashes[pointer] else { continue }
                    let index = Int(Int16(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset + 0x3A, as: Int16.self)))
                    let type = UInt32(littleEndian: raw.loadUnaligned(
                        fromByteOffset: offset + 0x3C, as: UInt32.self))
                    if key == MGKeys.greenTea || key == MGKeys.notGreenTea {
                        guard type == 11, (0..<16384).contains(index) else { return false }
                        let location = "\(sectionID):\(offset % 64)"
                        if key == MGKeys.greenTea {
                            green.insert(index)
                            greenLocations.insert(location)
                        } else {
                            notGreen.insert(index)
                            notGreenLocations.insert(location)
                        }
                    }
                    guard (-1..<16384).contains(index), (1...11).contains(type) else { continue }
                    if index >= 0 { indices.insert(index) }
                }
                return true
            }
            if !valid { return nil }
        }

        guard let maximum = indices.max(), maximum >= 1,
              indices.count > (maximum + 1) / 2,
              green.count == 1, notGreen.count == 1,
              let greenIndex = green.first, let notGreenIndex = notGreen.first,
              greenIndex != notGreenIndex,
              greenLocations.count == 1,
              greenLocations == notGreenLocations else { return nil }

        return MGCacheLayout(uuid: uuid, slotCount: maximum + 1,
                             greenTeaIndex: greenIndex, notGreenTeaIndex: notGreenIndex)
    }
}
