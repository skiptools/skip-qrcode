# SkipQRCode

This is a free [Skip](https://skip.tools) Swift/Kotlin library project containing the following modules:

SkipQRCode

## Installation

Add SkipQRCode as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/skiptools/skip-qrcode.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SkipQRCode", package: "skip-qrcode")
        ]
    )
]
```

## Quick Start

### Basic Usage

```swift
import SwiftUI
import SkipQRCode

struct ContentView: View {
    @State private var showScanner = false
    @State private var scannedCode: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Scan QR Code") {
                showScanner = true
            }
            .buttonStyle(.borderedProminent)
            
            if let code = scannedCode {
                Text("Scanned: \(code)")
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showScanner) {
            #if os(iOS)
            BarcodeScannerView { code in
                scannedCode = code
                showScanner = false
            }
            .ignoresSafeArea()
            #elseif os(Android)
            // Android scanner launches as a native activity
            Color.clear
                .onAppear {
                    showScanner = false
                    AndroidBarcodeScanner.scan { code in
                        if let code = code {
                            scannedCode = code
                        }
                    }
                }
            #endif
        }
    }
}
```

### Advanced Example with Error Handling

```swift
import SwiftUI
import SkipQRCode

struct AdvancedScannerView: View {
    @State private var showScanner = false
    @State private var scannedCode: String?
    @State private var scanError: String?
    @State private var isScanning = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("QR Code Scanner")
                .font(.title)
            
            if let code = scannedCode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanned Code:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(code)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            
            if let error = scanError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(action: startScanning) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text(isScanning ? "Scanning..." : "Scan QR Code")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
        .padding()
        .sheet(isPresented: $showScanner) {
            #if os(iOS)
            BarcodeScannerView { code in
                handleScanResult(code)
            }
            .ignoresSafeArea()
            #elseif os(Android)
            Color.clear
                .onAppear {
                    showScanner = false
                    performAndroidScan()
                }
            #endif
        }
    }
    
    private func startScanning() {
        scannedCode = nil
        scanError = nil
        isScanning = true
        showScanner = true
    }
    
    private func handleScanResult(_ code: String) {
        scannedCode = code
        showScanner = false
        isScanning = false
    }
    
    #if os(Android)
    private func performAndroidScan() {
        AndroidBarcodeScanner.scan { code in
            isScanning = false
            if let code = code {
                scannedCode = code
            } else {
                scanError = "Scan cancelled or failed"
            }
        }
    }
    #endif
}
```

## Platform-Specific Behavior

### iOS

**Implementation**: Uses VisionKit's `DataScannerViewController`
- Requires iOS 17.0+
- Full-screen camera interface
- Automatic barcode detection
- Built-in guidance overlay
- Pinch-to-zoom support
- High frame rate tracking

**Permissions**: Add camera usage description to your `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes and barcodes</string>
```

### Android

**Implementation**: Uses Google ML Kit with CameraX
- Requires Android API 24+
- Native activity-based scanner
- ML Kit barcode detection
- Torch/flashlight control
- Portrait orientation

**Permissions**: Automatically included in the package's `AndroidManifest.xml`

## API Reference

### iOS: `BarcodeScannerView`

A SwiftUI view that embeds the iOS barcode scanner.

```swift
public struct BarcodeScannerView: UIViewControllerRepresentable {
    public init(onResult: @escaping (String) -> Void)
}
```

**Parameters:**
- `onResult`: Callback invoked when a barcode is scanned. Receives the barcode string.

**Usage:**
```swift
BarcodeScannerView { scannedCode in
    print("Scanned: \(scannedCode)")
}
.ignoresSafeArea() // Recommended for full-screen display
```

### Android: `AndroidBarcodeScanner`

A utility enum for launching the Android scanner.

```swift
public enum AndroidBarcodeScanner {
    public static func scan(completion: @escaping @Sendable (String?) -> Void)
}
```

**Parameters:**
- `completion`: Async callback invoked when scanning completes. Receives:
  - The scanned barcode string if successful
  - `nil` if the scan was cancelled or failed

**Usage:**
```swift
AndroidBarcodeScanner.scan { result in
    if let barcode = result {
        print("Scanned: \(barcode)")
    } else {
        print("Scan cancelled or failed")
    }
}
```

## Supported Barcode Types

SkipQRCode supports all common 1D and 2D barcode formats:

- **2D Codes**: QR Code, Data Matrix, Aztec, PDF417
- **1D Codes**: UPC-A, UPC-E, EAN-8, EAN-13
- **Other**: Code 39, Code 93, Code 128, ITF, Codabar
- **Specialized**: Driver's License, Calendar Events, Contact Info

## Architecture

SkipQRCode is a **Skip Fuse native package**, which means:

- ✅ **No Transpilation**: Swift code on iOS calls native frameworks directly
- ✅ **Native Bridge**: Swift on Android bridges to Kotlin via Skip's `AnyDynamicObject`
- ✅ **Platform Optimized**: Uses best-in-class libraries for each platform
- ✅ **High Performance**: Native execution on both iOS and Android

### Component Overview

```
iOS Side:
  SwiftUI → BarcodeScannerView → VisionKit

