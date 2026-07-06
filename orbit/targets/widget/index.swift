import WidgetKit
import SwiftUI

// MARK: - Shared data (mirrors src/widget.ts WidgetPayload)

private let appGroup = "group.com.tinybirdbigdreams.orbit"
private let storageKey = "orbit"

struct OrbitPerson: Codable, Identifiable {
  let name: String
  let initials: String
  let ring: Int
  let angle: Double
  let color: String
  let drift: Bool
  var id: String { "\(name)-\(ring)-\(Int(angle))" }
}

struct OrbitPayload: Codable {
  let updatedAt: Double
  let driftCount: Int
  let people: [OrbitPerson]
}

private let samplePayload = OrbitPayload(
  updatedAt: 0,
  driftCount: 3,
  people: [
    OrbitPerson(name: "Sarah", initials: "SA", ring: 2, angle: -20, color: "#7b6ef6", drift: false),
    OrbitPerson(name: "Mom", initials: "MO", ring: 1, angle: 150, color: "#ef6196", drift: false),
    OrbitPerson(name: "Leo", initials: "LE", ring: 3, angle: 60, color: "#f1973f", drift: true),
    OrbitPerson(name: "Priya", initials: "PR", ring: 2, angle: 118, color: "#36b08f", drift: false),
    OrbitPerson(name: "Marcus", initials: "MA", ring: 4, angle: -102, color: "#f1973f", drift: true),
    OrbitPerson(name: "Nina", initials: "NI", ring: 4, angle: 205, color: "#ef6196", drift: true),
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

private let youGrad = LinearGradient(
  colors: [Color(hex: "#8E7BFF"), Color(hex: "#6C5CE7")],
  startPoint: .topLeading, endPoint: .bottomTrailing
)
private let amber = Color(hex: "#E8A24A")
private let accent = Color(hex: "#7b6ef6")

// MARK: - Orbit drawing

struct PersonDot: View {
  let person: OrbitPerson
  let size: CGFloat
  var body: some View {
    ZStack {
      Circle().fill(Color(hex: person.color).opacity(0.92))
      Text(String(person.initials.prefix(2)))
        .font(.system(size: size * 0.4, weight: .bold))
        .foregroundColor(.white)
      if person.drift {
        Circle().stroke(amber, lineWidth: 2)
      }
    }
    .frame(width: size, height: size)
  }
}

struct OrbitCanvas: View {
  let payload: OrbitPayload
  let dotSize: CGFloat

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let center = CGPoint(x: w / 2, y: h / 2)
      let maxR = min(w, h) / 2 - dotSize / 2 - 3
      let maxRing = max(3, payload.people.map { $0.ring }.max() ?? 3)

      ZStack {
        // concentric rings
        ForEach(1...maxRing, id: \.self) { r in
          let d = 2 * maxR * CGFloat(r) / CGFloat(maxRing)
          Circle()
            .stroke(Color.white.opacity(r == 1 ? 0.16 : 0.08), lineWidth: 1)
            .frame(width: d, height: d)
            .position(center)
        }

        // "You" core
        Circle()
          .fill(youGrad)
          .frame(width: dotSize * 1.15, height: dotSize * 1.15)
          .position(center)

        // people, placed by ring (radius) + angle
        ForEach(payload.people) { p in
          let rr = maxR * CGFloat(p.ring) / CGFloat(maxRing)
          let rad = p.angle * Double.pi / 180
          PersonDot(person: p, size: dotSize)
            .position(x: center.x + CGFloat(cos(rad)) * rr,
                      y: center.y + CGFloat(sin(rad)) * rr)
        }
      }
    }
  }
}

// MARK: - Widget view

struct OrbitWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: OrbitEntry

  var body: some View {
    let compact = family == .systemSmall
    ZStack {
      OrbitCanvas(payload: entry.payload, dotSize: compact ? 22 : 26)

      VStack(spacing: 0) {
        HStack(spacing: 5) {
          ZStack {
            Circle().stroke(accent.opacity(0.6), lineWidth: 1.5).frame(width: 13, height: 13)
            Circle().fill(accent).frame(width: 5, height: 5).offset(x: 6.5)
          }
          Text("Orbit").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.92))
          Spacer()
          if entry.payload.driftCount > 0 {
            Text("\(entry.payload.driftCount)")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(amber)
          }
        }
        Spacer(minLength: 0)
        if entry.payload.people.isEmpty {
          Text("Add people in Orbit")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            .padding(.bottom, 2)
        }
      }
    }
    .widgetBackgroundCompat()
  }
}

// Handle the iOS 17 containerBackground requirement without breaking iOS 15/16.
extension View {
  @ViewBuilder
  func widgetBackgroundCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.padding(12).containerBackground(for: .widget) { Color(hex: "#0A0C16") }
    } else {
      self.padding(12).background(Color(hex: "#0A0C16"))
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
    .description("Your orbit at a glance — who's drifting to the edge.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
  var body: some Widget {
    OrbitWidget()
  }
}
