@preconcurrency import AVFoundation
import Observation

/// Owns the capture session. UI state lives on the main actor; the session itself is
/// configured and started on a private serial queue, as AVFoundation recommends.
@MainActor
@Observable
final class CameraController {
    enum Status: Equatable {
        case idle
        case denied
        case ready
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var position: AVCaptureDevice.Position = .front
    private(set) var isRecording = false
    /// The finished take, set when a recording ends.
    var finishedTake: URL?

    let session = AVCaptureSession()
    private let capture = Capture()

    /// Recording-clock seconds since recording began, or `nil` when not recording.
    var recordingTime: TimeInterval? {
        recordingStartedAt.map { Date.now.timeIntervalSince($0) }
    }
    private var recordingStartedAt: Date?

    func start() async {
        guard status == .idle || status == .denied else { return }
        guard await Self.requestAccess() else {
            status = .denied
            return
        }
        do {
            try await capture.configure(session: session, position: position)
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() {
        let session = session
        capture.queue.async { session.stopRunning() }
    }

    func flip() async {
        guard !isRecording else { return }
        let next: AVCaptureDevice.Position = position == .front ? .back : .front
        do {
            try await capture.switchCamera(session: session, to: next)
            position = next
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func startRecording() {
        guard status == .ready, !isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "take-\(UUID().uuidString).mov")
        isRecording = true
        recordingStartedAt = .now
        capture.record(to: url, mirrored: position == .front) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isRecording = false
                self.recordingStartedAt = nil
                switch result {
                case .success(let url): self.finishedTake = url
                case .failure(let error): self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func stopRecording() {
        capture.stopRecording()
    }

    private static func requestAccess() async -> Bool {
        let video = await AVCaptureDevice.requestAccess(for: .video)
        // A silent video is still useful, so the microphone is optional.
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return video
    }
}

enum CameraError: LocalizedError {
    case noCamera
    case cannotAdd

    var errorDescription: String? {
        switch self {
        case .noCamera: "This camera isn't available."
        case .cannotAdd: "The camera couldn't be set up."
        }
    }
}

/// Session work that must stay off the main thread. Everything here runs on `queue`.
private final class Capture: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.tinybirdbigdreams.talkstand.capture")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var completion: (@Sendable (Result<URL, Error>) -> Void)?

    func configure(session: AVCaptureSession, position: AVCaptureDevice.Position) async throws {
        try await perform {
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            session.sessionPreset = .high
            try self.addVideo(to: session, position: position)
            if let mic = AVCaptureDevice.default(for: .audio),
               AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
               let input = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(input) {
                session.addInput(input)
            }
            guard session.canAddOutput(self.movieOutput) else { throw CameraError.cannotAdd }
            session.addOutput(self.movieOutput)
        }
        queue.async { session.startRunning() }
    }

    func switchCamera(session: AVCaptureSession, to position: AVCaptureDevice.Position) async throws {
        try await perform {
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            let previous = self.videoInput
            if let previous { session.removeInput(previous) }
            do {
                try self.addVideo(to: session, position: position)
            } catch {
                if let previous, session.canAddInput(previous) { session.addInput(previous) }
                self.videoInput = previous
                throw error
            }
        }
    }

    func record(to url: URL, mirrored: Bool, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        queue.async {
            self.completion = completion
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
            }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async { self.movieOutput.stopRecording() }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        queue.async {
            // Stopping by hand reports an error with "finished successfully" set.
            let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
            if let error, finished != true {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(outputFileURL))
            }
            self.completion = nil
        }
    }

    private func addVideo(to session: AVCaptureSession, position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAdd }
        session.addInput(input)
        videoInput = input
    }

    private func perform(_ work: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
