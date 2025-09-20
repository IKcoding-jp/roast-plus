package com.ikcoding.roastplus

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.common.GoogleApiAvailability

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.ikcoding.roastplus/firebase_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFirebaseConfig" -> {
                    try {
                        val config = mapOf(
                            "apiKey" to BuildConfig.FIREBASE_API_KEY,
                            "appId" to BuildConfig.FIREBASE_APP_ID,
                            "projectId" to BuildConfig.FIREBASE_PROJECT_ID,
                            "storageBucket" to BuildConfig.FIREBASE_STORAGE_BUCKET,
                            "messagingSenderId" to BuildConfig.MESSAGING_SENDER_ID,
                            "googleSignInClientId" to BuildConfig.GOOGLE_SIGN_IN_CLIENT_ID
                        )
                        result.success(config)
                    } catch (e: Exception) {
                        result.error("CONFIG_ERROR", "Failed to get Firebase config", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // Google Play Services の可用性をチェック
        val googleApiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = googleApiAvailability.isGooglePlayServicesAvailable(this)

        if (resultCode != com.google.android.gms.common.ConnectionResult.SUCCESS) {
            // Google Play Services が利用できない場合の処理
            android.util.Log.w("MainActivity", "Google Play Services が利用できません: $resultCode")
        }
    }
}
