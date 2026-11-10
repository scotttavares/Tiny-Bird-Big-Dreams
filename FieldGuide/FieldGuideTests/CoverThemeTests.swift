import Testing
@testable import FieldGuide

@Suite("Covers")
struct CoverThemeTests {
    @Test func newNotebooksCycleThroughCovers() {
        #expect(NotebookTheme.next(after: 0) == .journal)
        #expect(NotebookTheme.next(after: 1) == .pines)
        #expect(NotebookTheme.next(after: NotebookTheme.allCases.count) == .journal)
    }
}
