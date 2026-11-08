import Foundation

/// Where take recordings are kept (plan 010, decision 6): `Recordings/<script title>/Step 3 Take 2.mov`
/// in the app's Documents, which the Files app shows as On My iPhone › Earwig.
struct RecordingStore {
    /// The app's Documents; a take's `recordingPath` is relative to it.
    let documents: URL

    static var standard: RecordingStore { RecordingStore(documents: URL.documentsDirectory) }

    var root: URL { documents.appending(path: "Recordings", directoryHint: .isDirectory) }

    /// The file a take's recording is written to, its folder made if need be. A file already
    /// there is removed, since the writer will not write over one.
    func url(scriptTitle: String, step: Int, take: Int, video: Bool) throws -> URL {
        let folder = root.appending(path: Self.folderName(scriptTitle), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: Self.fileName(step: step, take: take, video: video))
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        return url
    }

    /// Named as the slate says it.
    static func fileName(step: Int, take: Int, video: Bool) -> String {
        "Step \(step) Take \(take).\(video ? "mov" : "m4a")"
    }

    /// The script's title as a folder name: no slashes or colons, never empty or hidden.
    static func folderName(_ title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
    }

    /// A recording's path relative to Documents, as a take keeps it.
    func relativePath(of url: URL) -> String? {
        let base = documents.standardizedFileURL.path(percentEncoded: false)
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard path.hasPrefix(base) else { return nil }
        return String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func url(forRelativePath path: String) -> URL {
        documents.appending(path: path)
    }
}
