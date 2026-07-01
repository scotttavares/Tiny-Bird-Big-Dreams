import WidgetKit
import SwiftUI

// MARK: - Shared data (mirrors src/widget.ts WidgetPayload)

private let appGroup = "group.com.tinybirdbigdreams.orbit"
private let storageKey = "orbit"

struct OrbitPerson: Codable, Identifiable {
  let name: String
  let initials: String
  let ring: Int
  let color: String
  let drift: Bool
  var id: String { "\(name)-\(ring)" }
}

struct OrbitPayload: Codable {
  let updatedAt: Double
  let driftCount: Int
  let people: [OrbitPerson]
}

private let samplePayload = OrbitPayload(
  updatedAt: 0,
  driftCount: 2,
  people: [
    OrbitPerson(name: "Sarah", initials: "SA", ring: 4, color: "#7b6ef6", drift: true),
    OrbitPerson(name: "Mom", initials: "MO", ring: 1, color: "#ef6196", drift: false),
    OrbitPerson(name: "Leo", initials: "LE", ring: 3, color: "#f1973f", drift: true),
    OrbitPerson(name: "Priya", initials: "PR", ring: 2, color: "#36b08f", drift: false),
  ]
)

private func loadPayload() -> OrbitPayload? {
  guard
    let defaults = UserDefaults(suiteName: appGroup),
    let raw = defaults.string(forKey: storageKey),
    let data = raw.data(using: .utf8)
  else { return nil }
  return try? JSONDecoder().decode(OrbitPayload.self, from: data)
}

// MARK: - Timeline

struct OrbitEntry: TimelineEntry {
  let date: Date
  let payload: OrbitPayload
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> OrbitEntry {
    OrbitEntry(date: Date(), payload: samplePayload)
  }

  func getSnapshot(in context: Context, completion: @escaping (OrbitEntry) -> Void) {
    completion(OrbitEntry(date: Date(), payload: loadPayload() ?? samplePayload))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitEntry>) -> Void) {
    let entry = OrbitEntry(date: Date(), payload: loadPayload() ?? samplePayload)
    // The app calls reloadAllTimelines() on every change; this is just a fallback.
    let next = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(4 * 3600)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

// MARK: - Helpers

extension Color {
  init(hex: String) {
    let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r = Double((v & 0xFF0000) >> 16) / 255.0
    let g = Double((v & 0x00FF00) >> 8) / 255.0
    let b = Double(v & 0x0000FF) / 255.0
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}

private let accent = Color(hex: "#7b6ef6")

// MARK: - Subviews

struct PersonDot: View {
  let person: OrbitPerson
  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle().fill(Color(hex: person.color).opacity(0.9))
        Text(person.initials)
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
        if person.drift {
          Circle().stroke(Color(hex: "#E8A24A"), lineWidth: 2)
        }
      }
      .frame(width: 40, height: 40)
      Text(person.name)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
  }
}

struct Header: View {
  var body: some View {
    HStack(spacing: 6) {
      ZStack {
        Circle().stroke(accent.opacity(0.5), lineWidth: 1.5).frame(width: 16, height: 16)
        Circle().fill(accent).frame(width: 6, height: 6).offset(x: 8)
      }
      Text("Orbit")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.primary)
    }
  }
}

// MARK: - Widget content

struct OrbitWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: OrbitEntry

  private var summary: String {
    let n = entry.payload.driftCount
    if n == 0 { return "Everyone's close" }
    return n == 1 ? "1 person drifting" : "\(n) people drifting"
  }

  var body: some View {
    let people = entry.payload.people
    let shown = family == .systemSmall ? Array(people.prefix(2)) : Array(people.prefix(4))
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Header()
        Spacer()
        if entry.payload.driftCount > 0 {
          Text("\(entry.payload.driftCount)")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(hex: "#E8A24A"))
        }
      }
      Text(summary)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)
      Spacer(minLength: 0)
      HStack(spacing: family == .systemSmall ? 10 : 16) {
        ForEach(shown) { PersonDot(person: $0) }
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBackgroundCompat()
  }
}

// Handle the iOS 17 containerBackground requirement without breaking iOS 15/16.
extension View {
  @ViewBuilder
  func widgetBackgroundCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.padding(14).containerBackground(for: .widget) { Color(hex: "#0A0C16") }
    } else {
      self.padding(14).background(Color(hex: "#0A0C16"))
    }
  }
}

// MARK: - Widget

struct OrbitWidget: Widget {
  let kind = "OrbitWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      OrbitWidgetView(entry: entry)
    }
    .configurationDisplayName("Orbit")
    .description("See who's drifting to the edge of your orbit — and pull them back.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
  var body: some Widget {
    OrbitWidget()
  }
}
