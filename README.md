# SkipQRCode

A [Skip](https://skip.dev) Swift/Kotlin library that generates and scans QR codes with one SwiftUI API on iOS and Android.

- **Generate**: `QRCodeView` draws text as a QR code; `QRCode` exports it as a PNG or exposes its modules
- **Scan**: `QRScannerView` is a live camera box that reports each QR code it sees, with torch control
- **Camera access**: `CameraAccess` checks, requests, and recovers camera permission

## Installation

Add SkipQRCode as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/skiptools/skip-qrcode.git", "0.0.1"..<"2.0.0")
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

On iOS, add a camera usage description to your app's `Info.plist`. On Android, the `CAMERA` permission is merged from the package's manifest.

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to scan QR codes.</string>
```

## Generating QR Codes

### Displaying a Code

`QRCodeView` draws text as a QR code, black on white with the standard quiet zone. It scales to fit the space it is given while staying square and sharp:

```swift
import SwiftUI
import SkipQRCode

struct ShareView: View {
    var body: some View {
        QRCodeView("https://skip.tools")
            .frame(width: 240, height: 240)
    }
}
```

Use a higher error correction level when the code may be printed small, damaged, or partly covered by a logo:

```swift
QRCodeView("https://skip.tools", correction: .high)
```

The code is always square and sharp: in a frame of any shape, it fits inside and is centered. Nothing is drawn when the text is empty or too long to encode.

### Exporting an Image

`QRCode` encodes text into a grid of modules. Use `pngData(scale:)` to save or share the code as an image:

```swift
let code = try QRCode("https://skip.tools")
if let png = code.pngData(scale: 10) {
    try png.write(to: URL.documentsDirectory.appending(path: "qrcode.png"))
}
```

`scale` is the number of pixels per module, so the image is `(code.size + 8) * scale` pixels wide. Encoding throws `QRCodeError.emptyText` or `QRCodeError.tooLong` when the text can't be encoded.

### Custom Rendering

Read the modules directly to draw the code in your own style:

```swift
let code = try QRCode("Skip")
for y in 0..<code.size {
    for x in 0..<code.size where code.isDark(x: x, y: y) {
        // draw a dot at (x, y)
    }
}
```

## Scanning QR Codes

### The Scanner

`QRScannerView` is a live camera preview. It reports the first QR code it sees, then dismisses the screen it is on: a sheet or full-screen cover closes, and a pushed view pops back. To keep scanning instead, pass `dismissesOnScan: false`, and it reports each code as it comes into view; a code that stays in view is reported once.

```swift
// Scan a series of codes on one screen
QRScannerView(dismissesOnScan: false) { code in scannedCodes.append(code) }
```

It is as flexible as any SwiftUI view, from a small box to the whole screen:

```swift
// A small square box
QRScannerView { code in scannedCode = code }
    .frame(width: 160, height: 160)
    .clipShape(RoundedRectangle(cornerRadius: 16))

// A full-width banner
QRScannerView { code in scannedCode = code }
    .frame(height: 320)

// The whole screen: no frame needed
QRScannerView { code in scannedCode = code }
    .ignoresSafeArea()
```

Without a frame it covers the screen: it takes all the space it is offered, and the screen's size along an axis left open, such as a `ScrollView`'s or `List`'s height. The camera image fills the view and is cropped to its shape, and only codes visible inside the view are reported.

`QRScannerView` only scans: show it when `CameraAccess.status` is `.authorized`.

### Torch

Set `isTorchOn` to light the scene in the dark. Offer the toggle only where `CameraAccess.hasTorch` is true:

```swift
@State var isTorchOn = false

QRScannerView(isTorchOn: isTorchOn) { code in scannedCode = code }
    .overlay(alignment: .bottomTrailing) {
        if CameraAccess.hasTorch {
            Toggle("Torch", systemImage: "flashlight.on.fill", isOn: $isTorchOn)
                .toggleStyle(.button)
                .padding()
        }
    }
```

### Scanning Once

To scan a single code, present the scanner. It closes itself on the first code, the same on iOS and Android:

```swift
.sheet(isPresented: $isScanning) {
    QRScannerView { code in scannedCode = code }
        .ignoresSafeArea()
}
```

Request camera access before presenting it, as described below.

### Camera Access

`CameraAccess` tells you whether the app can scan, asks the user while the system still can, and opens Settings when only the user can turn access back on:

```swift
struct ScanScreen: View {
    @State var status = CameraAccess.status
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            switch status {
            case .authorized:
                QRScannerView { code in print(code) }
            case .notDetermined:
                Button("Allow Camera") { Task { status = await CameraAccess.request() } }
            case .denied:
                Button("Open Settings") { Task { await CameraAccess.openSettings() } }
            case .restricted, .unsupported:
                Text("Scanning isn't available on this device")
            }
        }
        .task { status = await CameraAccess.request() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { status = CameraAccess.status } // back from Settings
        }
    }
}
```

| Status | Meaning | Next step |
|---|---|---|
| `.authorized` | Access granted and the device can scan | Show `QRScannerView` |
| `.notDetermined` | Access isn't granted, and the system may still ask | `CameraAccess.request()` |
| `.denied` | The user turned access off | `CameraAccess.openSettings()` |
| `.restricted` | Blocked by device policy, such as parental controls | Explain; the user can't change it |
| `.unsupported` | No usable camera, or the iOS Simulator | Hide scanning |

Every check reads the system's current state, with nothing cached, so changes made in Settings are always seen. On Android, the system reports a refusal only to the request that got it, so `status` reports `.notDetermined` until `request()` finds out. `request()` asks from an invisible activity, and in `onRequestPermissionsResult` checks whether Android will show the prompt again; after the user refuses twice it returns `.denied`, and `status` reports `.denied` from then on while the app runs. That can't go stale: Android restarts the app when access is revoked in Settings, and a grant there is read directly. Calls made while the prompt is showing share it. Calling `request()` when the scanner appears, as above, takes the user straight to the right step.

## API Reference

### `QRCodeView`

```swift
public struct QRCodeView: View {
    public init(_ text: String, correction: QRCorrection = .medium)
}
```

### `QRCode`

```swift
public struct QRCode {
    public let size: Int
    public init(_ text: String, correction: QRCorrection = .medium) throws
    public func isDark(x: Int, y: Int) -> Bool
    public func pngData(scale: Int = 10) -> Data?
}
```

- `size`: Modules on each side, excluding the quiet zone (21 to 177)
- `init`: Throws `QRCodeError.emptyText` or `QRCodeError.tooLong` when the text can't be encoded
- `isDark(x:y:)`: Whether a module is dark; modules outside the grid are light
- `pngData(scale:)`: PNG image, black on white with a 4-module quiet zone

### `QRCorrection`

How much of the code can be damaged and still be read: `.low` (7%), `.medium` (15%), `.quartile` (25%) or `.high` (30%).

### `QRScannerView`

```swift
public struct QRScannerView: View {
    public init(isTorchOn: Bool = false, dismissesOnScan: Bool = true, onScan: @escaping (String) -> Void)
}
```

- `isTorchOn`: Whether the back camera's torch is on, where `CameraAccess.hasTorch` is true
- `dismissesOnScan`: Whether to dismiss the scanner's screen after reporting the first code; when `false`, it keeps scanning
- `onScan`: Called on the main thread with the QR code's text, before the screen is dismissed

### `CameraAccess`

Main-actor camera permission checks for `QRScannerView`.

```swift
public struct CameraAccess {
    public static var status: CameraStatus { get }
    public static var hasTorch: Bool { get }
    public static func request() async -> CameraStatus
    public static func openSettings() async -> Bool
}
```

- `status`: The current status, without asking the user
- `hasTorch`: Whether the back camera has a torch for `QRScannerView(isTorchOn:)`
- `request()`: Asks the user only while the status is `.notDetermined`, then returns the new status
- `openSettings()`: Opens the app's page in Settings (iOS) or App info (Android)

### `CameraStatus`

`.authorized`, `.notDetermined`, `.denied`, `.restricted` or `.unsupported`. See [Camera Access](#camera-access).

## Architecture

SkipQRCode is a transpiled Skip package with bridging, so it works in both Skip Lite and Skip Fuse apps.

| | iOS | Android |
|---|---|---|
| Generation | Core Image `CIQRCodeGenerator` → SwiftUI `Image` | [ZXing](https://github.com/zxing/zxing) → `Bitmap` → Compose `Image` |
| Scanning | VisionKit `DataScannerViewController` | CameraX preview + ML Kit barcode scanning (`QRScanner.kt`) |
| Torch | `AVCaptureDevice.torchMode` | `CameraController.enableTorch` |
| Camera access | `AVCaptureDevice` authorization status | `CameraPermissionActivity` with `onRequestPermissionsResult` |

## Requirements

- **iOS**: 17.0 or later; scanning needs a device with a camera, not the Simulator
- **Android**: the minimum Android version supported by Skip
- **Skip**: 1.6.27 or later

## Building and Testing

Install Skip using [Homebrew](https://brew.sh):

```bash
brew install skiptools/skip/skip
```

Run the tests on macOS and, transpiled, on Robolectric:

```bash
swift test
```

## Troubleshooting

**The scanner stays black**
- Check that `CameraAccess.status` is `.authorized` before showing `QRScannerView`
- On iOS, check that `NSCameraUsageDescription` is in your `Info.plist`
- On Android, check Logcat for errors tagged `QRScanner` or `CameraPermissionActivity`

**Codes aren't detected**
- `QRScannerView` reads QR codes only, not other barcode types
- Only codes fully inside the view are reported; in a small box, move the code into the frame
- Make sure the code is well lit

## License

This software is licensed under the
[Mozilla Public License 2.0](https://www.mozilla.org/MPL/).
