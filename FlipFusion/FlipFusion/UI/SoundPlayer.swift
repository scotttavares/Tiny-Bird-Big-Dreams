import AVFoundation

/// Plays the game's short sound effects (the WAV files in Resources/Sounds).
/// Sounds follow the phone's silent switch and play over any music already on.
@MainActor
final class SoundPlayer {
    enum Sound: String, CaseIterable {
        case slide, merge1, merge2, merge3, merge4, merge5, merge6
        case rotate, chain, tick, over, start, boom, bonus, powerup, fever, mode
        case combo, hurry
        /// The creatures out of the crates.
        case chomp, monkey, ufo, roar, stomp
        /// The shark's whole attack: the surge out of the water, the growl, the bites.
        case shark
        /// The daily chest: a rattle, the lid bursting open, coins pouring out.
        case chest
    }

    /// The background tunes. Each loops until another takes over.
    enum Track: String, CaseIterable {
        /// The timed game.
        case timed = "music"
        /// The endless game: slower and mellower.
        case endless = "music-endless"
        /// Double points and the last seconds of a timed game: fast.
        case rush = "music-rush"
        /// One tune for each theme. They play in every game mode.
        case neon = "music-neon"
        case sunset = "music-sunset"
        case ocean = "music-ocean"
        case bubblegum = "music-bubblegum"
        case lava = "music-lava"
        case frost = "music-frost"
        case gold = "music-gold"
        case party = "music-party"
        case galaxy = "music-galaxy"
        case rainforest = "music-rainforest"
        case jurassic = "music-jurassic"
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

        for track in Track.allCases {
            guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.volume = track == .rush ? 0.32 : 0.28
            player.prepareToPlay()
            tracks[track] = player
        }
        refreshMusic()
    }

    /// The settings key for the music switch in the menu. Music is on until turned off.
    nonisolated static let musicKey = "ff.musicOn"

    private var tracks: [Track: AVAudioPlayer] = [:]
    private var track = Track.timed

    /// Changes the tune. The one left behind keeps its place for next time; the
    /// rush always starts from its beginning.
    func setTrack(_ wanted: Track) {
        // A tune that failed to load falls back to the first one.
        let newTrack = tracks[wanted] == nil ? Track.timed : wanted
        guard newTrack != track else { return }
        tracks[track]?.pause()
        track = newTrack
        if newTrack == .rush {
            tracks[newTrack]?.currentTime = 0
        }
        refreshMusic()
    }

    /// Starts or stops the music to match the switch in the menu. Call it when the
    /// switch changes and when the app comes back to the screen.
    func refreshMusic() {
        guard let music = tracks[track] else { return }
        let wanted = UserDefaults.standard.object(forKey: Self.musicKey) as? Bool ?? true
        if wanted, !music.isPlaying {
            music.play()
        } else if !wanted, music.isPlaying {
            music.pause()
        }
    }

    /// Quietens the music while the app is away from the screen.
    func pauseMusic() {
        tracks[track]?.pause()
    }

    /// The settings key for the sound switch in the menu. Sound is on until turned off.
    nonisolated static let enabledKey = "ff.soundOn"

    func play(_ sound: Sound, volume: Float = 1) {
        guard UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true else { return }
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
