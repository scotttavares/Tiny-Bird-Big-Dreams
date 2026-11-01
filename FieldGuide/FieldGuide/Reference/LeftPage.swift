import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// What the left (or top) page is showing.
enum LeftPageMode: String, CaseIterable, Identifiable {
    case reference
    case camera
    case lastPage
    case wholePage
    case fieldNotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reference: "Reference"
        case .camera: "Live Camera"
        case .lastPage: "Last Page"
        case .wholePage: "Whole Page"
        case .fieldNotes: "Field Notes"
        }
    }

    var symbol: String {
        switch self {
        case .reference: "photo"
        case .camera: "camera.viewfinder"
        case .lastPage: "book.pages"
        case .wholePage: "viewfinder"
        case .fieldNotes: "note.text"
        }
    }
}

/// The page beside the canvas, with a row of buttons to choose what it shows.
struct LeftPage: View {
    let model: AppModel

    @State private var mode = LeftPageMode.reference

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(LeftPageMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Image(systemName: option.symbol)
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(mode == option ? Theme.onAccent : Theme.inkText)
                            .background(mode == option ? Color.accentColor : .clear, in: .rect(cornerRadius: 10))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }
            .padding(3)
            .background(.regularMaterial, in: .rect(cornerRadius: 13))

            Group {
                switch mode {
                case .reference:
                    ReferenceSlot(model: model)
                case .camera:
                    LiveCameraPane(model: model) { mode = .reference }
                case .lastPage:
                    LastPageSpread(model: model)
                case .wholePage:
                    WholePageOverview(model: model)
                case .fieldNotes:
                    if let page = model.currentPage {
                        FieldNotesPane(model: model, page: page)
                            .id(page.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The open page as an image, redrawn shortly after it changes.
struct LivePageImage: View {
    let model: AppModel
    var width: CGFloat = 700

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Theme.paper
            }
        }
        .task(id: model.canvas.revision) {
            if image != nil { try? await Task.sleep(for: .milliseconds(120)) }
            guard !Task.isCancelled else { return }
            image = PageRenderer.sketchImage(drawing: model.canvas.drawing, paperStyle: model.canvas.paperStyle,
                                             paperTint: model.canvas.paperTint, items: model.canvas.items,
                                             width: width, scale: 1)
        }
    }
}

/// The whole page while the canvas is zoomed in: shows what's in view, and a tap goes there.
struct WholePageOverview: View {
    let model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let page = WorkspaceCanvasGeometry.pageRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                LivePageImage(model: model)
                    .frame(width: page.width, height: page.height)
                    .offset(x: page.minX, y: page.minY)
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    let scale = page.width / PageGeometry.size.width
                    if model.canvas.zoomFactor > 1.02, let visible = model.canvas.canvasView?.visiblePageRect {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: visible.width * scale, height: visible.height * scale)
                            .offset(x: page.minX + visible.minX * scale, y: page.minY + visible.minY * scale)
                            .allowsHitTesting(false)
                    }
                }
            }
            .contentShape(.rect)
            .onTapGesture { location in
                let scale = page.width / PageGeometry.size.width
                model.canvas.centerView(on: CGPoint(x: (location.x - page.minX) / scale, y: (location.y - page.minY) / scale))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("The whole page")
        .accessibilityHint("Tap a spot to move the zoomed canvas there.")
    }
}

/// The page before this one, so the two read as an open book. Items on it can be dragged across
/// the fold, leaving a copy on the open page.
struct LastPageSpread: View {
    private static let tokenPrefix = "fieldguide-last-page-item:"

    let model: AppModel

    @State private var image: UIImage?

    static func itemID(from token: String) -> UUID? {
        guard token.hasPrefix(tokenPrefix) else { return nil }
        return UUID(uuidString: String(token.dropFirst(tokenPrefix.count)))
    }

