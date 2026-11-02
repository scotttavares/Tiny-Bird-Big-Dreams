import Foundation

/// One thing to say on camera.
struct Script: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "", body: String = "", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    /// The title to show in lists: the typed title, else the first line of the script.
    var displayTitle: String {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(40))
    }

    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// Roughly how long the script takes to say at `wordsPerMinute`.
    func duration(wordsPerMinute: Double) -> TimeInterval {
        guard wordsPerMinute > 0 else { return 0 }
        return Double(wordCount) / wordsPerMinute * 60
    }

    static let sample = Script(
        title: "Hello from Talkstand",
        body: """
        Hi, it's me. I'm trying out Talkstand.
        My phone is standing up on the table, and my words are scrolling right under the camera.
        If I trip over a line, I tap back and say it again.
        That's it. One take, and it's ready to send.
        """
    )
}
