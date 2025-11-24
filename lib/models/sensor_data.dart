/// Sensor data model matching Firebase Realtime Database schema
/// Supports multiple sensor types: SOIL_SENSOR, ENVIRONMENT, WATER_SENSOR
/// From firmware: nodes/{nodeId}/latest_data and sensor_data/{nodeId}/{timestamp}
class SensorData {
  final String id; // Auto-generated ID for local use
  final String nodeId; // Node address in hex format (e.g., "0xCC64")
  final int counter; // Packet sequence number from node
  final String
  deviceType; // Device type: "soil_sensor", "environment", "water_sensor"
  final double battery; // Battery voltage in Volts
  final DateTime timestamp; // Unix timestamp (NTP synchronized from gateway)
  final int? rssi; // Signal strength at gateway (-dBm)
  final double? snr; // Signal-to-Noise Ratio (dB)

  // ===== Soil Sensor Fields (SOIL_SENSOR) =====
  final double? soilMoisture; // Soil moisture (%) [0-100]
  final double? soilTemperature; // Soil temperature (°C)
  final double? pH; // Soil pH [0-14], optimal 6-7
  final double? conductivity; // Electrical Conductivity (µS/cm) [0-10]
  final double? nitrogen; // Nitrogen content (mg/kg) [0-300]
  final double? phosphorus; // Phosphorus content (mg/kg) [0-200]
  final double? potassium; // Potassium content (mg/kg) [0-300]

  // ===== Environment Sensor Fields =====
  final double? temperature; // Air temperature (°C)
  final double? humidity; // Relative humidity (%)
  final double? pressure; // Atmospheric pressure (hPa)
  final double? lightIntensity; // Light intensity (lux)

  // ===== Water Sensor Fields =====
  final double? waterTemp; // Water temperature (°C)
  final double? tds; // Total Dissolved Solids (ppm)
  final double? turbidity; // Water turbidity (NTU)

  SensorData({
    required this.id,
    required this.nodeId,
    required this.counter,
    required this.deviceType,
    required this.battery,
    required this.timestamp,
    this.rssi,
    this.snr,
    // Soil sensor
    this.soilMoisture,
    this.soilTemperature,
    this.pH,
    this.conductivity,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    // Environment sensor
    this.temperature,
    this.humidity,
    this.pressure,
    this.lightIntensity,
    // Water sensor
    this.waterTemp,
    this.tds,
    this.turbidity,
  });

