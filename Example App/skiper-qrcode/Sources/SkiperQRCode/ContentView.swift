import SwiftUI
import SkipQRCode

#if !os(Android)
import VisionKit
#endif

struct ContentView: View {
    @State var scannedCode: String?
    @State var isShowingScanner = false
    @State var scanHistory: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("QR/Barcode Scanner Test")
                    .font(.title)
                    .bold()
                
                if let code = scannedCode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Scanned:")
                            .font(.headline)
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                Button {
                    isShowingScanner = true
                } label: {
                    Label("Scan Code", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if !scanHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scan History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List(scanHistory, id: \.self) { code in
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    #if os(Android)
                    Text("📱 Android Scanner")
                        .font(.caption)
                        .foregroundColor(.green)
                    #else
                    Text("📱 iOS Scanner")
                        .font(.caption)
                        .foregroundColor(.blue)
                    #endif
                }
                .padding()
            }
            .navigationTitle("Skip QR Code")
        }
        .sheet(isPresented: $isShowingScanner) {
            #if os(Android)
            // Android: Use transparent view that immediately launches scanner
            Color.clear
                .onAppear {
                    isShowingScanner = false
                    AndroidBarcodeScanner.scan { code in
                        if let code = code {
                            scannedCode = code
                            scanHistory.insert(code, at: 0)
                        }
                    }
                }
            #else
            // iOS: Use VisionKit DataScannerViewController
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScannerView { code in
                    scannedCode = code
                    scanHistory.insert(code, at: 0)
                    isShowingScanner = false
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Scanner Not Available")
                        .font(.title2)
                    Text("This device doesn't support barcode scanning")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Close") {
                        isShowingScanner = false
                    }
                    .padding()
                }
                .padding()
            }
            #endif
        }
    }
}

#if !os(Android)
/// iOS barcode scanner using VisionKit's DataScannerViewController
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        
        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    onScan(payload)
                }
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Auto-scan first barcode found
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScan(payload)
                    return
                }
            }
        }
    }
}
#endif
