package skip.qrcode

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.view.View
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
        super.onCreate(savedInstanceState)
        
        try {
            
            // Create layout programmatically to avoid resource merging issues
            val rootLayout = androidx.constraintlayout.widget.ConstraintLayout(this).apply {
                setBackgroundColor(android.graphics.Color.BLACK)
                layoutParams = android.view.ViewGroup.LayoutParams(
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT
                )
            }
            
            // Camera preview
            previewView = PreviewView(this).apply {
                id = View.generateViewId()
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(
                    androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.MATCH_PARENT,
                    androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.MATCH_PARENT
                )
            }
            rootLayout.addView(previewView)
            
            // Bottom controls container
            val bottomControls = android.widget.LinearLayout(this).apply {
                id = View.generateViewId()
                orientation = android.widget.LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.CENTER
                setPadding(48, 48, 48, 48)
                layoutParams = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams(
                    androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.MATCH_PARENT,
                    androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomToBottom = androidx.constraintlayout.widget.ConstraintLayout.LayoutParams.PARENT_ID
                }
            }
            
            // Torch button
            torchButton = Button(this).apply {
                text = "Torch"
                setTextColor(android.graphics.Color.WHITE)
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                layoutParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    marginEnd = 32
                }
            }
            bottomControls.addView(torchButton)
            
            // Close button
            closeButton = Button(this).apply {
                text = "Close"
                setTextColor(android.graphics.Color.WHITE)
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                layoutParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }
            bottomControls.addView(closeButton)
            
            rootLayout.addView(bottomControls)
            setContentView(rootLayout)

            cameraExecutor = Executors.newSingleThreadExecutor()

            torchButton.setOnClickListener {
                toggleTorch()
            }

            closeButton.setOnClickListener {
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
            if (hasCameraPermission()) {
                startCamera()
            } else {
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
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

            cameraProviderFuture.addListener({
                try {
                    val cameraProvider = cameraProviderFuture.get()
                    bindCameraUseCases(cameraProvider)
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
        camera?.let {
            val currentState = it.cameraInfo.torchState.value == TorchState.ON
            it.cameraControl.enableTorch(!currentState)
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