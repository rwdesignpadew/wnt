package pl.wnt.wnt_driver

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingPhone: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.wnt/phone")
            .setMethodCallHandler { call, result ->
                if (call.method != "call") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = call.argument<String>("phone")?.trim().orEmpty()
                if (phone.isBlank()) {
                    result.error("invalid_phone", "Brak numeru telefonu.", null)
                    return@setMethodCallHandler
                }
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                    startDirectCall(phone)
                } else {
                    pendingPhone = phone
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), 7312)
                }
                result.success(true)
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7312 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            pendingPhone?.let(::startDirectCall)
        }
        pendingPhone = null
    }

    private fun startDirectCall(phone: String) {
        startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:${Uri.encode(phone)}")))
    }
}
