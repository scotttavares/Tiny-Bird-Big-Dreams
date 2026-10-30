import Foundation
import Testing
@testable import FieldGuide

@MainActor
struct ReleaseTests {
    @Test func theTourShowsOnceAPageIsOpen() {
        #expect(WelcomeTour.isDue(hasSeen: false, coverShowing: false, isDemo: false))
        #expect(!WelcomeTour.isDue(hasSeen: true, coverShowing: false, isDemo: false))
        #expect(!WelcomeTour.isDue(hasSeen: false, coverShowing: true, isDemo: false))
        #expect(!WelcomeTour.isDue(hasSeen: false, coverShowing: false, isDemo: true))
    }

    @Test func theAppShipsAPrivacyManifest() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }

    @Test func itemsSavedBeforeFramesStillOpen() throws {
        let saved = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","content":{"sticker":{"_0":"star"}},"center":[10,20],"width":100}"#
        let item = try JSONDecoder().decode(PageItem.self, from: Data(saved.utf8))
        #expect(item.frame == .print)
        #expect(item.look == .original)
    }
}
