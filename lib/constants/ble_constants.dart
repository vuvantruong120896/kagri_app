/// BLE Provisioning Constants
///
/// This file contains all UUIDs and constants for BLE provisioning
/// of Gateway and Node devices in the Kagri system.
///
/// Updated: November 2025
/// Architecture: PROVISIONING_BLE_ARCHITECTURE.md

class BleConstants {
  // ============================================================================
  // GATEWAY BLE SERVICE & CHARACTERISTICS
  // ============================================================================

  /// Gateway BLE Service UUID
  /// Used for provisioning Gateway devices via BLE
  static const String gatewayServiceUuid =
      '0000ffb0-0000-1000-8000-00805f9b34fb';

  /// Gateway Command Characteristic (Write)
  /// Mobile app writes provisioning payload to this characteristic
  static const String gatewayCommandCharUuid =
      '0000ffb1-0000-1000-8000-00805f9b34fb';

  /// Gateway Response Characteristic (Notify)
  /// Gateway sends response (including gatewayMAC) via this characteristic
  static const String gatewayResponseCharUuid =
      '0000ffb2-0000-1000-8000-00805f9b34fb';

  // ============================================================================
  // NODE BLE SERVICE & CHARACTERISTICS
  // ============================================================================

  /// Node BLE Service UUID
  /// Used for provisioning Node devices via BLE
  /// NOTE: Different from Gateway to avoid conflicts
  static const String nodeServiceUuid = '0000ffc0-0000-1000-8000-00805f9b34fb';

  /// Node Command Characteristic (Write)
  /// Mobile app writes provisioning payload to this characteristic
  static const String nodeCommandCharUuid =
      '0000ffc1-0000-1000-8000-00805f9b34fb';

  /// Node Response Characteristic (Notify)
  /// Node sends response (including nodeAddress) via this characteristic
  static const String nodeResponseCharUuid =
      '0000ffc2-0000-1000-8000-00805f9b34fb';

  // ============================================================================
  // DEVICE NAMING CONVENTIONS
  // ============================================================================

  /// Gateway device name prefix
  /// Format: KAGRI-GW-XXXX (where XXXX = last 4 digits of Gateway MAC)
  static const String gatewayNamePrefix = 'KAGRI-GW-';

  /// Node device name prefix
  /// Format: KAGRI-NODE-XXXX (where XXXX = last 4 digits of Node MAC)
  static const String nodeNamePrefix = 'KAGRI-NODE-';

  /// Handheld device name prefix
  /// Format: KAGRI-HHC-XXXX (WiFi config), KAGRI-HHT-XXXX (sensor data)
  static const String handheldNamePrefix = 'KAGRI-HH';

  /// Handheld WiFi Config device prefix
  /// Format: KAGRI-HHC-XXXX (where XXXX = last 4 digits of MAC)
  /// Used when device is in WiFi configuration mode
  static const String handheldWiFiNamePrefix = 'KAGRI-HHC-';

  /// Handheld Sensor Data device prefix
  /// Format: KAGRI-HHT-XXXX (where XXXX = last 4 digits of MAC)
  /// Used when device is advertising sensor data for transmission
  static const String handheldSensorNamePrefix = 'KAGRI-HHT-';

  // ============================================================================
  // HANDHELD BLE SERVICE & CHARACTERISTICS
  // ============================================================================

  /// Handheld WiFi Config BLE Service UUID
  /// Used for provisioning Handheld devices with WiFi credentials via BLE
  static const String handheldWiFiServiceUuid =
      '0000ffb0-0000-1000-8000-00805f9b34fb';

  /// Handheld WiFi Config Command Characteristic (Write)
  /// Mobile app writes WiFi credentials to this characteristic
  static const String handheldWiFiCommandCharUuid =
      '0000ffb1-0000-1000-8000-00805f9b34fb';

  /// Handheld WiFi Config Response Characteristic (Notify)
  /// Handheld sends response via this characteristic
  static const String handheldWiFiResponseCharUuid =
      '0000ffb2-0000-1000-8000-00805f9b34fb';

  /// Handheld Sensor Data BLE Service UUID
  /// Used for receiving sensor data from Handheld devices via BLE
  static const String handheldSensorServiceUuid =
      '0000ffe0-0000-1000-8000-00805f9b34fb';

  /// Handheld Sensor Data Characteristic (Notify)
  /// Handheld sends sensor data via this characteristic
  static const String handheldSensorDataCharUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';

  /// Handheld Sensor Data Command Characteristic (Write)
  /// Mobile app sends commands via this characteristic
  static const String handheldSensorCommandCharUuid =
      '0000ffe2-0000-1000-8000-00805f9b34fb';

  // ============================================================================
  // TIMEOUTS & DELAYS
  // ============================================================================

