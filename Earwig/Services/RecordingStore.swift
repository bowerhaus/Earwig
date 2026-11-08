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

    // MARK: - Keeping

    /// The last recording made with Keep Recordings off: the one the next such recording replaces.
    static let lastUnkeptKey = "lastUnkeptRecording"

    /// A recording has started at `path`. With Keep off, the last recording made with Keep off
    /// is deleted and this one takes its place; with Keep on, it is kept and nothing is deleted.
    /// Returns the path deleted, if any.
    @discardableResult
    func started(_ path: String, keep: Bool, defaults: UserDefaults) -> String? {
        guard !keep else { return nil }
        let previous = defaults.string(forKey: Self.lastUnkeptKey)
        defaults.set(path, forKey: Self.lastUnkeptKey)
        guard let previous, previous != path else { return nil }
        delete(previous)
        return previous
    }

    /// A recording at `path` came to nothing: its file, if any, goes, and it is not the last.
    func discard(_ path: String, defaults: UserDefaults) {
        delete(path)
        if defaults.string(forKey: Self.lastUnkeptKey) == path { defaults.removeObject(forKey: Self.lastUnkeptKey) }
    }

    func delete(_ path: String) {
        let url = url(forRelativePath: path)
        if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
    }

    /// Every recording, with their folders.
    func deleteAll(defaults: UserDefaults) throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        defaults.removeObject(forKey: Self.lastUnkeptKey)
    }

    /// Bytes the recordings take up.
    func size() -> Int64 {
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    // MARK: - Room

    /// Below this a video take records sound only (decision 6).
    static let minimumFreeForVideo: Int64 = 1_000_000_000

    /// Bytes free for a recording, as iOS counts room for important use; `nil` if unknown.
    func freeSpace() -> Int64? {
        (try? documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
    }
}
