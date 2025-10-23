package skip.qrcode

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Transparent trampoline activity that launches MLKitScanActivity for result,
 * then forwards the result to a static callback and finishes immediately.
 * 
 * This allows Skip Swift code to use a simple callback pattern instead of
 * managing Android's activity-for-result contract directly.
 */
class ScanHostActivity : ComponentActivity() {

    companion object {
        private const val TAG = "ScanHostActivity"
        
        // Simple result storage that Swift can poll
        @Volatile
        private var lastResultCode: Int? = null
        
        @Volatile
        private var lastBarcode: String? = null
        
        @Volatile
        private var resultReady = false

        /**
         * Launch the barcode scanner from any context.
         * Swift should poll hasResult() and then call getResultCode() / getBarcode()
         */
        @JvmStatic
        fun launch(context: Context) {
            Log.d(TAG, "launch() called with context=$context")
            // Clear previous results
            lastResultCode = null
            lastBarcode = null
            resultReady = false
            
            val intent = Intent(context, ScanHostActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            Log.d(TAG, "Starting ScanHostActivity...")
            context.startActivity(intent)
            Log.d(TAG, "startActivity() completed")
        }
        
        @JvmStatic
        fun hasResult(): Boolean {
            return resultReady
        }
        
        @JvmStatic
        fun getResultCode(): Int {
            return lastResultCode ?: Activity.RESULT_CANCELED
        }
        
        @JvmStatic
        fun getBarcode(): String? {
            return lastBarcode
        }
        
        @JvmStatic
        fun clearResult() {
            lastResultCode = null
            lastBarcode = null
            resultReady = false
        }
        
        private fun setResult(resultCode: Int, barcode: String?) {
            Log.d(TAG, "setResult: resultCode=$resultCode, barcode=$barcode")
            lastResultCode = resultCode
            lastBarcode = barcode
            resultReady = true
        }
    }

    private val launcher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        Log.d(TAG, "Activity result received: resultCode=${result.resultCode}")
        
        // Extract barcode from result intent if successful
        val barcode = if (result.resultCode == Activity.RESULT_OK) {
            result.data?.getStringExtra(MLKitScanActivity.EXTRA_BARCODE)
        } else {
            null
        }
        
        // Store result in companion object for Swift to poll
        Companion.setResult(result.resultCode, barcode)
        
        Log.d(TAG, "Finishing ScanHostActivity")
        finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "onCreate() called")
        super.onCreate(savedInstanceState)
        // Immediately launch the scanner activity
        try {
            val scanIntent = Intent(this, MLKitScanActivity::class.java)
            Log.d(TAG, "Launching MLKitScanActivity...")
            launcher.launch(scanIntent)
            Log.d(TAG, "launcher.launch() completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error launching MLKitScanActivity", e)
            Companion.setResult(Activity.RESULT_CANCELED, null)
            finish()
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy() called")
        super.onDestroy()
    }
}