package skip.qrcode

import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.ImageAnalysis
import androidx.camera.mlkit.vision.MlKitAnalyzer
import androidx.camera.view.CameraController
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode

private const val TAG = "QRScanner"

/** A value seen again within this many milliseconds is treated as still in view, and not reported again. */
private const val REPEAT_INTERVAL_MS = 1_500L

/**
 * Live camera preview that reports each QR code as it comes into view, using CameraX and ML Kit.
 *
 * The preview fills [modifier]'s bounds, cropping the camera image to them, and only codes inside
 * those bounds are reported, so a small box scans just what it shows. Along an axis its parent leaves
 * unbounded, such as a scroll view's, it takes the window's size.
 * Camera access must already be granted; without it the preview stays black.
 * [isTorchOn] lights the scene on devices with a flash unit.
 */
@Composable
fun QRScanner(modifier: Modifier, isTorchOn: Boolean, onScan: (String) -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnScan by rememberUpdatedState(onScan)
    val currentIsTorchOn by rememberUpdatedState(isTorchOn)
    val windowSize = LocalWindowInfo.current.containerSize
    val previewView = remember {
        PreviewView(context).apply {
            // TextureView-backed, so the preview follows Compose clipping such as rounded corners
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }

    val controller = remember {
        LifecycleCameraController(context).apply { setEnabledUseCases(CameraController.IMAGE_ANALYSIS) }
    }

    LaunchedEffect(controller, isTorchOn) {
        controller.enableTorch(isTorchOn)
    }

    DisposableEffect(lifecycleOwner) {
        val mainExecutor = ContextCompat.getMainExecutor(context)
        val scanner = BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
        )
        // A torch request made before the camera is attached is dropped, so apply it again once frames stream
        val streamObserver = Observer<PreviewView.StreamState> { state ->
            if (state == PreviewView.StreamState.STREAMING) controller.enableTorch(currentIsTorchOn)
        }
        previewView.previewStreamState.observe(lifecycleOwner, streamObserver)
        var lastValue: String? = null
        var lastSeen = 0L

        // View-referenced coordinates map each code into the preview, so codes cropped out of view are skipped
        val analyzer = MlKitAnalyzer(listOf(scanner), ImageAnalysis.COORDINATE_SYSTEM_VIEW_REFERENCED, mainExecutor) analyze@{ result ->
            val bounds = Rect(0, 0, previewView.width, previewView.height)
            val value = result.getValue(scanner)
                ?.firstOrNull { barcode -> barcode.boundingBox?.let(bounds::contains) == true }
                ?.rawValue
                ?: return@analyze
            val now = SystemClock.elapsedRealtime()
            if (value != lastValue || now - lastSeen > REPEAT_INTERVAL_MS) currentOnScan(value)
            lastValue = value
            lastSeen = now
        }
        controller.setImageAnalysisAnalyzer(mainExecutor, analyzer)
        previewView.controller = controller
        try {
            controller.bindToLifecycle(lifecycleOwner)
        } catch (e: Exception) {
            Log.e(TAG, "Could not start the camera", e)
        }

        onDispose {
            previewView.previewStreamState.removeObserver(streamObserver)
            previewView.controller = null
            controller.unbind()
            scanner.close()
        }
    }

    AndroidView(factory = { previewView }, modifier = modifier.fillWhenUnbounded(windowSize))
}

/** Fills the parent's bounds, and takes [size] along any axis the parent leaves unbounded. */
private fun Modifier.fillWhenUnbounded(size: IntSize) = layout { measurable, constraints ->
    val width = if (constraints.hasBoundedWidth) constraints.maxWidth else size.width
    val height = if (constraints.hasBoundedHeight) constraints.maxHeight else size.height
    val placeable = measurable.measure(Constraints.fixed(width, height))
    layout(width, height) { placeable.place(0, 0) }
}
