import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A script's text for Share, the way back to the Mac (plan 015, decision 6): a `.md` file named
/// after the title, for AirDrop, Files and Mail, and the plain text, for Copy. What is shared is
/// the stored text exactly as written, so a Cutaway script goes back as Cutaway.
struct ScriptText: Transferable {
    let title: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .markdownText) { script in
            SentTransferredFile(try script.file())
        }
        ProxyRepresentation(exporting: \.text)
    }

    /// The file's name: the title with characters a file name can't have removed.
    var fileName: String {
        let name = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name.isEmpty ? "Script" : name) + ".md"
    }

    /// The text written to a file of its own in the temporary folder.
    private func file() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Share-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName)
        try Data((text + "\n").utf8).write(to: url)
        return url
    }
}

extension UTType {
    /// Markdown, `.md`, as the system knows it, or plain text if it doesn't.
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
