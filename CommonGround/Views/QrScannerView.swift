import AVFoundation
import SwiftUI
import UIKit

struct QrScannerSheet: View {
    var onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var invalidHint: String?
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                switch cameraStatus {
                case .authorized:
                    scannerBody
                case .notDetermined:
                    ProgressView("Requesting camera…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            cameraStatus = granted ? .authorized : .denied
                        }
                default:
                    deniedBody
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var scannerBody: some View {
        ZStack {
            CameraBarcodeScanner { raw in
                let code = extractCheckInCode(raw)
                if code.isEmpty {
                    invalidHint = "That QR isn’t a check-in code."
                } else {
                    onCode(code)
                    dismiss()
                }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 240, height: 240)
                Text(invalidHint ?? "Align the event QR inside the frame")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .background(Color.black)
    }

    private var deniedBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.8))
            Text("Camera access is off")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable camera in Settings to scan check-in QR codes, or enter the code manually.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white, in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

/// Accept plain codes or URL / JSON payloads that contain the code.
func extractCheckInCode(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    if let match = trimmed.range(of: #"[?&]code=([^&]+)"#, options: .regularExpression) {
        let part = String(trimmed[match])
        if let eq = part.firstIndex(of: "=") {
            return String(part[part.index(after: eq)...])
        }
    }
    if let regex = try? NSRegularExpression(pattern: #"check[-_]?in[/:=]([A-Za-z0-9_-]+)"#, options: .caseInsensitive),
       let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
       let range = Range(match.range(at: 1), in: trimmed) {
        return String(trimmed[range])
    }
    if let regex = try? NSRegularExpression(pattern: #""code"\s*:\s*"([^"]+)""#),
       let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
       let range = Range(match.range(at: 1), in: trimmed) {
        return String(trimmed[range])
    }
    if trimmed.range(of: #"^[A-Za-z0-9_-]{4,32}$"#, options: .regularExpression) != nil {
        return trimmed
    }
    return ""
}

private struct CameraBarcodeScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCode = onCode
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.onCode = onCode
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var handled = false
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureSession() }
                }
            }
        default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        preview = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !handled,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              !value.isEmpty
        else { return }
        handled = true
        session.stopRunning()
        onCode?(value)
    }
}
