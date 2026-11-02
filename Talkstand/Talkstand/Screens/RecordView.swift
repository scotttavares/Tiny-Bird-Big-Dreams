import SwiftUI

/// Stand mode: the script scrolls on one half while the other half films you.
struct RecordView: View {
    let script: Script

    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraController()
    @State private var engine: PrompterEngine
    @State private var activeFold: CGRect?
    @State private var countdown: Int?
    @AppStorage("wordsPerMinute") private var wordsPerMinute = 140.0
    @AppStorage("fontSize") private var fontSize = 34.0

    init(script: Script) {
        self.script = script
        _engine = State(initialValue: PrompterEngine(text: script.body))
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = StandLayout.make(size: proxy.size, activeFold: activeFold)
            ZStack(alignment: .topLeading) {
                Color.black
                PrompterView(engine: engine, fontSize: fontSize)
                    .frame(width: layout.script.width, height: layout.script.height)
                    .offset(x: layout.script.minX, y: layout.script.minY)
                stage
                    .frame(width: layout.stage.width, height: layout.stage.height)
                    .offset(x: layout.stage.minX, y: layout.stage.minY)
            }
        }
        .readsFold(into: $activeFold)
        .ignoresSafeArea(edges: .bottom)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: wordsPerMinute, initial: true) { _, value in engine.wordsPerMinute = value }
        .sheet(item: Binding(get: { camera.finishedTake.map(Take.init) }, set: { camera.finishedTake = $0?.url })) { take in
            TakeReviewView(take: take, flubs: engine.flubs) {
                engine.restart()
            }
        }
    }

    // MARK: - Stage

    private var stage: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                preview
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.35))
                        .transition(.opacity)
                }
                if camera.isRecording {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Label(Self.clock(camera.recordingTime ?? 0), systemImage: "record.circle")
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.red, in: .capsule)
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            controls
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(Color("StageColor").opacity(0.92))
        // Drives the scroll from the recording clock (or wall clock when rehearsing).
        .background {
            TimelineView(.animation(paused: !engine.isPlaying)) { context in
                Color.clear.onChange(of: context.date) { _, _ in
                    engine.tick(at: clockNow)
                }
            }
        }
        .onChange(of: engine.isFinished) { _, finished in
            if finished && camera.isRecording {
                // Leave a beat after the last word before stopping.
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    camera.stopRecording()
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch camera.status {
        case .ready:
            CameraPreview(session: camera.session)
        case .denied:
            message("Talkstand needs the camera to film you. Turn it on in Settings.", button: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .failed(let reason):
            message(reason, button: "Try again") { Task { await camera.start() } }
        case .idle:
            Color.black.overlay(ProgressView().tint(.white))
        }
    }

    private func message(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(text).multilineTextAlignment(.center).foregroundStyle(.white)
            Button(button, action: action).buttonStyle(.bordered).tint(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private var controls: some View {
        HStack(alignment: .center) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            .disabled(camera.isRecording)

            Spacer()

            Button { engine.backOneLine(at: camera.recordingTime) } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 52, height: 52)
            }
            .accessibilityLabel("Back one line")

            Spacer()

            recordButton

            Spacer()

            Button { Task { await camera.flip() } } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera").frame(width: 52, height: 52)
            }
            .accessibilityLabel(camera.position == .front ? "Use the back camera" : "Use the front camera")
            .disabled(camera.isRecording)

            Spacer()

            Menu {
                Picker("Speed", selection: $wordsPerMinute) {
                    ForEach([100.0, 120, 140, 160, 180, 200], id: \.self) { Text("\(Int($0)) words a minute").tag($0) }
                }
                Picker("Text size", selection: $fontSize) {
                    Text("Small").tag(26.0)
                    Text("Medium").tag(34.0)
                    Text("Large").tag(44.0)
                }
            } label: {
                Image(systemName: "textformat.size").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Speed and text size")
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: camera.isRecording ? 8 : 30)
                    .fill(.red)
                    .frame(width: camera.isRecording ? 30 : 60, height: camera.isRecording ? 30 : 60)
            }
            .animation(.spring(duration: 0.25), value: camera.isRecording)
        }
        .accessibilityLabel(camera.isRecording ? "Stop recording" : "Start recording")
        .disabled(camera.status != .ready || countdown != nil)
    }

    // MARK: - Actions

    /// The recording clock while filming, so stumble times line up with the video.
    private var clockNow: TimeInterval {
        camera.recordingTime ?? Date.now.timeIntervalSinceReferenceDate
    }

    private func toggleRecording() {
        if camera.isRecording {
            engine.pause()
            camera.stopRecording()
            return
        }
        Task {
            engine.restart()
            for second in stride(from: 3, through: 1, by: -1) {
                withAnimation { countdown = second }
                try? await Task.sleep(for: .seconds(1))
            }
            withAnimation { countdown = nil }
            camera.startRecording()
            engine.play(at: 0)
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// A finished recording, identifiable for the review sheet.
struct Take: Identifiable {
    let url: URL
    var id: URL { url }
}
