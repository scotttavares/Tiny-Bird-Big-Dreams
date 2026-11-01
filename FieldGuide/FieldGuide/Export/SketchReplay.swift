import AVFoundation
import PencilKit
import SwiftUI
import UIKit

/// One frame of a replay: how much ink is down, which items are stuck on, and which is landing.
struct ReplayFrame: Equatable, Sendable {
    var strokes: Int
    var shown: Set<UUID>
    var entering: UUID?
    /// How far through its entrance the entering item is, 0 to 1.
    var progress: Double = 0
}

/// How an item looks partway through its entrance.
struct ReplayEntrancePose: Equatable, Sendable {
    var scale: Double
    var spin: Double
    var opacity: Double
    /// How far the burst around a landing has spread, 0 to 1; nil before it lands and after it fades.
    var burst: Double?
}

/// A page rebuilt stroke by stroke, with stickers, photos, videos and tape slamming down between
/// the strokes. Strokes keep the order they were made and the time they were made, so items only
/// have to remember when they were added; anything erased or removed is simply gone from the replay.
@MainActor
enum SketchReplay {
    nonisolated static let maxSteps = 240
    static let framesPerSecond: Int32 = 30
    /// Frames the finished page stays up at the end of a video.
    static let holdFrames = 45

    /// How many strokes each step shows, ending at all of them.
    nonisolated static func steps(strokeCount: Int, maxSteps: Int = maxSteps) -> [Int] {
        guard strokeCount > 0 else { return [0] }
        let count = min(strokeCount, maxSteps)
        return (1...count).map { strokeCount * $0 / count }
    }

    /// Frames each item takes to land: a big moment on a sparse page, quicker on a crowded one.
    nonisolated static func entranceFrames(itemCount: Int) -> Int {
        max(10, min(24, 300 / max(itemCount, 1)))
    }

    /// Every frame of a replay, ending on the finished page. Items land between the strokes they
    /// were added between; ones with no date are spread evenly through the drawing.
    nonisolated static func timeline(strokeDates: [Date], items: [PageItem], maxSteps: Int = maxSteps) -> [ReplayFrame] {
        let strokeCount = strokeDates.count
        let undatedCount = items.filter { $0.addedAt == nil }.count
        var undatedSeen = 0
        let arrivals = items.map { item -> (item: PageItem, strokes: Int) in
            if let added = item.addedAt {
                return (item, strokeDates.firstIndex { $0 > added } ?? strokeCount)
            }
            defer { undatedSeen += 1 }
            return (item, strokeCount * undatedSeen / undatedCount)
        }
        .enumerated()
        .sorted { ($0.element.strokes, $0.offset) < ($1.element.strokes, $1.offset) }
        .map { $0.element }

        let entrance = entranceFrames(itemCount: items.count)
        var frames: [ReplayFrame] = []
        var shown: Set<UUID> = []
        var strokes = 0
        var pending = steps(strokeCount: strokeCount, maxSteps: maxSteps)[...]
        for arrival in arrivals {
            while let next = pending.first, next <= arrival.strokes {
                if next > strokes {
                    strokes = next
                    frames.append(ReplayFrame(strokes: strokes, shown: shown))
                }
                pending.removeFirst()
            }
            strokes = max(strokes, arrival.strokes)
            for step in 1...entrance {
                frames.append(ReplayFrame(strokes: strokes, shown: shown, entering: arrival.item.id,
                                          progress: Double(step) / Double(entrance)))
            }
            shown.insert(arrival.item.id)
        }
        for next in pending where next > strokes {
            strokes = next
            frames.append(ReplayFrame(strokes: strokes, shown: shown))
        }
        if frames.last?.entering != nil || frames.isEmpty {
            frames.append(ReplayFrame(strokes: strokes, shown: shown))
        }
        return frames
    }

    static func timeline(for page: ExportPage) -> [ReplayFrame] {
        timeline(strokeDates: page.drawing.strokes.map(\.path.creationDate), items: page.items)
    }

    /// Falls from huge while spinning, squashes as it hits, then bounces to rest.
    nonisolated static func entrancePose(progress: Double) -> ReplayEntrancePose {
        let landing = 0.55
        let progress = min(max(progress, 0), 1)
        if progress < landing {
            let fall = progress / landing
            return ReplayEntrancePose(scale: 3.2 - 2.34 * fall * fall, spin: 0.6 * (1 - fall * fall),
                                      opacity: min(1, fall * 5), burst: nil)
        }
        let settle = (progress - landing) / (1 - landing)
        return ReplayEntrancePose(scale: 1 - 0.14 * cos(settle * 3 * .pi) * (1 - settle),
                                  spin: 0.08 * sin(settle * 2 * .pi) * (1 - settle),
                                  opacity: 1, burst: settle < 0.7 ? settle / 0.7 : nil)
    }

