import 'dart:math';
import '../models/sensor_data.dart';
import '../models/device.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final Random _random = Random();

  // Mock devices matching Firebase node schema (hex addresses like firmware)
  final List<Device> _mockDevices = [
    Device(
      nodeId: '0xCC64', // Node address in hex format
      name: 'Sensor Nhà kính 1',
      type: 'sensor',
      firmwareVersion: '1.0.0',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    Device(
      nodeId: '0x4F70', // Node address in hex format
      name: 'Sensor Nhà kính 2',
      type: 'sensor',
      firmwareVersion: '1.0.0',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Device(
      nodeId: '0x09F8', // Node address in hex format
      name: 'Sensor Ngoài trời',
      type: 'sensor',
      firmwareVersion: '0.9.0',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      lastSeen: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
  ];

  List<Device> getMockDevices() => _mockDevices;

  /// Generate historical mock sensor data (for charts/analytics)
  List<SensorData> generateMockSensorData({String? nodeId, int count = 20}) {
    final List<SensorData> data = [];
    final now = DateTime.now();
    int globalCounter = _random.nextInt(1000) + 1000; // Starting counter

    final devicesToGenerate = nodeId != null
        ? _mockDevices.where((d) => d.nodeId == nodeId).toList()
        : _mockDevices;

    for (int i = 0; i < count; i++) {
      for (final device in devicesToGenerate) {
        final timestamp = now.subtract(Duration(minutes: i * 5));

        // All devices are now SOIL_SENSOR type
        const deviceType = 'soil_sensor';

        // Generate soil moisture (20-80%)
        final baseMoisture = device.nodeId == '0x09F8' ? 30.0 : 55.0;
        final soilMoisture = baseMoisture + (_random.nextDouble() - 0.5) * 15;

        // Generate soil temperature (15-35°C)
        double baseTemp = 25.0;
        if (device.nodeId == '0xCC64') baseTemp = 28.0;
        if (device.nodeId == '0x4F70') baseTemp = 26.0;
        if (device.nodeId == '0x09F8') baseTemp = 22.0;

        final hour = timestamp.hour;
        double timeVariation = 0;
        if (hour >= 6 && hour <= 18) {
          timeVariation = 5 * sin((hour - 6) * pi / 12);
        }
        final soilTemperature =
            baseTemp + timeVariation + (_random.nextDouble() - 0.5) * 4;

        // Generate pH (6.0-7.5 optimal for most plants)
        final pH = 6.5 + (_random.nextDouble() - 0.5) * 1.0;

        // Generate EC (electrical conductivity) in mS/cm
        final ec = 1.0 + _random.nextDouble() * 1.5;

        // Generate NPK values (nitrogen, phosphorus, potassium)
        final nitrogen = 80.0 + _random.nextDouble() * 100;
        final phosphorus = 40.0 + _random.nextDouble() * 80;
        final potassium = 150.0 + _random.nextDouble() * 150;

        // Generate battery voltage (3.0V to 4.2V)
        final battery = 3.5 + _random.nextDouble() * 0.7;

        // Generate RSSI (-40 to -80 dBm)
        final rssi = -40 - _random.nextInt(40);

        // Generate SNR (5.0 to 12.0 dB)
        final snr = 5.0 + _random.nextDouble() * 7.0;

        data.add(
          SensorData(
            id: 'mock_${device.nodeId}_$i',
            nodeId: device.nodeId,
            counter: globalCounter++,
            deviceType: deviceType,
            soilMoisture: double.parse(
              soilMoisture.clamp(0, 100).toStringAsFixed(1),
            ),
            soilTemperature: double.parse(soilTemperature.toStringAsFixed(1)),
            pH: double.parse(pH.clamp(0, 14).toStringAsFixed(2)),
            ec: double.parse(ec.toStringAsFixed(2)),
            nitrogen: double.parse(nitrogen.toStringAsFixed(1)),
            phosphorus: double.parse(phosphorus.toStringAsFixed(1)),
            potassium: double.parse(potassium.toStringAsFixed(1)),
            battery: double.parse(battery.toStringAsFixed(2)),
            timestamp: timestamp,
            rssi: rssi,
            snr: double.parse(snr.toStringAsFixed(1)),
          ),
        );
      }
    }

    // Sort by timestamp descending
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return data;
  }

  SensorData? getMockLatestSensorData(String nodeId) {
    final data = generateLatestMockSensorData(nodeId: nodeId);
    return data.isNotEmpty ? data.first : null;
  }

  /// Generate continuous mock data stream for demo (updates every 5 seconds)
  Stream<List<SensorData>> getMockSensorDataStream({String? nodeId}) {
    return Stream.periodic(const Duration(seconds: 5), (count) {
      return generateLatestMockSensorData(nodeId: nodeId);
    });
  }

  /// Generate only the latest data for each device (no duplicates)
  /// This simulates nodes/{nodeId}/latest_data from Firebase
  List<SensorData> generateLatestMockSensorData({String? nodeId}) {
    final List<SensorData> data = [];
    final now = DateTime.now();
    int baseCounter = _random.nextInt(1000) + 2000; // Starting counter

    final devicesToGenerate = nodeId != null
        ? _mockDevices.where((d) => d.nodeId == nodeId).toList()
        : _mockDevices;

    // Generate ONE latest record per device - ALWAYS include all devices
    for (final device in devicesToGenerate) {
      const deviceType = 'soil_sensor';

      // Generate soil moisture (20-80%)
      final baseMoisture = device.nodeId == '0x09F8' ? 30.0 : 55.0;
      final soilMoisture = baseMoisture + (_random.nextDouble() - 0.5) * 15;

      // Generate soil temperature (15-35°C)
      double baseTemp = 25.0;
      if (device.nodeId == '0xCC64') baseTemp = 28.0;
      if (device.nodeId == '0x4F70') baseTemp = 26.0;
      if (device.nodeId == '0x09F8') baseTemp = 22.0;

      final hour = now.hour;
      double timeVariation = 0;
      if (hour >= 6 && hour <= 18) {
        timeVariation = 5 * sin((hour - 6) * pi / 12);
      }
      final soilTemperature =
          baseTemp + timeVariation + (_random.nextDouble() - 0.5) * 4;

      // Generate pH (6.0-7.5)
      final pH = 6.5 + (_random.nextDouble() - 0.5) * 1.0;

      // Generate EC (electrical conductivity)
      final ec = 1.0 + _random.nextDouble() * 1.5;

      // Generate NPK
      final nitrogen = 80.0 + _random.nextDouble() * 100;
      final phosphorus = 40.0 + _random.nextDouble() * 80;
      final potassium = 150.0 + _random.nextDouble() * 150;

      // Generate battery voltage (3.0V to 4.2V)
      final battery = 3.5 + _random.nextDouble() * 0.7;

      // Generate RSSI (-40 to -80 dBm)
      final rssi = -40 - _random.nextInt(40);

      // Generate SNR (5.0 to 12.0 dB)
      final snr = 5.0 + _random.nextDouble() * 7.0;

      data.add(
        SensorData(
          id: 'mock_${device.nodeId}_latest',
          nodeId: device.nodeId,
          counter: baseCounter++,
          deviceType: deviceType,
          soilMoisture: double.parse(
            soilMoisture.clamp(0, 100).toStringAsFixed(1),
          ),
          soilTemperature: double.parse(soilTemperature.toStringAsFixed(1)),
          pH: double.parse(pH.clamp(0, 14).toStringAsFixed(2)),
          ec: double.parse(ec.toStringAsFixed(2)),
          nitrogen: double.parse(nitrogen.toStringAsFixed(1)),
          phosphorus: double.parse(phosphorus.toStringAsFixed(1)),
          potassium: double.parse(potassium.toStringAsFixed(1)),
          battery: double.parse(battery.toStringAsFixed(2)),
          timestamp: now,
          rssi: rssi,
          snr: double.parse(snr.toStringAsFixed(1)),
        ),
      );
    }

    return data;
  }

  /// Stream of mock devices with updated timestamps
  Stream<List<Device>> getMockDevicesStream() {
    return Stream.periodic(const Duration(seconds: 10), (count) {
      // Keep device status stable - only update lastSeen timestamp
      final updatedDevices = _mockDevices.map((device) {
        return device.copyWith(
          lastSeen: DateTime.now().subtract(
            Duration(
              seconds: _random.nextInt(60), // 0-60 seconds ago
            ),
          ),
        );
      }).toList();

      // Separate gateways and nodes, then sort stably
      final gateways = <Device>[];
      final nodes = <Device>[];

      for (final device in updatedDevices) {
        if (device.isGateway) {
          gateways.add(device);
        } else {
          nodes.add(device);
        }
      }

      // Sort gateways by MAC (stable order)
      gateways.sort(
        (a, b) =>
            (a.gatewayMAC ?? a.nodeId).compareTo(b.gatewayMAC ?? b.nodeId),
      );

      // Sort nodes by nodeId (stable order)
      nodes.sort((a, b) => a.nodeId.compareTo(b.nodeId));

      // Return: gateways first, then nodes
      return [...gateways, ...nodes];
    });
  }
}
