import SwiftUI
import WidgetKit

/// A one-tap "new page" shortcut for the Lock Screen (the Duo's outer display when folded)
/// and the Home Screen. Tapping opens `fieldguide://new-page`.
@main
struct FieldGuideWidgetBundle: WidgetBundle {
    var body: some Widget {
        NewPageWidget()
    }
}

struct NewPageWidget: Widget {
    static let kind = "com.tinybirdbigdreams.fieldguide.new-page"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NewPageProvider()) { _ in
            NewPageWidgetView()
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
                .widgetURL(URL(string: "fieldguide://new-page"))
        }
        .configurationDisplayName("New Field Page")
        .description("Start a fresh page in Field Guide with one tap.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

struct NewPageEntry: TimelineEntry {
    let date: Date
}

struct NewPageProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewPageEntry {
        NewPageEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewPageEntry) -> Void) {
        completion(NewPageEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewPageEntry>) -> Void) {
        completion(Timeline(entries: [NewPageEntry(date: .now)], policy: .never))
    }
}

struct NewPageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "square.and.pencil")
                    .font(.title2)
            }
            .accessibilityLabel("New field page")
        case .accessoryRectangular:
            Label {
                VStack(alignment: .leading) {
                    Text("Field Guide")
                        .font(.headline)
                    Text("New page")
                        .font(.caption)
                }
            } icon: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityElement(children: .combine)
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("New page")
                    .font(.headline)
                Text("Field Guide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Start a new Field Guide page")
        }
    }
}
