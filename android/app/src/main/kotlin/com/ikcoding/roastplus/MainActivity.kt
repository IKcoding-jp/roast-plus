package com.ikcoding.roastplus

import io.flutter.embedding.android.FlutterFragmentActivity
import com.google.android.gms.common.GoogleApiAvailability

class MainActivity : FlutterFragmentActivity() {
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
