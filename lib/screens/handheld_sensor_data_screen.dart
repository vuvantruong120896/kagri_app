import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import '../constants/ble_constants.dart';
import '../services/ble_provisioning_service.dart';
import '../services/firebase_service.dart';
import '../services/device_registry_service.dart';

/// Handheld Sensor Data Reception Screen
///
/// Receives sensor data from Handheld soil sensor devices via BLE.
/// Features:
/// - Real-time sensor data display
/// - Temperature, Moisture, EC, pH, NPK readings
/// - Automatic data reception and parsing
/// - Connection status monitoring
/// - Data export capability (future)
///
/// Device Mode: KAGRI-HHT-XXXX (Handheld in Sensor Data transmission mode)
///
/// Updated: November 2025

class HandheldSensorDataScreen extends StatefulWidget {
  final BluetoothDevice device;

  const HandheldSensorDataScreen({super.key, required this.device});

  @override
  State<HandheldSensorDataScreen> createState() =>
      _HandheldSensorDataScreenState();
}

class _HandheldSensorDataScreenState extends State<HandheldSensorDataScreen> {
  final BleProvisioningService _bleService = BleProvisioningService();
  final FirebaseService _firebaseService = FirebaseService();
  final DeviceRegistryService _deviceRegistry = DeviceRegistryService();

  // Connection state
  bool _isConnecting = false;
  bool _isConnected = false;
  String _statusMessage = 'Bắt đầu...';
  bool _isUploading = false;

  // Sensor data
  Map<String, dynamic> _sensorData = {};
  DateTime? _lastDataReceived;
  int _dataPointsReceived = 0;

  @override
  void initState() {
    super.initState();
    _connectAndReceiveData();
  }

  @override
  void dispose() {
    _bleService.disconnect(widget.device);
    super.dispose();
  }

  // ============================================================================
  // CONNECTION & DATA RECEPTION
  // ============================================================================

