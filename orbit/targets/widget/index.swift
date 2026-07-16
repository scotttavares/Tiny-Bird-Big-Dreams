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

// The app's current theme, so the widget matches the color style in use.
struct WidgetTheme: Codable {
  let bg: String       // widget background
  let text: String     // primary text (light on dark themes, dark on light ones)
  let accent: String   // logo mark / primary accent
  let drift: String    // "drifting away" highlight (the amber-equivalent)
  let you0: String     // "You" core gradient, start
  let you1: String     // "You" core gradient, end

  // Dark "night sky" — used when a snapshot predates theming, or none is stored.
  static let fallback = WidgetTheme(
    bg: "#0A0C16", text: "#EDEFF7", accent: "#7b6ef6",
    drift: "#E8A24A", you0: "#8E7BFF", you1: "#6C5CE7"
  )
}

struct OrbitPayload: Codable {
  let updatedAt: Double
  let driftCount: Int
  let total: Int?             // optional so older cached snapshots still decode
  let people: [OrbitPerson]
  let theme: WidgetTheme?     // optional so older cached snapshots still decode
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
  ],
  theme: nil
)

private func loadPayload() -> OrbitPayload? {
  guard
    let defaults = UserDefaults(suiteName: appGroup),
    let raw = defaults.string(forKey: storageKey),
    let data = raw.data(using: .utf8)
  else { return nil }
  return try? JSONDecoder().decode(OrbitPayload.self, from: data)
}

// Advance every person's angle by `deg`, so successive timeline entries show the
// orbit turned a little further — the closest a home-screen widget gets to
// "orbiting" (WidgetKit renders static snapshots; it can't animate frame by frame).
private func rotate(_ p: OrbitPayload, by deg: Double) -> OrbitPayload {
  OrbitPayload(
    updatedAt: p.updatedAt,
    driftCount: p.driftCount,
    total: p.total,
    people: p.people.map {
      OrbitPerson(name: $0.name, initials: $0.initials, ring: $0.ring,
                  angle: $0.angle + deg, color: $0.color, drift: $0.drift)
    },
    theme: p.theme
  )
}

// MARK: - Timeline

struct OrbitEntry: TimelineEntry {
  let date: Date
  let payload: OrbitPayload
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> OrbitEntry {
    // Prefer the real (themed) snapshot even for the placeholder, so adding the
    // widget shows the user's current color style right away.
    OrbitEntry(date: Date(), payload: loadPayload() ?? samplePayload)
  }

  func getSnapshot(in context: Context, completion: @escaping (OrbitEntry) -> Void) {
    completion(OrbitEntry(date: Date(), payload: loadPayload() ?? samplePayload))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitEntry>) -> Void) {
    let base = loadPayload() ?? samplePayload
    // A multi-entry timeline lets the orbit turn a little on each refresh
    // (WidgetKit animates the step on iOS 17+). We advance everyone's angle
    // across a handful of entries, then ask to reload. The app also reloads on
    // any real change, which resets the rotation to the latest data.
    let now = Date()
    let steps = 6
    let stepDegrees = 16.0
    let stepSeconds: TimeInterval = 10 * 60
    var entries: [OrbitEntry] = []
    for i in 0..<steps {
      entries.append(OrbitEntry(date: now.addingTimeInterval(Double(i) * stepSeconds),
                                payload: rotate(base, by: Double(i) * stepDegrees)))
    }
    let refresh = now.addingTimeInterval(Double(steps) * stepSeconds)
    completion(Timeline(entries: entries, policy: .after(refresh)))
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

// Resolved colors for the active theme. Passed down via the environment so each
// subview can read it without threading a parameter through every initializer.
struct Palette {
  let bg: Color
  let text: Color
  let accent: Color
  let drift: Color
  let you: LinearGradient
  // primary text at a given opacity (was `.white.opacity(...)` on the dark-only build)
  func t(_ o: Double) -> Color { text.opacity(o) }

  init(_ th: WidgetTheme) {
    bg = Color(hex: th.bg)
    text = Color(hex: th.text)
    accent = Color(hex: th.accent)
    drift = Color(hex: th.drift)
    you = LinearGradient(
      colors: [Color(hex: th.you0), Color(hex: th.you1)],
      startPoint: .topLeading, endPoint: .bottomTrailing
    )
  }
}

private struct PaletteKey: EnvironmentKey {
  static let defaultValue = Palette(.fallback)
}
extension EnvironmentValues {
  var palette: Palette {
    get { self[PaletteKey.self] }
    set { self[PaletteKey.self] = newValue }
  }
}

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
  @Environment(\.palette) private var palette
  var size: CGFloat = 13
  var body: some View {
    ZStack {
      Circle().stroke(palette.accent.opacity(0.6), lineWidth: size / 8.5).frame(width: size, height: size)
      Circle().fill(palette.accent).frame(width: size * 0.38, height: size * 0.38).offset(x: size / 2)
    }
  }
}

