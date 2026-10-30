import AVFoundation
import SwiftUI
import UIKit

/// Full-screen AVFoundation camera for capturing a reference photo.
struct CameraCaptureView: View {
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraController()
    @State private var state: CameraController.State = .starting
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state {
            case .starting:
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Starting camera")
            case .running:
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
                    .accessibilityLabel("Camera viewfinder")
            case .unavailable, .denied:
                ContentUnavailableView {
                    Label(state == .denied ? "Camera Access Off" : "No Camera", systemImage: "camera.slash")
                } description: {
                    Text(state == .denied
                         ? "Allow camera access in Settings to capture reference photos."
                         : "This device has no camera available. Add a reference from your photo library instead.")
                }
                .foregroundStyle(.white)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.body.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Button {
                    capture()
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .background(Circle().fill(.white.opacity(isCapturing ? 0.4 : 0.9)).padding(6))
                        .frame(width: 76, height: 76)
                }
                .disabled(state != .running || isCapturing)
                .accessibilityLabel("Take photo")
                Spacer()
                Color.clear.frame(width: 60, height: 44)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .task {
            state = await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isCapturing) { _, new in new }
    }

    private func capture() {
        isCapturing = true
        Task {
            let data = await camera.capturePhoto()
            isCapturing = false
            if let data, let image = UIImage(data: data) {
                onCapture(image)
                dismiss()
            }
        }
    }
}

/// Owns the capture session. Session work happens on a private serial queue.
final class CameraController: NSObject, @unchecked Sendable {
    enum State: Equatable, Sendable {
        case starting, running, unavailable, denied
    }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.tinybirdbigdreams.fieldguide.camera")
    private var pending: CheckedContinuation<Data?, Never>?
    /// Set from the main thread by the preview; read on the session queue when capturing.
    private var captureRotationAngle: CGFloat = 90
    private let lock = NSLock()

    private static func backCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    func start() async -> State {
        guard Self.backCamera() != nil else {
            return .unavailable
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            return .denied
        }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                session.beginConfiguration()
                session.sessionPreset = .photo
                guard let device = Self.backCamera(),
                      let input = try? AVCaptureDeviceInput(device: device),
                      session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    continuation.resume(returning: .unavailable)
                    return
                }
                session.addInput(input)
                session.addOutput(output)
                session.commitConfiguration()
                session.startRunning()
                continuation.resume(returning: .running)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setCaptureRotationAngle(_ angle: CGFloat) {
        lock.withLock { captureRotationAngle = angle }
    }

    func capturePhoto() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                pending = continuation
                let angle = lock.withLock { captureRotationAngle }
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async { [self] in
            pending?.resume(returning: data)
            pending = nil
        }
    }
}

/// Live preview layer, kept level with the horizon as the device rotates.
struct CameraPreview: UIViewRepresentable {
    let camera: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.camera = camera
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        weak var camera: CameraController?
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // `layerClass` guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if rotationCoordinator == nil,
               let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            }
            guard let rotationCoordinator else { return }
            let previewAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(previewAngle) {
                connection.videoRotationAngle = previewAngle
            }
            camera?.setCaptureRotationAngle(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        }
    }
}
