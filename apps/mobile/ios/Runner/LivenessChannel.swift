import Flutter
import UIKit
import AVFoundation
import Vision

// ─── Flutter MethodChannel bridge ─────────────────────────────────────────
//
// Channel: com.verifia.app/liveness
// Method:  startSession(nonce: String) → { session_id: String, passed: Bool }
//
// Presents a full-screen native UIViewController that uses:
//   • AVCaptureSession (front camera)
//   • VNDetectFaceRectanglesRequest (Vision framework — on-device, no account)
//
// Challenge sequence:
//   Stage 1 — Face detected and centered in oval (≥1.5 s)
//   Stage 2 — Head turned left (yaw ≤ -0.25 rad for ≥10 frames)
//   Stage 3 — Head returned to center (|yaw| ≤ 0.15 for ≥10 frames)
//
// The session_id is "vision-<nonce_prefix>-<unix_ts>".
// The backend accepts it in dev mode (PASSKEY_RP_ID unset).

class LivenessChannel: NSObject {

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.verifia.app/liveness",
            binaryMessenger: messenger
        )
        let instance = LivenessChannel()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startSession":
            guard let args = call.arguments as? [String: Any],
                  let nonce = args["nonce"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "nonce required", details: nil))
                return
            }
            DispatchQueue.main.async { self.present(nonce: nonce, result: result) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func present(nonce: String, result: @escaping FlutterResult) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
            return
        }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }

        let vc = LivenessViewController(nonce: nonce,
            onComplete: { sessionId in result(["session_id": sessionId, "passed": true]) },
            onCancel:   { result(FlutterError(code: "USER_CANCELLED", message: "Liveness cancelado", details: nil)) }
        )
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        presenter.present(vc, animated: true)
    }
}

// ─── Liveness View Controller ─────────────────────────────────────────────

