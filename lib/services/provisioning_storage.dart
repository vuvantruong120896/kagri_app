import 'package:shared_preferences/shared_preferences.dart';

/// Provisioning Storage Service
///
/// Manages persistent storage of provisioning data including:
/// - Gateway MAC addresses for Node provisioning
/// - Provisioned device list
/// - Last provisioning session info
///
/// Updated: November 2025

class ProvisioningStorage {
  // ============================================================================
  // STORAGE KEYS
  // ============================================================================

  static const String _keyGatewayMacList = 'provisioned_gateway_macs';
  static const String _keyLastGatewayMac = 'last_gateway_mac';
  static const String _keyLastProvisionedDeviceType = 'last_device_type';
  static const String _keyLastProvisionedDeviceName = 'last_device_name';
  static const String _keyProvisioningTimestamp = 'last_provisioning_timestamp';

  // ============================================================================
  // SINGLETON INSTANCE
  // ============================================================================

  static final ProvisioningStorage _instance = ProvisioningStorage._internal();
  factory ProvisioningStorage() => _instance;
  ProvisioningStorage._internal();

  // ============================================================================
  // GATEWAY MAC MANAGEMENT
  // ============================================================================

  /// Save Gateway MAC address after successful provisioning
  /// This MAC will be used when provisioning Nodes
  Future<void> saveGatewayMAC(String mac) async {
    final prefs = await SharedPreferences.getInstance();

    // Save as last Gateway MAC
    await prefs.setString(_keyLastGatewayMac, mac);

    // Add to list of all provisioned Gateways
    final List<String> gatewayList = await getGatewayMACList();
    if (!gatewayList.contains(mac)) {
      gatewayList.add(mac);
      await prefs.setStringList(_keyGatewayMacList, gatewayList);
    }

    print('[ProvisioningStorage] Gateway MAC saved: $mac');
  }

  /// Get the most recently provisioned Gateway MAC
  /// Returns null if no Gateway has been provisioned yet
  Future<String?> getLastGatewayMAC() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastGatewayMac);
  }

  /// Get list of all provisioned Gateway MACs
  /// Useful when user has multiple Gateways
  Future<List<String>> getGatewayMACList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyGatewayMacList) ?? [];
  }

  /// Check if any Gateway has been provisioned
  Future<bool> hasProvisionedGateway() async {
    final mac = await getLastGatewayMAC();
    return mac != null && mac.isNotEmpty;
  }

  /// Remove a Gateway MAC from storage
  Future<void> removeGatewayMAC(String mac) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove from list
    final List<String> gatewayList = await getGatewayMACList();
    gatewayList.remove(mac);
    await prefs.setStringList(_keyGatewayMacList, gatewayList);

    // If this was the last Gateway MAC, clear it
    final lastMAC = await getLastGatewayMAC();
    if (lastMAC == mac) {
      if (gatewayList.isNotEmpty) {
        // Set the most recent remaining Gateway as last
        await prefs.setString(_keyLastGatewayMac, gatewayList.last);
      } else {
        // No more Gateways, remove the key
        await prefs.remove(_keyLastGatewayMac);
      }
    }

    print('[ProvisioningStorage] Gateway MAC removed: $mac');
  }

  /// Clear all Gateway MACs
  Future<void> clearAllGatewayMACs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGatewayMacList);
    await prefs.remove(_keyLastGatewayMac);
    print('[ProvisioningStorage] All Gateway MACs cleared');
  }

  // ============================================================================
  // PROVISIONING SESSION INFO
  // ============================================================================

  /// Save last provisioning session info
  Future<void> saveLastProvisioningSession({
    required String deviceType,
    required String deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastProvisionedDeviceType, deviceType);
    await prefs.setString(_keyLastProvisionedDeviceName, deviceName);
    await prefs.setInt(
      _keyProvisioningTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get last provisioned device type
  Future<String?> getLastProvisionedDeviceType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastProvisionedDeviceType);
  }

  /// Get last provisioned device name
  Future<String?> getLastProvisionedDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastProvisionedDeviceName);
  }

  /// Get last provisioning timestamp
  Future<DateTime?> getLastProvisioningTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyProvisioningTimestamp);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Clear all provisioning data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGatewayMacList);
    await prefs.remove(_keyLastGatewayMac);
    await prefs.remove(_keyLastProvisionedDeviceType);
    await prefs.remove(_keyLastProvisionedDeviceName);
    await prefs.remove(_keyProvisioningTimestamp);
    print('[ProvisioningStorage] All data cleared');
  }

  /// Get storage summary for debugging
  Future<Map<String, dynamic>> getSummary() async {
    return {
      'gatewayMACList': await getGatewayMACList(),
      'lastGatewayMAC': await getLastGatewayMAC(),
      'lastDeviceType': await getLastProvisionedDeviceType(),
      'lastDeviceName': await getLastProvisionedDeviceName(),
      'lastTimestamp': await getLastProvisioningTimestamp(),
      'hasGateway': await hasProvisionedGateway(),
    };
  }

  /// Print storage summary to console
  Future<void> printSummary() async {
    final summary = await getSummary();
    print('[ProvisioningStorage] Summary:');
    summary.forEach((key, value) {
      print('  $key: $value');
    });
  }
}
