import Foundation
import Testing
import UIKit
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

    @Test func everyAppIconChoiceShipsWithTheApp() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])
        #expect(Set(alternates.keys) == Set(AppIconChoice.allCases.compactMap(\.iconName)))
        for choice in AppIconChoice.allCases {
            #expect(UIImage(named: choice.previewName) != nil)
        }
    }

    @Test func anUnknownAppIconFallsBackToTheDefault() {
        #expect(AppIconChoice.current(alternateIconName: nil) == .ochre)
        #expect(AppIconChoice.current(alternateIconName: "AppIcon-Rust") == .rust)
        #expect(AppIconChoice.current(alternateIconName: "Retired") == .ochre)
    }

    @Test func itemsSavedBeforeFramesStillOpen() throws {
        let saved = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","content":{"sticker":{"_0":"star"}},"center":[10,20],"width":100}"#
        let item = try JSONDecoder().decode(PageItem.self, from: Data(saved.utf8))
        #expect(item.frame == .print)
        #expect(item.look == .original)
        #expect(item.addedAt == nil)
    }
}
