package skip.qrcode

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.core.app.ActivityCompat

/**
 * Invisible activity that asks for camera access and reports the outcome as a [CameraStatus].
 *
 * Backs `CameraAccess.request()` on Android. Requests made while the prompt is showing share it,
 * and all receive its answer.
 */
class CameraPermissionActivity : ComponentActivity() {

    companion object {
        private const val TAG = "CameraPermissionActivity"
        private const val CAMERA_PERMISSION_REQUEST = 101

        /** Callbacks waiting on the prompt in progress; guarded by its own lock. */
        private val pending = mutableListOf<(CameraStatus) -> Unit>()

        /**
         * The outcome of the last request in this process. Android reports a refusal only to the
         * request that got it, so this is how `CameraAccess.status` knows access is `denied`. It can't
         * go stale: Android restarts the app when a permission is revoked in Settings, and a grant
         * there is read from the system directly.
         */
        @Volatile
        var lastResult: CameraStatus? = null
            private set

        /**
         * Asks for camera access from any context. [onResult] is called once on the main thread with
         * `authorized`, `notDetermined` when Android will still show the prompt, or `denied` once it won't.
         */
        @JvmStatic
        fun request(context: Context, onResult: (CameraStatus) -> Unit) {
            val isFirst = synchronized(pending) {
                pending += onResult
                pending.size == 1
            }
            if (!isFirst) return

            Log.d(TAG, "Requesting camera permission")
            val intent = Intent(context, CameraPermissionActivity::class.java)
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }

        private fun deliver(status: CameraStatus) {
            lastResult = status
            val callbacks = synchronized(pending) { pending.toList().also { pending.clear() } }
            callbacks.forEach { it(status) }
        }
    }

    /** Set once the prompt answers, so closing afterwards doesn't report a second outcome. */
    private var isAnswered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // When recreated mid-request, the pending request still answers through onRequestPermissionsResult
        if (savedInstanceState != null) return
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
    }

    @Suppress("OVERRIDE_DEPRECATION") // ComponentActivity prefers the Activity Result API; this activity answers its own request
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_REQUEST) return

        val status = when {
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED -> CameraStatus.authorized
            // An interrupted request, or a first refusal: Android still shows the prompt next time
            grantResults.isEmpty() ||
                ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA) -> CameraStatus.notDetermined
            // Refused twice: only Settings can turn access back on
            else -> CameraStatus.denied
        }
        Log.d(TAG, "Camera permission result: $status")
        isAnswered = true
        deliver(status)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Closed without an answer, so nothing is decided yet
        if (isFinishing && !isAnswered) deliver(CameraStatus.notDetermined)
    }
}
