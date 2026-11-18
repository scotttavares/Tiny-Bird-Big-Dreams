import Foundation

/// A level as stored in `levels.json`. The same file drives the game, the unit tests and
/// the Python design tools in `tools/`, so the format is deliberately plain.
struct LevelData: Codable, Identifiable, Equatable, Sendable {
    var id: Int
    var name: String
    var par: Int
    var palette: [Mood]
    var hint: String
    var size: [Double]
    var gravity: Double?
    var segments: [SegmentData]
    var pegs: [BodyData]
    var jellies: [BodyData]
    var nests: [NestData]
    var solution: [ActionData]

    var width: Double { size.count > 0 ? size[0] : 400 }
    var height: Double { size.count > 1 ? size[1] : 720 }

    /// Stars earned for finishing with `moves` mood changes.
    func stars(forMoves moves: Int) -> Int {
        if moves <= par { return 3 }
        if moves <= par + 1 { return 2 }
        return 1
    }
}

struct SegmentData: Codable, Equatable, Sendable {
    var a: [Double]
    var b: [Double]
    var r: Double?
    var bouncy: Bool?
}

struct BodyData: Codable, Equatable, Sendable {
    var id: String
    var pos: [Double]
    var mood: Mood
    var swappable: Bool?
    var r: Double?
    var rangeScale: Double?
}

struct NestData: Codable, Equatable, Sendable {
    /// x, y, width, height in world units (y up).
    var rect: [Double]
    /// `nil` accepts any mood.
    var mood: Mood?
    var count: Int?
}

struct ActionData: Codable, Equatable, Sendable {
    var t: Double
    var target: String
    var mood: Mood
}

struct LevelFile: Codable, Sendable {
    var version: Int
    var levels: [LevelData]
}

enum LevelCatalog {
    static func load(bundle: Bundle = .main) -> [LevelData] {
        guard let url = bundle.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LevelFile.self, from: data) else {
            return []
        }
        return file.levels.sorted { $0.id < $1.id }
    }
}
