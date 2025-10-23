package skip.qrcode

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * CameraX + ML Kit barcode scanner activity.
 * Returns the scanned barcode value via RESULT_OK intent extra "barcode".
 */
class MLKitScanActivity : AppCompatActivity() {

    private lateinit var cameraExecutor: ExecutorService
    private lateinit var previewView: PreviewView
    private lateinit var torchButton: Button
    private lateinit var closeButton: Button
    
    private var camera: Camera? = null
    private var isProcessing = false

    companion object {
        private const val TAG = "MLKitScanActivity"
        private const val CAMERA_PERMISSION_REQUEST = 100
        const val EXTRA_BARCODE = "barcode"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "onCreate() called")
        super.onCreate(savedInstanceState)
        
        try {
            Log.d(TAG, "Setting content view...")
            setContentView(R.layout.activity_mlkit_scan)

            Log.d(TAG, "Finding views...")
            previewView = findViewById(R.id.previewView)
            torchButton = findViewById(R.id.torchButton)
            closeButton = findViewById(R.id.closeButton)

            Log.d(TAG, "Creating camera executor...")
            cameraExecutor = Executors.newSingleThreadExecutor()

            torchButton.setOnClickListener {
                Log.d(TAG, "Torch button clicked")
                toggleTorch()
            }

            closeButton.setOnClickListener {
                Log.d(TAG, "Close button clicked")
                setResult(Activity.RESULT_CANCELED)
                finish()
            }

            Log.d(TAG, "Checking camera permission...")
            if (hasCameraPermission()) {
                Log.d(TAG, "Camera permission granted, starting camera")
                startCamera()
            } else {
                Log.d(TAG, "Camera permission not granted, requesting...")
                requestCameraPermission()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate", e)
            Toast.makeText(this, "Failed to initialize scanner: ${e.message}", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_REQUEST) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                Toast.makeText(this, "Camera permission required", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private fun startCamera() {
        Log.d(TAG, "startCamera() called")
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
            Log.d(TAG, "Got camera provider future")

            cameraProviderFuture.addListener({
                try {
                    Log.d(TAG, "Camera provider listener called")
                    val cameraProvider = cameraProviderFuture.get()
                    Log.d(TAG, "Got camera provider, binding use cases...")
                    bindCameraUseCases(cameraProvider)
                    Log.d(TAG, "Camera use cases bound successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Camera initialization failed", e)
                    Toast.makeText(this, "Failed to start camera: ${e.message}", Toast.LENGTH_SHORT).show()
                    finish()
                }
            }, ContextCompat.getMainExecutor(this))
        } catch (e: Exception) {
            Log.e(TAG, "Error in startCamera()", e)
            Toast.makeText(this, "Camera setup failed: ${e.message}", Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    private fun bindCameraUseCases(cameraProvider: ProcessCameraProvider) {
        val preview = Preview.Builder()
            .build()
            .also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also {
                it.setAnalyzer(cameraExecutor, BarcodeAnalyzer { barcode ->
                    handleBarcodeDetected(barcode)
                })
            }

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            cameraProvider.unbindAll()
            camera = cameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalysis
            )
        } catch (e: Exception) {
            Log.e(TAG, "Use case binding failed", e)
        }
    }

    private fun handleBarcodeDetected(barcode: String) {
        if (isProcessing) return
        isProcessing = true

        runOnUiThread {
            val resultIntent = Intent().apply {
                putExtra(EXTRA_BARCODE, barcode)
            }
            setResult(Activity.RESULT_OK, resultIntent)
            finish()
        }
    }

    private fun toggleTorch() {
        camera?.let { cam ->
            val currentState = cam.cameraInfo.torchState.value ?: TorchState.OFF
            val newState = currentState == TorchState.OFF
            cam.cameraControl.enableTorch(newState)
            torchButton.text = if (newState) "Torch On" else "Torch"
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    /**
     * Analyzer that processes camera frames with ML Kit barcode scanning
     */
    private class BarcodeAnalyzer(
        private val onBarcodeDetected: (String) -> Unit
    ) : ImageAnalysis.Analyzer {

        private val scanner = BarcodeScanning.getClient()

        @androidx.camera.core.ExperimentalGetImage
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage != null) {
                val image = InputImage.fromMediaImage(
                    mediaImage,
                    imageProxy.imageInfo.rotationDegrees
                )

                scanner.process(image)
                    .addOnSuccessListener { barcodes ->
                        for (barcode in barcodes) {
                            when (barcode.valueType) {
                                Barcode.TYPE_TEXT,
                                Barcode.TYPE_URL,
                                Barcode.TYPE_PRODUCT,
                                Barcode.TYPE_CONTACT_INFO,
                                Barcode.TYPE_EMAIL,
                                Barcode.TYPE_PHONE,
                                Barcode.TYPE_SMS,
                                Barcode.TYPE_WIFI,
                                Barcode.TYPE_GEO,
                                Barcode.TYPE_CALENDAR_EVENT,
                                Barcode.TYPE_DRIVER_LICENSE -> {
                                    barcode.rawValue?.let { value ->
                                        onBarcodeDetected(value)
                                        return@addOnSuccessListener
                                    }
                                }
                            }
                        }
                    }
                    .addOnFailureListener {
                        Log.e(TAG, "Barcode scanning failed", it)
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            } else {
                imageProxy.close()
            }
        }
    }
}