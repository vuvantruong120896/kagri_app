import 'dart:async';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../models/routing_table.dart';
import '../models/gateway_status.dart';
import '../config/firebase_config.dart';
import 'firebase_service.dart';
import 'mock_data_service.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  FirebaseService? _firebaseService;
  final MockDataService _mockDataService = MockDataService();

  // Use mock data flag - initialized from FirebaseConfig
  // Can be toggled at runtime, but default comes from config
  bool useMockData = FirebaseConfig.useMockData;

  FirebaseService get firebaseService {
    if (_firebaseService == null) {
      try {
        _firebaseService = FirebaseService();
      } catch (e) {
        print('Firebase not available: $e');
        // Fall back to mock data if Firebase is not available
        useMockData = true;
        rethrow;
      }
    }
    return _firebaseService!;
  }

  /// Get stream of sensor data for a specific node from sensor_data path
  /// nodeId: Node address in hex format (e.g., "0xCC64")
  Stream<List<SensorData>> getSensorDataStream({required String nodeId}) {
    if (useMockData) {
      return _mockDataService.getMockSensorDataStream(nodeId: nodeId);
    } else {
      try {
        return firebaseService.getSensorDataStream(nodeId: nodeId);
      } catch (e) {
        print('Firebase error, falling back to mock data: $e');
        useMockData = true;
        return _mockDataService.getMockSensorDataStream(nodeId: nodeId);
      }
    }
  }

  /// Get stream of all nodes/devices from routing table only
  Stream<List<Device>> getDevicesStream() {
    if (useMockData) {
      return _mockDataService.getMockDevicesStream();
    } else {
      try {
        return firebaseService.getNodesStream();
      } catch (e) {
        print('Firebase error: $e');
        // Fallback to mock data on error
        useMockData = true;
        return _mockDataService.getMockDevicesStream();
      }
    }
  }

  /// Get latest sensor data for a specific node
  Future<SensorData?> getLatestSensorData(String nodeId) {
    if (useMockData) {
      return Future.value(_mockDataService.getMockLatestSensorData(nodeId));
    } else {
      try {
        return firebaseService.getLatestSensorData(nodeId);
      } catch (e) {
        print('Firebase error, falling back to mock data: $e');
        useMockData = true;
        return Future.value(_mockDataService.getMockLatestSensorData(nodeId));
      }
    }
  }

  /// Get historical sensor data by date range
  Future<List<SensorData>> getSensorDataByDateRange({
    required String nodeId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (useMockData) {
      // For mock data, generate data for the date range
      final data = _mockDataService.generateMockSensorData(
        nodeId: nodeId,
        count: 50,
      );
      return Future.value(
        data.where((item) {
          return item.timestamp.isAfter(startDate) &&
              item.timestamp.isBefore(endDate);
        }).toList(),
      );
    } else {
      try {
        return firebaseService.getSensorDataByDateRange(
          nodeId: nodeId,
          startDate: startDate,
          endDate: endDate,
        );
      } catch (e) {
        print('Firebase error, falling back to mock data: $e');
        useMockData = true;
        final data = _mockDataService.generateMockSensorData(
          nodeId: nodeId,
          count: 50,
        );
        return Future.value(
          data.where((item) {
            return item.timestamp.isAfter(startDate) &&
                item.timestamp.isBefore(endDate);
          }).toList(),
        );
      }
    }
  }

  /// Get stream for a specific device/node
  Stream<Device?> getDeviceStream(String nodeId) {
    if (useMockData) {
      return _mockDataService.getMockDevicesStream().map((devices) {
        try {
          return devices.firstWhere((device) => device.nodeId == nodeId);
        } catch (e) {
          return null;
        }
      });
    } else {
      try {
        // For Firebase, we use getNodesStream and filter
        return firebaseService.getNodesStream().map((devices) {
          try {
            return devices.firstWhere((device) => device.nodeId == nodeId);
          } catch (e) {
            return null;
          }
        });
      } catch (e) {
        print('Firebase error, falling back to mock data: $e');
        useMockData = true;
        return _mockDataService.getMockDevicesStream().map((devices) {
          try {
            return devices.firstWhere((device) => device.nodeId == nodeId);
          } catch (e) {
            return null;
          }
        });
      }
    }
  }

  // Firebase-only methods (for when Firebase is configured)
  Future<void> updateNodeInfo(
    String nodeId,
    Map<String, dynamic> updates, {
    String? gatewayMAC,
  }) {
    return firebaseService.updateNodeInfo(
      nodeId,
      updates,
      gatewayMAC: gatewayMAC,
    );
  }

  Future<void> addSensorData(
    String nodeId,
    SensorData sensorData, {
    String? gatewayMAC,
  }) {
    return firebaseService.addSensorData(
      nodeId,
      sensorData,
      gatewayMAC: gatewayMAC,
    );
  }

  Future<void> cleanupOldData(String nodeId, {int daysToKeep = 7}) {
    return firebaseService.cleanupOldData(nodeId, daysToKeep: daysToKeep);
  }

  /// Get routing table stream from gateway
  /// This returns the mesh network topology
  Stream<RoutingTable?> getRoutingTableStream(String gatewayId) {
    if (useMockData) {
      // For mock data, return null (no routing table)
      return Stream.value(null);
    } else {
      try {
        return firebaseService.getRoutingTableStream(gatewayId);
      } catch (e) {
        print('Firebase error getting routing table: $e');
        return Stream.value(null);
      }
    }
  }

  /// Get list of all gateways
  Stream<List<String>> getGatewaysStream() {
    if (useMockData) {
      // For mock data, return a mock gateway
      return Stream.value(['GW_MOCK']);
    } else {
      try {
        return firebaseService.getGatewaysStream();
      } catch (e) {
        print('Firebase error getting gateways: $e');
        return Stream.value(['GW_MOCK']);
      }
    }
  }

  /// Get gateway status stream
  Stream<GatewayStatus?> getGatewayStatusStream(String gatewayId) {
    if (useMockData) {
      return Stream.value(null);
    } else {
      try {
        return firebaseService.getGatewayStatusStream(gatewayId);
      } catch (e) {
        print('Firebase error getting gateway status: $e');
        return Stream.value(null);
      }
    }
  }

  // Method to switch data source
  void setUseMockData(bool useMock) {
    useMockData = useMock;
  }

  // Check if Firebase is configured
  bool get isFirebaseConfigured => !useMockData;

  // Get data source info
  String get dataSourceInfo => useMockData ? 'Mock Data' : 'Firebase';
}