    private static func drawEntrance(of item: PageItem, progress: Double, in context: CGContext) {
        let pose = entrancePose(progress: progress)
        var moved = item
        moved.width *= CGFloat(pose.scale)
        moved.rotation += pose.spin
        context.saveGState()
        context.setAlpha(CGFloat(pose.opacity))
        PageItemArt.draw([moved], in: context)
        context.restoreGState()

        guard let burst = pose.burst.map({ CGFloat($0) }) else { return }
        let size = PageItemArt.size(of: item)
        let radius: CGFloat = max(size.width, size.height) / 2 * (1.05 + 0.4 * burst)
        let length: CGFloat = 46 * (1 - burst)
        context.saveGState()
        context.setStrokeColor(UIColor(red: 0.77, green: 0.33, blue: 0.17, alpha: 1 - burst).cgColor)
        context.setLineWidth(9)
        context.setLineCap(.round)
        for ray in 0..<12 {
            let angle = Double(ray) / 12 * 2 * .pi
            let direction = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
            context.move(to: CGPoint(x: item.center.x + direction.dx * radius, y: item.center.y + direction.dy * radius))
            context.addLine(to: CGPoint(x: item.center.x + direction.dx * (radius + length),
                                        y: item.center.y + direction.dy * (radius + length)))
        }
        context.strokePath()
        context.restoreGState()
    }

    static func image(_ page: ExportPage, frame: ReplayFrame, width: CGFloat) -> UIImage {
        let entering = page.items.first { $0.id == frame.entering }
        return PageRenderer.sketchImage(
            drawing: PKDrawing(strokes: page.drawing.strokes.prefix(frame.strokes)), paperStyle: page.paperStyle,
            paperTint: page.paperTint, items: page.items.filter { frame.shown.contains($0.id) }, width: width, scale: 1,
            overlay: entering.map { item in { drawEntrance(of: item, progress: frame.progress, in: $0) } }
        )
    }

    /// Writes the replay as an MP4 and returns the temporary file.
    static func exportVideo(_ page: ExportPage, onProgress: (Double) -> Void) async throws -> URL {
        let width = 720
        let height = Int(CGFloat(width) * PageGeometry.size.height / PageGeometry.size.width) / 2 * 2
        let directory = FileManager.default.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(ExportService.sanitized(page.title)) replay.mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        let frames = timeline(for: page)
        var frameIndex: Int64 = 0
        for (index, replayFrame) in (frames + Array(repeating: frames[frames.count - 1], count: holdFrames)).enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let image = Self.image(page, frame: replayFrame, width: CGFloat(width))
            guard let pool = adaptor.pixelBufferPool, let buffer = pixelBuffer(from: image, pool: pool, width: width, height: height) else {
                throw CocoaError(.fileWriteUnknown)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: framesPerSecond))
            frameIndex += 1
            onProgress(Double(index + 1) / Double(frames.count + holdFrames))
            await Task.yield()
        }
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    private static func pixelBuffer(from image: UIImage, pool: CVPixelBufferPool, width: Int, height: Int) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created) == kCVReturnSuccess, let buffer = created,
              let source = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

/// Watches the page being drawn, and saves it as a video to share.
struct ReplayView: View {
    let page: ExportPage
    private let frames: [ReplayFrame]

    @Environment(\.dismiss) private var dismiss
    @State private var position = 0.0
    @State private var isPlaying = true
    @State private var frameImage: UIImage?
    @State private var exportProgress: Double?
    @State private var sharedFile: SharedFile?
    @State private var exportFailed = false

    private var stepIndex: Int { min(Int(position), frames.count - 1) }

    init(page: ExportPage) {
        self.page = page
        frames = SketchReplay.timeline(for: page)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Group {
                    if let frameImage {
                        Image(uiImage: frameImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 6))
                            .shadow(radius: 3)
                    } else {
                        Theme.paper
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Replay of the page")

                HStack(spacing: 12) {
                    Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                        if !isPlaying, stepIndex == frames.count - 1 { position = 0 }
                        isPlaying.toggle()
                    }
                    .labelStyle(.iconOnly)
                    Slider(value: $position, in: 0...Double(max(frames.count - 1, 1)))
                        .accessibilityLabel("Replay position")
                }

                if let exportProgress {
                    ProgressView("Saving Video…", value: exportProgress)
                } else {
                    Button("Share as Video", systemImage: "square.and.arrow.up") {
                        Task { await export() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(page.drawing.strokes.isEmpty && page.items.isEmpty)
                }
                if exportFailed {
                    Text("That video couldn't be saved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Theme.chrome)
            .navigationTitle("Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: stepIndex) {
            frameImage = SketchReplay.image(page, frame: frames[stepIndex], width: 720)
        }
        .task(id: isPlaying) {
            while isPlaying, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / Double(SketchReplay.framesPerSecond)))
                if stepIndex >= frames.count - 1 {
                    isPlaying = false
                } else {
                    position += 1
                }
            }
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(file: file)
                .presentationDetents([.medium, .large])
        }
    }

    private func export() async {
        isPlaying = false
        exportFailed = false
        exportProgress = 0
        defer { exportProgress = nil }
        do {
            let url = try await SketchReplay.exportVideo(page) { exportProgress = $0 }
            sharedFile = SharedFile(url: url)
        } catch {
            exportFailed = true
        }
    }
}
