// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception

import Foundation

#if !SKIP_BRIDGE
// Transpiled implementation - only included when NOT bridging

/// Barcode scanner for Android.
public struct AndroidBarcodeScanner {
    
    /// Launch the barcode scanner on Android.
    /// - Parameter completion: Called with the scanned barcode string, or nil if cancelled/failed
    public static func scan(completion: @escaping @Sendable (String?) -> Void) {
        #if SKIP
        let ctx = ProcessInfo.processInfo.androidContext
        skip.qrcode.ScanHostActivity.clearResult()
        skip.qrcode.ScanHostActivity.launch(ctx)
        
        Task.detached {
            for _ in 0..<600 {
                let hasResult = skip.qrcode.ScanHostActivity.hasResult()
                if hasResult {
                    let resultCode = skip.qrcode.ScanHostActivity.getResultCode()
                    let barcode = skip.qrcode.ScanHostActivity.getBarcode()
                    skip.qrcode.ScanHostActivity.clearResult()
                    
                    if resultCode == android.app.Activity.RESULT_OK {
                        completion(barcode)
                    } else {
                        completion(nil)
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            completion(nil)
        }
        #else
        completion(nil)
        #endif
    }
}

#endif
