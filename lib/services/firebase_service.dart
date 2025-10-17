import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../models/gateway_status.dart';
import '../models/routing_table.dart';
import '../config/firebase_config.dart';

/// Firebase Realtime Database service matching firmware schema
/// Database structure:
/// - nodes/{nodeId}/info - Node information
/// - nodes/{nodeId}/latest_data - Latest sensor reading
/// - sensor_data/{nodeId}/{timestamp} - Historical sensor data
/// - gateways/{gatewayId}/status - Gateway status
/// - gateways/{gatewayId}/routing_table - Network routing table
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Realtime Database instance (lazy initialization)
  FirebaseDatabase? _database;
  FirebaseDatabase get database {
    if (_database == null) {
      if (Firebase.apps.isEmpty) {
        throw Exception(
          'Firebase not initialized. Call Firebase.initializeApp() first.',
        );
      }
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FirebaseConfig.databaseUrl,
      );
    }
    return _database!;
  }

  // Database paths matching firmware structure
  static const String nodesPath = 'nodes';
  static const String sensorDataPath = 'sensor_data';
  static const String gatewaysPath = 'gateways';

  /// Get stream of all nodes with their latest data
  /// Returns list of devices with latest sensor readings
  Stream<List<Device>> getNodesStream() {
    final ref = database.ref(nodesPath);

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return <Device>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Device> devices = [];

      data.forEach((nodeId, nodeData) {
        if (nodeData is Map) {
          final nodeMap = Map<String, dynamic>.from(nodeData);

          // Merge info and latest_data
          final info = nodeMap['info'] != null
              ? Map<String, dynamic>.from(nodeMap['info'] as Map)
              : <String, dynamic>{};

          // Create device with info
          final device = Device.fromJson(info, nodeId: nodeId);

          // Attach latest data if available
          if (nodeMap['latest_data'] != null) {
            final latestDataMap = Map<String, dynamic>.from(
              nodeMap['latest_data'] as Map,
            );
            final latestData = SensorData.fromJson(
              latestDataMap,
              nodeId: nodeId,
            );
            devices.add(
              device.copyWith(
                latestData: latestData,
                lastSeen: latestData.timestamp,
              ),
            );
          } else {
            devices.add(device);
          }
        }
      });

      // Sort by last seen (newest first)
      devices.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      return devices;
    });
  }

  /// Get stream of latest sensor data for a specific node
  /// Path: nodes/{nodeId}/latest_data
  Stream<SensorData?> getLatestDataStream(String nodeId) {
    final ref = database.ref('$nodesPath/$nodeId/latest_data');

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return SensorData.fromJson(data, nodeId: nodeId);
    });
  }

  /// Get stream of historical sensor data for a node
  /// Path: sensor_data/{nodeId}/{timestamp}
  /// Returns data sorted by timestamp (newest first)
  Stream<List<SensorData>> getSensorDataStream({
    required String nodeId,
    int limit = 100,
  }) {
    final ref = database.ref('$sensorDataPath/$nodeId');

    return ref.orderByKey().limitToLast(limit).onValue.map((event) {
      if (event.snapshot.value == null) return <SensorData>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<SensorData> sensorDataList = [];

      data.forEach((timestampKey, value) {
        if (value is Map) {
          final sensorMap = Map<String, dynamic>.from(value);
          // Add timestamp from key if not in data
          if (!sensorMap.containsKey('timestamp')) {
            sensorMap['timestamp'] = int.parse(timestampKey);
          }
          sensorDataList.add(
            SensorData.fromJson(sensorMap, nodeId: nodeId, id: timestampKey),
          );
        }
      });

      // Sort by timestamp descending (newest first)
      sensorDataList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sensorDataList;
    });
  }

  /// Get historical sensor data by date range
  /// Path: sensor_data/{nodeId}/{timestamp}
  Future<List<SensorData>> getSensorDataByDateRange({
    required String nodeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$nodeId');
    final snapshot = await ref
        .orderByKey()
        .startAt(startTimestamp.toString())
        .endAt(endTimestamp.toString())
        .get();

    if (snapshot.value == null) return <SensorData>[];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final List<SensorData> sensorDataList = [];

    data.forEach((timestampKey, value) {
      if (value is Map) {
        final sensorMap = Map<String, dynamic>.from(value);
        if (!sensorMap.containsKey('timestamp')) {
          sensorMap['timestamp'] = int.parse(timestampKey);
        }
        sensorDataList.add(
          SensorData.fromJson(sensorMap, nodeId: nodeId, id: timestampKey),
        );
      }
    });

    // Sort by timestamp descending
    sensorDataList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sensorDataList;
  }

  /// Get gateway status stream
  /// Path: gateways/{gatewayId}/status
  Stream<GatewayStatus?> getGatewayStatusStream(String gatewayId) {
    final ref = database.ref('$gatewaysPath/$gatewayId/status');

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return GatewayStatus.fromJson(data, gatewayId: gatewayId);
    });
  }

  /// Get list of all gateways
  Stream<List<String>> getGatewaysStream() {
    final ref = database.ref(gatewaysPath);

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return <String>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.keys.toList();
    });
  }

  /// Get routing table stream from gateway
  /// Path: gateways/{gatewayId}/routing_table
  Stream<RoutingTable?> getRoutingTableStream(String gatewayId) {
    final ref = database.ref('$gatewaysPath/$gatewayId/routing_table');

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RoutingTable.fromJson(data);
    });
  }

  /// Get routing table (one-time fetch)
  Future<RoutingTable?> getRoutingTable(String gatewayId) async {
    final ref = database.ref('$gatewaysPath/$gatewayId/routing_table');
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return RoutingTable.fromJson(data);
  }

  /// Get latest sensor data (one-time fetch)
  Future<SensorData?> getLatestSensorData(String nodeId) async {
    final ref = database.ref('$nodesPath/$nodeId/latest_data');
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return SensorData.fromJson(data, nodeId: nodeId);
  }

  /// Get node info (one-time fetch)
  Future<Device?> getNodeInfo(String nodeId) async {
    final ref = database.ref('$nodesPath/$nodeId/info');
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Device.fromJson(data, nodeId: nodeId);
  }

  /// Update node info
  /// This is typically done by the gateway, but mobile app can update name
  Future<void> updateNodeInfo(
    String nodeId,
    Map<String, dynamic> updates,
  ) async {
    final ref = database.ref('$nodesPath/$nodeId/info');
    await ref.update(updates);
  }

  /// Write sensor data (for testing only - normally done by gateway)
  Future<void> addSensorData(String nodeId, SensorData sensorData) async {
    final timestamp = sensorData.timestamp.millisecondsSinceEpoch ~/ 1000;

    // Write to latest_data
    await database
        .ref('$nodesPath/$nodeId/latest_data')
        .set(sensorData.toJson());

    // Write to historical data
    await database
        .ref('$sensorDataPath/$nodeId/$timestamp')
        .set(sensorData.toJson());
  }

  /// Clean up old sensor data (older than specified days)
  Future<void> cleanupOldData(String nodeId, {int daysToKeep = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$nodeId');
    final snapshot = await ref
        .orderByKey()
        .endAt(cutoffTimestamp.toString())
        .get();

    if (snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      // Delete old entries
      for (var key in data.keys) {
        await ref.child(key).remove();
      }
    }
  }

  /// Check if Firebase is available
  bool isAvailable() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
