package com.example.kagri_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.net.wifi.WifiManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kagri.app/wifi"
    private val PERMISSION_REQUEST_CODE = 123

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanWiFi" -> {
                        scanWiFiNetworks(result)
                    }
                    "isWiFiEnabled" -> {
                        result.success(isWiFiEnabled())
                    }
                    "requestWiFiPermission" -> {
                        requestWiFiPermission(result)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun scanWiFiNetworks(result: MethodChannel.Result) {
        // Check if WiFi permission is granted
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "WiFi scan permission not granted", null)
            return
        }

        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            // Start WiFi scan
            wifiManager.startScan()
            
            // Get scan results
            val scanResults = wifiManager.scanResults
            
            // Extract SSID list (remove empty and duplicates)
            val networks = scanResults
                .mapNotNull { it.SSID }
                .filter { it.isNotEmpty() }
                .distinct()
                .sorted()
            
            result.success(networks)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", "WiFi scan failed: ${e.message}", null)
        }
    }

    private fun isWiFiEnabled(): Boolean {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            return wifiManager.isWifiEnabled
        } catch (e: Exception) {
            return false
        }
    }

    private fun requestWiFiPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                PERMISSION_REQUEST_CODE
            )
            result.success(false) // Will be granted after user responds
        }
    }
}
