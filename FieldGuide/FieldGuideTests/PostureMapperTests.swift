import CoreGraphics
import Foundation
import Testing
@testable import FieldGuide

@Suite("PostureMapper")
struct PostureMapperTests {
    private let innerDisplay = CGSize(width: 1000, height: 820)
    private let outerDisplay = CGSize(width: 390, height: 844)
    private let verticalFold = CGRect(x: 494, y: 0, width: 12, height: 820)
    private let horizontalFold = CGRect(x: 0, y: 404, width: 1000, height: 12)

    @Test func activeVerticalFoldIsBook() {
        let inputs = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 120,
                                   activeDivision: verticalFold, anyDivision: verticalFold,
                                   containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .book)
    }

    @Test func activeHorizontalFoldIsLaptop() {
        let inputs = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 115,
                                   activeDivision: horizontalFold, anyDivision: horizontalFold,
                                   containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .laptop)
    }

    @Test func steepHorizontalFoldIsTent() {
        let inputs = PostureInputs(hingeStatus: .partiallyOpen, hingeAngleDegrees: 85,
                                   activeDivision: horizontalFold, anyDivision: horizontalFold,
                                   containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .tent)
    }

    @Test func horizontalFoldWithoutAngleIsLaptop() {
        let inputs = PostureInputs(activeDivision: horizontalFold, containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .laptop)
    }

    @Test func closedHingeIsClosed() {
        let inputs = PostureInputs(hingeStatus: .closed, hingeAngleDegrees: 0, containerSize: outerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .closed)
    }

    @Test func flatOpenWithInactiveVerticalFoldIsBook() {
        let inputs = PostureInputs(hingeStatus: .fullyOpen, hingeAngleDegrees: 180,
                                   anyDivision: verticalFold, containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .book)
    }

    @Test func flatOpenRotatedIsLaptop() {
        let inputs = PostureInputs(hingeStatus: .fullyOpen, hingeAngleDegrees: 180,
                                   anyDivision: horizontalFold, containerSize: innerDisplay)
        #expect(PostureMapper.posture(for: inputs) == .laptop)
    }

    @Test func openButNarrowWindowIsSinglePage() {
        let inputs = PostureInputs(hingeStatus: .fullyOpen, hingeAngleDegrees: 180, containerSize: CGSize(width: 480, height: 820))
        #expect(PostureMapper.posture(for: inputs) == .closed)
    }

    @Test(arguments: [
        (CGSize(width: 390, height: 844), Posture.closed),
        (CGSize(width: 1024, height: 1366), Posture.book),
        (CGSize(width: 599, height: 900), Posture.closed),
        (CGSize(width: 600, height: 900), Posture.book),
    ])
    func noHingeFallsBackToWidth(size: CGSize, expected: Posture) {
        #expect(PostureMapper.posture(for: PostureInputs(containerSize: size)) == expected)
    }

    @Test func bookHingeRectUsesFoldAndMinimumThickness() {
        let inputs = PostureInputs(activeDivision: verticalFold, anyDivision: verticalFold, containerSize: innerDisplay)
        let rect = PostureMapper.hingeRect(for: .book, inputs: inputs)
        #expect(rect.midX == verticalFold.midX)
        #expect(rect.width == 24)
        #expect(rect.height == innerDisplay.height)
    }

    @Test func bookHingeRectWithoutFoldIsCentered() {
        let inputs = PostureInputs(containerSize: CGSize(width: 1000, height: 800))
        let rect = PostureMapper.hingeRect(for: .book, inputs: inputs)
        #expect(rect == CGRect(x: 488, y: 0, width: 24, height: 800))
    }

    @Test func laptopHingeRectIsHorizontal() {
        let inputs = PostureInputs(activeDivision: horizontalFold, containerSize: innerDisplay)
        let rect = PostureMapper.hingeRect(for: .laptop, inputs: inputs)
        #expect(rect.midY == horizontalFold.midY)
        #expect(rect.width == innerDisplay.width)
        #expect(rect.height == 24)
    }

    @Test func singlePagePosturesHaveNoHinge() {
        let inputs = PostureInputs(containerSize: outerDisplay)
        #expect(PostureMapper.hingeRect(for: .closed, inputs: inputs).isNull)
        #expect(PostureMapper.hingeRect(for: .tent, inputs: inputs).isNull)
    }
}

@MainActor
@Suite("SystemPostureProvider")
struct SystemPostureProviderTests {
    private func makeDefaults() -> UserDefaults {
        let name = "FieldGuideTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func ingestUpdatesPostureAndHinge() {
        let provider = SystemPostureProvider(defaults: makeDefaults())
        provider.ingest(PostureInputs(containerSize: CGSize(width: 390, height: 844)))
        #expect(provider.posture == .closed)
        #expect(provider.hingeRect.isNull)

        provider.ingest(PostureInputs(containerSize: CGSize(width: 1000, height: 800)))
        #expect(provider.posture == .book)
        #expect(!provider.hingeRect.isNull)
    }

    @Test func overrideWinsAndClears() {
        let provider = SystemPostureProvider(defaults: makeDefaults())
        provider.ingest(PostureInputs(containerSize: CGSize(width: 1000, height: 800)))
        provider.override = .tent
        #expect(provider.posture == .tent)
        provider.override = nil
        #expect(provider.posture == .book)
    }

    @Test func overrideIsReadFromDefaults() {
        let defaults = makeDefaults()
        defaults.set("laptop", forKey: SystemPostureProvider.overrideDefaultsKey)
        let provider = SystemPostureProvider(defaults: defaults)
        #expect(provider.posture == .laptop)
    }
}
