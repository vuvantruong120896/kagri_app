import 'package:flutter/services.dart';

/// Service for scanning WiFi networks on the device
class WiFiScanService {
  static const platform = MethodChannel('com.kagri.app/wifi');

  /// Scan available WiFi networks
  /// Returns list of WiFi SSID names
  static Future<List<String>> scanWiFiNetworks() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('scanWiFi');

      // Convert dynamic list to List<String> and remove duplicates
      final Set<String> uniqueNetworks = result
          .whereType<String>()
          .where((ssid) => ssid.isNotEmpty)
          .toSet();

      // Sort alphabetically
      final sortedNetworks = uniqueNetworks.toList()..sort();

      print('[WiFiScan] Found ${sortedNetworks.length} networks');
      return sortedNetworks;
    } on PlatformException catch (e) {
      print('[WiFiScan] Error: ${e.message}');
      throw Exception('Failed to scan WiFi: ${e.message}');
    }
  }

  /// Check if device has WiFi enabled
  static Future<bool> isWiFiEnabled() async {
    try {
      final bool result = await platform.invokeMethod('isWiFiEnabled');
      return result;
    } catch (e) {
      print('[WiFiScan] Error checking WiFi status: $e');
      return false;
    }
  }

  /// Request WiFi permission from user (for Android 11+)
  static Future<bool> requestWiFiPermission() async {
    try {
      final bool result = await platform.invokeMethod('requestWiFiPermission');
      return result;
    } catch (e) {
      print('[WiFiScan] Error requesting permission: $e');
      return false;
    }
  }
}
