import Foundation

enum FileHelperError: Error {
    case documentsDirectoryNotFound
    case cannotAccessSecurityScopedResource
    case copyFailed(Error)
}

enum FileHelper {
    static func documentsDirectory() -> URL {
        // Safe fallback to temporary directory if Documents cannot be resolved on some test targets
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }

    /// Copy a security-scoped URL into the app Documents directory, returning the stored filename + relative path.
    static func copyToDocuments(from srcURL: URL, suggestedName: String? = nil) throws -> (fileName: String, relativePath: String) {
        let docs = documentsDirectory()
        let name = suggestedName ?? srcURL.lastPathComponent
        let destURL = docs.appendingPathComponent(name)
        var finalURL = destURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let base = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            let newName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            finalURL = docs.appendingPathComponent(newName)
            counter += 1
        }

        guard srcURL.startAccessingSecurityScopedResource() else {
            throw FileHelperError.cannotAccessSecurityScopedResource
        }
        defer { srcURL.stopAccessingSecurityScopedResource() }

        do {
            try FileManager.default.copyItem(at: srcURL, to: finalURL)
        } catch {
            throw FileHelperError.copyFailed(error)
        }

        let relativePath = finalURL.lastPathComponent
        return (fileName: relativePath, relativePath: relativePath)
    }

    /// Return a file URL for a stored relative path inside the app's documents directory, or nil if not found.
    static func urlFor(relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        let url = documentsDirectory().appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Convenience overload that accepts an optional String (matching existing call sites that might pass `doc.storedPath`).
    static func urlFor(_ relativePath: String?) -> URL? {
        guard let rel = relativePath, !rel.isEmpty else { return nil }
        return urlFor(relativePath: rel)
    }
}