  /// Create from Firebase Realtime Database JSON
  /// Supports both latest_data and historical sensor_data structures
  /// Detects sensor type automatically
  factory SensorData.fromJson(
    Map<String, dynamic> json, {
    String? nodeId,
    String? id,
  }) {
    // Detect device type from JSON structure
    String deviceType = json['deviceType'] ?? 'soil_sensor';

    // Fallback: detect by available fields
    if (!json.containsKey('deviceType')) {
      if (json.containsKey('soilMoisture')) {
        deviceType = 'soil_sensor';
      } else if (json.containsKey('humidity')) {
        deviceType = 'environment';
      } else if (json.containsKey('waterTemp')) {
        deviceType = 'water_sensor';
      }
    }

    return SensorData(
      id: id ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nodeId: nodeId ?? json['nodeId'] ?? json['node_id'] ?? '',
      counter: json['counter'] ?? 0,
      deviceType: deviceType,
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
      // Soil sensor fields
      soilMoisture: json['soilMoisture']?.toDouble(),
      soilTemperature: json['soilTemperature']?.toDouble(),
      pH: json['pH']?.toDouble(),
      conductivity: json['conductivity']?.toDouble(),
      nitrogen: json['nitrogen']?.toDouble(),
      phosphorus: json['phosphorus']?.toDouble(),
      potassium: json['potassium']?.toDouble(),
      // Environment sensor fields
      temperature: json['temperature']?.toDouble(),
      humidity: json['humidity']?.toDouble(),
      pressure: json['pressure']?.toDouble(),
      lightIntensity: json['lightIntensity']?.toDouble(),
      // Water sensor fields
      waterTemp: json['waterTemp']?.toDouble(),
      tds: json['tds']?.toDouble(),
      turbidity: json['turbidity']?.toDouble(),
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'counter': counter,
      'deviceType': deviceType,
      'battery': battery,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000, // Unix seconds
    };

    // Add sensor-specific fields
    switch (deviceType) {
      case 'soil_sensor':
        if (soilMoisture != null) json['soilMoisture'] = soilMoisture!;
        if (soilTemperature != null) json['soilTemperature'] = soilTemperature!;
        if (pH != null) json['pH'] = pH!;
        if (conductivity != null) json['conductivity'] = conductivity!;
        if (nitrogen != null) json['nitrogen'] = nitrogen!;
        if (phosphorus != null) json['phosphorus'] = phosphorus!;
        if (potassium != null) json['potassium'] = potassium!;
        break;
      case 'environment':
        if (temperature != null) json['temperature'] = temperature!;
        if (humidity != null) json['humidity'] = humidity!;
        if (pressure != null) json['pressure'] = pressure!;
        if (lightIntensity != null) json['lightIntensity'] = lightIntensity!;
        break;
      case 'water_sensor':
        if (waterTemp != null) json['waterTemp'] = waterTemp!;
        if (pH != null) json['pH'] = pH!;
        if (tds != null) json['tds'] = tds!;
        if (turbidity != null) json['turbidity'] = turbidity!;
        break;
    }

    // Optional fields
    if (rssi != null) json['rssi'] = rssi!;
    if (snr != null) json['snr'] = snr!;

    return json;
  }

  @override
  String toString() {
    switch (deviceType) {
      case 'soil_sensor':
        return 'SensorData(id: $id, nodeId: $nodeId, type: soil, moisture: ${soilMoisture}%, temp: ${soilTemperature}°C, pH: ${pH}, battery: ${battery}V)';
      case 'environment':
        return 'SensorData(id: $id, nodeId: $nodeId, type: env, temp: ${temperature}°C, humidity: ${humidity}%, battery: ${battery}V)';
      case 'water_sensor':
        return 'SensorData(id: $id, nodeId: $nodeId, type: water, temp: ${waterTemp}°C, pH: ${pH}, TDS: ${tds}ppm, battery: ${battery}V)';
      default:
        return 'SensorData(id: $id, nodeId: $nodeId, type: $deviceType, battery: ${battery}V)';
    }
  }

  SensorData copyWith({
    String? id,
    String? nodeId,
    int? counter,
    String? deviceType,
    double? battery,
    DateTime? timestamp,
    int? rssi,
    double? snr,
    double? soilMoisture,
    double? soilTemperature,
    double? pH,
    double? conductivity,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? temperature,
    double? humidity,
    double? pressure,
    double? lightIntensity,
    double? waterTemp,
    double? tds,
    double? turbidity,
  }) {
    return SensorData(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      counter: counter ?? this.counter,
      deviceType: deviceType ?? this.deviceType,
      battery: battery ?? this.battery,
      timestamp: timestamp ?? this.timestamp,
      rssi: rssi ?? this.rssi,
      snr: snr ?? this.snr,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      soilTemperature: soilTemperature ?? this.soilTemperature,
      pH: pH ?? this.pH,
      conductivity: conductivity ?? this.conductivity,
      nitrogen: nitrogen ?? this.nitrogen,
      phosphorus: phosphorus ?? this.phosphorus,
      potassium: potassium ?? this.potassium,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      pressure: pressure ?? this.pressure,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      waterTemp: waterTemp ?? this.waterTemp,
      tds: tds ?? this.tds,
      turbidity: turbidity ?? this.turbidity,
    );
  }

  /// Battery level percentage estimate (assuming 3.5V = 0%, 4.2V = 100%)
  /// Updated to match firmware battery thresholds (Nov 24, 2025)
  double get batteryPercentage {
    const minVoltage = 3.5; // Changed from 3.0V to match firmware
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
