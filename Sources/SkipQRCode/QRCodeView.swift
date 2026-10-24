// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import SwiftUI
#if SKIP
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
#endif

/// Displays text as a QR code, black on white with a quiet zone.
///
/// The code scales to fit the available space while staying square and sharp.
/// Nothing is drawn when the text is empty or too long to encode.
public struct QRCodeView: View {
    let text: String
    let correction: QRCorrection

    public init(_ text: String, correction: QRCorrection = .medium) {
        self.text = text
        self.correction = correction
    }

    #if SKIP
    public var body: some View {
        ComposeView { context in
            let bitmap = remember(text, correction) { (try? QRCode(text, correction: correction))?.bitmap().asImageBitmap() }
            if let bitmap {
                androidx.compose.foundation.Image(bitmap: bitmap, contentDescription: nil, modifier: context.modifier.aspectRatio(Float(1.0)), contentScale: ContentScale.Fit, filterQuality: FilterQuality.None)
            }
        }
    }
    #else
    public var body: some View {
        if let image = (try? QRCode(text, correction: correction))?.cgImage() {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(1, contentMode: .fit)
        }
    }
    #endif
}
#endif
