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
  let total: Int?        // optional so older cached snapshots still decode
  let people: [OrbitPerson]
}

private let samplePayload = OrbitPayload(
  updatedAt: 0,
  driftCount: 3,
  total: 6,
  people: [
    OrbitPerson(name: "Sarah", initials: "SA", ring: 2, angle: -20, color: "#7b6ef6", drift: false),
    OrbitPerson(name: "Mom", initials: "MO", ring: 1, angle: 150, color: "#ef6196", drift: false),
    OrbitPerson(name: "Leo", initials: "LE", ring: 3, angle: 60, color: "#f1973f", drift: true),
    OrbitPerson(name: "Priya", initials: "PR", ring: 2, angle: 118, color: "#36b08f", drift: false),
    OrbitPerson(name: "Marcus", initials: "MA", ring: 4, angle: -102, color: "#f1973f", drift: true),
    OrbitPerson(name: "Nina", initials: "NI", ring: 5, angle: 205, color: "#ef6196", drift: true),
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

// Short "how far out" label — mirrors the app's ring → time buckets.
private func ringLabel(_ r: Int) -> String {
  switch r {
  case 1: return "this week"
  case 2: return "this month"
  case 3: return "3 months"
  case 4: return "6 months"
  case 5: return "a year"
  default: return "over a year"
  }
}

private func totalOf(_ p: OrbitPayload) -> Int { p.total ?? p.people.count }

// MARK: - Header

struct OrbitMark: View {
  var size: CGFloat = 13
  var body: some View {
    ZStack {
      Circle().stroke(accent.opacity(0.6), lineWidth: size / 8.5).frame(width: size, height: size)
      Circle().fill(accent).frame(width: size * 0.38, height: size * 0.38).offset(x: size / 2)
    }
  }
}

// MARK: - Orbit drawing (large widget)

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
        ForEach(1...maxRing, id: \.self) { r in
          let d = 2 * maxR * CGFloat(r) / CGFloat(maxRing)
          Circle()
            .stroke(Color.white.opacity(r == 1 ? 0.16 : 0.08), lineWidth: 1)
            .frame(width: d, height: d)
            .position(center)
        }

        Circle()
          .fill(youGrad)
          .frame(width: dotSize * 1.1, height: dotSize * 1.1)
          .position(center)

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

// MARK: - Small: numbers + text only

struct SmallStatView: View {
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        OrbitMark()
        Text("Orbit").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.9))
      }
      Spacer(minLength: 0)
      if total == 0 {
        Text("Add people\nin Orbit")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white.opacity(0.55))
      } else if payload.driftCount > 0 {
        Text("\(payload.driftCount)")
          .font(.system(size: 46, weight: .heavy)).foregroundColor(amber)
        Text(payload.driftCount == 1 ? "person" : "people")
          .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.9))
        Text("drifting away")
          .font(.system(size: 12.5, weight: .medium)).foregroundColor(.white.opacity(0.5))
      } else {
        Text("\(total)")
          .font(.system(size: 46, weight: .heavy)).foregroundColor(.white)
        Text(total == 1 ? "person close" : "people close")
          .font(.system(size: 13.5, weight: .semibold)).foregroundColor(.white.opacity(0.9))
        Text("all in reach ✨")
          .font(.system(size: 12.5, weight: .medium)).foregroundColor(.white.opacity(0.5))
      }
      Spacer(minLength: 0)
      if total > 0 && payload.driftCount > 0 {
        Text("\(total) in your orbit")
          .font(.system(size: 11.5, weight: .medium)).foregroundColor(.white.opacity(0.4))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Medium: numbers + text, with who's drifting

struct MediumStatView: View {
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }
  var drifters: [OrbitPerson] { payload.people.filter { $0.drift } }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        OrbitMark()
        Text("Orbit").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.9))
      }
      Spacer(minLength: 6)
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 1) {
          Text("\(payload.driftCount)")
            .font(.system(size: 44, weight: .heavy))
            .foregroundColor(payload.driftCount > 0 ? amber : .white)
          Text(payload.driftCount == 1 ? "person drifting" : "people drifting")
            .font(.system(size: 12.5, weight: .semibold)).foregroundColor(.white.opacity(0.85))
          Text("\(total) in your orbit")
            .font(.system(size: 11.5, weight: .medium)).foregroundColor(.white.opacity(0.45))
        }
        .frame(width: 118, alignment: .leading)

        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)

        VStack(alignment: .leading, spacing: 7) {
          if drifters.isEmpty {
            Text(total == 0 ? "Add people in Orbit" : "Everyone's close right now ✨")
              .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.55))
          } else {
            ForEach(Array(drifters.prefix(3))) { p in
              HStack(spacing: 8) {
                Circle().fill(Color(hex: p.color)).frame(width: 8, height: 8)
                Text(p.name)
                  .font(.system(size: 13.5, weight: .semibold)).foregroundColor(.white.opacity(0.92))
                  .lineLimit(1)
                Spacer(minLength: 4)
                Text(ringLabel(p.ring))
                  .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5))
              }
            }
            if drifters.count > 3 {
              Text("+\(drifters.count - 3) more")
                .font(.system(size: 11.5, weight: .medium)).foregroundColor(.white.opacity(0.4))
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Large: the orbit, drawn big

struct LargeOrbitView: View {
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        OrbitMark(size: 16)
        Text("Orbit").font(.system(size: 15, weight: .bold)).foregroundColor(.white.opacity(0.92))
        Spacer()
        Text(payload.driftCount > 0 ? "\(payload.driftCount) drifting away" : "all close ✨")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(payload.driftCount > 0 ? amber : .white.opacity(0.6))
      }
      if total == 0 {
        Spacer()
        Text("Add people in Orbit")
          .font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.5))
        Spacer()
      } else {
        OrbitCanvas(payload: payload, dotSize: 34)
      }
    }
  }
}

// MARK: - Widget view

struct OrbitWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: OrbitEntry

  var body: some View {
    Group {
      switch family {
      case .systemSmall: SmallStatView(payload: entry.payload)
      case .systemLarge: LargeOrbitView(payload: entry.payload)
      default: MediumStatView(payload: entry.payload)
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
    .description("Your orbit at a glance — who's drifting to the edge.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
  var body: some Widget {
    OrbitWidget()
  }
}
