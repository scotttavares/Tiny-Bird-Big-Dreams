import Foundation
import SwiftData

/// Keeps `ImageStore` and the `MediaFile` copies level, off the main thread, so photos, clips and
/// voice notes reach other devices. A file is only removed when the user deletes it (`AppModel`):
/// a copy can arrive here before the page that uses it, so an unused copy proves nothing.
@ModelActor
actor MediaSync {
    /// Past this, a file stays on the device that made it; iCloud won't carry much more at once.
    static let largestFile = 200_000_000

    /// Returns whether any file arrived from another device.
    func reconcile(imageStore: ImageStore) -> Bool {
        var known = FetchDescriptor<MediaFile>()
        known.propertiesToFetch = [\.path]
        let records = (try? modelContext.fetch(known)) ?? []
        let copied = Set(records.map(\.path))

        var arrived = false
        for record in records where !imageStore.exists(record.path) {
            guard let data = record.data, (try? imageStore.write(data, to: record.path)) != nil else { continue }
            arrived = true
        }

        let pages = (try? modelContext.fetch(FetchDescriptor<Page>())) ?? []
        for path in Set(pages.flatMap(\.mediaPaths)).subtracting(copied) {
            guard let size = imageStore.size(of: path), size <= Self.largestFile,
                  let data = try? Data(contentsOf: imageStore.url(for: path), options: .mappedIfSafe) else { continue }
            modelContext.insert(MediaFile(path: path, data: data))
            // One at a time, so a run of clips never sits in memory together.
            try? modelContext.save()
        }
        return arrived
    }
}
