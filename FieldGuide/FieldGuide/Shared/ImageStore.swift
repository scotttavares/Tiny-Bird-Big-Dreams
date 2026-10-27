import Foundation
import UIKit

/// Reference images on disk, inside the app container. SwiftData only stores the relative path.
struct ImageStore: Sendable {
    let root: URL

    static let directoryName = "References"

    /// `Application Support/FieldGuide`, created on demand.
    static var standard: ImageStore {
        let base = URL.applicationSupportDirectory.appending(path: "FieldGuide", directoryHint: .isDirectory)
        return ImageStore(root: base)
    }

    /// Writes `image` as JPEG and returns its path relative to `root`.
    func save(_ image: UIImage, quality: CGFloat = 0.85) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try save(jpegData: data)
    }

    func save(jpegData: Data) throws -> String {
        let directory = root.appending(path: Self.directoryName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let relativePath = "\(Self.directoryName)/\(UUID().uuidString).jpg"
        try jpegData.write(to: root.appending(path: relativePath), options: [.atomic, .completeFileProtection])
        return relativePath
    }

    func url(for relativePath: String) -> URL {
        root.appending(path: relativePath)
    }

    func image(at relativePath: String?) -> UIImage? {
        guard let relativePath else { return nil }
        return UIImage(contentsOfFile: url(for: relativePath).path(percentEncoded: false))
    }

    func delete(_ relativePath: String?) {
        guard let relativePath else { return }
        try? FileManager.default.removeItem(at: url(for: relativePath))
    }
}
