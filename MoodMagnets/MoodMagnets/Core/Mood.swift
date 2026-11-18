import Foundation

/// The three moods. A jelly's mood decides how it pulls, pushes and reacts.
///
/// Field rules (source → target):
/// - Happy pulls Happy and Nervous jellies closer. Grumpy jellies ignore it.
/// - Grumpy pushes everyone away.
/// - Nervous has no field, but reacts the most to everyone else's.
///
/// Touch rules:
/// - A Nervous jelly hugged by something Happy for a moment cheers up (becomes Happy).
/// - A Nervous jelly that bumps into something Grumpy jumps away in fright.
enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case happy
    case grumpy
    case nervous

    var id: String { rawValue }

    /// How strongly this mood reacts to other moods' fields.
    var response: Double {
        switch self {
        case .happy: return 1.0
        case .grumpy: return 0.4
        case .nervous: return 1.5
        }
    }

    /// Mass used for collisions. Grumpy jellies are hard to budge.
    var mass: Double {
        switch self {
        case .happy: return 1.0
        case .grumpy: return 3.0
        case .nervous: return 0.6
        }
    }

    var title: String {
        switch self {
        case .happy: return "Happy"
        case .grumpy: return "Grumpy"
        case .nervous: return "Nervous"
        }
    }

    var blurb: String {
        switch self {
        case .happy: return "Pulls friends close. Its hugs cheer up Nervous jellies."
        case .grumpy: return "Pushes everyone away, and won't be pushed around."
        case .nervous: return "Light and jumpy. Rushes to Happy, flees from Grumpy."
        }
    }
}
