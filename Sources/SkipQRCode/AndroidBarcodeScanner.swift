// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception

import Foundation
import SkipFuse

/// Bridge utility for launching the Android barcode scanner and receiving results.
/// This provides a callback-based API for Swift code to interact with the native Android scanner.
public enum AndroidBarcodeScanner {
    
    /// Launch the barcode scanner on Android.
    /// - Parameter completion: Called with the scanned barcode string, or nil if cancelled/failed
    public static func scan(completion: @escaping @Sendable (String?) -> Void) {
        #if os(Android)
        logger.info("AndroidBarcodeScanner.scan: starting...")
        
        // Get application context from Skip Fuse
        let ctx = ProcessInfo.processInfo.dynamicAndroidContext()
        logger.info("AndroidBarcodeScanner.scan: got context")
        
        // Use AnyDynamicObject to access the ScanHostActivity Kotlin class
        do {
            logger.info("AndroidBarcodeScanner.scan: accessing ScanHostActivity statics...")
            // Access the static methods of ScanHostActivity
            let scanHostStatics = try AnyDynamicObject(forStaticsOfClassName: "skip.qrcode.ScanHostActivity")
            logger.info("AndroidBarcodeScanner.scan: got statics object")
            
            // Clear any previous results
            try scanHostStatics.clearResult() as Void
            logger.info("AndroidBarcodeScanner.scan: cleared previous results")
            
            // Launch the scanner
            logger.info("AndroidBarcodeScanner.scan: calling launch()...")
            try scanHostStatics.launch(ctx) as Void
            logger.info("AndroidBarcodeScanner.scan: launch() called successfully")
            
            // Poll for results on a detached background task
            Task.detached {
                logger.info("AndroidBarcodeScanner: starting polling task...")
                await pollForResult(scanHostStatics: scanHostStatics, completion: completion)
            }
            
        } catch {
            logger.error("AndroidBarcodeScanner: failed to launch scanner - \(error)")
            completion(nil)
        }
        #else
        // On non-Android platforms, immediately return nil
        completion(nil)
        #endif
    }
    
    #if os(Android)
    /// Poll the Kotlin activity for results
    private static func pollForResult(scanHostStatics: AnyDynamicObject, completion: @escaping (String?) -> Void) async {
        // Poll for up to 60 seconds
        for _ in 0..<600 {
            do {
                let hasResult: Bool = try scanHostStatics.hasResult() ?? false
                
                if hasResult {
                    logger.info("AndroidBarcodeScanner: result is ready")
                    let resultCode: Int = try scanHostStatics.getResultCode() ?? 0
                    let barcode: String? = try? scanHostStatics.getBarcode()
                    
                    logger.info("AndroidBarcodeScanner: resultCode=\(resultCode), barcode=\(barcode ?? "nil")")
                    
                    // Clear the result
                    try? scanHostStatics.clearResult() as Void
                    
                    // RESULT_OK = -1 in Android
                    if resultCode == -1 {
                        completion(barcode)
                    } else {
                        completion(nil)
                    }
                    return
                }
            } catch {
                logger.error("AndroidBarcodeScanner: error polling result - \(error)")
            }
            
            // Wait 100ms before polling again
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        logger.info("AndroidBarcodeScanner: polling timeout")
        completion(nil)
    }
    #endif
}