import AVFoundation
import UIKit

/// The soft thump of a notebook closing, generated so the app needs no sound file. It respects
/// the silent switch, like other small interface sounds.
@MainActor
enum BookSound {
    private static var player: AVAudioPlayer?

    static func playClose() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(data: closeSound())
        player?.volume = 0.5
        player?.play()
    }

    /// A low thud under a short brush of paper noise, as 16-bit mono WAV.
    nonisolated static func closeSound(sampleRate: Int = 44_100, duration: Double = 0.2) -> Data {
        let count = Int(Double(sampleRate) * duration)
        var samples = Data(capacity: count * 2)
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            let thud = sin(2 * .pi * 85 * time) * exp(-time * 26)
            let paper = Double.random(in: -1...1) * exp(-time * 70) * 0.28
            let value = Int16(max(-1, min(1, thud * 0.8 + paper)) * Double(Int16.max))
            withUnsafeBytes(of: value.littleEndian) { samples.append(contentsOf: $0) }
        }

        func bytes<T: FixedWidthInteger>(_ value: T) -> Data {
            withUnsafeBytes(of: value.littleEndian) { Data($0) }
        }
        var wav = Data("RIFF".utf8)
        wav += bytes(UInt32(36 + samples.count))
        wav += Data("WAVEfmt ".utf8)
        wav += bytes(UInt32(16))
        wav += bytes(UInt16(1))
        wav += bytes(UInt16(1))
        wav += bytes(UInt32(sampleRate))
        wav += bytes(UInt32(sampleRate * 2))
        wav += bytes(UInt16(2))
        wav += bytes(UInt16(16))
        wav += Data("data".utf8)
        wav += bytes(UInt32(samples.count))
        return wav + samples
    }
}
