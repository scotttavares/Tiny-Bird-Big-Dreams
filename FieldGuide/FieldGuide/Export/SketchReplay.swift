import AVFoundation
import PencilKit
import SwiftUI
import UIKit

/// A page redrawn stroke by stroke. Strokes keep the order they were made, so nothing extra has
/// to be recorded; a stroke that was erased is simply gone from the replay too.
@MainActor
enum SketchReplay {
    static let maxSteps = 240
    static let framesPerSecond: Int32 = 30
    /// Frames the finished page stays up at the end of a video.
    static let holdFrames = 45

    /// How many strokes each step shows, ending at all of them.
    nonisolated static func steps(strokeCount: Int, maxSteps: Int = maxSteps) -> [Int] {
        guard strokeCount > 0 else { return [0] }
        let count = min(strokeCount, maxSteps)
        return (1...count).map { strokeCount * $0 / count }
    }

    static func frame(_ page: ExportPage, strokes count: Int, width: CGFloat) -> UIImage {
        PageRenderer.sketchImage(drawing: PKDrawing(strokes: page.drawing.strokes.prefix(count)), paperStyle: page.paperStyle,
                                 paperTint: page.paperTint, items: page.items, width: width, scale: 1)
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

        let steps = steps(strokeCount: page.drawing.strokes.count)
        var frameIndex: Int64 = 0
        for (index, strokes) in (steps + Array(repeating: steps.last ?? 0, count: holdFrames)).enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let image = frame(page, strokes: strokes, width: CGFloat(width))
            guard let pool = adaptor.pixelBufferPool, let buffer = pixelBuffer(from: image, pool: pool, width: width, height: height) else {
                throw CocoaError(.fileWriteUnknown)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: framesPerSecond))
            frameIndex += 1
            onProgress(Double(index + 1) / Double(steps.count + holdFrames))
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

    @Environment(\.dismiss) private var dismiss
    @State private var position = 0.0
    @State private var isPlaying = true
    @State private var frameImage: UIImage?
    @State private var exportProgress: Double?
    @State private var sharedFile: SharedFile?
    @State private var exportFailed = false

    private var steps: [Int] { SketchReplay.steps(strokeCount: page.drawing.strokes.count) }
    private var stepIndex: Int { min(Int(position), steps.count - 1) }

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
                        if !isPlaying, stepIndex == steps.count - 1 { position = 0 }
                        isPlaying.toggle()
                    }
                    .labelStyle(.iconOnly)
                    Slider(value: $position, in: 0...Double(max(steps.count - 1, 1)))
                        .accessibilityLabel("Replay position")
                }

                if let exportProgress {
                    ProgressView("Saving Video…", value: exportProgress)
                } else {
                    Button("Share as Video", systemImage: "square.and.arrow.up") {
                        Task { await export() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(page.drawing.strokes.isEmpty)
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
            frameImage = SketchReplay.frame(page, strokes: steps[stepIndex], width: 720)
        }
        .task(id: isPlaying) {
            while isPlaying, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / Double(SketchReplay.framesPerSecond)))
                if stepIndex >= steps.count - 1 {
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