// MARK: - Orbit drawing (large widget)

struct PersonDot: View {
  @Environment(\.palette) private var palette
  let person: OrbitPerson
  let size: CGFloat
  var body: some View {
    ZStack {
      Circle().fill(Color(hex: person.color).opacity(0.92))
      Text(String(person.initials.prefix(2)))
        .font(.system(size: size * 0.4, weight: .bold))
        .foregroundColor(.white)
      if person.drift {
        Circle().stroke(palette.drift, lineWidth: 2)
      }
    }
    .frame(width: size, height: size)
  }
}

struct OrbitCanvas: View {
  @Environment(\.palette) private var palette
  let payload: OrbitPayload
  let dotSize: CGFloat
  var trails: Bool = false   // draw comet tails so the orbit reads as in-motion

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
            .stroke(palette.text.opacity(r == 1 ? 0.16 : 0.08), lineWidth: 1)
            .frame(width: d, height: d)
            .position(center)
        }

        Circle()
          .fill(palette.you)
          .frame(width: dotSize * 1.1, height: dotSize * 1.1)
          .position(center)

        ForEach(payload.people) { p in
          let rr = maxR * CGFloat(p.ring) / CGFloat(maxRing)
          let rad = p.angle * Double.pi / 180
          // Comet tail: a few fading, shrinking ghosts just behind the person.
          // Widgets can't run a continuous animation, so this implies the
          // orbital motion; the timeline also rotates everyone slowly over time.
          if trails {
            ForEach(1...3, id: \.self) { k in
              let ga = (p.angle - Double(k) * 13) * Double.pi / 180
              let gs = dotSize * (1 - CGFloat(k) * 0.14)
              Circle()
                .fill(Color(hex: p.color).opacity(0.30 - Double(k) * 0.08))
                .frame(width: gs, height: gs)
                .position(x: center.x + CGFloat(cos(ga)) * rr,
                          y: center.y + CGFloat(sin(ga)) * rr)
            }
          }
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
  @Environment(\.palette) private var palette
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        OrbitMark()
        Text("Orbit").font(.system(size: 12, weight: .bold)).foregroundColor(palette.t(0.9))
      }
      Spacer(minLength: 0)
      if total == 0 {
        Text("Add people\nin Orbit")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(palette.t(0.55))
      } else if payload.driftCount > 0 {
        Text("\(payload.driftCount)")
          .font(.system(size: 46, weight: .heavy)).foregroundColor(palette.drift)
        Text(payload.driftCount == 1 ? "person" : "people")
          .font(.system(size: 14, weight: .semibold)).foregroundColor(palette.t(0.9))
        Text("drifting away")
          .font(.system(size: 12.5, weight: .medium)).foregroundColor(palette.t(0.5))
      } else {
        Text("\(total)")
          .font(.system(size: 46, weight: .heavy)).foregroundColor(palette.text)
        Text(total == 1 ? "person close" : "people close")
          .font(.system(size: 13.5, weight: .semibold)).foregroundColor(palette.t(0.9))
        Text("all in reach ✨")
          .font(.system(size: 12.5, weight: .medium)).foregroundColor(palette.t(0.5))
      }
      Spacer(minLength: 0)
      if total > 0 && payload.driftCount > 0 {
        Text("\(total) in your orbit")
          .font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.t(0.4))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Medium: the orbit on the left, who's drifting on the right