Android Side:
  SwiftUI → AndroidBarcodeScanner → ScanHostActivity → MLKitScanActivity
                                      (Kotlin)           (CameraX + ML Kit)
```

## Requirements

- **iOS**: 17.0 or later
- **Android**: API 24 (Android 7.0) or later
- **Skip**: 1.6.27 or later
- **Xcode**: 15.0 or later

## Building

This project uses the [Skip](https://skip.tools) plugin with native compilation mode.

Install Skip using [Homebrew](https://brew.sh):
```bash
brew install skiptools/skip/skip
```

Build the package:
```bash
swift build
```

## Testing

Run tests using:
```bash
swift test
```

For parity testing across platforms:
```bash
skip test
```

## Troubleshooting

### iOS

**Scanner doesn't appear:**
- Ensure you're running on iOS 17.0 or later
- Check that `NSCameraUsageDescription` is in your Info.plist
- Verify camera permissions are granted

**Scanner shows but doesn't scan:**
- Check that `DataScannerViewController.isSupported` returns true
- Ensure good lighting conditions
- Try different barcode types

### Android

**Scanner crashes on launch:**
- Verify all dependencies are properly resolved
- Check that camera permissions are declared in manifest
- Ensure device has a working camera

**Scanned results not returning:**
- Check LogCat for error messages (tag: `MLKitScanActivity`, `ScanHostActivity`)
- Ensure ML Kit dependencies are included
- Verify network connectivity (ML Kit may download models)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository
2. Install Skip: `brew install skiptools/skip/skip`
3. Open in Xcode or your preferred IDE
4. Make your changes
5. Run tests: `swift test` or `skip test`
6. Submit a PR

## Credits

Built with [Skip](https://skip.tools) - Swift for iOS and Android

**Technologies Used:**
- iOS: VisionKit, SwiftUI
- Android: ML Kit, CameraX, Kotlin, Jetpack Compose

## License

This software is licensed under the
[GNU Lesser General Public License v3.0](https://spdx.org/licenses/LGPL-3.0-only.html),
with the following
[linking exception](https://spdx.org/licenses/LGPL-3.0-linking-exception.html)
to clarify that distribution to restricted environments (e.g., app stores) is permitted:

> This software is licensed under the LGPL3, included below.
> As a special exception to the GNU Lesser General Public License version 3
> ("LGPL3"), the copyright holders of this Library give you permission to
> convey to a third party a Combined Work that links statically or dynamically
> to this Library without providing any Minimal Corresponding Source or
> Minimal Application Code as set out in 4d or providing the installation
> information set out in section 4e, provided that you comply with the other
> provisions of LGPL3 and provided that you meet, for the Application the
> terms and conditions of the license(s) which apply to the Application.
> Except as stated in this special exception, the provisions of LGPL3 will
> continue to comply in full to this Library. If you modify this Library, you
> may apply this exception to your version of this Library, but you are not
> obliged to do so. If you do not wish to do so, delete this exception
> statement from your version. This exception does not (and cannot) modify any
> license terms which apply to the Application, with which you must still
> comply.
