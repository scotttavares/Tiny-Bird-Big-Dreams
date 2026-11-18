import XCTest
@testable import MoodMagnets

final class LevelSolutionTests: XCTestCase {
    private var levels: [LevelData] = []

    override func setUp() {
        super.setUp()
        levels = LevelCatalog.load()
    }

    func testCatalogLoads() {
        XCTAssertEqual(levels.count, 10)
        XCTAssertEqual(levels.map(\.id), Array(1...10))
        for level in levels {
            XCTAssertFalse(level.jellies.isEmpty, "\(level.name) has no jellies")
            XCTAssertFalse(level.nests.isEmpty, "\(level.name) has no nests")
            XCTAssertFalse(level.palette.isEmpty, "\(level.name) has no palette")
            for action in level.solution {
                XCTAssertTrue(level.palette.contains(action.mood), "\(level.name): solution uses a mood the palette doesn't offer")
            }
        }
    }

    /// Every level's stored solution must win, within par.
    func testEveryStoredSolutionWins() {
        for level in levels {
            let sim = Simulation.run(level, actions: level.solution)
            XCTAssertTrue(sim.won, "Level \(level.id) \(level.name): stored solution did not win (t=\(sim.t), failed=\(sim.failed))")
            XCTAssertLessThanOrEqual(sim.moves, level.par, "Level \(level.id): solution needs more moves than par")
            XCTAssertEqual(level.stars(forMoves: sim.moves), 3)
        }
    }

    /// Doing nothing must never win (otherwise the puzzle is free).
    func testIdlingNeverWins() {
        for level in levels {
            let sim = Simulation.run(level, actions: [])
            XCTAssertFalse(sim.won, "Level \(level.id) \(level.name) wins without any moves")
        }
    }

    /// Solutions still win when every jelly starts a point or two off, so levels aren't knife-edge.
    func testSolutionsAreRobustToSmallNudges() {
        for level in levels {
            for dx in [-2.0, 2.0] {
                var nudged = level
                nudged.jellies = level.jellies.map { jelly in
                    var copy = jelly
                    copy.pos = [jelly.pos[0] + dx, jelly.pos[1]]
                    return copy
                }
                XCTAssertTrue(Simulation.run(nudged, actions: level.solution).won, "Level \(level.id) fails when nudged by \(dx)")
            }
        }
    }

    func testDeterminism() {
        guard let level = levels.first(where: { $0.id == 9 }) else { return XCTFail("missing level 9") }
        let a = Simulation.run(level, actions: level.solution, maxTime: 3)
        let b = Simulation.run(level, actions: level.solution, maxTime: 3)
        XCTAssertEqual(a.t, b.t)
        for (x, y) in zip(a.jellies, b.jellies) {
            XCTAssertEqual(x.x, y.x)
            XCTAssertEqual(x.y, y.y)
            XCTAssertEqual(x.mood, y.mood)
        }
    }
}

final class MoodRuleTests: XCTestCase {
    private func level(jellies: [BodyData], pegs: [BodyData] = [], nests: [NestData]? = nil) -> LevelData {
        LevelData(
            id: 99, name: "Test", par: 1, palette: Mood.allCases, hint: "", size: [400, 720], gravity: nil,
            segments: [SegmentData(a: [0, 40], b: [400, 40], r: 8, bouncy: nil)],
            pegs: pegs, jellies: jellies,
            nests: nests ?? [NestData(rect: [0, 600, 10, 10], mood: .happy, count: 1)],
            solution: []
        )
    }

    private func jelly(_ id: String, _ x: Double, _ mood: Mood, swappable: Bool = false) -> BodyData {
        BodyData(id: id, pos: [x, 74], mood: mood, swappable: swappable, r: nil, rangeScale: nil)
    }

    private func advance(_ sim: Simulation, seconds: Double) {
        for _ in 0..<Int(seconds / Simulation.dt) { sim.step() }
    }

    func testHappyHugCheersUpNervous() {
        let sim = Simulation(level: level(jellies: [jelly("h", 150, .happy), jelly("n", 240, .nervous)]))
        advance(sim, seconds: 3)
        XCTAssertEqual(sim.body(id: "n")?.mood, .happy)
        XCTAssertTrue(sim.drainEvents().contains(.cheer("n")))
    }