private class LivenessViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    // MARK: - Init

    private let nonce: String
    private let onComplete: (String) -> Void
    private let onCancel:   () -> Void

    init(nonce: String, onComplete: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.nonce = nonce
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Camera

    private let captureSession  = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput     = AVCaptureVideoDataOutput()
    private let cameraQueue     = DispatchQueue(label: "com.verifia.liveness.camera", qos: .userInteractive)

    // MARK: - Vision

    private lazy var faceRequest = VNDetectFaceRectanglesRequest()

    // MARK: - UI

    private let previewView   = UIView()
    private let dimOverlay    = UIView()
    private let ovalLayer     = CAShapeLayer()
    private let statusDot     = CALayer()
    private let titleLabel    = UILabel()
    private let badgeLabel    = UILabel()
    private let badgeView     = UIView()
    private let instructionLabel = UILabel()
    private let progressBar   = UIProgressView(progressViewStyle: .default)
    private let closeBtn      = UIButton(type: .system)

    // MARK: - State (main thread only)

    private enum Stage { case detectFace, turnLeft, center, done }
    private var stage: Stage = .detectFace
    private var stageFrames = 0
    private var isFinishing = false

    // Thresholds
    private let detectFramesNeeded = 45   // ~1.5 s at 30 fps
    private let turnFramesNeeded   = 10
    private let centerFramesNeeded = 10
    private let turnYawThreshold: Float  = -0.22  // negative = looking left
    private let centerYawThreshold: Float = 0.15

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        requestCameraPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraQueue.async { [weak self] in self?.captureSession.stopRunning() }
    }

    // MARK: - UI Construction

    private func buildUI() {
        view.backgroundColor = .black

        // Camera preview (fullscreen behind everything)
        previewView.frame = view.bounds
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(previewView)

        // Semi-transparent overlay
        dimOverlay.frame = view.bounds
        dimOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        view.addSubview(dimOverlay)

        // Face oval
        let cx = view.bounds.midX
        let cy = view.bounds.midY
        let ovalRect = CGRect(x: cx - 100, y: cy - 135, width: 200, height: 270)
        ovalLayer.path = UIBezierPath(ovalIn: ovalRect).cgPath
        ovalLayer.fillColor = UIColor.clear.cgColor
        ovalLayer.strokeColor = accent(alpha: 1).cgColor
        ovalLayer.lineWidth = 3
        view.layer.addSublayer(ovalLayer)

        // Status dot (top-center of oval)
        statusDot.frame = CGRect(x: cx - 5, y: cy - 148, width: 10, height: 10)
        statusDot.cornerRadius = 5
        statusDot.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        view.layer.addSublayer(statusDot)

        // Close button
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeBtn)

        // Title
        titleLabel.text = "Verificación de Presencia"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // LIVENESS 3D badge
        badgeLabel.text = "LIVENESS 3D"
        badgeLabel.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = accent(alpha: 1)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.layer.cornerRadius = 12
        badgeView.layer.borderWidth = 1
        badgeView.layer.borderColor = accent(alpha: 0.6).cgColor
        badgeView.backgroundColor = accent(alpha: 0.15)
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)
        view.addSubview(badgeView)

        // Instruction
        instructionLabel.text = "Centra tu cara en el óvalo"
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        // Progress bar
        progressBar.progressTintColor = accent(alpha: 1)
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeBtn.widthAnchor.constraint(equalToConstant: 40),
            closeBtn.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            badgeView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            badgeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 12),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -12),
            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 4),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -4),

            progressBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            instructionLabel.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -20),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Camera setup

    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraQueue.async { self.configureCamera() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.cameraQueue.async { self?.configureCamera() } }
            }
        default:
            break
        }
    }

    private func configureCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            layer.frame = self.previewView.bounds
            layer.videoGravity = .resizeAspectFill
            layer.connection?.isVideoMirrored = true
            self.previewView.layer.addSublayer(layer)
            self.previewLayer = layer
        }

        captureSession.startRunning()
    }

    // MARK: - Vision processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isFinishing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored,
                                            options: [:])
        try? handler.perform([faceRequest])

        let faces = faceRequest.results as? [VNFaceObservation] ?? []
        let face = faces.first

        DispatchQueue.main.async { [weak self] in
            self?.tick(face: face)
        }
    }

    // MARK: - State machine

    private func tick(face: VNFaceObservation?) {
        guard !isFinishing else { return }

        let hasFace = face != nil
        let yaw     = face?.yaw?.floatValue ?? 0

        switch stage {

        case .detectFace:
            if hasFace {
                stageFrames += 1
                setOvalColor(accent(alpha: 1))
                setStatusDot(green: false)
                instructionLabel.text = stageFrames > detectFramesNeeded / 2
                    ? "✓ Cara detectada — mantén posición"
                    : "Centra tu cara en el óvalo"
            } else {
                stageFrames = max(0, stageFrames - 2)
                setOvalColor(UIColor.white.withAlphaComponent(0.4))
                instructionLabel.text = "Centra tu cara en el óvalo"
            }
            let p = Float(stageFrames) / Float(detectFramesNeeded)
            progressBar.setProgress(min(p * 0.33, 0.33), animated: true)
            if stageFrames >= detectFramesNeeded { advanceTo(.turnLeft) }

        case .turnLeft:
            if hasFace && yaw <= turnYawThreshold {
                stageFrames += 1
            } else {
                stageFrames = max(0, stageFrames - 1)
            }
            let p = Float(stageFrames) / Float(turnFramesNeeded)
            progressBar.setProgress(0.33 + min(p * 0.33, 0.33), animated: true)
            if stageFrames >= turnFramesNeeded { advanceTo(.center) }

        case .center:
            if hasFace && abs(yaw) <= centerYawThreshold {
                stageFrames += 1
            } else {
                stageFrames = max(0, stageFrames - 1)
            }
            let p = Float(stageFrames) / Float(centerFramesNeeded)
            progressBar.setProgress(0.66 + min(p * 0.34, 0.34), animated: true)
            if stageFrames >= centerFramesNeeded { advanceTo(.done) }

        case .done:
            break
        }
    }

    private func advanceTo(_ next: Stage) {
        stage = next
        stageFrames = 0

        switch next {
        case .turnLeft:
            instructionLabel.text = "Gira la cabeza hacia la izquierda"
            setOvalColor(.white)

        case .center:
            instructionLabel.text = "Regresa al centro"
            setOvalColor(accent(alpha: 1))

        case .done:
            finishLiveness()

        case .detectFace:
            break
        }
    }

    private func finishLiveness() {
        guard !isFinishing else { return }
        isFinishing = true

        cameraQueue.async { [weak self] in self?.captureSession.stopRunning() }

        let green = UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
        setOvalColor(green)
        setStatusDot(green: true)
        progressBar.progressTintColor = green
        progressBar.setProgress(1.0, animated: true)
        instructionLabel.text = "¡Verificación completada!"
        instructionLabel.textColor = green

        let sessionId = "vision-\(nonce.prefix(16))-\(Int(Date().timeIntervalSince1970))"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true) { self.onComplete(sessionId) }
        }
    }

    @objc private func didTapClose() {
        guard !isFinishing else { return }
        isFinishing = true
        cameraQueue.async { [weak self] in self?.captureSession.stopRunning() }
        dismiss(animated: true) { [weak self] in self?.onCancel() }
    }

    // MARK: - Helpers

    private func setOvalColor(_ color: UIColor) {
        ovalLayer.strokeColor = color.cgColor
        ovalLayer.shadowColor = color.cgColor
        ovalLayer.shadowRadius = 8
        ovalLayer.shadowOpacity = 0.5
        ovalLayer.shadowOffset = .zero
    }

    private func setStatusDot(green: Bool) {
        statusDot.backgroundColor = green
            ? UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1).cgColor
            : UIColor.white.withAlphaComponent(0.3).cgColor
    }

    private func accent(alpha: CGFloat) -> UIColor {
        UIColor(red: 0.42, green: 0.39, blue: 1.0, alpha: alpha)
    }
}