  Future<void> _connectAndReceiveData() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Kết nối đến Handheld...';
    });

    try {
      // Connect to device
      await _bleService.connect(widget.device);
      setState(() => _statusMessage = 'Tìm kiếm BLE services...');

      // Get sensor data from device
      await _receiveHandheldSensorData();

      setState(() {
        _isConnected = true;
        _statusMessage = 'Kết nối thành công!';
      });
    } catch (e) {
      print('[SensorData] Error: $e');
      setState(() {
        _isConnected = false;
        _statusMessage = 'Lỗi: ${e.toString()}';
      });

      if (!mounted) return;
      _showError(e.toString());
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _receiveHandheldSensorData() async {
    try {
      setState(() => _statusMessage = 'Chờ dữ liệu cảm biến...');

      // Discover services
      final services = await widget.device.discoverServices();
      print('[SensorData] Found ${services.length} services');

      // Find Sensor Data service
      BluetoothService? sensorService;
      for (final service in services) {
        print('[SensorData] Service: ${service.uuid}');
        if (_matchUuid(
          service.uuid.toString(),
          BleConstants.handheldSensorServiceUuid,
        )) {
          sensorService = service;
          print('[SensorData] ✓ Found Sensor Data service');
          break;
        }
      }

      if (sensorService == null) {
        throw Exception('Sensor Data service not found');
      }

      // Find sensor data characteristic
      BluetoothCharacteristic? sensorDataChar;
      for (final char in sensorService.characteristics) {
        print('[SensorData] Characteristic: ${char.uuid}');
        if (_matchUuid(
          char.uuid.toString(),
          BleConstants.handheldSensorDataCharUuid,
        )) {
          sensorDataChar = char;
          print('[SensorData] ✓ Found Sensor Data characteristic');
          break;
        }
      }

      if (sensorDataChar == null) {
        throw Exception('Sensor Data characteristic not found');
      }

      // Setup listener BEFORE subscribing to avoid missing first notification
      setState(() => _statusMessage = 'Chuẩn bị nhận dữ liệu...');

      bool dataReceived = false;
      late StreamSubscription<List<int>> subscription;

      subscription = sensorDataChar.onValueReceived.listen((value) async {
        if (value.isNotEmpty && !dataReceived) {
          try {
            final dataStr = utf8.decode(value);
            print('[SensorData] Raw data: $dataStr');

            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            print('[SensorData] Parsed data: $data');

            setState(() {
              _sensorData = data;
              _lastDataReceived = DateTime.now();
              _dataPointsReceived++;
              _statusMessage = 'Đã nhận dữ liệu cảm biến!';
              _isUploading = true;
              dataReceived = true;
            });

            // Upload to Firebase immediately after receiving data
            await _uploadToFirebase(data);
          } catch (e) {
            print('[SensorData] Error parsing data: $e');
          }
        }
      });

      // Now subscribe to notifications
      await sensorDataChar.setNotifyValue(true);

      // Wait for sensor data (with timeout)
      setState(() => _statusMessage = 'Chờ dữ liệu cảm biến từ thiết bị....');

      // Wait maximum 10 seconds for data
      await Future.delayed(const Duration(seconds: 10));

      subscription.cancel();

      // Unsubscribe and disconnect to notify Handheld
      if (dataReceived) {
        print('[SensorData] Data received, unsubscribing...');
        try {
          await sensorDataChar.setNotifyValue(false);
          print('[SensorData] Unsubscribed successfully');

          // Wait a moment for unsubscribe to complete
          await Future.delayed(const Duration(milliseconds: 500));

          // Now disconnect to trigger Handheld disconnect callback
          print('[SensorData] Disconnecting from Handheld...');
          await _bleService.disconnect(widget.device);
          print('[SensorData] Disconnected successfully');
        } catch (e) {
          print('[SensorData] Unsubscribe/disconnect error: $e');
        }
      }

      if (!dataReceived) {
        throw Exception('No sensor data received');
      }
    } catch (e) {
      print('[SensorData] Reception error: $e');
      rethrow;
    }
  }

  /// Extract last 2 bytes from BLE device name as nodeID (hex format)
  /// Example: "KAGRI-HHT-65E0" → "0x65E0", "KAGRI-HHT-45A" → "0x45A"
  String _extractNodeIdFromDeviceName(String deviceName) {
    // Get last part (characters after last '-')
    final parts = deviceName.split('-');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      // Take entire last part as nodeID in hex format
      // Examples: "65E0" → "0x65E0", "45A" → "0x45A"
      return '0x${lastPart.toUpperCase()}';
    }
    return '0xFFFF'; // Fallback
  }

  /// Normalize Handheld sensor data to match Node format
  /// Handheld sends: temperature, humidity, ec, pH, N, P, K
  /// Should convert to Node format: soilTemperature, soilMoisture, conductivity, ph, nitrogen, phosphorus, potassium
  Map<String, dynamic> _normalizeSensorData(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};

    // Field mapping: Handheld format -> Node format
    data.forEach((key, value) {
      switch (key.toLowerCase()) {
        case 'temperature':
          normalized['soilTemperature'] = value;
          break;
        case 'humidity':
        case 'moisture':
          normalized['soilMoisture'] = value;
          break;
        case 'ec':
        case 'conductivity':
          normalized['conductivity'] = value;
          break;
        case 'ph':
          normalized['pH'] = value;
          break;
        case 'n':
        case 'nitrogen':
          normalized['nitrogen'] = value;
          break;
        case 'p':
        case 'phosphorus':
          normalized['phosphorus'] = value;
          break;
        case 'k':
        case 'potassium':
          normalized['potassium'] = value;
          break;
        case 'timestamp':
          normalized['timestamp'] = value;
          break;
        default:
          normalized[key] = value;
      }
    });

    return normalized;
  }

  /// Upload sensor data to Firebase
  Future<void> _uploadToFirebase(Map<String, dynamic> sensorData) async {
    try {
      print('[SensorData] Uploading to Firebase...');
      setState(() => _statusMessage = 'Đang tải lên Firebase...');

      // Normalize Handheld data to match Node format
      final normalizedData = _normalizeSensorData(sensorData);
      print('[SensorData] Normalized data: $normalizedData');

      // Extract nodeID from device name (e.g., "65E0" from "KAGRI-HHT-65E0")
      final nodeId = _extractNodeIdFromDeviceName(widget.device.name);
      print('[SensorData] Using nodeID from device name: $nodeId');

      // Register Handheld device if not already registered
      try {
        await _deviceRegistry.registerDevice(
          nodeId: nodeId,
          deviceType: 'handheld',
          displayName: 'Handheld $nodeId',
          location: null,
          notes: 'Soil sensor via BLE',
          firmwareVersion: null,
        );
        print('[SensorData] ✅ Handheld device registered: $nodeId');
      } catch (e) {
        print('[SensorData] Warning: Failed to register device: $e');
        // Continue with data upload even if registration fails
      }

      final success = await _firebaseService.addHandheldSensorData(
        normalizedData,
        nodeId,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          if (success) {
            _statusMessage = '✅ Dữ liệu đã lưu lên Firebase!';
            print('[SensorData] Firebase upload successful');
          } else {
            _statusMessage = '⚠️ Lỗi tải lên Firebase';
            print('[SensorData] Firebase upload failed');
          }
        });
      }
    } catch (e) {
      print('[SensorData] Error uploading to Firebase: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = '❌ Lỗi: ${e.toString()}';
        });
      }
    }
  }

  /// Match UUID (handles both short and long format)
  bool _matchUuid(String uuid1, String uuid2) {
    final u1 = uuid1.toLowerCase().replaceAll('-', '');
    final u2 = uuid2.toLowerCase().replaceAll('-', '');
    return u1 == u2 || u1.contains(u2) || u2.contains(u1);
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            const Text('Lỗi'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to discovery screen
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  Widget _buildSensorReading(
    String label,
    dynamic value,
    String unit, {
    Color? color,
  }) {
    String displayValue = '-';
    if (value != null) {
      if (value is num) {
        displayValue = value.toStringAsFixed(2);
      } else {
        displayValue = value.toString();
      }
    }

    // Default to blue if no color provided
    Color bgColor = color ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: bgColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConnecting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dữ liệu cảm biến Handheld'),
          elevation: 0,
          backgroundColor: Colors.blue[700],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.devices, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thiết bị',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.device.platformName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isConnected ? '🟢 Kết nối' : '🔴 Ngắt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isConnected
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status
              Text(
                'Trạng thái',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    if (_isConnecting || _isUploading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.orange[700],
                          ),
                        ),
                      )
                    else if (_isConnected)
                      Icon(Icons.check_circle, color: Colors.green[700])
                    else
                      Icon(Icons.error, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sensor Data Display
              if (_sensorData.isNotEmpty) ...[
                Text(
                  'Dữ liệu cảm biến',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),

                // Temperature
                _buildSensorReading(
                  'Nhiệt độ',
                  _sensorData['temperature'] ?? _sensorData['temp'],
                  '°C',
                  color: Colors.red,
                ),
                const SizedBox(height: 12),

                // Moisture (now as humidity)
                _buildSensorReading(
                  'Độ ẩm',
                  _sensorData['humidity'] ?? _sensorData['moisture'],
                  '%',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),

                // EC
                _buildSensorReading(
                  'EC',
                  _sensorData['ec'],
                  'mS/cm',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),

                // pH
                _buildSensorReading(
                  'pH',
                  _sensorData['pH'] ?? _sensorData['ph'],
                  '',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),

                // NPK
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorReading(
                        'N',
                        _sensorData['N'] ?? _sensorData['n'],
                        'mg/kg',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSensorReading(
                        'P',
                        _sensorData['P'] ?? _sensorData['p'],
                        'mg/kg',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSensorReading(
                        'K',
                        _sensorData['K'] ?? _sensorData['k'],
                        'mg/kg',
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Timestamp
                if (_lastDataReceived != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cập nhật lần cuối',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastDataReceived!.toString().split('.')[0],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Data points counter
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.data_usage, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Text(
                        'Tổng số lần nhận: $_dataPointsReceived',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Waiting for data
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.blue[700]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Chờ dữ liệu cảm biến...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