struct MediumOrbitView: View {
  @Environment(\.palette) private var palette
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }
  var drifters: [OrbitPerson] { payload.people.filter { $0.drift } }

  var body: some View {
    GeometryReader { geo in
      let side = geo.size.height
      HStack(spacing: 14) {
        OrbitCanvas(payload: payload, dotSize: 22)
          .frame(width: side, height: side)

        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 5) {
            OrbitMark()
            Text("Orbit").font(.system(size: 12, weight: .bold)).foregroundColor(palette.t(0.9))
            Spacer()
            if payload.driftCount > 0 {
              Text("\(payload.driftCount)").font(.system(size: 12, weight: .bold)).foregroundColor(palette.drift)
            }
          }
          Spacer(minLength: 8)
          if total == 0 {
            Text("Add people\nin Orbit")
              .font(.system(size: 13, weight: .medium)).foregroundColor(palette.t(0.55))
          } else if drifters.isEmpty {
            Text("Everyone's close\nright now ✨")
              .font(.system(size: 13, weight: .medium)).foregroundColor(palette.t(0.6))
          } else {
            Text("DRIFTING AWAY")
              .font(.system(size: 10.5, weight: .bold)).foregroundColor(palette.t(0.4))
              .padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 7) {
              ForEach(Array(drifters.prefix(3))) { p in
                HStack(spacing: 8) {
                  Circle().fill(Color(hex: p.color)).frame(width: 8, height: 8)
                  Text(p.name)
                    .font(.system(size: 13.5, weight: .semibold)).foregroundColor(palette.t(0.92))
                    .lineLimit(1)
                  Spacer(minLength: 4)
                  Text(ringLabel(p.ring))
                    .font(.system(size: 12, weight: .medium)).foregroundColor(palette.t(0.5))
                }
              }
              if drifters.count > 3 {
                Text("+\(drifters.count - 3) more")
                  .font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.t(0.4))
              }
            }
          }
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

// MARK: - Large: the orbit, drawn big

struct LargeOrbitView: View {
  @Environment(\.palette) private var palette
  let payload: OrbitPayload
  var total: Int { totalOf(payload) }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        OrbitMark(size: 16)
        Text("Orbit").font(.system(size: 15, weight: .bold)).foregroundColor(palette.t(0.92))
        Spacer()
        Text(payload.driftCount > 0 ? "\(payload.driftCount) drifting away" : "all close ✨")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(payload.driftCount > 0 ? palette.drift : palette.t(0.6))
      }
      if total == 0 {
        Spacer()
        Text("Add people in Orbit")
          .font(.system(size: 15, weight: .medium)).foregroundColor(palette.t(0.5))
        Spacer()
      } else {
        OrbitCanvas(payload: payload, dotSize: 34, trails: true)
      }
    }
  }
}

// MARK: - Widget view

struct OrbitWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: OrbitEntry

  var body: some View {
    let palette = Palette(entry.payload.theme ?? .fallback)
    Group {
      switch family {
      case .systemSmall: SmallStatView(payload: entry.payload)
      case .systemLarge: LargeOrbitView(payload: entry.payload)
      default: MediumOrbitView(payload: entry.payload)
      }
    }
    .environment(\.palette, palette)
    .widgetBackgroundCompat(palette.bg)
  }
}

// Handle the iOS 17 containerBackground requirement without breaking iOS 15/16.
extension View {
  @ViewBuilder
  func widgetBackgroundCompat(_ bg: Color) -> some View {
    if #available(iOS 17.0, *) {
      self.padding(14).containerBackground(for: .widget) { bg }
    } else {
      self.padding(14).background(bg)
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
