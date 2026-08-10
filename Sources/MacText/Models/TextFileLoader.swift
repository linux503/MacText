import Foundation

enum FileOpenError: LocalizedError {
    case isDirectory
    case tooLarge(bytes: Int)
    case binary
    case unreadable

    var errorDescription: String? {
        switch self {
        case .isDirectory:
            return "That item is a folder, not a text file."
        case .tooLarge(let bytes):
            let mb = Double(bytes) / 1_048_576
            return String(format: "File is too large to open (%.1f MB). MacText supports up to 40 MB.", mb)
        case .binary:
            return "This looks like a binary file and cannot be opened as text."
        case .unreadable:
            return "Could not read the file with a supported text encoding."
        }
    }
}

enum TextFileLoader {
    /// Soft cap: skip syntax highlight above this.
    static let highlightLimitBytes = 1_500_000
    /// Hard cap: refuse to open.
    static let openLimitBytes = 40_000_000

    struct LoadedFile {
        var content: String
        var byteCount: Int
        var shouldHighlight: Bool
    }

    static func load(url: URL) throws -> LoadedFile {
        let standardized = url.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDir) else {
            throw FileOpenError.unreadable
        }
        if isDir.boolValue {
            throw FileOpenError.isDirectory
        }

        let values = try standardized.resourceValues(forKeys: [.fileSizeKey])
        let size = values.fileSize ?? 0
        if size > openLimitBytes {
            throw FileOpenError.tooLarge(bytes: size)
        }

        let data = try Data(contentsOf: standardized, options: [.mappedIfSafe])
        if looksBinary(data) {
            throw FileOpenError.binary
        }

        guard let content = decodeText(data) else {
            throw FileOpenError.unreadable
        }

        return LoadedFile(
            content: content,
            byteCount: data.count,
            shouldHighlight: data.count <= highlightLimitBytes
        )
    }

    /// Null bytes or a high ratio of control bytes ⇒ treat as binary.
    private static func looksBinary(_ data: Data) -> Bool {
        if data.isEmpty { return false }
        let sampleCount = min(data.count, 8192)
        var control = 0
        var nul = 0
        for byte in data.prefix(sampleCount) {
            if byte == 0 { nul += 1 }
            if byte < 0x09 || (byte > 0x0D && byte < 0x20 && byte != 0x1B) {
                control += 1
            }
        }
        if nul > 0 { return true }
        return Double(control) / Double(sampleCount) > 0.30
    }

    private static func decodeText(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
        if let s = String(data: data, encoding: .utf16BigEndian) { return s }

        let cfEncodings: [CFStringEncodings] = [
            .GB_18030_2000,
            .GBK_95,
            .macChineseSimp,
            .EUC_CN,
            .big5,
            .shiftJIS,
            .EUC_KR
        ]
        for cf in cfEncodings {
            let encoding = CFStringEncoding(UInt32(cf.rawValue))
            let ns = CFStringConvertEncodingToNSStringEncoding(encoding)
            let enc = String.Encoding(rawValue: ns)
            if let s = String(data: data, encoding: enc) {
                return s
            }
        }
        return String(data: data, encoding: .isoLatin1)
    }
}
