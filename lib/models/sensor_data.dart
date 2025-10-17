/// Sensor data model matching Firebase Realtime Database schema
/// From firmware: nodes/{nodeId}/latest_data and sensor_data/{nodeId}/{timestamp}
class SensorData {
  final String id; // Auto-generated ID for local use
  final String nodeId; // Node address in hex format (e.g., "0xCC64")
  final int counter; // Packet sequence number from node
  final double temperature; // Temperature in Celsius
  final double humidity; // Humidity percentage (0-100%)
  final double battery; // Battery voltage in Volts
  final DateTime timestamp; // Unix timestamp (NTP synchronized from gateway)
  final int? rssi; // Signal strength at gateway (-dBm)
  final double? snr; // Signal-to-Noise Ratio (dB)

  SensorData({
    required this.id,
    required this.nodeId,
    required this.counter,
    required this.temperature,
    required this.humidity,
    required this.battery,
    required this.timestamp,
    this.rssi,
    this.snr,
  });

  /// Create from Firebase Realtime Database JSON
  /// Supports both latest_data and historical sensor_data structures
  factory SensorData.fromJson(
    Map<String, dynamic> json, {
    String? nodeId,
    String? id,
  }) {
    return SensorData(
      id: id ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nodeId: nodeId ?? json['nodeId'] ?? json['node_id'] ?? '',
      counter: json['counter'] ?? 0,
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      battery: (json['battery'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['timestamp'] is int
                  ? json['timestamp'] *
                        1000 // Firebase uses Unix seconds
                  : int.parse(json['timestamp'].toString()) * 1000,
            )
          : DateTime.now(),
      rssi: json['rssi'],
      snr: json['snr']?.toDouble(),
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'counter': counter,
      'temperature': temperature,
      'humidity': humidity,
      'battery': battery,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000, // Unix seconds
    };

    // Optional fields - only include if not null
    if (rssi != null) json['rssi'] = rssi!;
    if (snr != null) json['snr'] = snr!;

    return json;
  }

  @override
  String toString() {
    return 'SensorData(id: $id, nodeId: $nodeId, temp: $temperature°C, humidity: $humidity%, battery: ${battery}V, counter: $counter)';
  }

  SensorData copyWith({
    String? id,
    String? nodeId,
    int? counter,
    double? temperature,
    double? humidity,
    double? battery,
    DateTime? timestamp,
    int? rssi,
    double? snr,
  }) {
    return SensorData(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      counter: counter ?? this.counter,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      battery: battery ?? this.battery,
      timestamp: timestamp ?? this.timestamp,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
    );
  }

  /// Battery level percentage estimate (assuming 3.0V = 0%, 4.2V = 100%)
  double get batteryPercentage {
    const minVoltage = 3.0;
    const maxVoltage = 4.2;
    if (battery <= minVoltage) return 0.0;
    if (battery >= maxVoltage) return 100.0;
    return ((battery - minVoltage) / (maxVoltage - minVoltage)) * 100;
  }

  /// Check if battery is low (< 20%)
  bool get isBatteryLow => batteryPercentage < 20;

  /// Check if signal is weak (RSSI < -80 dBm)
  bool get isSignalWeak => rssi != null && rssi! < -80;
}
