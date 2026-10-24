// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
#if SKIP
import SwiftUI
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
#elseif os(iOS)
import AVFoundation
import UIKit
import VisionKit
#endif

/// Whether the app can use the camera to scan, and what to do when it can't.
public enum CameraStatus: Sendable {
    /// Access is granted and the device can scan: show `QRScannerView`.
    case authorized
    /// Access isn't granted, and the system may still ask the user: call `CameraAccess.request()`.
    case notDetermined
    /// The user turned access off, and only Settings can turn it back on: call `CameraAccess.openSettings()`.
    case denied
    /// Device policy, such as parental controls, blocks the camera, and the user can't change it.
    case restricted
    /// The device can't scan, for example without a camera or in the iOS Simulator.
    case unsupported
}

/// Camera permission checks for `QRScannerView`.
///
/// Check `status` before showing the scanner, `request()` access while it is `.notDetermined`,
/// and `openSettings()` once access is `.denied`. Check `status` again when the app becomes
/// active, since the user may have changed access in Settings.
///
/// Every check reads the system's current state, so changes made in Settings are always seen.
/// On Android, the system reports a refusal only to the request that got it, so `status` reports
/// `.notDetermined` until `request()` finds out, and `.denied` from then on while the app runs.
/// That can't go stale: Android restarts the app when access is revoked in Settings, and a grant
/// there is read directly.
@MainActor
public struct CameraAccess {
    /// The current camera status, without asking the user.
    public static var status: CameraStatus {
        #if SKIP
        let context = ProcessInfo.processInfo.androidContext
        guard context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) else { return .unsupported }
        if ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED {
            return .authorized
        }
        // Android reports a refusal only to the request that got it
        return CameraPermissionActivity.lastResult == CameraStatus.denied ? .denied : .notDetermined
        #elseif os(iOS)
        guard DataScannerViewController.isSupported else { return .unsupported }
        return switch AVCaptureDevice.authorizationStatus(for: .video) {
        	case .authorized: .authorized
        	case .notDetermined: .notDetermined
        	case .restricted: .restricted
        	default: .denied
        }
        #else
        return .unsupported
        #endif
    }

    /// Whether the back camera has a torch that `QRScannerView` can turn on.
    public static var hasTorch: Bool {
        #if SKIP
        return ProcessInfo.processInfo.androidContext.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
        #elseif os(iOS)
        return AVCaptureDevice.scannerCamera?.hasTorch ?? false
        #else
        return false
        #endif
    }

    /// Asks the user for camera access while the system can still ask, and returns the resulting status.
    ///
    /// Returns the current status at once, without asking, when it is anything but `.notDetermined`.
    /// Calls made while the prompt is showing wait for its answer rather than asking again.
    @discardableResult
    public static func request() async -> CameraStatus {
        let current = status
        guard current == .notDetermined else { return current }
        #if SKIP
        // CameraPermissionActivity asks, then reads whether Android will ask again
        let context = UIApplication.shared.androidActivity ?? ProcessInfo.processInfo.androidContext
        return suspendCoroutine { continuation in
            CameraPermissionActivity.request(context) { result in
                continuation.resume(result)
            }
        }
        #elseif os(iOS)
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return status
        #else
        return current
        #endif
    }

    /// Opens this app's page in Settings, where the user can turn camera access back on.
    @discardableResult
    public static func openSettings() async -> Bool {
        #if SKIP || os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        return await UIApplication.shared.open(url)
        #else
        return false
        #endif
    }
}
#endif
