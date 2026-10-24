// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
#if SKIP
import android.graphics.Bitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.nio.charset.StandardCharsets
#else
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
#endif

/// How much of a QR code can be damaged or covered and still be read.
///
/// Higher levels are more robust but need more modules for the same text.
public enum QRCorrection: Sendable {
    /// Recovers about 7% of the code.
    case low
    /// Recovers about 15% of the code.
    case medium
    /// Recovers about 25% of the code.
    case quartile
    /// Recovers about 30% of the code.
    case high
}

/// Why text could not be encoded as a QR code.
public enum QRCodeError: Error, Sendable {
    /// The text is empty.
    case emptyText
    /// The text does not fit, even in the largest QR code at the chosen correction level.
    case tooLong
}

/// A QR code symbol: a square grid of dark and light modules.
///
/// Encoding uses Core Image on Apple platforms and [ZXing](https://github.com/zxing/zxing) on Android.
public struct QRCode: Sendable {
    /// The number of modules on each side, excluding the quiet zone.
    public let size: Int
    private let modules: [Bool]

    /// Encodes `text`, throwing `QRCodeError` when it is empty or too long to fit in a QR code.
    public init(_ text: String, correction: QRCorrection = .medium) throws {
        guard !text.isEmpty else { throw QRCodeError.emptyText }
        #if SKIP
        let hints = java.util.HashMap<EncodeHintType, Any>()
        hints.put(EncodeHintType.ERROR_CORRECTION, correction.level)
        hints.put(EncodeHintType.MARGIN, 0)
        if !StandardCharsets.US_ASCII.newEncoder().canEncode(text) {
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8")
        }
        guard let matrix = try? QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, hints) else { throw QRCodeError.tooLong }
        let n = matrix.width
        modules = (0..<n * n).map { matrix.get($0 % n, $0 / n) }
        size = n
        #else
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = correction.level
        guard let image = filter.outputImage else { throw QRCodeError.tooLong }
        // Core Image adds a one-module light border, which is dropped here.
        let width = Int(image.extent.width)
        let n = width - 2
        var pixels = [UInt8](repeating: 0, count: width * width)
        CIContext().render(image, toBitmap: &pixels, rowBytes: width, bounds: image.extent, format: .L8, colorSpace: nil)
        modules = (0..<n * n).map { pixels[($0 / n + 1) * width + $0 % n + 1] < 128 }
        size = n
        #endif
    }

    /// Whether the module at column `x`, row `y` is dark. Modules outside the grid are light.
    public func isDark(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < size && y < size && modules[y * size + x]
    }

    /// PNG image of the code, black on white with a quiet zone, `scale` pixels per module.
    public func pngData(scale: Int = 10) -> Data? {
        #if SKIP
        let stream = java.io.ByteArrayOutputStream()
        guard bitmap(scale: scale).compress(Bitmap.CompressFormat.PNG, 100, stream) else { return nil }
        return Data(platformValue: stream.toByteArray())
        #else
        guard let image = cgImage(scale: scale) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
        #endif
    }

    /// Width of the light border around the code, in modules, as required by the QR specification.
    static let quietZone = 4

    /// Side length of a rendered image in pixels.
    func imageWidth(scale: Int) -> Int {
        (size + 2 * Self.quietZone) * scale
    }

    /// Whether pixel `index` of a row-major image `imageWidth(scale:)` wide is dark.
    func isDark(pixel index: Int, scale: Int) -> Bool {
        let width = imageWidth(scale: scale)
        return isDark(x: index % width / scale - Self.quietZone, y: index / width / scale - Self.quietZone)
    }

    #if SKIP
    /// The code as a bitmap, black on white with a quiet zone, `scale` pixels per module.
    func bitmap(scale: Int = 1) -> Bitmap {
        let width = imageWidth(scale: scale)
        let colors = IntArray(width * width)
        for i in 0..<colors.size {
            colors[i] = isDark(pixel: i, scale: scale) ? android.graphics.Color.BLACK : android.graphics.Color.WHITE
        }
        return Bitmap.createBitmap(colors, width, width, Bitmap.Config.ARGB_8888)
    }
    #else
    /// The code as an image, black on white with a quiet zone, `scale` pixels per module.
    func cgImage(scale: Int = 1) -> CGImage? {
        let width = imageWidth(scale: scale)
        let pixels = (0..<width * width).map { isDark(pixel: $0, scale: scale) ? UInt8(0) : UInt8(255) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: width, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
    #endif
}

extension QRCorrection {
    #if SKIP
    var level: ErrorCorrectionLevel {
        switch self {
        	case .low: return ErrorCorrectionLevel.L
        	case .medium: return ErrorCorrectionLevel.M
        	case .quartile: return ErrorCorrectionLevel.Q
        	case .high: return ErrorCorrectionLevel.H
        }
    }
    #else
    var level: String {
        switch self {
        	case .low: "L"
        	case .medium: "M"
        	case .quartile: "Q"
        	case .high: "H"
        }
    }
    #endif
}
#endif
