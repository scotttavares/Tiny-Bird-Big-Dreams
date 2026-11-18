import AVFoundation

/// Plays the game's short sound effects (the WAV files in Resources/Sounds).
/// Sounds follow the phone's silent switch and play over any music already on.
@MainActor
final class SoundPlayer {
    enum Sound: String, CaseIterable {
        case slide, merge1, merge2, merge3, merge4, merge5, merge6
        case rotate, chain, tick, over, start, boom, bonus, powerup, fever, mode
    }

    /// A few copies of each sound, so the same one can overlap itself.
    private var voices: [Sound: [AVAudioPlayer]] = [:]
    private var nextVoice: [Sound: Int] = [:]

    init() {
        // The unit tests launch the app in a simulator with no audio hardware, where
        // setting up audio can stall for minutes. Tests need no sound.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)

        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            var players: [AVAudioPlayer] = []
            for _ in 0..<3 {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    players.append(player)
                }
            }
            voices[sound] = players
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard let players = voices[sound], !players.isEmpty else { return }
        let index = (nextVoice[sound] ?? 0) % players.count
        nextVoice[sound] = index + 1
        let player = players[index]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Bigger tiles ring higher: 4 is the lowest note, 128 and up the highest.
    static func merge(for value: Int) -> Sound {
        switch value {
        case ..<8: return .merge1
        case 8: return .merge2
        case 16: return .merge3
        case 32: return .merge4
        case 64: return .merge5
        default: return .merge6
        }
    }
}