    var body: some View {
        if let previous = model.previousPage {
            GeometryReader { proxy in
                let page = WorkspaceCanvasGeometry.pageRect(in: proxy.size)
                let scale = page.width / PageGeometry.size.width
                ZStack(alignment: .topLeading) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: page.width, height: page.height)
                            .offset(x: page.minX, y: page.minY)
                            .accessibilityLabel("Previous page: \(previous.title)")
                    }
                    ForEach(PageItem.stacked(previous.items)) { item in
                        grip(for: item, scale: scale)
                    }
                    .offset(x: page.minX, y: page.minY)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .task(id: previous.id) {
                image = PageRenderer.sketchImage(drawing: CanvasStore.decode(previous.drawingData), paperStyle: previous.paperStyle,
                                                 paperTint: previous.paperTint, items: previous.items, width: 900, scale: 1)
            }
        } else {
            ContentUnavailableView("No Earlier Page", systemImage: "book.pages",
                                   description: Text("This is the first page of the notebook."))
        }
    }

    private func grip(for item: PageItem, scale: CGFloat) -> some View {
        let size = PageItemArt.size(of: item)
        return Color.clear
            .contentShape(.rect)
            .frame(width: size.width * scale, height: size.height * scale)
            .rotationEffect(.radians(item.rotation))
            .position(x: item.center.x * scale, y: item.center.y * scale)
            .draggable(Self.tokenPrefix + item.id.uuidString) {
                if let art = PageItemArt.image(for: item) {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A viewfinder beside the canvas, to sketch what's in front of the phone.
struct LiveCameraPane: View {
    let model: AppModel
    let onCaptured: () -> Void

    @State private var camera = CameraController()
    @State private var state: CameraController.State = .starting
    @State private var isCapturing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            switch state {
            case .starting:
                ProgressView()
                    .tint(.white)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel("Starting camera")
            case .running:
                CameraPreview(camera: camera)
                    .accessibilityLabel("Camera viewfinder")
                controls
            case .unavailable, .denied:
                ContentUnavailableView {
                    Label(state == .denied ? "Camera Access Off" : "No Camera", systemImage: "camera.slash")
                } description: {
                    Text(state == .denied ? "Allow camera access in Settings to sketch from the live view." : "This device has no camera available.")
                }
                .foregroundStyle(.white)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .task { state = await camera.start() }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                capture { image in
                    model.setReference(image: image, kind: .camera)
                    onCaptured()
                }
            } label: {
                Label("Freeze", systemImage: "pause.circle.fill")
            }
            Button {
                capture { model.addPhoto($0) }
            } label: {
                Label("Stick on Page", systemImage: "photo.badge.plus")
            }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .disabled(isCapturing)
        .padding(12)
    }

    private func capture(_ use: @escaping (UIImage) -> Void) {
        isCapturing = true
        Task {
            let data = await camera.capturePhoto()
            isCapturing = false
            if let data, let image = UIImage(data: data) {
                use(image.downscaled(maxDimension: 2400))
            }
        }
    }
}

/// The page's field record: when, where, the weather, written notes and voice notes.
struct FieldNotesPane: View {
    let model: AppModel
    @Bindable var page: Page

    @State private var lookup = LocationLookup()
    @State private var isLocating = false
    @State private var recorder = VoiceRecorder()
    @State private var recordingPath: String?
    @State private var player: AVAudioPlayer?
    @State private var playingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.fieldDate.formatted(date: .complete, time: .omitted))
                        .font(.system(.headline, design: .serif))
                    Text(page.fieldDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .accessibilityHidden(true)
                    TextField("Where are you?", text: $page.locationName)
                    Button {
                        Task { await usePlace() }
                    } label: {
                        if isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location")
                        }
                    }
                    .accessibilityLabel("Use current place")
                    .disabled(isLocating)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FieldWeather.allCases) { weather in
                            let isOn = page.weather == weather
                            Button {
                                page.weather = isOn ? nil : weather
                                model.save()
                            } label: {
                                Image(systemName: weather.symbol)
                                    .font(.title3)
                                    .frame(width: 42, height: 38)
                                    .foregroundStyle(isOn ? Theme.onAccent : Theme.inkText)
                                    .background(isOn ? Color.accentColor : Theme.paperEdge, in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(weather.title)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }

                TextField("What did you notice?", text: $page.fieldNotes, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(4...12)

                Divider()

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Label(recorder.isRecording ? "Stop Recording" : "Add Voice Note",
                          systemImage: recorder.isRecording ? "stop.circle.fill" : "mic")
                }
                .buttonStyle(.bordered)
                .tint(recorder.isRecording ? .red : Theme.inkText)

                ForEach(page.voiceNotes) { note in
                    HStack {
                        Button {
                            play(note)
                        } label: {
                            Label(note.date.formatted(date: .omitted, time: .shortened),
                                  systemImage: playingID == note.id ? "stop.fill" : "play.fill")
                        }
                        Text(Duration.seconds(note.duration).formatted(.time(pattern: .minuteSecond)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Delete Voice Note", systemImage: "trash", role: .destructive) { model.deleteVoiceNote(note, from: page) }
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .foregroundStyle(Theme.inkText)
        .background(Theme.paper, in: .rect(cornerRadius: 14))
        .onChange(of: page.fieldNotes) { _, _ in model.save() }
        .onChange(of: page.locationName) { _, _ in model.save() }
        .onDisappear {
            player?.stop()
            if recorder.isRecording { finishRecording() }
        }
    }

    private func usePlace() async {
        isLocating = true
        defer { isLocating = false }
        if let name = try? await lookup.currentPlaceName() { page.locationName = name }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            finishRecording()
        } else if let path = try? model.imageStore.newAudioPath(),
                  await recorder.start(to: model.imageStore.url(for: path)) {
            player?.stop()
            playingID = nil
            recordingPath = path
        }
    }

    private func finishRecording() {
        let duration = recorder.stop()
        if let recordingPath {
            page.voiceNotes.append(VoiceNote(path: recordingPath, date: .now, duration: duration))
            model.save()
        }
        recordingPath = nil
    }

    private func play(_ note: VoiceNote) {
        player?.stop()
        guard playingID != note.id else {
            playingID = nil
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        player = try? AVAudioPlayer(contentsOf: model.imageStore.url(for: note.path))
        player?.play()
        playingID = player == nil ? nil : note.id
    }
}

/// Records one voice note at a time.
@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false

    @ObservationIgnored private var recorder: AVAudioRecorder?

    func start(to url: URL) async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings), recorder.record() else { return false }
        self.recorder = recorder
        isRecording = true
        return true
    }

    /// Stops and returns the recording's length in seconds.
    func stop() -> Double {
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        return duration
    }
}
