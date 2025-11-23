/// Registered Device Model
/// Represents a device that has been provisioned and registered to the user's account
/// This is the persistent record in Firebase under users/{uid}/devices/
///
/// Separate from routing_table which is dynamic and changes based on network topology

import 'device.dart';

class RegisteredDevice {
  /// Unique node ID (e.g., "0x1234", "gateway_0xABCD")
  final String nodeId;

  /// Device type: "soil_sensor", "env_sensor", "gateway"
  final String deviceType;

  /// User-defined display name (customizable)
  final String displayName;

  /// Optional location/area description
  final String? location;

  /// Optional notes/description
  final String? notes;

  /// When the device was first provisioned
  final DateTime provisionedAt;

  /// Firmware version (if available)
  final String? firmwareVersion;

  /// Who provisioned this device (e.g., "mobile_app_v1.0.0")
  final String? provisionedBy;

  // Runtime status fields (synced from routing_table)

  /// Is device currently online (from routing_table)
  bool isOnline;

  /// Last seen timestamp (from routing_table lastUpdate)
  DateTime? lastSeen;

  /// Signal strength (RSSI) if available
  int? rssi;

  /// Hop count from gateway (from routing_table)
  int? hopCount;

  RegisteredDevice({
    required this.nodeId,
    required this.deviceType,
    required this.displayName,
    this.location,
    this.notes,
    required this.provisionedAt,
    this.firmwareVersion,
    this.provisionedBy,
    this.isOnline = false,
    this.lastSeen,
    this.rssi,
    this.hopCount,
  });

  /// Create RegisteredDevice from Firebase snapshot
  factory RegisteredDevice.fromFirebase(
    String key,
    Map<dynamic, dynamic> data,
  ) {
    // Normalize nodeId to lowercase hex format (0xXXXX)
    String nodeId =
        data['nodeId'] as String? ?? key.replaceFirst('device_', '');
    nodeId = nodeId.toLowerCase();
    if (!nodeId.startsWith('0x')) {
      nodeId = '0x$nodeId';
    }

    String displayName = data['displayName'] as String? ?? 'Unknown Device';
    // Auto-fix old "Sensor" naming to "Node"
    if (displayName.startsWith('Sensor ')) {
      displayName = displayName.replaceFirst('Sensor ', 'Node ');
    }

    return RegisteredDevice(
      nodeId: nodeId,
      deviceType: data['deviceType'] as String? ?? 'unknown',
      displayName: displayName,
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      provisionedAt: data['provisionedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['provisionedAt'] as int)
          : DateTime.now(),
      firmwareVersion: data['firmwareVersion'] as String?,
      provisionedBy: data['provisionedBy'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: data['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int)
          : null,
      rssi: data['rssi'] as int?,
      hopCount: data['hopCount'] as int?,
    );
  }

  /// Convert to Firebase-compatible map
  Map<String, dynamic> toFirebase() {
    return {
      'nodeId': nodeId,
      'deviceType': deviceType,
      'displayName': displayName,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
      'provisionedAt': provisionedAt.millisecondsSinceEpoch,
      if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
      if (provisionedBy != null) 'provisionedBy': provisionedBy,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': lastSeen!.millisecondsSinceEpoch,
      if (rssi != null) 'rssi': rssi,
      if (hopCount != null) 'hopCount': hopCount,
    };
  }

  /// Create a copy with updated fields
  RegisteredDevice copyWith({
    String? nodeId,
    String? deviceType,
    String? displayName,
    String? location,
    String? notes,
    DateTime? provisionedAt,
    String? firmwareVersion,
    String? provisionedBy,
    bool? isOnline,
    DateTime? lastSeen,
    int? rssi,
    int? hopCount,
  }) {
    return RegisteredDevice(
      nodeId: nodeId ?? this.nodeId,
      deviceType: deviceType ?? this.deviceType,
      displayName: displayName ?? this.displayName,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      provisionedAt: provisionedAt ?? this.provisionedAt,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      provisionedBy: provisionedBy ?? this.provisionedBy,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      hopCount: hopCount ?? this.hopCount,
    );
  }

  /// Get display-friendly device type name
  String get deviceTypeDisplayName {
    switch (deviceType.toLowerCase()) {
      case 'soil_sensor':
        return 'Soil Sensor';
      case 'env_sensor':
        return 'Environment Sensor';
      case 'gateway':
        return 'Gateway';
      default:
        return deviceType;
    }
  }

  /// Get device icon based on type
  String get deviceIcon {
    switch (deviceType.toLowerCase()) {
      case 'soil_sensor':
        return '🌱';
      case 'env_sensor':
        return '🌡️';
      case 'gateway':
        return '📡';
      default:
        return '📟';
    }
  }

  /// Check if device is considered offline (not seen in last 22 minutes)
  /// 22 minutes is the threshold after which we assume the device is offline
  bool get isConsideredOffline {
    if (lastSeen == null) return true;
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    return difference.inMinutes >= 22; // Offline if not seen for 22+ minutes
  }

  /// Computed online status based on lastSeen timestamp
  /// This replaces the old routing_table sync approach
  bool get computedIsOnline {
    return !isConsideredOffline;
  }

  /// Get time since last seen as human-readable string
  String get timeSinceLastSeen {
    if (lastSeen == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  String toString() {
    return 'RegisteredDevice(nodeId: $nodeId, type: $deviceType, name: $displayName, online: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegisteredDevice && other.nodeId == nodeId;
  }

  @override
  int get hashCode => nodeId.hashCode;

  /// Convert RegisteredDevice to Device model for compatibility
  /// This allows using existing UI code that expects Device model
  Device toDevice() {
    return Device(
      nodeId: nodeId,
      name: displayName,
      type: deviceType == 'gateway' ? 'gateway' : 'sensor',
      firmwareVersion: firmwareVersion,
      createdAt: provisionedAt,
      lastSeen: lastSeen ?? provisionedAt,
      inRoutingTable: isOnline,
      metric: hopCount ?? 0,
      rssi: rssi,
    );
  }
}
