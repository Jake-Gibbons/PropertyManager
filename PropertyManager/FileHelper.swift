import Foundation

enum FileHelper {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    static func copyToDocuments(from srcURL: URL, suggestedName: String? = nil) throws -> (fileName: String, relativePath: String) {
        let docs = documentsDirectory()
        let name = suggestedName ?? srcURL.lastPathComponent
        let destURL = docs.appendingPathComponent(name)
        var finalURL = destURL; var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let base = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            let newName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            finalURL = docs.appendingPathComponent(newName); counter += 1
        }
        if srcURL.startAccessingSecurityScopedResource() {
            defer { srcURL.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: srcURL, to: finalURL)
        } else {
            try FileManager.default.copyItem(at: srcURL, to: finalURL)
        }
        return (finalURL.lastPathComponent, finalURL.lastPathComponent)
    }
    static func urlFor(relativePath: String) -> URL { documentsDirectory().appendingPathComponent(relativePath) }
}
