/// Gateway status model matching Firebase Realtime Database schema
/// From firmware: gateways/{gatewayId}/status
class GatewayStatus {
  final String gatewayId;
  final int connectedNodes; // Number of nodes in routing table
  final int totalPacketsReceived; // Total LoRa packets received since boot
  final int totalPacketsSent; // Total LoRa packets sent since boot
  final bool wifiConnected;
  final int wifiRssi; // WiFi signal strength (-dBm)
  final bool firebaseConnected;
  final int uptimeSeconds; // Gateway uptime in seconds
  final int freeHeap; // Available RAM in bytes
  final DateTime timestamp; // Status update timestamp

  GatewayStatus({
    required this.gatewayId,
    required this.connectedNodes,
    required this.totalPacketsReceived,
    required this.totalPacketsSent,
    required this.wifiConnected,
    required this.wifiRssi,
    required this.firebaseConnected,
    required this.uptimeSeconds,
    required this.freeHeap,
    required this.timestamp,
  });

  /// Create from Firebase Realtime Database JSON
  factory GatewayStatus.fromJson(
    Map<String, dynamic> json, {
    String? gatewayId,
  }) {
    return GatewayStatus(
      gatewayId: gatewayId ?? '',
      connectedNodes: json['connected_nodes'] ?? 0,
      totalPacketsReceived: json['total_packets_received'] ?? 0,
      totalPacketsSent: json['total_packets_sent'] ?? 0,
      wifiConnected: json['wifi_connected'] ?? false,
      wifiRssi: json['wifi_rssi'] ?? 0,
      firebaseConnected: json['firebase_connected'] ?? false,
      uptimeSeconds: json['uptime_seconds'] ?? 0,
      freeHeap: json['free_heap'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['timestamp'] is int
                  ? json['timestamp'] *
                        1000 // Firebase uses Unix seconds
                  : int.parse(json['timestamp'].toString()) * 1000,
            )
          : DateTime.now(),
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    return {
      'connected_nodes': connectedNodes,
      'total_packets_received': totalPacketsReceived,
      'total_packets_sent': totalPacketsSent,
      'wifi_connected': wifiConnected,
      'wifi_rssi': wifiRssi,
      'firebase_connected': firebaseConnected,
      'uptime_seconds': uptimeSeconds,
      'free_heap': freeHeap,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Human-readable uptime string
  String get uptimeText {
    final duration = Duration(seconds: uptimeSeconds);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Free heap in MB
  double get freeHeapMB => freeHeap / 1024 / 1024;

  /// Free heap in KB
  double get freeHeapKB => freeHeap / 1024;

  /// Check if gateway is healthy
  bool get isHealthy {
    return wifiConnected &&
        firebaseConnected &&
        freeHeap > 50000 && // At least 50KB free
        wifiRssi > -80; // Signal not too weak
  }

  @override
  String toString() {
    return 'GatewayStatus(id: $gatewayId, nodes: $connectedNodes, wifi: $wifiConnected, firebase: $firebaseConnected)';
  }
}