    func testHappyDoesNotPullGrumpy() {
        let sim = Simulation(level: level(jellies: [jelly("h", 150, .happy), jelly("g", 230, .grumpy)]))
        advance(sim, seconds: 2)
        XCTAssertEqual(sim.body(id: "g")?.x ?? 0, 230, accuracy: 1)
    }

    func testGrumpyPushesNervousAway() {
        let sim = Simulation(level: level(jellies: [jelly("g", 150, .grumpy), jelly("n", 220, .nervous)]))
        advance(sim, seconds: 1)
        XCTAssertGreaterThan(sim.body(id: "n")?.x ?? 0, 260)
    }

    func testNervousBumpingGrumpyStoneJumps() {
        let stone = BodyData(id: "s", pos: [100, 48], mood: .grumpy, swappable: false, r: nil, rangeScale: nil)
        let sim = Simulation(level: level(jellies: [jelly("n", 134, .nervous)], pegs: [stone]))
        var peak = 0.0
        for _ in 0..<60 {
            sim.step()
            peak = max(peak, sim.body(id: "n")?.y ?? 0)
        }
        XCTAssertGreaterThan(peak, 150)
        XCTAssertTrue(sim.drainEvents().contains(.scare("n")))
    }

    func testMovesOnlyCountRealChanges() {
        let sim = Simulation(level: level(jellies: [jelly("a", 100, .nervous, swappable: true), jelly("b", 300, .nervous)]))
        XCTAssertFalse(sim.apply(target: "b", mood: .happy), "locked jellies can't change")
        XCTAssertFalse(sim.apply(target: "a", mood: .nervous), "same mood is free and ignored")
        XCTAssertTrue(sim.apply(target: "a", mood: .grumpy))
        XCTAssertEqual(sim.moves, 1)
    }

    func testFallingFails() {
        var data = level(jellies: [jelly("a", 200, .happy)])
        data.segments = []
        let sim = Simulation(level: data)
        advance(sim, seconds: 2)
        XCTAssertTrue(sim.failed)
    }

    func testNestNeedsSettledJellies() {
        let data = level(jellies: [jelly("a", 200, .happy)], nests: [NestData(rect: [150, 40, 100, 70], mood: .happy, count: 1)])
        let sim = Simulation(level: data)
        advance(sim, seconds: 1)
        XCTAssertTrue(sim.won)
    }

    func testStars() {
        let data = level(jellies: [jelly("a", 200, .happy)])
        XCTAssertEqual(data.stars(forMoves: 1), 3)
        XCTAssertEqual(data.stars(forMoves: 2), 2)
        XCTAssertEqual(data.stars(forMoves: 5), 1)
    }
}

final class PostureTests: XCTestCase {
    func testNoHingeUsesWindowWidth() {
        XCTAssertEqual(PostureMapper.posture(for: PostureInputs(containerSize: CGSize(width: 390, height: 844))), .closed)
        XCTAssertEqual(PostureMapper.posture(for: PostureInputs(containerSize: CGSize(width: 820, height: 1180))), .book)
    }

    func testActiveDivisionDecidesBookOrLaptop() {
        let vertical = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 140,
                                     activeDivision: CGRect(x: 330, y: 0, width: 20, height: 900),
                                     containerSize: CGSize(width: 680, height: 900))
        XCTAssertEqual(PostureMapper.posture(for: vertical), .book)
        let horizontal = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 120,
                                       activeDivision: CGRect(x: 0, y: 440, width: 680, height: 20),
                                       containerSize: CGSize(width: 680, height: 900))
        XCTAssertEqual(PostureMapper.posture(for: horizontal), .laptop)
        var tent = horizontal
        tent.hingeAngleDegrees = 80
        XCTAssertEqual(PostureMapper.posture(for: tent), .tent)
    }

    func testClosedHinge() {
        XCTAssertEqual(PostureMapper.posture(for: PostureInputs(hingeStatus: .closed, containerSize: CGSize(width: 900, height: 900))), .closed)
    }
}
