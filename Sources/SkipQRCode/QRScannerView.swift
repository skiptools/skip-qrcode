// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import SwiftUI
#if os(iOS)
import AVFoundation
import VisionKit
#endif

/// Live camera preview that reports each QR code as it comes into view.
///
/// The preview fills the space it is given, so size and shape it like any view, for example with
/// `frame` and `clipShape`. Without a frame it covers the screen, even inside a scroll view.
/// It only scans: show it when `CameraAccess.status` is `.authorized`. Set `isTorchOn` to light
/// the scene, on devices where `CameraAccess.hasTorch` is true.
///
/// By default it reports the first code, then dismisses the screen it is on: a sheet or full-screen
/// cover closes, and a pushed view pops. Pass `dismissesOnScan: false` to keep scanning instead,
/// reporting each code as it comes into view.
/// Scanning uses VisionKit on iOS, and CameraX with ML Kit on Android.
public struct QRScannerView: View {
    let isTorchOn: Bool
    let dismissesOnScan: Bool
    let onScan: (String) -> Void

    @Environment(\.dismiss) var dismiss

    public init(isTorchOn: Bool = false, dismissesOnScan: Bool = true, onScan: @escaping (String) -> Void) {
        self.isTorchOn = isTorchOn
        self.dismissesOnScan = dismissesOnScan
        self.onScan = onScan
    }

    /// Reports `code`, then dismisses the scanner's screen when `dismissesOnScan` is set.
    func scannedCode(_ code: String) {
        onScan(code)
        guard dismissesOnScan else { return }
        dismiss()
    }

    #if SKIP
    public var body: some View {
        ComposeView { context in
            ComposeContainer(modifier: context.modifier, fillWidth: true, fillHeight: true) { modifier in
                QRScanner(modifier: modifier, isTorchOn: isTorchOn, onScan: { scannedCode($0) })
            }
        }
    }
    #elseif os(iOS)
    public var body: some View {
        DataScanner(isTorchOn: isTorchOn, onScan: { scannedCode($0) })
    }
    #else
    public var body: some View {
        Color.black
    }
    #endif
}

#if os(iOS)
/// VisionKit scanner reporting each QR code once as it comes into view.
struct DataScanner: UIViewControllerRepresentable {
    let isTorchOn: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // No guidance overlay, whose hints don't fit small boxes; highlights still mark each code
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
        context.coordinator.setTorch(isTorchOn)
    }

    /// Takes the offered size, and the screen's along any axis left open, such as a scroll view's.
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController scanner: DataScannerViewController, context: Context) -> CGSize? {
        let scene = scanner.view.window?.windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        let screen = scene?.screen.bounds.size ?? .zero
        return CGSize(width: proposal.width ?? screen.width, height: proposal.height ?? screen.height)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        /// The camera whose torch lights the scan, looked up once.
        private lazy var camera = AVCaptureDevice.scannerCamera

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        /// Turns the torch on or off, locking the camera only when the mode actually changes,
        /// since every lock briefly holds up the running stream.
        func setTorch(_ isOn: Bool) {
            let mode: AVCaptureDevice.TorchMode = isOn ? .on : .off
            guard let camera, camera.hasTorch, camera.torchMode != mode, camera.isTorchModeSupported(mode) else { return }
            do {
                try camera.lockForConfiguration()
                camera.torchMode = mode
                camera.unlockForConfiguration()
            } catch {
                // The camera is reconfiguring; the next update tries again
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let barcode) in addedItems {
                if let value = barcode.payloadStringValue {
                    onScan(value)
                }
            }
        }
    }
}

extension AVCaptureDevice {
    /// The back camera a scanner session streams from.
    ///
    /// On iPhones with several back cameras this is the virtual device that switches between them.
    /// Torch changes must go to it: locking one of its constituent cameras instead stalls the stream.
    static var scannerCamera: AVCaptureDevice? {
        DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first
    }
}
#endif
#endif