  /// BLE scan timeout (seconds)
  static const int scanTimeoutSeconds = 15;

  /// BLE connection timeout (seconds)
  static const int connectionTimeoutSeconds = 10;

  /// Response notification timeout (seconds)
  static const int responseTimeoutSeconds = 30;

  /// Delay after connection before sending data (milliseconds)
  static const int connectionStabilizationDelayMs = 500;

  // ============================================================================
  // PAYLOAD KEYS
  // ============================================================================

  // Gateway payload keys
  static const String keyUserUID = 'userUID';
  static const String keyIsWiFi = 'isWiFi';
  static const String keyWiFiSSID = 'wifiSSID';
  static const String keyWiFiPassword = 'wifiPassword';
  static const String keyTimestamp = 'timestamp';

  // Node payload keys
  static const String keyGatewayMAC = 'gatewayMAC';

  // Response keys
  static const String keyStatus = 'status';
  static const String keyMessage = 'message';
  static const String keyResponseGatewayMAC = 'gatewayMAC';
  static const String keyNodeAddress = 'nodeAddress';
  static const String keyCode = 'code';

  // ============================================================================
  // RESPONSE STATUS VALUES
  // ============================================================================

  static const String statusSuccess = 'success';
  static const String statusError = 'error';

  // ============================================================================
  // ERROR CODES
  // ============================================================================

  static const String errorWiFiMissing = 'ERR_WIFI_MISSING';
  static const String errorInvalidGatewayMAC = 'ERR_INVALID_GATEWAY_MAC';
  static const String errorInvalidJSON = 'ERR_INVALID_JSON';

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if device name is a Gateway
  static bool isGatewayDevice(String deviceName) {
    return deviceName.toUpperCase().startsWith(gatewayNamePrefix);
  }

  /// Check if device name is a Node
  static bool isNodeDevice(String deviceName) {
    return deviceName.toUpperCase().startsWith(nodeNamePrefix);
  }

  /// Check if device name is a Handheld
  static bool isHandheldDevice(String deviceName) {
    return deviceName.toUpperCase().startsWith(handheldNamePrefix);
  }

  /// Check if device is Handheld in WiFi Config mode (KAGRI-HHC-XXXX)
  static bool isHandheldWiFiDevice(String deviceName) {
    return deviceName.toUpperCase().startsWith(handheldWiFiNamePrefix);
  }

  /// Check if device is Handheld in Sensor Data mode (KAGRI-HHT-XXXX)
  static bool isHandheldSensorDevice(String deviceName) {
    return deviceName.toUpperCase().startsWith(handheldSensorNamePrefix);
  }

  /// Get Handheld sub-type (WiFi config or Sensor data)
  static HandheldType? getHandheldType(String deviceName) {
    if (isHandheldWiFiDevice(deviceName)) return HandheldType.wiFiConfig;
    if (isHandheldSensorDevice(deviceName)) return HandheldType.sensorData;
    return null;
  }

  /// Extract device type from name
  static DeviceType? getDeviceType(String deviceName) {
    if (isGatewayDevice(deviceName)) return DeviceType.gateway;
    if (isNodeDevice(deviceName)) return DeviceType.node;
    if (isHandheldDevice(deviceName)) return DeviceType.handheld;
    return null;
  }

  /// Validate MAC address format (AA:BB:CC:DD:EE:FF)
  static bool isValidMacAddress(String mac) {
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$');
    return macRegex.hasMatch(mac);
  }
}

/// Device type enum
enum DeviceType { gateway, node, handheld }

/// Handheld sub-type enum
enum HandheldType { wiFiConfig, sensorData }

/// Extension for HandheldType display
extension HandheldTypeExtension on HandheldType {
  String get displayName {
    switch (this) {
      case HandheldType.wiFiConfig:
        return 'WiFi Configuration';
      case HandheldType.sensorData:
        return 'Sensor Data';
    }
  }

  String get description {
    switch (this) {
      case HandheldType.wiFiConfig:
        return 'Configure WiFi credentials';
      case HandheldType.sensorData:
        return 'Receive sensor data';
    }
  }

  String get icon {
    switch (this) {
      case HandheldType.wiFiConfig:
        return '📡'; // WiFi config icon
      case HandheldType.sensorData:
        return '📊'; // Sensor data icon
    }
  }
}

/// Extension for DeviceType display
extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.gateway:
        return 'Gateway';
      case DeviceType.node:
        return 'Node';
      case DeviceType.handheld:
        return 'Handheld Sensor';
    }
  }

  String get icon {
    switch (this) {
      case DeviceType.gateway:
        return '🌐'; // Gateway icon
      case DeviceType.node:
        return '📡'; // Node icon
      case DeviceType.handheld:
        return '📊'; // Handheld sensor icon
    }
  }
}
