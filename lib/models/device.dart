import 'sensor_data.dart';

/// Device/Node model matching Firebase Realtime Database schema
/// From firmware: nodes/{nodeId}/info and nodes/{nodeId}/latest_data
class Device {
  final String nodeId; // Node address in hex format (e.g., "0xCC64")
  final String name; // Human-readable name
  final String type; // Node type: "sensor", "relay", "actuator"
  final String? firmwareVersion;
  final DateTime createdAt; // First registration timestamp
  final DateTime lastSeen; // Last data received timestamp
  final SensorData? latestData; // Latest sensor reading

  Device({
    required this.nodeId,
    required this.name,
    required this.type,
    this.firmwareVersion,
    required this.createdAt,
    required this.lastSeen,
    this.latestData,
  });

  /// Create from Firebase Realtime Database nodes/{nodeId}/info JSON
  factory Device.fromJson(Map<String, dynamic> json, {String? nodeId}) {
    return Device(
      nodeId: nodeId ?? json['address'] ?? json['nodeId'] ?? '',
      name: json['name'] ?? 'Sensor Node',
      type: json['type'] ?? 'sensor',
      firmwareVersion: json['firmware_version'] ?? json['firmwareVersion'],
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['created_at'] is int
                  ? json['created_at'] *
                        1000 // Firebase uses Unix seconds
                  : int.parse(json['created_at'].toString()) * 1000,
            )
          : DateTime.now(),
      lastSeen: json['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['last_seen'] is int
                  ? json['last_seen'] * 1000
                  : int.parse(json['last_seen'].toString()) * 1000,
            )
          : DateTime.now(),
      latestData: json['latestData'] != null
          ? SensorData.fromJson(json['latestData'], nodeId: nodeId)
          : null,
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    return {
      'address': nodeId,
      'name': name,
      'type': type,
      'firmware_version': firmwareVersion,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000, // Unix seconds
      'last_seen': lastSeen.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Check if node is currently online (seen within last 2 minutes)
  bool get isOnline {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    return difference.inMinutes < 2; // Online if seen within 2 minutes
  }

  /// Status text for UI display
  String get statusText => isOnline ? 'Online' : 'Offline';

  /// Check if node is recently active (seen within last 10 minutes)
  bool get isRecentlyActive {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    return difference.inMinutes < 10;
  }

  /// Human-readable time since last seen
  String get lastSeenText {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
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
    return 'Device(nodeId: $nodeId, name: $name, type: $type, isOnline: $isOnline)';
  }

  Device copyWith({
    String? nodeId,
    String? name,
    String? type,
    String? firmwareVersion,
    DateTime? createdAt,
    DateTime? lastSeen,
    SensorData? latestData,
  }) {
    return Device(
      nodeId: nodeId ?? this.nodeId,
      name: name ?? this.name,
      type: type ?? this.type,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      latestData: latestData ?? this.latestData,
    );
  }
}
